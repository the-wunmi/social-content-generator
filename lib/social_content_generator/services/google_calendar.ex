defmodule SocialContentGenerator.Services.GoogleCalendar do
  @moduledoc """
  Pure Google Calendar API client.
  Handles API interactions without database operations.
  """

  @google_calendar_api_url "https://www.googleapis.com/calendar/v3"

  @doc """
  Fetches events from Google Calendar API.
  Returns raw event data without storing in database.
  """
  def fetch_events(access_token, start_time, end_time \\ nil) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    params = build_params(start_time, end_time)

    case HTTPoison.get("#{@google_calendar_api_url}/calendars/primary/events?#{params}", headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)
        {:ok, response["items"] || []}

      {:ok, %{status_code: 401, body: _}} ->
        {:error, :token_expired}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "Failed to fetch events: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to fetch events: #{reason}"}
    end
  end

  @doc """
  Legacy function for backward compatibility.
  Fetches events for the next 7 days.
  """
  def list_events(access_token) do
    now = DateTime.utc_now()
    one_week_from_now = DateTime.add(now, 7 * 24 * 60 * 60, :second)
    fetch_events(access_token, now, one_week_from_now)
  end

  @doc """
  Extracts meeting URL from event data.
  Supports Zoom, Teams, Google Meet, and conference data.
  """
  def extract_meeting_url(event_data) do
    cond do
      url = event_data["hangoutLink"] -> url
      url = extract_conference_url(event_data["conferenceData"]) -> url
      url = extract_zoom_url(event_data["location"]) -> url
      url = extract_teams_url(event_data["location"]) -> url
      url = extract_meet_url(event_data["location"]) -> url
      url = extract_zoom_url(event_data["description"]) -> url
      url = extract_teams_url(event_data["description"]) -> url
      url = extract_meet_url(event_data["description"]) -> url
      true -> nil
    end
  end

  @doc """
  Parses datetime from Google Calendar event data.
  """
  def parse_datetime(%{"dateTime" => date_time}) do
    case DateTime.from_iso8601(date_time) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  def parse_datetime(%{"date" => date}) do
    case DateTime.from_iso8601("#{date}T00:00:00Z") do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  def parse_datetime(_), do: DateTime.utc_now()

  # Private functions

  defp build_params(start_time, end_time) do
    params = %{
      timeMin: DateTime.to_iso8601(start_time),
      singleEvents: true,
      orderBy: "startTime"
    }

    params =
      if end_time do
        Map.put(params, :timeMax, DateTime.to_iso8601(end_time))
      else
        params
      end

    URI.encode_query(params)
  end

  defp extract_zoom_url(text) when is_binary(text) do
    # More comprehensive Zoom URL patterns
    patterns = [
      # Standard join links with optional params
      ~r/https:\/\/[\w-]+\.zoom\.us\/j\/\d+(?:\?[\w=&%-]*)?/,
      # Direct zoom.us links
      ~r/https:\/\/zoom\.us\/j\/\d+(?:\?[\w=&%-]*)?/,
      # Meeting-specific links
      ~r/https:\/\/[\w-]+\.zoom\.us\/meeting\/\d+\/[\w-]+/
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [url] -> url
        _ -> nil
      end
    end)
  end

  defp extract_zoom_url(_), do: nil

  defp extract_teams_url(text) when is_binary(text) do
    # More comprehensive Teams URL patterns
    patterns = [
      ~r/https:\/\/teams\.microsoft\.com\/l\/meetup-join\/[\w%-]+/,
      ~r/https:\/\/teams\.live\.com\/meet\/[\w-]+/,
      ~r/https:\/\/[\w-]+\.teams\.microsoft\.com\/[\w\/-]+/
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [url] -> url
        _ -> nil
      end
    end)
  end

  defp extract_teams_url(_), do: nil

  defp extract_meet_url(text) when is_binary(text) do
    # Google Meet URL patterns
    patterns = [
      ~r/https:\/\/meet\.google\.com\/[\w-]+/,
      ~r/https:\/\/meet\.google\.com\/lookup\/[\w-]+/
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [url] -> url
        _ -> nil
      end
    end)
  end

  defp extract_meet_url(_), do: nil

  defp extract_conference_url(nil), do: nil

  defp extract_conference_url(conference_data) when is_map(conference_data) do
    # Extract from entryPoints - prioritize video entry points
    entry_points = conference_data["entryPoints"] || []

    # Look for video entry point first (most reliable for joining meetings)
    video_entry =
      Enum.find(entry_points, fn entry ->
        entry["entryPointType"] == "video"
      end)

    case video_entry do
      %{"uri" => uri} when is_binary(uri) ->
        uri

      _ ->
        # Fallback to any entry point with a valid URI
        case Enum.find(entry_points, fn entry ->
               is_binary(entry["uri"]) and String.starts_with?(entry["uri"], "http")
             end) do
          %{"uri" => uri} -> uri
          _ -> nil
        end
    end
  end
end
