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
      |> Repo.preload(automation: :user, meeting: [:attendees, :calendar_event])

    # Generate email recipients and subject dynamically
    to_emails = automation_output.meeting.attendees |> Enum.map(& &1.email) |> Enum.join(", ")
    subject = "Follow-up: #{automation_output.meeting.calendar_event.title}"

    case Email.send_email(
           to_emails,
           subject,
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
