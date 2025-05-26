defmodule SocialContentGenerator.Services.SocialMedia do
  @moduledoc """
  Handles integration with various social media platforms.
  """

  alias SocialContentGenerator.Services.OpenAI
  require Logger

  def generate_post_content(meeting_data, automation_data) do
    Logger.info("SocialMedia.generate_post_content called")
    Logger.info("Meeting: #{meeting_data.id} - #{meeting_data.calendar_event.title}")
    Logger.info("Automation: #{automation_data.name} (#{automation_data.output_type})")
    Logger.info("Integration: #{automation_data.integration.provider}")

    case OpenAI.generate_social_post(meeting_data, automation_data) do
      {:ok, content} ->
        Logger.info("OpenAI generated content successfully")
        Logger.info("Content length: #{String.length(content)} characters")
        {:ok, content}

      {:error, error} ->
        Logger.error("OpenAI social post generation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  def post_to_linkedin(content, access_token) do
    Logger.info("Posting to LinkedIn")
    Logger.info("Content length: #{String.length(content)} characters")
    Logger.info("Access token present: #{!is_nil(access_token)}")

    # Implement LinkedIn posting logic here
    # This would use the LinkedIn API to post the content
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        text: content
      })

    Logger.info("Making LinkedIn API request")

    case HTTPoison.post("https://api.linkedin.com/v2/ugcPosts", body, headers) do
      {:ok, %{status_code: 201}} ->
        Logger.info("Successfully posted to LinkedIn")
        {:ok, "Posted to LinkedIn"}

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("LinkedIn API error: #{status_code}")
        Logger.error("Response: #{response_body}")
        {:error, "Failed to post to LinkedIn: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        Logger.error("LinkedIn HTTP error: #{reason}")
        {:error, "Failed to post to LinkedIn: #{reason}"}
    end
  end

  def post_to_facebook(content, access_token) do
    Logger.info("Posting to Facebook")
    Logger.info("Content length: #{String.length(content)} characters")
    Logger.info("Access token present: #{!is_nil(access_token)}")

    # Implement Facebook posting logic here
    # This would use the Facebook API to post the content
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        message: content
      })

    Logger.info("Making Facebook API request")

    case HTTPoison.post("https://graph.facebook.com/v18.0/me/feed", body, headers) do
      {:ok, %{status_code: 200}} ->
        Logger.info("Successfully posted to Facebook")
        {:ok, "Posted to Facebook"}

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("Facebook API error: #{status_code}")
        Logger.error("Response: #{response_body}")
        {:error, "Failed to post to Facebook: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Facebook HTTP error: #{reason}")
        {:error, "Failed to post to Facebook: #{reason}"}
    end
  end
end
