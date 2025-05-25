defmodule SocialContentGenerator.Workers.BotWorker do
  @moduledoc """
  Handles background jobs for bot management and polling.
  """

  use Oban.Worker,
    queue: :bots,
    max_attempts: 5

  alias SocialContentGenerator.Meetings
  alias SocialContentGenerator.Services.Recall
  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Bots.Bot
  alias SocialContentGenerator.Meetings.MeetingAttendee
  import Ecto.Query
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "poll_bot", "bot_id" => bot_id}}) do
    case Repo.get(Bot, bot_id) do
      nil ->
        Logger.warning("Bot #{bot_id} not found for polling")
        {:cancel, "Bot not found"}

      %Bot{integration_bot_id: integration_bot_id, join_at: join_at} = bot ->
        now = DateTime.utc_now()

        # Only start polling if it's time to join or past join time
        if join_at && DateTime.compare(now, join_at) == :lt do
          Logger.info("Bot #{bot_id} not ready to join yet (join_at: #{join_at}), rescheduling")

          # Reschedule for join time
          %{action: "poll_bot", bot_id: bot.id}
          |> new(scheduled_at: join_at)
          |> Oban.insert()

          :ok
        else
          poll_bot_status(bot, integration_bot_id)
        end
    end
  end

  def perform(%Oban.Job{
        args: %{"action" => "create_bot", "calendar_event_id" => calendar_event_id}
      }) do
    alias SocialContentGenerator.Calendars

    case Calendars.get_calendar_event(calendar_event_id) do
      nil ->
        Logger.warning("Calendar event #{calendar_event_id} not found for bot creation")
        {:cancel, "Calendar event not found"}

      calendar_event ->
        create_bot_for_calendar_event(calendar_event)
    end
  end

  defp poll_bot_status(%Bot{} = bot, integration_bot_id) do
    case Recall.poll_bot_status(integration_bot_id) do
      {:ok, %{status: "done", transcript: transcript} = bot_data} ->
        # Bot is complete, create meeting now
        Logger.info("Bot #{bot.id} completed, creating meeting with transcript")

        create_meeting_for_completed_bot(bot, transcript, bot_data.meeting_participants)

        :ok

      {:ok, %{status: status}}
      when status in ["in_call_recording", "in_call_not_recording", "call_ended"] ->
        # Meeting is still in progress or processing, reschedule check
        Logger.debug("Bot #{bot.id} status: #{status}, rescheduling poll")

        %{action: "poll_bot", bot_id: bot.id}
        |> new(schedule_in: 60)
        |> Oban.insert()

        :ok

      {:ok, %{status: status}} when status in ["joining_call", "in_waiting_room", "scheduled"] ->
        # Bot is joining, check more frequently
        Logger.debug("Bot #{bot.id} joining meeting, status: #{status}")

        %{action: "poll_bot", bot_id: bot.id}
        |> new(schedule_in: 30)
        |> Oban.insert()

        :ok

      {:error, reason} ->
        Logger.error("Error polling bot #{bot.id}: #{reason}")

        # Update bot status to indicate error
        Bot.changeset(bot, %{status: "inactive"})
        |> Repo.update()

        {:error, reason}
    end
  end

  defp create_meeting_for_completed_bot(bot, transcript, participants) do
    # Get the calendar event associated with this bot
    bot = Repo.preload(bot, [:calendar_events])
    calendar_event = List.first(bot.calendar_events)

    if calendar_event do
      calendar_event = Repo.preload(calendar_event, [:integration])

      # Find the user who owns this integration
      user_integration =
        from(ui in SocialContentGenerator.Users.UserIntegration,
          where: ui.integration_id == ^calendar_event.integration_id,
          preload: [:user]
        )
        |> Repo.one()

      if user_integration do
        # Create meeting with the bot_id and transcript
        case Meetings.create_meeting(%{
               calendar_event_id: calendar_event.id,
               user_id: user_integration.user_id,
               integration_id: calendar_event.integration_id,
               bot_id: bot.id,
               transcript: transcript,
               status: "completed"
             }) do
          {:ok, meeting} ->
            Logger.info("Created meeting #{meeting.id} for completed bot #{bot.id}")

            # Store attendees from bot data
            store_meeting_attendees(meeting, participants)

            # Update bot status
            Bot.changeset(bot, %{status: "inactive"})
            |> Repo.update()

            # Trigger automation processing
            schedule_automation_processing(meeting)

          {:error, reason} ->
            Logger.error(
              "Failed to create meeting for completed bot #{bot.id}: #{inspect(reason)}"
            )
        end
      else
        Logger.error("No user integration found for calendar event #{calendar_event.id}")
      end
    else
      Logger.error("No calendar event found for bot #{bot.id}")
    end
  end

  defp create_bot_for_calendar_event(calendar_event) do
    alias SocialContentGenerator.Calendars
    calendar_event = Repo.preload(calendar_event, [:integration])

    case calendar_event.meeting_url do
      nil ->
        Logger.warning("No meeting URL found for calendar event #{calendar_event.id}")
        {:error, "No meeting URL"}

      meeting_url ->
        # Get join offset from calendar event or default
        join_offset = calendar_event.join_offset_minutes || 5

        case Recall.create_bot_for_calendar_event(calendar_event, join_offset) do
          {:ok, bot_data} ->
            # Calculate join time
            join_at = DateTime.add(calendar_event.start_time, -join_offset * 60, :second)

            # Create bot record
            {:ok, bot} =
              %Bot{}
              |> Bot.changeset(%{
                name: bot_data.name,
                integration_bot_id: bot_data.integration_bot_id,
                status: bot_data.status,
                join_at: join_at,
                configuration: %{
                  recall_status: bot_data.recall_status,
                  join_offset_minutes: join_offset,
                  meeting_platform: Recall.extract_meeting_platform(meeting_url)
                },
                integration_id: calendar_event.integration_id
              })
              |> Repo.insert()

            Calendars.update_calendar_event(calendar_event, %{bot_id: bot.id})

            # Schedule polling to start at join time
            %{action: "poll_bot", bot_id: bot.id}
            |> new(scheduled_at: join_at)
            |> Oban.insert()

            Logger.info("Created bot #{bot.id} for calendar event #{calendar_event.id}")
            :ok

          {:error, reason} ->
            Logger.error(
              "Failed to create bot for calendar event #{calendar_event.id}: #{reason}"
            )

            {:error, reason}
        end
    end
  end

  defp store_meeting_attendees(meeting, participants) when is_list(participants) do
    # Get existing attendees
    existing_attendees =
      from(a in MeetingAttendee, where: a.meeting_id == ^meeting.id)
      |> Repo.all()

    # Convert new attendees data to normalized format
    new_attendees =
      Enum.map(participants, fn participant ->
        %{
          email: participant["email"],
          name: participant["name"] || "Unknown",
          role: if(participant["is_host"], do: "organizer", else: "attendee"),
          meeting_id: meeting.id
        }
      end)

    Logger.debug(
      "Syncing attendees for meeting #{meeting.id}: #{length(existing_attendees)} existing, #{length(new_attendees)} new"
    )

    # Create maps for efficient lookup
    existing_by_email = Map.new(existing_attendees, &{&1.email, &1})
    new_by_email = Map.new(new_attendees, &{&1.email, &1})

    # Find attendees to delete (exist in DB but not in new data)
    emails_to_delete =
      MapSet.difference(
        MapSet.new(Map.keys(existing_by_email)),
        MapSet.new(Map.keys(new_by_email))
      )

    # Find attendees to insert (exist in new data but not in DB)
    emails_to_insert =
      MapSet.difference(
        MapSet.new(Map.keys(new_by_email)),
        MapSet.new(Map.keys(existing_by_email))
      )

    # Find attendees to update (exist in both but data might have changed)
    emails_to_update =
      MapSet.intersection(
        MapSet.new(Map.keys(existing_by_email)),
        MapSet.new(Map.keys(new_by_email))
      )
      |> Enum.filter(fn email ->
        existing = existing_by_email[email]
        new_data = new_by_email[email]

        existing.name != new_data.name || existing.role != new_data.role
      end)

    # Perform deletions
    if not Enum.empty?(emails_to_delete) do
      attendee_ids_to_delete =
        emails_to_delete
        |> Enum.map(&existing_by_email[&1].id)

      {deleted_count, _} =
        from(a in MeetingAttendee, where: a.id in ^attendee_ids_to_delete)
        |> Repo.delete_all()

      Logger.debug("Deleted #{deleted_count} attendees")
    end

    # Perform insertions
    inserted_count =
      Enum.reduce(emails_to_insert, 0, fn email, acc ->
        case %MeetingAttendee{}
             |> MeetingAttendee.changeset(new_by_email[email])
             |> Repo.insert() do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    if inserted_count > 0 do
      Logger.debug("Inserted #{inserted_count} attendees")
    end

    # Perform updates
    updated_count =
      Enum.reduce(emails_to_update, 0, fn email, acc ->
        existing_attendee = existing_by_email[email]
        new_data = new_by_email[email]

        case existing_attendee
             |> MeetingAttendee.changeset(new_data)
             |> Repo.update() do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    if updated_count > 0 do
      Logger.debug("Updated #{updated_count} attendees")
    end

    Logger.info(
      "Synced attendees for meeting #{meeting.id}: #{inserted_count} inserted, #{updated_count} updated, #{Enum.count(emails_to_delete)} deleted"
    )
  end

  defp store_meeting_attendees(_meeting, _), do: :ok

  defp schedule_automation_processing(meeting) do
    # Schedule the existing meeting worker to handle automation
    SocialContentGenerator.Workers.MeetingWorker.new(%{meeting_id: meeting.id})
    |> Oban.insert()
  end

  defp get_join_offset_minutes(event, user) do
    # Priority: event setting > user setting > app config
    event.join_offset_minutes ||
      user.bot_join_offset_minutes ||
      Application.get_env(:social_content_generator, :bot)[:join_offset_minutes]
  end

  @doc """
  Cleans up a bot when note taker is disabled:
  1. Cancels any scheduled poll jobs
  2. Deletes the bot from Recall API
  3. Soft deletes the bot in our database
  """
  def cleanup_bot_for_calendar_event(calendar_event_id) do
    alias SocialContentGenerator.Calendars

    case Calendars.get_calendar_event(calendar_event_id) do
      %{bot_id: nil} ->
        # No bot to clean up
        :ok

      %{bot_id: bot_id} = calendar_event ->
        case Repo.get(Bot, bot_id) do
          nil ->
            # Bot already deleted, just clear the reference
            Calendars.update_calendar_event(calendar_event, %{bot_id: nil})
            :ok

          %Bot{integration_bot_id: integration_bot_id, deleted_at: nil} = bot ->
            Logger.info("Cleaning up bot #{bot_id} for calendar event #{calendar_event_id}")

            # 1. Cancel scheduled poll jobs
            cancel_scheduled_poll_jobs(bot_id)

            # 2. Delete bot from Recall API
            case Recall.delete_bot(integration_bot_id) do
              :ok ->
                Logger.info("Successfully deleted bot #{integration_bot_id} from Recall")

              {:error, reason} ->
                Logger.warning(
                  "Failed to delete bot #{integration_bot_id} from Recall: #{reason}"
                )

                # Continue with soft delete even if Recall deletion fails
            end

            # 3. Soft delete the bot in our database
            Bot.changeset(bot, %{deleted_at: DateTime.utc_now()})
            |> Repo.update()

            # 4. Clear bot reference from calendar event
            Calendars.update_calendar_event(calendar_event, %{bot_id: nil})

            Logger.info("Successfully cleaned up bot #{bot_id}")
            :ok

          %Bot{deleted_at: deleted_at} when not is_nil(deleted_at) ->
            # Bot already soft deleted, just clear the reference
            Calendars.update_calendar_event(calendar_event, %{bot_id: nil})
            :ok
        end

      nil ->
        Logger.warning("Calendar event #{calendar_event_id} not found for bot cleanup")
        {:error, "Calendar event not found"}
    end
  end

  defp cancel_scheduled_poll_jobs(bot_id) do
    # Cancel any scheduled poll jobs for this bot using Oban's clean API
    query =
      from(j in Oban.Job,
        where:
          j.state in ["available", "scheduled"] and
            j.queue == "bots" and
            fragment(
              "?->>'action' = ? AND ?->>'bot_id' = ?",
              j.args,
              "poll_bot",
              j.args,
              ^to_string(bot_id)
            )
      )

    case Oban.cancel_all_jobs(query) do
      {:ok, count} when count > 0 ->
        Logger.info("Cancelled #{count} scheduled poll jobs for bot #{bot_id}")

      {:ok, 0} ->
        Logger.debug("No scheduled poll jobs found for bot #{bot_id}")
    end
  end
end
