defmodule SocialContentGenerator.Workers.CalendarWorker do
  @moduledoc """
  Handles background jobs for calendar event processing.
  """

  require Logger

  use Oban.Worker,
    queue: :calendar,
    max_attempts: 3,
    unique: [period: 300, fields: [:args]]

  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Calendars.GoogleCalendar
  alias SocialContentGenerator.Meetings
  alias SocialContentGenerator.Workers.BotWorker
  alias SocialContentGenerator.Repo
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_integration_id" => user_integration_id}}) do
    # Get the user integration with preloaded integration
    user_integration =
      from(ui in UserIntegration,
        where: ui.id == ^user_integration_id and is_nil(ui.deleted_at),
        preload: [:integration]
      )
      |> Repo.one()

    case user_integration do
      nil ->
        # User integration was deleted or doesn't exist
        {:cancel, "User integration not found or deleted"}

      %UserIntegration{integration: %{provider: "google", scopes: scopes}} = ui ->
        # Only process Google Calendar integrations
        if "calendar" in scopes do
          fetch_and_sync_events(ui)
        else
          :ok
        end

      _other ->
        # Not a Google Calendar integration, skip
        :ok
    end
  end

  defp fetch_and_sync_events(%UserIntegration{} = user_integration) do
    require Logger

    Logger.info("Starting calendar sync for user_integration #{user_integration.id}")

    case GoogleCalendar.fetch_and_store_events(user_integration, DateTime.utc_now()) do
      {:ok, events} ->
        Logger.info(
          "Successfully synced #{length(events)} calendar_worker events for user_integration #{user_integration.id}"
        )

        # Process events for meeting bot creation
        process_events_for_bots(events, user_integration)

        # Schedule next sync in 1 hour (3600 seconds)
        schedule_next_sync(user_integration, 3600)
        :ok

      {:error, reason} ->
        Logger.warning(
          "Error fetching calendar events for user_integration #{user_integration.id}: #{reason}"
        )

        # Use attempt number for exponential backoff instead of user_integration.id
        # This ensures proper backoff progression
        attempt = System.system_time(:second) |> rem(3)

        backoff_seconds =
          case attempt do
            # 5 minutes
            0 -> 300
            # 15 minutes
            1 -> 900
            # 1 hour
            2 -> 3600
          end

        Logger.info(
          "Rescheduling calendar sync for user_integration #{user_integration.id} in #{backoff_seconds} seconds due to error"
        )

        schedule_next_sync(user_integration, backoff_seconds)
        {:error, reason}
    end
  end

  defp schedule_next_sync(%UserIntegration{} = user_integration, delay_seconds) do
    require Logger

    scheduled_at = DateTime.add(DateTime.utc_now(), delay_seconds, :second)

    Logger.info(
      "Scheduling next calendar sync for user_integration #{user_integration.id} in #{delay_seconds} seconds (at #{scheduled_at})"
    )

    %{"user_integration_id" => user_integration.id}
    |> new(scheduled_in: delay_seconds)
    |> Oban.insert()
  end

  defp process_events_for_bots(events, user_integration) do
    require Logger

    user_integration = Repo.preload(user_integration, [:user, :integration])
    now = DateTime.utc_now()

    IO.inspect(user_integration)

    # Find events with meeting URLs that need bots and are starting soon
    events_needing_bots =
      Enum.filter(events, fn event ->
        # Event is in the future but within the next 2 hours (to catch events starting soon)
        event.meeting_url != nil and
          event.note_taker_enabled == true and
          DateTime.compare(event.start_time, now) == :gt and
          DateTime.diff(event.start_time, now, :second) <= 7200
      end)

    IO.inspect(events_needing_bots)

    Enum.each(events_needing_bots, fn event ->
      # Check if meeting already exists
      Logger.info("do we need bots")

      case Meetings.get_meeting(calendar_event_id: event.id) do
        nil ->
          # Calculate when to create the meeting and bot (join_offset minutes before start)
          join_offset_minutes = get_join_offset_minutes(event, user_integration.user)
          bot_creation_time = DateTime.add(event.start_time, -join_offset_minutes * 60, :second)

          Logger.info("no meeting:::")

          if DateTime.compare(bot_creation_time, now) != :gt do
            # Time to create meeting and bot now
            create_meeting_and_bot_now(event, user_integration)
          else
            # Schedule meeting and bot creation for later
            schedule_meeting_and_bot_creation(event, user_integration, bot_creation_time)
          end

        existing_meeting ->
          Logger.info("1 meeting:::")

          IO.inspect(existing_meeting)
          # Meeting exists, check if we need to create bot
          if is_nil(existing_meeting.bot_id) do
            join_offset_minutes = get_join_offset_minutes(event, user_integration.user)
            bot_creation_time = DateTime.add(event.start_time, -join_offset_minutes * 60, :second)

            IO.inspect(join_offset_minutes)
            IO.inspect(bot_creation_time)

            if DateTime.compare(bot_creation_time, now) != :gt do
              # Time to create bot now
              BotWorker.new(%{action: "create_bot", meeting_id: existing_meeting.id})
              |> Oban.insert()
            else
              # Schedule bot creation for later
              BotWorker.new(%{action: "create_bot", meeting_id: existing_meeting.id})
              |> Oban.insert(scheduled_at: bot_creation_time)
            end
          end
      end
    end)
  end

  defp create_meeting_and_bot_now(event, user_integration) do
    Logger.info("ermmmm")

    case Meetings.create_meeting(%{
           calendar_event_id: event.id,
           user_id: user_integration.user_id,
           integration_id: user_integration.integration_id,
           status: "scheduled"
         }) do
      {:ok, meeting} ->
        Logger.info(
          "Created meeting #{meeting.id} for calendar event #{event.id} (meeting starting soon)"
        )

        # Create bot immediately
        BotWorker.new(%{action: "create_bot", meeting_id: meeting.id})
        |> Oban.insert()

      {:error, reason} ->
        Logger.error("Failed to create meeting for event #{event.id}: #{inspect(reason)}")
    end
  end

  defp schedule_meeting_and_bot_creation(event, user_integration, scheduled_time) do
    # Schedule a job to create the meeting and bot at the right time
    Logger.info("scheduling", event, user_integration, scheduled_time)

    %{
      action: "create_meeting_and_bot",
      calendar_event_id: event.id,
      user_integration_id: user_integration.id
    }
    |> BotWorker.new(scheduled_at: scheduled_time)
    |> Oban.insert()

    Logger.info("Scheduled meeting and bot creation for event #{event.id} at #{scheduled_time}")
  end

  defp get_join_offset_minutes(event, user) do
    # Priority: event setting > user setting > app config
    event.join_offset_minutes ||
      user.bot_join_offset_minutes ||
      Application.get_env(:social_content_generator, :bot)[:join_offset_minutes]
  end
end
