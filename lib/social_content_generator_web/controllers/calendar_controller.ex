defmodule SocialContentGeneratorWeb.CalendarController do
  use SocialContentGeneratorWeb, :controller

  alias SocialContentGenerator.Calendars
  alias SocialContentGenerator.Integrations
  alias SocialContentGenerator.Services.OAuth

  def index(conn, params) do
    user_id = conn.assigns.current_user.id
    force_refresh = Map.get(params, "refresh") == "true"

    # Get events with smart sync or immediate refresh
    case Calendars.list_all_events(user_id, force_refresh: force_refresh) do
      {:ok, events} ->
        # Get connection info for UI
        google_calendar_integrations =
          Integrations.list_user_integrations(user_id: user_id)
          |> Enum.filter(fn ui ->
            ui.integration.provider == "google" and "calendar" in ui.integration.scopes
          end)

        render(conn, :index,
          events: events,
          has_calendar_connections: length(google_calendar_integrations) > 0,
          connected_accounts_count: length(google_calendar_integrations),
          is_fresh_data: force_refresh
        )
    end
  end

  def connect_google_calendar(conn, _params) do
    redirect_uri = unverified_url(conn, ~p"/calendar/google/callback")
    auth_url = OAuth.google_auth_url(redirect_uri, :calendar)
    redirect(conn, external: auth_url)
  end

  def google_calendar_callback(conn, %{"code" => code}) do
    redirect_uri = unverified_url(conn, ~p"/calendar/google/callback")

    with {:ok, token_data} <- OAuth.google_exchange_code(code, redirect_uri),
         {:ok, user_info} <- OAuth.google_get_user_info(token_data["access_token"]),
         {:ok, _integration} <-
           create_google_calendar_integration(conn.assigns.current_user, token_data, user_info) do
      conn
      |> put_flash(:info, "Successfully connected Google Calendar account")
      |> redirect(to: ~p"/calendar")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to connect Google Calendar: #{reason}")
        |> redirect(to: ~p"/calendar")
    end
  end

  def update(conn, %{"id" => event_id, "calendar_event" => event_params}) do
    case Calendars.get_calendar_event(event_id) do
      nil ->
        conn
        |> put_flash(:error, "Event not found")
        |> redirect(to: ~p"/calendar")

      event ->
        # Check if event is in the past
        if DateTime.compare(event.end_time, DateTime.utc_now()) == :lt do
          conn
          |> put_flash(:error, "Cannot update past events")
          |> redirect(to: ~p"/calendar")
        else
          # Convert string values to boolean for note_taker_enabled
          normalized_params = normalize_event_params(event_params)

          case Calendars.update_calendar_event(event, normalized_params) do
            {:ok, updated_event} ->
              message =
                case normalized_params["note_taker_enabled"] do
                  true -> "Note taker enabled"
                  false -> "Note taker disabled"
                  _ -> "Event updated"
                end

              conn
              |> put_flash(:info, message)
              |> redirect(to: ~p"/calendar")

            {:error, _changeset} ->
              conn
              |> put_flash(:error, "Failed to update event")
              |> redirect(to: ~p"/calendar")
          end
        end
    end
  end

  defp normalize_event_params(params) do
    case Map.get(params, "note_taker_enabled") do
      "true" -> Map.put(params, "note_taker_enabled", true)
      "false" -> Map.put(params, "note_taker_enabled", false)
      "" -> Map.put(params, "note_taker_enabled", false)
      nil -> Map.put(params, "note_taker_enabled", false)
      value when is_boolean(value) -> params
      _ -> Map.put(params, "note_taker_enabled", false)
    end
  end

  defp create_google_calendar_integration(user, token_data, _user_info) do
    alias SocialContentGenerator.Integrations

    # Get the Google Calendar integration
    integration = Integrations.get_integration(slug: "google-calendar")

    attrs = %{
      integration_id: integration.id,
      access_token: token_data["access_token"],
      refresh_token: token_data["refresh_token"],
      expires_at: DateTime.utc_now() |> DateTime.add(token_data["expires_in"], :second),
      user_id: user.id
    }

    # Check if this Google account is already connected
    existing = Integrations.get_user_integration(user_id: user.id, integration_id: integration.id)

    case existing do
      nil -> Integrations.create_user_integration(attrs)
      user_integration -> Integrations.update_user_integration(user_integration, attrs)
    end
  end
end
