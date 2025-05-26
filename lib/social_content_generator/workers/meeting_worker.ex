defmodule SocialContentGenerator.Workers.MeetingWorker do
  @moduledoc """
  Handles background jobs for meeting management.
  """

  use Oban.Worker,
    queue: :meetings,
    max_attempts: 3

  alias SocialContentGenerator.Meetings
  alias SocialContentGenerator.Services.Recall
  alias SocialContentGenerator.Services.SocialMedia
  alias SocialContentGenerator.Services.Email
  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Automations.AutomationOutput
  alias SocialContentGenerator.Automations.Automation
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id}}) do
    case Meetings.get_meeting(meeting_id) do
      nil ->
        {:error, "Meeting not found or deleted"}

      meeting ->
        # This worker now only handles automation generation after meeting completion
        # Bot polling is handled by BotWorker
        if meeting.status == "completed" and meeting.transcript do
          generate_automation_outputs(meeting)
          :ok
        else
          Logger.warning(
            "Meeting #{meeting_id} not ready for automation processing (status: #{meeting.status})"
          )

          :ok
        end
    end
  end

  defp generate_automation_outputs(meeting) do
    # Get all active automations for the user
    automations =
      from(a in Automation,
        where: a.user_id == ^meeting.user_id and a.active == true,
        preload: [:integration, :user]
      )
      |> Repo.all()

    # Generate outputs for each automation
    Enum.each(automations, fn automation ->
      case automation.output_type do
        "social_post" ->
          generate_social_post(meeting, automation)

        "email" ->
          generate_email(meeting, automation)

        _ ->
          {:error, "Unsupported automation output type"}
      end
    end)
  end

  defp generate_social_post(meeting, automation) do
    post_content = SocialMedia.generate_post_content(meeting, automation)

    %AutomationOutput{}
    |> AutomationOutput.changeset(%{
      content: post_content,
      output_type: "social_post",
      status: "draft",
      user_id: meeting.user_id,
      meeting_id: meeting.id,
      automation_id: automation.id,
      metadata: %{
        platform: automation.integration.provider
      }
    })
    |> Repo.insert()
  end

  defp generate_email(meeting, automation) do
    email_content = Email.generate_email_content(meeting, automation)

    %AutomationOutput{}
    |> AutomationOutput.changeset(%{
      content: email_content,
      output_type: "email",
      status: "draft",
      user_id: meeting.user_id,
      meeting_id: meeting.id,
      automation_id: automation.id,
      metadata: %{
        to: meeting.attendees |> Enum.map(& &1.email) |> Enum.join(", "),
        subject: "Follow-up: #{meeting.title}"
      }
    })
    |> Repo.insert()
  end
end
