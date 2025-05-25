defmodule SocialContentGenerator.Workers.EmailWorker do
  @moduledoc """
  Handles background jobs for email sending.
  """

  use Oban.Worker,
    queue: :email,
    max_attempts: 3

  alias SocialContentGenerator.Automations.AutomationOutput
  alias SocialContentGenerator.Services.Email
  alias SocialContentGenerator.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"automation_output_id" => automation_output_id}}) do
    automation_output =
      Repo.get!(AutomationOutput, automation_output_id)
      |> Repo.preload(automation: :user)

    case Email.send_email(
           automation_output.metadata["to"],
           automation_output.metadata["subject"],
           automation_output.content,
           automation_output.automation.user.email,
           automation_output.automation.user.smtp_config
         ) do
      :ok ->
        update_automation_output_status(automation_output, "sent")

      {:error, reason} ->
        # Log error and reschedule
        IO.puts("Error sending email: #{reason}")

        %{automation_output_id: automation_output_id}
        |> new(schedule_in: 300)
        |> Oban.insert()

        :ok
    end
  end

  defp update_automation_output_status(automation_output, status) do
    automation_output
    |> AutomationOutput.changeset(%{status: status})
    |> Repo.update()
  end
end
