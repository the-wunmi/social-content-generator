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
          where:
            ui.integration_id == ^calendar_event.integration_id and ui.user_id == ^bot.user_id,
          preload: [:user]
        )
        |> Repo.one()

      if user_integration do
        # Create meeting with the bot_id and transcript
        case Meetings.create_meeting(%{
               calendar_event_id: calendar_event.id,
               user_id: user_integration.user_id,
               integration_id:
                 Recall.get_meeting_platform_integration_id(calendar_event.meeting_url),
               bot_id: bot.id,
               transcript: transcript,
               status: "completed"
             }) do
          {:ok, meeting} ->
            Logger.info("Created meeting #{meeting.id} for completed bot #{bot.id}")

            # Store attendees from bot data
            store_meeting_attendees(meeting, participants, calendar_event)

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
                user_id: calendar_event.user_id,
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

  defp store_meeting_attendees(meeting, participants, _calendar_event)
       when not is_list(participants) do
    Logger.warning(
      "No valid participants data for meeting #{meeting.id}: #{inspect(participants)}"
    )

    :ok
  end

  defp store_meeting_attendees(meeting, participants, calendar_event) do
    # Preload calendar event attendees for name matching
    calendar_event = Repo.preload(calendar_event, [:attendees])

    # Create a lookup map of calendar attendees by normalized name
    calendar_attendees_by_name =
      calendar_event.attendees
      |> Enum.map(fn attendee ->
        {normalize_name(attendee.name), attendee}
      end)
      |> Map.new()

    # Convert participants to meeting attendees with email guessing
    meeting_attendees =
      Enum.map(participants, fn participant ->
        participant_name = participant["name"] || "Unknown Participant"
        normalized_name = normalize_name(participant_name)

        # Try to find matching calendar attendee by name
        guessed_email =
          case Map.get(calendar_attendees_by_name, normalized_name) do
            %{email: email} -> email
            nil -> generate_fallback_email(participant_name)
          end

        %{
          email: guessed_email,
          name: participant_name,
          role: if(participant["is_host"], do: "organizer", else: "attendee"),
          user_id: calendar_event.user_id,
          meeting_id: meeting.id
        }
      end)

    # Insert all attendees (no need to check for existing since meeting is new)
    inserted_count =
      Enum.reduce(meeting_attendees, 0, fn attendee_attrs, acc ->
        case %MeetingAttendee{}
             |> MeetingAttendee.changeset(attendee_attrs)
             |> Repo.insert() do
          {:ok, _} ->
            acc + 1

          {:error, changeset} ->
            Logger.warning("Failed to insert meeting attendee: #{inspect(changeset.errors)}")
            acc
        end
      end)

    Logger.info("Created #{inserted_count} meeting attendees for meeting #{meeting.id}")
  end

  # Helper function to normalize names for matching
  defp normalize_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.trim()
    # Remove common prefixes/suffixes
    |> String.replace(~r/\b(mr|mrs|ms|dr|prof)\.?\s*/i, "")
    # Remove extra whitespace
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_name(_), do: ""

  # Generate a fallback email when no match is found
  defp generate_fallback_email(name) when is_binary(name) do
    # Create a simple email from the name
    email_prefix =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s]/, "")
      |> String.replace(~r/\s+/, ".")
      # Limit length
      |> String.slice(0, 20)

    "#{email_prefix}@unknown.participant"
  end

  defp generate_fallback_email(_), do: "unknown@unknown.participant"

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
