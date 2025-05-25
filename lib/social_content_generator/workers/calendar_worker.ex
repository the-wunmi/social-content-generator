defmodule SocialContentGenerator.Workers.CalendarWorker do
  @moduledoc """
  Handles background jobs for calendar event processing.
  """

  use Oban.Worker,
    queue: :calendar,
    max_attempts: 3,
    unique: [period: 300, fields: [:args]]

  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Calendars.GoogleCalendar
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

  defp sync_events_only(%UserIntegration{} = user_integration) do
    require Logger

    Logger.info("Manual calendar sync for user_integration #{user_integration.id}")

    now = DateTime.utc_now()
    future_date = DateTime.add(now, 7 * 24 * 60 * 60, :second)

    case GoogleCalendar.fetch_and_store_events(user_integration, now, future_date) do
      {:ok, events} ->
        Logger.info(
          "Successfully synced #{length(events)} events for user_integration #{user_integration.id}"
        )

        {:ok, events}

      {:error, reason} ->
        Logger.warning(
          "Error fetching calendar events for user_integration #{user_integration.id}: #{reason}"
        )

        {:error, reason}
    end
  end

  defp fetch_and_sync_events(%UserIntegration{} = user_integration) do
    require Logger

    Logger.info("Starting calendar sync for user_integration #{user_integration.id}")

    now = DateTime.utc_now()
    future_date = DateTime.add(now, 7 * 24 * 60 * 60, :second)

    case GoogleCalendar.fetch_and_store_events(user_integration, now, future_date) do
      {:ok, events} ->
        Logger.info(
          "Successfully synced #{length(events)} events for user_integration #{user_integration.id}"
        )

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
end
