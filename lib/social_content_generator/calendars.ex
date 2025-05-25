defmodule SocialContentGenerator.Calendars do
  @moduledoc """
  Context module for managing calendar events and integrations.
  """

  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Calendars.{CalendarEvent, CalendarEventAttendee}
  alias SocialContentGenerator.Integrations
  alias SocialContentGenerator.Calendars.GoogleCalendar

  @doc """
  Gets all upcoming calendar events for a user from the database.
  Automatically triggers smart background sync if data is stale, or immediate sync if force_refresh is true.
  """
  def list_upcoming_events(user_id, opts \\ []) do
    days_ahead = Keyword.get(opts, :days_ahead, 7)
    force_refresh = Keyword.get(opts, :force_refresh, false)

    now = DateTime.utc_now()
    future_date = DateTime.add(now, days_ahead * 24 * 60 * 60, :second)

    # Get user's Google Calendar integrations and events in one efficient query
    {integrations, events} = get_user_calendar_data(user_id, now, future_date)

    if force_refresh do
      # Force immediate sync and return fresh events
      fresh_events =
        integrations
        |> Enum.flat_map(fn user_integration ->
          case GoogleCalendar.fetch_and_store_events(user_integration, now, future_date) do
            {:ok, events} -> events
            {:error, _reason} -> []
          end
        end)
        |> Enum.sort_by(& &1.start_time, DateTime)

      {:ok, fresh_events}
    else
      # Smart sync: only sync if data is stale
      if should_sync_calendar_data?(integrations) do
        schedule_background_sync(integrations)
      end

      {:ok, events}
    end
  end

  @doc """
  Gets a calendar event by ID.
  """
  def get_calendar_event(id) do
    CalendarEvent.not_deleted(CalendarEvent)
    |> where(id: ^id)
    |> preload([:integration, :attendees])
    |> Repo.one()
  end

  @doc """
  Updates a calendar event.
  """
  def update_calendar_event(%CalendarEvent{} = event, attrs) do
    event
    |> CalendarEvent.changeset(attrs)
    |> Repo.update()
  end

  # Private helper functions

  defp get_user_calendar_data(user_id, start_time, end_time) do
    # Single query to get all user integrations with calendar scope
    integrations =
      Integrations.list_user_integrations(user_id: user_id)
      |> Enum.filter(fn ui ->
        ui.integration.provider == "google" and "calendar" in ui.integration.scopes
      end)

    integration_ids = Enum.map(integrations, & &1.integration_id)

    # Get events for the time range if we have integrations
    events =
      if Enum.empty?(integration_ids) do
        []
      else
        CalendarEvent.not_deleted(CalendarEvent)
        |> where([ce], ce.integration_id in ^integration_ids)
        |> where([ce], ce.start_time >= ^start_time and ce.start_time <= ^end_time)
        |> order_by([ce], ce.start_time)
        |> preload([:integration, :attendees])
        |> Repo.all()
      end

    {integrations, events}
  end

  defp should_sync_calendar_data?(integrations) do
    if Enum.empty?(integrations) do
      false
    else
      # Check if any integration hasn't been synced in the last minute
      one_minute_ago = DateTime.add(DateTime.utc_now(), -60, :second)

      Enum.any?(integrations, fn integration ->
        integration.updated_at < one_minute_ago
      end)
    end
  end

  defp schedule_background_sync(integrations) do
    alias SocialContentGenerator.Workers.CalendarWorker

    # Schedule sync jobs with 1-minute delay to avoid immediate execution
    integrations
    |> Enum.each(fn user_integration ->
      %{"user_integration_id" => user_integration.id}
      # 1 minute delay
      |> CalendarWorker.new(schedule_in: 60)
      |> Oban.insert()
    end)
  end
end
