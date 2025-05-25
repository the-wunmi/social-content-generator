defmodule SocialContentGenerator.Workers.CalendarWorker do
  @moduledoc """
  Handles background jobs for calendar event processing.
  """

  require Logger

  use Oban.Worker,
    queue: :calendar,
    max_attempts: 3

  # unique: [period: 300, fields: [:args]]

  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Calendars.GoogleCalendar
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

    # Find events with meeting URLs that need bots
    events_needing_bots =
      Enum.filter(events, fn event ->
        # Event is in the future and has meeting URL and note taker enabled
        # Only if bot doesn't already exist
        event.meeting_url != nil and
          event.note_taker_enabled == true and
          DateTime.compare(event.start_time, now) == :gt and
          is_nil(event.bot_id)
      end)

    Logger.info("Found #{length(events_needing_bots)} events needing bots")

    Enum.each(events_needing_bots, fn event ->
      # Calculate when to create the bot (join_offset minutes before start)
      join_offset_minutes = get_join_offset_minutes(event, user_integration.user)
      bot_creation_time = DateTime.add(event.start_time, -join_offset_minutes * 60, :second)

      if DateTime.compare(bot_creation_time, now) != :gt do
        # Time to create bot now
        create_bot_now(event)
      else
        # Schedule bot creation for later
        schedule_bot_creation(event, bot_creation_time)
      end
    end)
  end

  defp create_bot_now(event) do
    Logger.info("Creating bot for calendar event #{event.id}")

    BotWorker.new(%{action: "create_bot", calendar_event_id: event.id})
    |> Oban.insert()
  end

  defp schedule_bot_creation(event, scheduled_time) do
    Logger.info("Scheduling bot creation for event #{event.id} at #{scheduled_time}")

    BotWorker.new(%{action: "create_bot", calendar_event_id: event.id})
    |> Oban.insert(scheduled_at: scheduled_time)
  end

  defp get_join_offset_minutes(event, user) do
    # Priority: event setting > user setting > app config
    event.join_offset_minutes ||
      user.bot_join_offset_minutes ||
      Application.get_env(:social_content_generator, :bot)[:join_offset_minutes]
  end
end
