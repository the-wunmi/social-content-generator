defmodule SocialContentGenerator.Workers.CalendarWorker do
  @moduledoc """
  Handles background jobs for calendar event processing.
  """

  use Oban.Worker,
    queue: :calendar,
    max_attempts: 3

  alias SocialContentGenerator.Integrations.Integration
  alias SocialContentGenerator.Calendars.CalendarEvent
  alias SocialContentGenerator.Calendars.CalendarEventAttendee
  alias SocialContentGenerator.Services.GoogleCalendar
  alias SocialContentGenerator.Repo
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"integration_id" => integration_id}}) do
    integration = Repo.get!(Integration, integration_id)

    case GoogleCalendar.list_events(integration.access_token) do
      {:ok, events} ->
        # Process each event
        Enum.each(events, fn event_data ->
          create_calendar_event(event_data, integration_id)
        end)

        :ok

      {:error, reason} ->
        # Log error and reschedule
        IO.puts("Error fetching calendar events: #{reason}")

        %{integration_id: integration_id}
        |> new(schedule_in: 300)
        |> Oban.insert()

        :ok
    end
  end

  defp create_calendar_event(event_data, integration_id) do
    # Extract meeting URL from description or location
    meeting_url = GoogleCalendar.extract_meeting_url(event_data)

    calendar_event_attrs = %{
      integration_event_id: event_data["id"],
      title: event_data["summary"],
      description: event_data["description"],
      start_time: GoogleCalendar.parse_datetime(event_data["start"]),
      end_time: GoogleCalendar.parse_datetime(event_data["end"]),
      location: event_data["location"],
      meeting_url: meeting_url,
      integration_id: integration_id
    }

    {:ok, calendar_event} =
      %CalendarEvent{}
      |> CalendarEvent.changeset(calendar_event_attrs)
      |> Repo.insert()

    # Create attendees
    Enum.each(event_data["attendees"] || [], fn attendee ->
      %CalendarEventAttendee{}
      |> CalendarEventAttendee.changeset(%{
        email: attendee["email"],
        name: attendee["displayName"],
        role: (attendee["organizer"] && "organizer") || "attendee",
        status: attendee["responseStatus"],
        calendar_event_id: calendar_event.id
      })
      |> Repo.insert()
    end)

    calendar_event
  end
end
