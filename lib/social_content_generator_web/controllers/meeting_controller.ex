defmodule SocialContentGeneratorWeb.MeetingController do
  use SocialContentGeneratorWeb, :controller

  alias Oban
  alias SocialContentGenerator.Meetings
  alias SocialContentGenerator.Workers.SocialMediaWorker
  alias SocialContentGenerator.Automations.AutomationOutput
  alias SocialContentGenerator.Repo

  def index(conn, _params) do
    user_id = conn.assigns.current_user.id

    meetings =
      Meetings.list_meetings(user_id: user_id)
      |> Repo.preload([:calendar_event, :attendees, :bot, :integration])
      |> Enum.sort_by(& &1.calendar_event.start_time, {:desc, DateTime})

    render(conn, :index, meetings: meetings)
  end

  def show(conn, %{"id" => id}) do
    meeting =
      Meetings.get_meeting(id: id, user_id: conn.assigns.current_user.id)
      |> Repo.preload([
        :calendar_event,
        :attendees,
        :bot,
        :integration,
        automation_outputs: [automation: :integration]
      ])

    case meeting do
      nil ->
        conn
        |> put_flash(:error, "Meeting not found")
        |> redirect(to: ~p"/meetings")

      meeting ->
        # Get user's active automations for manual generation
        automations =
          SocialContentGenerator.Automations.list_automations(
            user_id: conn.assigns.current_user.id
          )
          |> Enum.filter(& &1.active)
          |> Repo.preload([:integration])

        # Group automation outputs by automation and sort by most recent
        automation_outputs_by_automation =
          meeting.automation_outputs
          |> Enum.group_by(& &1.automation)
          |> Enum.sort_by(fn {automation, _outputs} -> automation.name end)

        render(conn, :show,
          meeting: meeting,
          automations: automations,
          automation_outputs_by_automation: automation_outputs_by_automation
        )
    end
  end

  def generate_automation(conn, %{"meeting_id" => meeting_id, "automation_id" => automation_id}) do
    user_id = conn.assigns.current_user.id

    # Verify the meeting belongs to the user
    meeting =
      Meetings.get_meeting(id: meeting_id, user_id: user_id)
      |> Repo.preload([
        :calendar_event,
        :attendees,
        :bot,
        :integration,
        automation_outputs: [automation: :integration]
      ])

    case meeting do
      nil ->
        conn
        |> put_flash(:error, "Meeting not found")
        |> redirect(to: ~p"/meetings")

      meeting ->
        # Verify the automation belongs to the user
        automation =
          SocialContentGenerator.Automations.get_automation(id: automation_id, user_id: user_id)
          |> Repo.preload([:integration])

        case automation do
          nil ->
            conn
            |> put_flash(:error, "Automation not found")
            |> redirect(to: ~p"/meetings/#{meeting_id}")

          automation ->
            # Check if transcript is available
            if meeting.transcript do
              case generate_automation_content(meeting, automation) do
                {:ok, _automation_output} ->
                  conn
                  |> put_flash(
                    :info,
                    "#{String.capitalize(String.replace(automation.output_type, "_", " "))} generated successfully"
                  )
                  |> redirect(to: ~p"/meetings/#{meeting_id}")

                {:error, reason} ->
                  conn
                  |> put_flash(:error, "Error generating content: #{reason}")
                  |> redirect(to: ~p"/meetings/#{meeting_id}")
              end
            else
              conn
              |> put_flash(:error, "Meeting transcript not available yet")
              |> redirect(to: ~p"/meetings/#{meeting_id}")
            end
        end
    end
  end

  def post_to_social_media(conn, %{
        "meeting_id" => meeting_id,
        "automation_output_id" => automation_output_id
      }) do
    user_id = conn.assigns.current_user.id

    # Verify the automation output belongs to the user
    automation_output =
      AutomationOutput
      |> Repo.get(automation_output_id)
      |> Repo.preload([:automation, :meeting])

    case automation_output do
      nil ->
        conn
        |> put_flash(:error, "Automation output not found")
        |> redirect(to: ~p"/meetings/#{meeting_id}")

      %{user_id: ^user_id} ->
        # Schedule the social media posting job
        %{"automation_output_id" => automation_output_id}
        |> SocialMediaWorker.new()
        |> Oban.insert()

        conn
        |> put_flash(
          :info,
          "Post is being published to #{get_platform_display_name(automation_output)}..."
        )
        |> redirect(to: ~p"/meetings/#{meeting_id}")

      _ ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: ~p"/meetings/#{meeting_id}")
    end
  end

  def update(conn, %{
        "meeting_id" => _meeting_id,
        "id" => automation_output_id,
        "automation_output" => automation_output_params
      }) do
    user_id = conn.assigns.current_user.id

    # Verify the automation output belongs to the user
    automation_output =
      AutomationOutput
      |> Repo.get(automation_output_id)
      |> Repo.preload([:automation, :meeting])

    case automation_output do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Automation output not found"})

      %{user_id: ^user_id} ->
        case AutomationOutput.changeset(automation_output, automation_output_params)
             |> Repo.update() do
          {:ok, _updated_output} ->
            conn
            |> put_status(:ok)
            |> json(%{success: true})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update content", details: changeset.errors})
        end

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Unauthorized"})
    end
  end

  defp get_platform_display_name(automation_output) do
    case automation_output.automation.integration.provider do
      "linkedin" -> "LinkedIn"
      "facebook" -> "Facebook"
      "twitter" -> "Twitter"
      platform when is_binary(platform) -> String.capitalize(platform)
      _ -> "social media"
    end
  end

  defp generate_automation_content(meeting, automation) do
    case automation.output_type do
      "social_post" ->
        SocialContentGenerator.Services.SocialMedia.generate_post_content(meeting, automation)
        |> create_automation_output(meeting, automation, "social_post")

      "email" ->
        SocialContentGenerator.Services.Email.generate_email_content(meeting, automation)
        |> create_automation_output(meeting, automation, "email")

      _ ->
        {:error, "Unsupported automation output type"}
    end
  end

  defp create_automation_output(content, meeting, automation, output_type) do
    %AutomationOutput{}
    |> AutomationOutput.changeset(%{
      content: content,
      output_type: output_type,
      status: "draft",
      user_id: meeting.user_id,
      meeting_id: meeting.id,
      automation_id: automation.id
    })
    |> Repo.insert()
  end
end
