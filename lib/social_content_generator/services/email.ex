defmodule SocialContentGenerator.Services.Email do
  @moduledoc """
  Handles email operations including SMTP configuration and sending.
  """

  alias SocialContentGenerator.Services.OpenAI
  require Logger

  def generate_email_content(meeting_data, automation_data) do
    Logger.info("Email.generate_email_content called")
    Logger.info("Meeting: #{meeting_data.id} - #{meeting_data.calendar_event.title}")
    Logger.info("Automation: #{automation_data.name} (#{automation_data.output_type})")

    case OpenAI.generate_follow_up_email(meeting_data, automation_data) do
      {:ok, content} ->
        Logger.info("OpenAI generated email content successfully")
        Logger.info("Content length: #{String.length(content)} characters")
        {:ok, content}

      {:error, error} ->
        Logger.error("OpenAI email generation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  def send_email(to, subject, body, from, _smtp_config) do
    Logger.info("Sending email...")
    Logger.info("To: #{to}")
    Logger.info("Subject: #{subject}")
    Logger.info("From: #{from}")
    Logger.info("Body length: #{String.length(body)} characters")

    # TODO: Implement actual email sending with SMTP
    Logger.info("Email sending not yet implemented - returning success")
    {:ok, "Email would be sent successfully"}
  end
end
