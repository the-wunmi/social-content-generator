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
  alias SocialContentGenerator.Meetings.{Meeting, MeetingAttendee}
  import Ecto.Query
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "poll_bot", "bot_id" => bot_id}}) do
    case Repo.get(Bot, bot_id) do
      nil ->
        Logger.warning("Bot #{bot_id} not found for polling")
        {:cancel, "Bot not found"}

      %Bot{integration_bot_id: integration_bot_id} = bot ->
        poll_bot_status(bot, integration_bot_id)
    end
  end

  def perform(%Oban.Job{args: %{"action" => "create_bot", "meeting_id" => meeting_id}}) do
    case Meetings.get_meeting(meeting_id) do
      nil ->
        Logger.warning("Meeting #{meeting_id} not found for bot creation")
        {:cancel, "Meeting not found"}

      meeting ->
        create_bot_for_meeting(meeting)
    end
  end

  def perform(%Oban.Job{
        args: %{
          "action" => "create_meeting_and_bot",
          "calendar_event_id" => calendar_event_id,
          "user_integration_id" => user_integration_id
        }
      }) do
    alias SocialContentGenerator.Calendars
    alias SocialContentGenerator.Users.UserIntegration

    # Get the calendar event and user integration
    calendar_event = Calendars.get_calendar_event(calendar_event_id)

    user_integration =
      Repo.get(UserIntegration, user_integration_id) |> Repo.preload([:user, :integration])

    case {calendar_event, user_integration} do
      {nil, _} ->
        Logger.warning("Calendar event #{calendar_event_id} not found")
        {:cancel, "Calendar event not found"}

      {_, nil} ->
        Logger.warning("User integration #{user_integration_id} not found")
        {:cancel, "User integration not found"}

      {event, ui} ->
        # Check if meeting already exists
        case Meetings.get_meeting(calendar_event_id: event.id) do
          nil ->
            # Create meeting and bot
            case Meetings.create_meeting(%{
                   calendar_event_id: event.id,
                   user_id: ui.user_id,
                   integration_id: ui.integration_id,
                   status: "scheduled"
                 }) do
              {:ok, meeting} ->
                Logger.info(
                  "Created meeting #{meeting.id} for calendar event #{event.id} (scheduled creation)"
                )

                create_bot_for_meeting(meeting)

              {:error, reason} ->
                Logger.error(
                  "Failed to create scheduled meeting for event #{event.id}: #{inspect(reason)}"
                )

                {:error, reason}
            end

          existing_meeting ->
            # Meeting exists, just create bot if needed
            if is_nil(existing_meeting.bot_id) do
              create_bot_for_meeting(existing_meeting)
            else
              Logger.info("Meeting #{existing_meeting.id} already has bot, skipping")
              :ok
            end
        end
    end
  end

  defp poll_bot_status(%Bot{} = bot, integration_bot_id) do
    case Recall.poll_bot_status(integration_bot_id) do
      {:ok, %{status: "done", transcript: transcript} = bot_data} ->
        # Meeting is complete, update meeting and bot
        Logger.info("Bot #{bot.id} completed, updating meeting with transcript")

        meeting = Repo.preload(bot, :meetings) |> Map.get(:meetings) |> List.first()

        if meeting do
          # Update meeting with transcript and completion status
          Meetings.update_meeting(meeting, %{
            transcript: transcript,
            status: "completed"
          })

          # Store attendees from bot data
          store_meeting_attendees(meeting, bot_data.meeting_participants)

          # Update bot status
          Bot.changeset(bot, %{status: "inactive"})
          |> Repo.update()

          # Trigger automation processing
          schedule_automation_processing(meeting)
        end

        :ok

      {:ok, %{status: status}}
      when status in ["in_call_recording", "in_call_not_recording", "call_ended"] ->
        # Meeting is still in progress or processing, reschedule check
        Logger.debug("Bot #{bot.id} status: #{status}, rescheduling poll")

        %{action: "poll_bot", bot_id: bot.id}
        |> new(schedule_in: 60)
        |> Oban.insert()

        :ok

      {:ok, %{status: status}} when status in ["joining_call", "in_waiting_room"] ->
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

        # Update associated meeting status
        meeting = Repo.preload(bot, :meetings) |> Map.get(:meetings) |> List.first()

        if meeting do
          Meetings.update_meeting(meeting, %{status: "failed"})
        end

        {:error, reason}
    end
  end

  defp create_bot_for_meeting(meeting) do
    meeting = Repo.preload(meeting, [:calendar_event, :integration, :user])
    calendar_event = meeting.calendar_event

    case calendar_event.meeting_url do
      nil ->
        Logger.warning("No meeting URL found for meeting #{meeting.id}")
        Meetings.update_meeting(meeting, %{status: "failed"})
        {:error, "No meeting URL"}

      meeting_url ->
        join_offset = get_join_offset_minutes(calendar_event, meeting.user)

        case Recall.create_bot_for_calendar_event(calendar_event, join_offset) do
          {:ok, bot_data} ->
            # Create bot record
            {:ok, bot} =
              %Bot{}
              |> Bot.changeset(%{
                name: bot_data.name,
                integration_bot_id: bot_data.integration_bot_id,
                status: bot_data.status,
                configuration: %{
                  recall_status: bot_data.recall_status,
                  join_offset_minutes: join_offset,
                  meeting_platform: Recall.extract_meeting_platform(meeting_url)
                },
                integration_id: meeting.integration_id
              })
              |> Repo.insert()

            # Update meeting with bot
            Meetings.update_meeting(meeting, %{
              bot_id: bot.id,
              status: "scheduled"
            })

            # Schedule polling
            %{action: "poll_bot", bot_id: bot.id}
            |> new(schedule_in: 60)
            |> Oban.insert()

            Logger.info("Created bot #{bot.id} for meeting #{meeting.id}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to create bot for meeting #{meeting.id}: #{reason}")
            Meetings.update_meeting(meeting, %{status: "failed"})
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
end
