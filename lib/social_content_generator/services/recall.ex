defmodule SocialContentGenerator.Services.Recall do
  @moduledoc """
  Service for interacting with the Recall.ai API.
  """

  alias SocialContentGenerator.Services.ApiClient
  require Logger

  @recall_api_url "https://us-east-1.recall.ai/api/v1"

  def create_bot(meeting_url, opts \\ []) do
    api_key = ApiClient.recall_api_key()

    headers = [
      {"Authorization", "Token #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    # Build bot configuration
    bot_config = %{
      meeting_url: meeting_url,
      bot_name: opts[:bot_name] || "Social Content Generator Bot",
      transcription_options: %{
        provider: "meeting_captions"
      }
    }

    # Add join_at if provided (for scheduled bots)
    bot_config =
      case opts[:join_at] do
        nil -> bot_config
        join_at -> Map.put(bot_config, :join_at, DateTime.to_iso8601(join_at))
      end

    body = Jason.encode!(bot_config)

    case HTTPoison.post("#{@recall_api_url}/bot", body, headers) do
      {:ok, %{status_code: 201, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)

        Logger.info("Successfully created recall bot: #{response["id"]}")

        {:ok,
         %{
           name: bot_config.bot_name,
           integration_bot_id: response["id"],
           status: "active",
           recall_status: get_latest_status_code(response, "unknown")
         }}

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("Failed to create recall bot: #{status_code} - #{response_body}")
        {:error, "Failed to create bot: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Failed to create recall bot: #{reason}")
        {:error, "Failed to create bot: #{reason}"}
    end
  end

  def get_bot_status(bot_id) do
    api_key = ApiClient.recall_api_key()

    headers = [
      {"Authorization", "Token #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get("#{@recall_api_url}/bot/#{bot_id}", headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)

        # Get the latest status from status_changes
        latest_status = get_latest_status_code(response, "scheduled")

        {:ok,
         %{
           status: latest_status,
           meeting_participants: response["meeting_participants"] || [],
           meeting_metadata: response["meeting_metadata"] || %{},
           video_url: response["video_url"],
           audio_url: response["audio_url"]
         }}

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("Failed to get bot status for #{bot_id}: #{status_code} - #{response_body}")
        {:error, "Failed to get bot status: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Failed to get bot status for #{bot_id}: #{reason}")
        {:error, "Failed to get bot status: #{reason}"}
    end
  end

  def get_bot_transcript(bot_id) do
    api_key = ApiClient.recall_api_key()

    headers = [
      {"Authorization", "Token #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get("#{@recall_api_url}/bot/#{bot_id}/transcript", headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, response} = Jason.decode(response_body)

        # Format transcript from the segments array
        transcript_text =
          response
          |> Enum.map(fn segment ->
            speaker = segment["speaker"] || "Unknown"

            # Extract text from all words in this segment
            words_text =
              segment["words"]
              |> Enum.map(fn word -> word["text"] || "" end)
              |> Enum.join(" ")

            "#{speaker}: #{words_text}"
          end)
          |> Enum.join("\n")

        {:ok, transcript_text}

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("Failed to get transcript for #{bot_id}: #{status_code} - #{response_body}")
        {:error, "Failed to get transcript: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Failed to get transcript for #{bot_id}: #{reason}")
        {:error, "Failed to get transcript: #{reason}"}
    end
  end

  def poll_bot_status(bot_id) do
    Logger.info(bot_id)

    case get_bot_status(bot_id) do
      {:ok, %{status: "done"} = bot_data} ->
        IO.inspect(bot_data)
        # Meeting is complete, get transcript

        case get_bot_transcript(bot_id) do
          {:ok, transcript} ->
            {:ok, Map.put(bot_data, :transcript, transcript)}

          error ->
            Logger.warning(
              "Failed to get transcript for completed bot #{bot_id}: #{inspect(error)}"
            )

            {:ok, bot_data}
        end

      {:ok, %{status: status} = bot_data}
      when status in ["in_call_recording", "in_call_not_recording"] ->
        # Meeting is in progress
        {:ok, bot_data}

      {:ok, %{status: "call_ended"} = bot_data} ->
        # Call ended but processing not complete yet
        {:ok, bot_data}

      {:ok, %{status: status} = bot_data}
      when status in ["joining_call", "in_waiting_room", "scheduled"] ->
        # Bot is joining or waiting
        {:ok, bot_data}

      {:ok, %{status: "fatal"} = bot_data} ->
        # Bot encountered a fatal error
        {:error, "Bot encountered fatal error: #{inspect(bot_data)}"}

      {:ok, %{status: status} = bot_data} ->
        # Unknown status, log and continue
        Logger.warning("Unknown bot status for #{bot_id}: #{status}")
        {:ok, bot_data}

      error ->
        error
    end
  end

  def extract_meeting_platform(meeting_url) when is_binary(meeting_url) do
    cond do
      String.contains?(meeting_url, "zoom.us") -> "zoom"
      String.contains?(meeting_url, "teams.microsoft.com") -> "teams"
      String.contains?(meeting_url, "meet.google.com") -> "google_meet"
      String.contains?(meeting_url, "webex.com") -> "webex"
      String.contains?(meeting_url, "gotomeeting.com") -> "gotomeeting"
      true -> "unknown"
    end
  end

  def extract_meeting_platform(_), do: "unknown"

  def delete_bot(bot_id) do
    api_key = ApiClient.recall_api_key()

    headers = [
      {"Authorization", "Token #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.delete("#{@recall_api_url}/bot/#{bot_id}", headers) do
      {:ok, %{status_code: 204}} ->
        Logger.info("Successfully deleted recall bot: #{bot_id}")
        :ok

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("Failed to delete recall bot #{bot_id}: #{status_code} - #{response_body}")
        {:error, "Failed to delete bot: #{status_code} - #{response_body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Failed to delete recall bot #{bot_id}: #{reason}")
        {:error, "Failed to delete bot: #{reason}"}
    end
  end

  # Convenience wrapper that accepts a calendar event struct
  def create_bot_for_calendar_event(
        %{meeting_url: meeting_url, start_time: start_time} = event,
        join_offset_minutes \\ nil
      ) do
    join_offset = join_offset_minutes || ApiClient.bot_join_offset_minutes()
    join_at = DateTime.add(start_time, -join_offset * 60, :second)

    create_bot(meeting_url,
      join_at: join_at,
      bot_name: "Social Content Generator Bot - #{event.title || "Meeting"}"
    )
  end

  # Helper function to safely get the latest status code from status_changes array
  defp get_latest_status_code(response, default) do
    case List.last(response["status_changes"]) do
      nil ->
        # If empty and has join_at, it's scheduled
        if Map.has_key?(response, "join_at"), do: "scheduled", else: default

      status_change ->
        Map.get(status_change, "code", default)
    end
  end
end
