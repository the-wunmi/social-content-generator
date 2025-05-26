defmodule SocialContentGenerator.Workers.MeetingWorker do
  @moduledoc """
  Handles background jobs for meeting management.
  """

  use Oban.Worker,
    queue: :meetings,
    max_attempts: 3

  alias SocialContentGenerator.Meetings
  alias SocialContentGenerator.Services.SocialMedia
  alias SocialContentGenerator.Services.Email
  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Automations.AutomationOutput
  alias SocialContentGenerator.Automations.Automation
  import Ecto.Query
  require Logger

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
    # Preload meeting with necessary associations
    meeting = Repo.preload(meeting, [:calendar_event, :attendees, :bot, :integration])

    # Get all active automations for the user
    automations =
      from(a in Automation,
        where: a.user_id == ^meeting.user_id and a.active == true,
        preload: [:integration, :user]
      )
      |> Repo.all()

    Logger.info("Found #{length(automations)} active automations for user #{meeting.user_id}")

    # Generate outputs for each automation
    Enum.each(automations, fn automation ->
      Logger.info("Processing automation: #{automation.name} (#{automation.output_type})")

      case automation.output_type do
        "social_post" ->
          case generate_social_post(meeting, automation) do
            {:ok, output} ->
              Logger.info("Generated social post output #{output.id}")

            {:error, reason} ->
              Logger.error("Failed to generate social post: #{inspect(reason)}")
          end

        "email" ->
          case generate_email(meeting, automation) do
            {:ok, output} ->
              Logger.info("Generated email output #{output.id}")

            {:error, reason} ->
              Logger.error("Failed to generate email: #{inspect(reason)}")
          end

        _ ->
          Logger.warning("Unsupported automation output type: #{automation.output_type}")
      end
    end)
  end

  defp generate_social_post(meeting, automation) do
    try do
      post_content = SocialMedia.generate_post_content(meeting, automation)

      %AutomationOutput{}
      |> AutomationOutput.changeset(%{
        content: post_content,
        output_type: "social_post",
        status: "draft",
        user_id: meeting.user_id,
        meeting_id: meeting.id,
        automation_id: automation.id
      })
      |> Repo.insert()
    rescue
      error ->
        Logger.error(
          "Failed to generate social post for meeting #{meeting.id}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp generate_email(meeting, automation) do
    case Email.generate_email_content(meeting, automation) do
      {:ok, email_content} ->
        %AutomationOutput{}
        |> AutomationOutput.changeset(%{
          content: email_content,
          output_type: "email",
          status: "draft",
          user_id: meeting.user_id,
          meeting_id: meeting.id,
          automation_id: automation.id
        })
        |> Repo.insert()

      {:error, reason} ->
        Logger.error("Failed to generate email for meeting #{meeting.id}: #{reason}")
        {:error, reason}
    end
  end
end
