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

  def create(conn, %{"meeting" => meeting_params}) do
    user_id = conn.assigns.current_user.id

    case Meetings.create_meeting(Map.put(meeting_params, "user_id", user_id)) do
      {:ok, meeting} ->
        # Create Recall.ai bot
        case Recall.create_bot(meeting) do
          {:ok, bot} ->
            # Update meeting with bot info
            meeting
            |> Meetings.update_meeting(%{bot: bot})
            |> case do
              {:ok, updated_meeting} ->
                # Queue the first polling job that will watch this meeting until it completes.
                %{meeting_id: updated_meeting.id}
                |> MeetingWorker.new()
                # TODO move away from controller
                |> Oban.insert()

                conn
                |> put_flash(:info, "Meeting created successfully")
                |> redirect(to: ~p"/meetings/#{updated_meeting}")

              {:error, _changeset} ->
                conn
                |> put_flash(:error, "Error updating meeting with bot info")
                |> redirect(to: ~p"/meetings")
            end

          {:error, reason} ->
            conn
            |> put_flash(:error, "Error creating bot: #{reason}")
            |> redirect(to: ~p"/meetings")
        end

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Error creating meeting")
        |> redirect(to: ~p"/meetings")
    end
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
