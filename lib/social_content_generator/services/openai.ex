defmodule SocialContentGenerator.Services.OpenAI do
  @moduledoc """
  Service for interacting with OpenAI-compatible APIs to generate content from meeting transcripts.
  Uses pure HTTP requests for maximum flexibility and vendor compatibility.

  ## Vendor Configuration Examples

  ### Standard OpenAI
  ```
  OPENAI_API_KEY=your_openai_api_key
  ```

  ### Custom Vendor (like the TypeScript example)
  ```
  OPENAI_API_KEY=your_api_key
  AI_BASE_URL=https://your-vendor.com/v1
  ```

  ### Vendor with Custom Headers
  ```
  OPENAI_API_KEY=your_api_key
  AI_BASE_URL=https://your-vendor.com/openai/deployments/your-deployment
  ```

  The service automatically handles different vendor configurations through environment variables.
  """

  alias SocialContentGenerator.Services.ApiClient
  require Logger

  @default_model "gpt-4"
  @default_max_tokens 500
  @default_temperature 0.7
  @default_base_url "https://api.openai.com/v1"
  @default_timeout 30_000

  @doc """
  Generates a social media post from meeting transcript and attendees.
  """
  def generate_social_post(meeting, automation) do
    Logger.info("🚀 Starting social post generation for meeting #{meeting.id}")
    Logger.info("📝 Meeting title: #{meeting.calendar_event.title}")
    Logger.info("🤖 Automation: #{automation.name} (#{automation.output_type})")

    prompt = build_social_post_prompt(meeting, automation)
    Logger.info("📄 Generated prompt length: #{String.length(prompt)} characters")

    result = call_ai(prompt, "social_post")
    Logger.info("✅ Social post generation result: #{inspect(result)}")
    result
  end

  @doc """
  Generates a follow-up email from meeting transcript and attendees.
  """
  def generate_follow_up_email(meeting, automation) do
    Logger.info("📧 Starting email generation for meeting #{meeting.id}")
    Logger.info("📝 Meeting title: #{meeting.calendar_event.title}")
    Logger.info("🤖 Automation: #{automation.name} (#{automation.output_type})")

    prompt = build_email_prompt(meeting, automation)
    Logger.info("📄 Generated prompt length: #{String.length(prompt)} characters")

    result = call_ai(prompt, "email")
    Logger.info("✅ Email generation result: #{inspect(result)}")
    result
  end

  # Private functions

  defp call_ai(prompt, content_type) do
    Logger.info("🔧 Starting AI call for content type: #{content_type}")

    config = get_ai_config()
    Logger.info("⚙️ AI Config loaded: #{inspect(config, pretty: true)}")

    if is_nil(config.api_key) do
      Logger.error("❌ AI API key not configured")
      {:error, "AI API key not configured"}
    else
      request_body = build_chat_request(prompt, content_type, config)
      Logger.info("📤 Chat request built: #{inspect(request_body, pretty: true)}")

      headers = build_headers(config)
      Logger.info("📋 Request headers: #{inspect(headers)}")

      url = "#{config.base_url}/chat/completions?api-version=2024-07-01-preview"
      Logger.info("🌐 Making API call to: #{url}")

      case make_http_request(url, request_body, headers, config) do
        {:ok, response} ->
          Logger.info("✅ API call successful!")
          Logger.info("📥 Raw response: #{inspect(response, pretty: true)}")
          result = extract_content(response)
          Logger.info("🎯 Extracted content result: #{inspect(result)}")
          result

        {:error, error} ->
          Logger.error("❌ AI API error occurred!")
          Logger.error("🔍 Error details: #{inspect(error, pretty: true)}")
          {:error, "AI request failed: #{inspect(error)}"}
      end
    end
  end

  defp make_http_request(url, body, headers, config) do
    json_body = Jason.encode!(body)
    timeout = config.timeout || @default_timeout

    Logger.info("🌐 Making HTTP POST request...")
    Logger.info("📍 URL: #{url}")
    Logger.info("⏱️ Timeout: #{timeout}ms")
    Logger.info("📦 Body size: #{String.length(json_body)} characters")

    case HTTPoison.post(url, json_body, headers, recv_timeout: timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Logger.info("✅ HTTP request successful (200)")

        case Jason.decode(response_body) do
          {:ok, decoded_response} ->
            Logger.info("✅ Response JSON decoded successfully")
            {:ok, decoded_response}

          {:error, decode_error} ->
            Logger.error("❌ Failed to decode JSON response: #{inspect(decode_error)}")
            Logger.error("📄 Raw response body: #{response_body}")
            {:error, "Failed to decode JSON response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("❌ HTTP request failed with status: #{status_code}")
        Logger.error("📄 Response body: #{response_body}")

        # Try to decode error response for better error messages
        case Jason.decode(response_body) do
          {:ok, error_response} ->
            error_message = get_in(error_response, ["error", "message"]) || "Unknown API error"
            Logger.error("💬 API Error Message: #{error_message}")
            {:error, "API Error (#{status_code}): #{error_message}"}

          {:error, _} ->
            {:error, "HTTP Error (#{status_code}): #{response_body}"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("❌ HTTP request failed: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp build_headers(config) do
    base_headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{config.api_key}"}
    ]

    # Add custom headers if specified
    custom_headers =
      if config.headers && map_size(config.headers) > 0 do
        Logger.info("📋 Adding custom headers: #{inspect(config.headers)}")
        Enum.map(config.headers, fn {key, value} -> {key, value} end)
      else
        []
      end

    final_headers = base_headers ++ custom_headers
    Logger.info("✅ Final headers built: #{length(final_headers)} headers")
    final_headers
  end

  defp build_chat_request(prompt, content_type, config) do
    Logger.info("📝 Building chat request for content type: #{content_type}")

    system_prompt = get_system_prompt(content_type)
    Logger.info("🤖 System prompt length: #{String.length(system_prompt)} characters")
    Logger.info("👤 User prompt length: #{String.length(prompt)} characters")

    request = %{
      model: config.model,
      messages: [
        %{
          role: "system",
          content: system_prompt
        },
        %{
          role: "user",
          content: prompt
        }
      ],
      max_tokens: config.max_tokens,
      temperature: config.temperature
    }

    Logger.info("⚙️ Request parameters:")
    Logger.info("  📊 Model: #{config.model}")
    Logger.info("  🎛️ Max tokens: #{config.max_tokens}")
    Logger.info("  🌡️ Temperature: #{config.temperature}")
    Logger.info("  💬 Messages count: #{length(request.messages)}")

    request
  end

  defp extract_content(response) do
    Logger.info("🔍 Extracting content from AI response...")

    case response do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        Logger.info("✅ Content extracted successfully")
        Logger.info("📏 Content length: #{String.length(content)} characters")
        Logger.info("📄 Content preview: #{String.slice(content, 0, 100)}...")
        {:ok, String.trim(content)}

      %{"choices" => choices} when is_list(choices) ->
        Logger.error("❌ Choices array exists but unexpected format")
        Logger.error("🔍 Choices: #{inspect(choices)}")
        {:error, "Unexpected response format - choices exist but malformed"}

      %{} = resp ->
        Logger.error("❌ Response is a map but missing expected structure")
        Logger.error("🔍 Response keys: #{inspect(Map.keys(resp))}")
        Logger.error("🔍 Full response: #{inspect(resp)}")
        {:error, "Unexpected response format"}

      _ ->
        Logger.error("❌ Response is not a map")
        Logger.error("🔍 Response type: #{inspect(response.__struct__ || :unknown)}")
        Logger.error("🔍 Response: #{inspect(response)}")
        {:error, "Unexpected response format"}
    end
  end

  defp get_ai_config do
    Logger.info("⚙️ Loading AI configuration...")

    ai_config = Application.get_env(:social_content_generator, :ai, %{})
    Logger.info("📋 Raw AI config from application: #{inspect(ai_config)}")

    provider = ai_config[:provider] || "openai"
    Logger.info("🏢 Provider: #{provider}")

    api_key = get_api_key(ai_config)

    Logger.info(
      "🔑 API key loaded: #{!is_nil(api_key)} (length: #{if api_key, do: String.length(api_key), else: 0})"
    )

    base_url = ai_config[:base_url] || @default_base_url
    Logger.info("🌐 Base URL: #{base_url}")

    config = %{
      provider: provider,
      api_key: api_key,
      model: ai_config[:model] || @default_model,
      max_tokens: ai_config[:max_tokens] || @default_max_tokens,
      temperature: ai_config[:temperature] || @default_temperature,
      base_url: base_url,
      headers: build_custom_headers(ai_config),
      timeout: ai_config[:timeout] || @default_timeout
    }

    Logger.info("✅ Final AI config: #{inspect(config, pretty: true)}")
    config
  end

  defp get_api_key(ai_config) do
    Logger.info("🔍 Retrieving API key...")

    config_key = ai_config[:openai_api_key]
    env_key = ApiClient.openai_api_key()

    Logger.info("🔑 Config API key present: #{!is_nil(config_key)}")
    Logger.info("🌍 Environment API key present: #{!is_nil(env_key)}")

    result = config_key || env_key
    Logger.info("✅ Final API key selected: #{!is_nil(result)}")

    result
  end

  defp build_custom_headers(ai_config) do
    Logger.info("📋 Building custom headers...")

    # Build headers based on configuration
    custom_headers = ai_config[:headers] || %{}
    Logger.info("🎨 Custom headers from config: #{inspect(custom_headers)}")

    api_key = get_api_key(ai_config)
    use_api_key_header = ai_config[:use_api_key_header]
    Logger.info("🔧 Use API key header: #{use_api_key_header}")

    base_headers =
      if api_key && use_api_key_header do
        headers = %{"api-key" => api_key}
        Logger.info("🔑 Adding API key to headers")
        headers
      else
        Logger.info("ℹ️ Not adding API key to headers")
        %{}
      end

    final_headers = Map.merge(base_headers, custom_headers)
    Logger.info("✅ Final headers: #{inspect(final_headers)}")
    final_headers
  end

  defp get_system_prompt("social_post") do
    """
    You are a professional social media content creator. Generate engaging LinkedIn/Facebook posts based on meeting transcripts.

    Guidelines:
    - Keep posts professional but engaging
    - Include 2-3 key takeaways or insights
    - Add relevant hashtags
    - Keep under 280 characters for social media
    - Use first person perspective
    - Make it sound natural and authentic
    """
  end

  defp get_system_prompt("email") do
    """
    You are a professional assistant writing follow-up emails after business meetings.

    Guidelines:
    - Be professional and courteous
    - Summarize key discussion points
    - Include clear action items if any were discussed
    - Mention next steps
    - Keep the tone warm but business-appropriate
    - Structure: greeting, summary, action items, next steps, closing
    """
  end

  defp build_social_post_prompt(meeting, automation) do
    Logger.info("📝 Building social post prompt...")

    attendee_names = meeting.attendees |> Enum.map(& &1.name) |> Enum.join(", ")
    Logger.info("👥 Attendees: #{attendee_names}")

    platform = automation.integration.provider
    Logger.info("📱 Platform: #{platform}")

    transcript_length = String.length(meeting.transcript || "")
    Logger.info("📄 Transcript length: #{transcript_length} characters")

    # Include example output if provided
    example_section =
      if automation.example_output && String.trim(automation.example_output) != "" do
        Logger.info(
          "📋 Using example output as guide (#{String.length(automation.example_output)} characters)"
        )

        """

        Example Output Style (use this as a guide for tone, format, and structure):
        #{automation.example_output}
        """
      else
        Logger.info("ℹ️ No example output provided")
        ""
      end

    prompt = """
    Create a #{platform} post about this meeting:

    Meeting Title: #{meeting.calendar_event.title}
    Attendees: #{attendee_names}

    Meeting Transcript:
    #{String.slice(meeting.transcript || "No transcript available", 0, 2000)}#{example_section}

    Generate an engaging social media post that highlights the key insights and value from this meeting.#{if example_section != "", do: " Follow the style, tone, and format shown in the example output above.", else: ""}
    """

    Logger.info("✅ Social post prompt built (#{String.length(prompt)} characters)")
    prompt
  end

  defp build_email_prompt(meeting, automation) do
    Logger.info("📧 Building email prompt...")

    attendee_names = meeting.attendees |> Enum.map(& &1.name) |> Enum.join(", ")
    Logger.info("👥 Attendees: #{attendee_names}")

    transcript_length = String.length(meeting.transcript || "")
    Logger.info("📄 Transcript length: #{transcript_length} characters")

    # Include example output if provided
    example_section =
      if automation.example_output && String.trim(automation.example_output) != "" do
        Logger.info(
          "📋 Using example output as guide (#{String.length(automation.example_output)} characters)"
        )

        """

        Example Output Style (use this as a guide for tone, format, and structure):
        #{automation.example_output}
        """
      else
        Logger.info("ℹ️ No example output provided")
        ""
      end

    prompt = """
    Write a follow-up email for this meeting:

    Meeting Title: #{meeting.calendar_event.title}
    Attendees: #{attendee_names}

    Meeting Transcript:
    #{String.slice(meeting.transcript || "No transcript available", 0, 3000)}#{example_section}

    Create a professional follow-up email that:
    1. Thanks attendees for their time
    2. Summarizes key discussion points
    3. Lists any action items mentioned
    4. Outlines next steps
    5. Includes appropriate subject line

    Format as a complete email with subject line.#{if example_section != "", do: " Follow the style, tone, and format shown in the example output above.", else: ""}
    """

    Logger.info("✅ Email prompt built (#{String.length(prompt)} characters)")
    prompt
  end
end
