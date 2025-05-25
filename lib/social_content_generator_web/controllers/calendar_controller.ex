defmodule SocialContentGeneratorWeb.CalendarController do
  use SocialContentGeneratorWeb, :controller

  alias SocialContentGenerator.Integrations.Integration
  alias SocialContentGenerator.Services.GoogleCalendar
  alias SocialContentGenerator.Repo
  import Ecto.Query

  def index(conn, _params) do
    user_id = conn.assigns.current_user.id

    # Get user's Google Calendar integration
    integration =
      from(i in Integration,
        where: i.user_id == ^user_id and i.provider == "google",
        limit: 1
      )
      |> Repo.one()

    case integration do
      nil ->
        conn
        |> put_flash(:error, "Please connect your Google Calendar first")
        |> redirect(to: ~p"/settings")

      integration ->
        case GoogleCalendar.list_events(user_id: user_id, integration_id: integration.id) do
          {:ok, events} ->
            render(conn, :index, events: events)

          {:error, reason} ->
            conn
            |> put_flash(:error, "Error fetching calendar events: #{reason}")
            |> redirect(to: ~p"/calendar")
        end
    end
  end
end
