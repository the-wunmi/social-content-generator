defmodule SocialContentGenerator.Services.OAuth do
  @moduledoc """
  OAuth service for handling authentication with external providers.
  """

  alias SocialContentGenerator.Services.ApiClient

  def google_auth_url(redirect_uri \\ nil, scope_type \\ :auth) do
    google_config = ApiClient.oauth_config(:google)
    client_id = google_config[:client_id]
    redirect_uri = redirect_uri || google_config[:redirect_uri]

    scope =
      case scope_type do
        :auth ->
          "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"

        :calendar ->
          "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"
      end

    "https://accounts.google.com/o/oauth2/v2/auth?" <>
      URI.encode_query(%{
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: scope,
        access_type: "offline",
        prompt: "consent"
      })
  end

  def google_exchange_code(code, redirect_uri \\ nil) do
    google_config = ApiClient.oauth_config(:google)
    client_id = google_config[:client_id]
    client_secret = google_config[:client_secret]
    redirect_uri = redirect_uri || google_config[:redirect_uri]

    body =
      URI.encode_query(%{
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        grant_type: "authorization_code"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://oauth2.googleapis.com/token", body, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Failed to exchange code: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "Failed to exchange code: #{inspect(error)}"}
    end
  end

  def google_get_user_info(access_token) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPoison.get("https://www.googleapis.com/oauth2/v2/userinfo", headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Failed to get user info: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "Failed to get user info: #{inspect(error)}"}
    end
  end

  def linkedin_auth_url(redirect_uri \\ nil) do
    linkedin_config = ApiClient.oauth_config(:linkedin)
    client_id = linkedin_config[:client_id]
    redirect_uri = redirect_uri || linkedin_config[:redirect_uri]
    scope = "r_liteprofile r_emailaddress w_member_social"

    "https://www.linkedin.com/oauth/v2/authorization?" <>
      URI.encode_query(%{
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: scope,
        state: generate_state()
      })
  end

  def linkedin_exchange_code(code) do
    linkedin_config = ApiClient.oauth_config(:linkedin)
    client_id = linkedin_config[:client_id]
    client_secret = linkedin_config[:client_secret]
    redirect_uri = linkedin_config[:redirect_uri]

    body =
      URI.encode_query(%{
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: client_id,
        client_secret: client_secret
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://www.linkedin.com/oauth/v2/accessToken", body, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Failed to exchange code: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "Failed to exchange code: #{inspect(error)}"}
    end
  end

  def facebook_auth_url(redirect_uri \\ nil) do
    facebook_config = ApiClient.oauth_config(:facebook)
    client_id = facebook_config[:client_id]
    redirect_uri = redirect_uri || facebook_config[:redirect_uri]
    scope = "pages_manage_posts,pages_read_engagement"

    "https://www.facebook.com/v18.0/dialog/oauth?" <>
      URI.encode_query(%{
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: scope,
        state: generate_state()
      })
  end

  def facebook_exchange_code(code) do
    facebook_config = ApiClient.oauth_config(:facebook)
    client_id = facebook_config[:client_id]
    client_secret = facebook_config[:client_secret]
    redirect_uri = facebook_config[:redirect_uri]

    body =
      URI.encode_query(%{
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        code: code
      })

    case HTTPoison.get("https://graph.facebook.com/v18.0/oauth/access_token?#{body}") do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Failed to exchange code: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "Failed to exchange code: #{inspect(error)}"}
    end
  end

  def refresh_token(user_integration) do
    case user_integration.integration.provider do
      "google" -> refresh_google_token(user_integration)
      "linkedin" -> refresh_linkedin_token(user_integration)
      "facebook" -> refresh_facebook_token(user_integration)
      _ -> {:error, "Unsupported provider"}
    end
  end

  defp refresh_google_token(user_integration) do
    google_config = ApiClient.oauth_config(:google)
    client_id = google_config[:client_id]
    client_secret = google_config[:client_secret]

    body =
      URI.encode_query(%{
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: user_integration.refresh_token,
        grant_type: "refresh_token"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://oauth2.googleapis.com/token", body, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Failed to refresh token: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "Failed to refresh token: #{inspect(error)}"}
    end
  end

  defp refresh_linkedin_token(user_integration) do
    linkedin_config = ApiClient.oauth_config(:linkedin)
    client_id = linkedin_config[:client_id]
    client_secret = linkedin_config[:client_secret]

    body =
      URI.encode_query(%{
        grant_type: "refresh_token",
        refresh_token: user_integration.refresh_token,
        client_id: client_id,
        client_secret: client_secret
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://www.linkedin.com/oauth/v2/accessToken", body, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Failed to refresh token: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "Failed to refresh token: #{inspect(error)}"}
    end
  end

  defp refresh_facebook_token(user_integration) do
    facebook_config = ApiClient.oauth_config(:facebook)
    client_id = facebook_config[:client_id]
    client_secret = facebook_config[:client_secret]

    body =
      URI.encode_query(%{
        grant_type: "fb_exchange_token",
        client_id: client_id,
        client_secret: client_secret,
        fb_exchange_token: user_integration.access_token
      })

    case HTTPoison.get("https://graph.facebook.com/v18.0/oauth/access_token?#{body}") do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Failed to refresh token: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "Failed to refresh token: #{inspect(error)}"}
    end
  end

  defp generate_state do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
    |> binary_part(0, 32)
  end
end
