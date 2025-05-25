defmodule SocialContentGeneratorWeb.MeetingController do
  use SocialContentGeneratorWeb, :controller

  alias Oban
  alias SocialContentGenerator.Meetings
  alias SocialContentGenerator.Services.Recall
  alias SocialContentGenerator.Social.SocialPost
  alias SocialContentGenerator.Workers.MeetingWorker

  def index(conn, _params) do
    user_id = conn.assigns.current_user.id
    meetings = Meetings.list_meetings(user_id: user_id)
    render(conn, :index, meetings: meetings)
  end

  def show(conn, %{"id" => id}) do
    meeting = Meetings.get_meeting(id)
    render(conn, :show, meeting: meeting)
  end

  def generate_post(conn, %{"meeting_id" => meeting_id, "automation_id" => automation_id}) do
    case SocialPost.generate_post(meeting_id, automation_id) do
      {:ok, _automation_output} ->
        conn
        |> put_flash(:info, "Post generated successfully")
        |> redirect(to: ~p"/meetings/#{meeting_id}")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Error generating post: #{reason}")
        |> redirect(to: ~p"/meetings/#{meeting_id}")
    end
  end
end
