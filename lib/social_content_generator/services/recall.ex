defmodule SocialContentGenerator.Services.Recall do
  @moduledoc """
  Handles integration with Recall.ai for meeting transcription.
  """

  @recall_api_url "https://api.recall.ai/api/v1"
  @recall_api_key System.get_env("RECALL_API_KEY")

  def create_bot(meeting_url, join_offset_minutes) do
    headers = [
      {"Authorization", "Bearer #{@recall_api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        meeting_url: meeting_url,
        join_offset_minutes: join_offset_minutes,
        bot_name: "Social Content Generator Bot"
      })

    case HTTPoison.post("#{@recall_api_url}/bots", body, headers) do
      {:ok, %{status_code: 201, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)

        {:ok,
         %{
           name: "Social Content Generator Bot",
           integration_bot_id: response["id"],
           status: "active",
           configuration: %{
             meeting_url: meeting_url,
             join_offset_minutes: join_offset_minutes
           }
         }}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "Failed to create bot: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to create bot: #{reason}"}
    end
  end

  def get_bot_status(bot_id) do
    headers = [
      {"Authorization", "Bearer #{@recall_api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get("#{@recall_api_url}/bots/#{bot_id}", headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)
        {:ok, response["status"]}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "Failed to get bot status: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to get bot status: #{reason}"}
    end
  end

  def get_bot_transcript(bot_id) do
    headers = [
      {"Authorization", "Bearer #{@recall_api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get("#{@recall_api_url}/bots/#{bot_id}/transcript", headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)
        {:ok, response["transcript"]}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "Failed to get transcript: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to get transcript: #{reason}"}
    end
  end

  def poll_bot_status(bot_id) do
    case get_bot_status(bot_id) do
      {:ok, "completed"} ->
        case get_bot_transcript(bot_id) do
          {:ok, transcript} -> {:ok, transcript}
          error -> error
        end

      {:ok, status} ->
        {:ok, status}

      error ->
        error
    end
  end

  # Convenience wrapper that accepts a %Meeting{} struct.
  def create_bot(%{meeting_url: meeting_url}) do
    join_offset = Application.get_env(:social_content_generator, :bot_join_offset_minutes, 5)
    create_bot(meeting_url, join_offset)
  end
end
