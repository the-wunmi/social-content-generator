defmodule SocialContentGenerator.Services.OAuth do
  @moduledoc """
  Handles OAuth authentication for various social media platforms.
  """

  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Integrations.Integration

  @doc """
  Initiates OAuth flow for Google.
  """
  def google_auth_url(redirect_uri \\ nil) do
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    redirect_uri = redirect_uri || System.get_env("GOOGLE_REDIRECT_URI")

    scope =
      "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"

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

  @doc """
  Exchanges authorization code for access token for Google.
  """
  def google_exchange_code(code, redirect_uri \\ nil) do
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    client_secret = System.get_env("GOOGLE_CLIENT_SECRET")
    redirect_uri = redirect_uri || System.get_env("GOOGLE_REDIRECT_URI")

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

  @doc """
  Gets user information from Google using access token.
  """
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

  @doc """
  Initiates OAuth flow for LinkedIn.
  """
  def linkedin_auth_url(redirect_uri \\ nil) do
    client_id = System.get_env("LINKEDIN_CLIENT_ID")
    redirect_uri = redirect_uri || System.get_env("LINKEDIN_REDIRECT_URI")
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

  @doc """
  Exchanges authorization code for access token for LinkedIn.
  """
  def linkedin_exchange_code(code) do
    client_id = System.get_env("LINKEDIN_CLIENT_ID")
    client_secret = System.get_env("LINKEDIN_CLIENT_SECRET")
    redirect_uri = System.get_env("LINKEDIN_REDIRECT_URI")

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

  @doc """
  Initiates OAuth flow for Facebook.
  """
  def facebook_auth_url(redirect_uri \\ nil) do
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    redirect_uri = redirect_uri || System.get_env("FACEBOOK_REDIRECT_URI")
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

  @doc """
  Exchanges authorization code for access token for Facebook.
  """
  def facebook_exchange_code(code) do
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    client_secret = System.get_env("FACEBOOK_CLIENT_SECRET")
    redirect_uri = System.get_env("FACEBOOK_REDIRECT_URI")

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

  @doc """
  Refreshes an expired access token.
  """
  def refresh_token(integration) do
    case integration.provider do
      "google" -> refresh_google_token(integration)
      "linkedin" -> refresh_linkedin_token(integration)
      "facebook" -> refresh_facebook_token(integration)
      _ -> {:error, "Unsupported provider"}
    end
  end

  defp refresh_google_token(integration) do
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    client_secret = System.get_env("GOOGLE_CLIENT_SECRET")

    body =
      URI.encode_query(%{
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: integration.refresh_token,
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

  defp refresh_linkedin_token(integration) do
    client_id = System.get_env("LINKEDIN_CLIENT_ID")
    client_secret = System.get_env("LINKEDIN_CLIENT_SECRET")

    body =
      URI.encode_query(%{
        grant_type: "refresh_token",
        refresh_token: integration.refresh_token,
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

  defp refresh_facebook_token(integration) do
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    client_secret = System.get_env("FACEBOOK_CLIENT_SECRET")

    body =
      URI.encode_query(%{
        grant_type: "fb_exchange_token",
        client_id: client_id,
        client_secret: client_secret,
        fb_exchange_token: integration.access_token
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
