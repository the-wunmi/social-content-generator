defmodule SocialContentGenerator.Services.GoogleCalendar do
  @moduledoc """
  Handles integration with Google Calendar.
  """

  @google_calendar_api_url "https://www.googleapis.com/calendar/v3"

  def list_events(access_token) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
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
        {:ok, response["items"]}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "Failed to fetch events: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to fetch events: #{reason}"}
    end
  end

  def extract_meeting_url(event_data) do
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

  def parse_datetime(%{"dateTime" => date_time}), do: DateTime.from_iso8601!(date_time)
  def parse_datetime(%{"date" => date}), do: DateTime.from_iso8601!("#{date}T00:00:00Z")
end
