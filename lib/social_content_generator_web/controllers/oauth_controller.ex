defmodule SocialContentGeneratorWeb.OAuthController do
  use SocialContentGeneratorWeb, :controller

  alias SocialContentGenerator.Services.OAuth
  alias SocialContentGenerator.Integrations
  alias SocialContentGenerator.Users

  def google_auth(conn, _params) do
    redirect_uri = unverified_url(conn, ~p"/auth/google/callback")
    auth_url = OAuth.google_auth_url(redirect_uri)
    redirect(conn, external: auth_url)
  end

  def google_callback(conn, %{"code" => code}) do
    redirect_uri = unverified_url(conn, ~p"/auth/google/callback")

    with {:ok, token_data} <- OAuth.google_exchange_code(code, redirect_uri),
         {:ok, user_info} <- OAuth.google_get_user_info(token_data["access_token"]),
         {:ok, user} <- find_or_create_user(user_info),
         {:ok, _integration} <- create_or_update_user_integration(user, "google", token_data) do
      conn
      |> put_session(:user_id, user.id)
      |> put_flash(:info, "Successfully signed in with Google")
      |> redirect(to: ~p"/settings")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to sign in with Google: #{reason}")
        |> redirect(to: ~p"/login")
    end
  end

  def linkedin_callback(conn, %{"code" => code}) do
    with {:ok, token_data} <- OAuth.linkedin_exchange_code(code),
         {:ok, _integration} <-
           create_or_update_user_integration(conn.assigns.current_user, "linkedin", token_data) do
      conn
      |> put_flash(:info, "Successfully connected to LinkedIn")
      |> redirect(to: ~p"/settings")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to connect to LinkedIn: #{reason}")
        |> redirect(to: ~p"/settings")
    end
  end

  def facebook_callback(conn, %{"code" => code}) do
    with {:ok, token_data} <- OAuth.facebook_exchange_code(code),
         {:ok, _integration} <-
           create_or_update_user_integration(conn.assigns.current_user, "facebook", token_data) do
      conn
      |> put_flash(:info, "Successfully connected to Facebook")
      |> redirect(to: ~p"/settings")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to connect to Facebook: #{reason}")
        |> redirect(to: ~p"/settings")
    end
  end

  defp find_or_create_user(user_info) do
    email = user_info["email"]

    case Users.get_user(email: email) do
      nil ->
        Users.create_user(%{
          email: email,
          first_name: user_info["given_name"],
          last_name: user_info["family_name"]
        })

      user ->
        {:ok, user}
    end
  end

  defp create_or_update_user_integration(user, provider, token_data) do
    integration = Integrations.get_integration(provider: provider, scopes: "auth")

    attrs = %{
      integration_id: integration.id,
      access_token: token_data["access_token"],
      refresh_token: token_data["refresh_token"],
      expires_at: DateTime.utc_now() |> DateTime.add(token_data["expires_in"], :second),
      user_id: user.id
    }

    case Integrations.get_user_integration(user_id: user.id, integration_id: integration.id) do
      nil -> Integrations.create_user_integration(attrs)
      integration -> Integrations.update_user_integration(integration, attrs)
    end
  end
end
