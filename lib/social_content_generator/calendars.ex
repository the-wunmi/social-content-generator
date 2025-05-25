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
  Gets all calendar events for a user from the database.
  Automatically triggers smart background sync if data is stale, or immediate sync if force_refresh is true.
  """
  def list_all_events(user_id, opts \\ []) do
    force_refresh = Keyword.get(opts, :force_refresh, false)

    # Get user's Google Calendar integrations and events in one efficient query
    {integrations, events} = get_user_calendar_data(user_id)

    if force_refresh do
      # Force immediate sync by calling CalendarWorker directly (ensures 100% consistency)
      alias SocialContentGenerator.Workers.CalendarWorker

      integrations
      |> Enum.each(fn user_integration ->
        # Create a fake Oban job and call perform directly
        job = %Oban.Job{args: %{"user_integration_id" => user_integration.id}}
        # TODO timeout after maybe 30s if slow, so handle events available already
        CalendarWorker.perform(job)
      end)

      # After sync, get fresh events from database (same as normal flow)
      {_integrations, fresh_events} = get_user_calendar_data(user_id)
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

  defp get_user_calendar_data(user_id) do
    # Single query to get all user integrations with calendar scope
    integrations =
      Integrations.list_user_integrations(user_id: user_id)
      |> Enum.filter(fn ui ->
        ui.integration.provider == "google" and "calendar" in ui.integration.scopes
      end)

    integration_ids = Enum.map(integrations, & &1.integration_id)

    # Get all events if we have integrations
    events =
      if Enum.empty?(integration_ids) do
        []
      else
        CalendarEvent.not_deleted(CalendarEvent)
        |> where([ce], ce.integration_id in ^integration_ids)
        |> order_by([ce], desc: ce.start_time)
        |> preload([:integration, :attendees])
        |> Repo.all()
      end

    {integrations, events}
  end

  # Helper functions for sync time ranges
  defp get_sync_start_time do
    # Fetch events from 30 days ago to capture recent past events
    DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)
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
      # TODO change to 60s
      |> CalendarWorker.new(schedule_in: 5)
      |> Oban.insert()
    end)
  end
end
