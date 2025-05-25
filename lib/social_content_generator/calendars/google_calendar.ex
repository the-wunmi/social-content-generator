defmodule SocialContentGenerator.Calendars.GoogleCalendar do
  @moduledoc """
  Handles integration with Google Calendar.
  """

  alias SocialContentGenerator.Calendars.CalendarEvent
  alias SocialContentGenerator.Calendars.CalendarEventAttendee
  alias SocialContentGenerator.Repo

  @google_calendar_api_url "https://www.googleapis.com/calendar/v3"

  def list_events(user_id, integration_id) do
    user_integration =
      Repo.get_by!(UserIntegration, user_id: user_id, integration_id: integration_id)

    headers = [
      {"Authorization", "Bearer #{user_integration.access_token}"},
      {"Content-Type", "application/json"}
    ]

    # Get events for the next 7 days
    now = DateTime.utc_now()
    one_week_from_now = DateTime.add(now, 7 * 24 * 60 * 60, :second)

    params =
      URI.encode_query(%{
        timeMin: DateTime.to_iso8601(now),
        timeMax: DateTime.to_iso8601(one_week_from_now),
        singleEvents: true,
        orderBy: "startTime"
      })

    case HTTPoison.get("#{@google_calendar_api_url}/calendars/primary/events?#{params}", headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)
        events = Enum.map(response["items"], &create_calendar_event(&1, integration_id))
        {:ok, events}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "Failed to fetch events: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to fetch events: #{reason}"}
    end
  end

  defp create_calendar_event(event_data, integration_id) do
    # Extract meeting URL from description or location
    meeting_url = extract_meeting_url(event_data)

    calendar_event_attrs = %{
      integration_event_id: event_data["id"],
      title: event_data["summary"],
      description: event_data["description"],
      start_time: parse_datetime(event_data["start"]),
      end_time: parse_datetime(event_data["end"]),
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

  defp extract_meeting_url(event_data) do
    cond do
      url = extract_zoom_url(event_data["description"]) -> url
      url = extract_zoom_url(event_data["location"]) -> url
      url = extract_teams_url(event_data["description"]) -> url
      url = extract_teams_url(event_data["location"]) -> url
      url = extract_meet_url(event_data["description"]) -> url
      url = extract_meet_url(event_data["location"]) -> url
      true -> nil
    end
  end

  defp extract_zoom_url(text) when is_binary(text) do
    case Regex.run(~r/https:\/\/[\w-]+\.zoom\.us\/j\/\d+/, text) do
      [url] -> url
      _ -> nil
    end
  end

  defp extract_zoom_url(_), do: nil

  defp extract_teams_url(text) when is_binary(text) do
    case Regex.run(~r/https:\/\/teams\.microsoft\.com\/l\/meetup-join\/[\w-]+/, text) do
      [url] -> url
      _ -> nil
    end
  end

  defp extract_teams_url(_), do: nil

  defp extract_meet_url(text) when is_binary(text) do
    case Regex.run(~r/https:\/\/meet\.google\.com\/[\w-]+/, text) do
      [url] -> url
      _ -> nil
    end
  end

  defp extract_meet_url(_), do: nil

  defp parse_datetime(%{"dateTime" => date_time}), do: DateTime.from_iso8601(date_time)
  defp parse_datetime(%{"date" => date}), do: DateTime.from_iso8601("#{date}T00:00:00Z")
end
