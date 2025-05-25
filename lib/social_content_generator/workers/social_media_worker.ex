defmodule SocialContentGenerator.Workers.SocialMediaWorker do
  @moduledoc """
  Handles background jobs for social media posting.
  """

  use Oban.Worker,
    queue: :social_media,
    max_attempts: 3

  alias SocialContentGenerator.Automations.AutomationOutput
  alias SocialContentGenerator.Services.SocialMedia
  alias SocialContentGenerator.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"automation_output_id" => automation_output_id}}) do
    automation_output =
      Repo.get!(AutomationOutput, automation_output_id)
      |> Repo.preload(automation: :integration)

    case automation_output.automation.integration.provider do
      "linkedin" ->
        case SocialMedia.post_to_linkedin(
               automation_output.content,
               automation_output.automation.integration.access_token
             ) do
          :ok ->
            update_automation_output_status(automation_output, "posted")

          error ->
            error
        end

      "facebook" ->
        case SocialMedia.post_to_facebook(
               automation_output.content,
               automation_output.automation.integration.access_token
             ) do
          :ok ->
            update_automation_output_status(automation_output, "posted")

          error ->
            error
        end

      _ ->
        {:error, "Unsupported social media platform"}
    end
  end

  defp update_automation_output_status(automation_output, status) do
    automation_output
    |> AutomationOutput.changeset(%{status: status})
    |> Repo.update()
  end
end
