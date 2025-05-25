defmodule SocialContentGenerator.Calendars.GoogleCalendar do
  @moduledoc """
  Handles integration with Google Calendar.
  """

  alias SocialContentGenerator.Integrations
  alias SocialContentGenerator.Integrations.Integration
  alias SocialContentGenerator.Calendars.CalendarEvent
  alias SocialContentGenerator.Calendars.CalendarEventAttendee
  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Repo
  import Ecto.Query

  @google_calendar_api_url "https://www.googleapis.com/calendar/v3"

  @doc """
  Fetches events from Google Calendar API and stores them in the database.
  """
  def fetch_and_store_events(%UserIntegration{} = user_integration, start_time) do
    headers = [
      {"Authorization", "Bearer #{user_integration.access_token}"},
      {"Content-Type", "application/json"}
    ]

    params =
      URI.encode_query(%{
        timeMin: DateTime.to_iso8601(start_time),
        singleEvents: true,
        orderBy: "startTime"
      })

    case HTTPoison.get("#{@google_calendar_api_url}/calendars/primary/events?#{params}", headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)

        events =
          Enum.map(response["items"], &upsert_calendar_event(&1, user_integration.integration_id))

        {:ok, events}

      {:ok, %{status_code: 401, body: _}} ->
        # Token expired, try to refresh
        case refresh_token_if_needed(user_integration) do
          {:ok, refreshed_integration} ->
            fetch_and_store_events(refreshed_integration, start_time)

          {:error, reason} ->
            {:error, "Authentication failed: #{reason}"}
        end

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "Failed to fetch events: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to fetch events: #{reason}"}
    end
  end

  @doc """
  Legacy function for backward compatibility.
  """
  def list_events(user_id, integration_id) do
    user_integration =
      Integrations.get_user_integration(user_id: user_id, integration_id: integration_id)

    # Fetch events from 30 days ago onwards (no end limit)
    start_time = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)

    fetch_and_store_events(user_integration, start_time)
  end

  defp upsert_calendar_event(event_data, integration_id) do
    # Extract meeting URL from description or location
    meeting_url = extract_meeting_url(event_data)
    integration_event_id = event_data["id"]

    calendar_event_attrs = %{
      integration_event_id: integration_event_id,
      title: event_data["summary"] || "Untitled Event",
      description: event_data["description"],
      start_time: parse_datetime(event_data["start"]),
      end_time: parse_datetime(event_data["end"]),
      location: event_data["location"],
      meeting_url: meeting_url,
      integration_id: integration_id
    }

    # Check if event already exists
    existing_event =
      CalendarEvent.not_deleted(CalendarEvent)
      |> where(
        [ce],
        ce.integration_event_id == ^integration_event_id and ce.integration_id == ^integration_id
      )
      |> Repo.one()

    calendar_event =
      case existing_event do
        nil ->
          # Create new event
          {:ok, event} =
            %CalendarEvent{}
            |> CalendarEvent.changeset(calendar_event_attrs)
            |> Repo.insert()

          event

        existing ->
          # Update existing event
          {:ok, event} =
            existing
            |> CalendarEvent.changeset(calendar_event_attrs)
            |> Repo.update()

          event
      end

    # Efficiently sync attendees
    sync_attendees(calendar_event, event_data["attendees"] || [])

    calendar_event
  end

  defp sync_attendees(calendar_event, new_attendees_data) do
    # Get existing attendees
    existing_attendees =
      from(a in CalendarEventAttendee, where: a.calendar_event_id == ^calendar_event.id)
      |> Repo.all()

    # Convert new attendees data to normalized format
    new_attendees =
      Enum.map(new_attendees_data, fn attendee ->
        %{
          email: attendee["email"],
          name: attendee["displayName"],
          role: (attendee["organizer"] && "organizer") || "attendee",
          status: attendee["responseStatus"],
          calendar_event_id: calendar_event.id
        }
      end)

    require Logger

    Logger.debug(
      "Syncing attendees for event #{calendar_event.id}: #{length(existing_attendees)} existing, #{length(new_attendees)} new"
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

        existing.name != new_data.name ||
          existing.role != new_data.role ||
          existing.status != new_data.status
      end)

    # Perform deletions
    if not Enum.empty?(emails_to_delete) do
      attendee_ids_to_delete =
        emails_to_delete
        |> Enum.map(&existing_by_email[&1].id)

      {deleted_count, _} =
        from(a in CalendarEventAttendee, where: a.id in ^attendee_ids_to_delete)
        |> Repo.delete_all()

      Logger.debug("Deleted #{deleted_count} attendees")
    end

    # Perform insertions
    inserted_count =
      Enum.reduce(emails_to_insert, 0, fn email, acc ->
        case %CalendarEventAttendee{}
             |> CalendarEventAttendee.changeset(new_by_email[email])
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
             |> CalendarEventAttendee.changeset(new_data)
             |> Repo.update() do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    if updated_count > 0 do
      Logger.debug("Updated #{updated_count} attendees")
    end
  end

  defp refresh_token_if_needed(%UserIntegration{} = user_integration) do
    alias SocialContentGenerator.Services.OAuth

    case OAuth.refresh_token(user_integration) do
      {:ok, token_data} ->
        attrs = %{
          access_token: token_data["access_token"],
          expires_at: DateTime.utc_now() |> DateTime.add(token_data["expires_in"], :second)
        }

        case Repo.update(UserIntegration.changeset(user_integration, attrs)) do
          {:ok, updated_integration} -> {:ok, updated_integration}
          {:error, changeset} -> {:error, "Failed to update token: #{inspect(changeset.errors)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_meeting_url(event_data) do
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

  defp parse_datetime(%{"dateTime" => date_time}) do
    case DateTime.from_iso8601(date_time) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_datetime(%{"date" => date}) do
    case DateTime.from_iso8601("#{date}T00:00:00Z") do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_datetime(_), do: DateTime.utc_now()
end
