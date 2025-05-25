defmodule SocialContentGenerator.Auth.OAuth do
  @moduledoc """
  Handles OAuth authentication for different platforms.
  """

  alias SocialContentGenerator.Users.User
  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Integrations.Integration
  alias SocialContentGenerator.Repo
  import Ecto.Query

  @google_client_id System.get_env("GOOGLE_CLIENT_ID")
  @google_client_secret System.get_env("GOOGLE_CLIENT_SECRET")
  @linkedin_client_id System.get_env("LINKEDIN_CLIENT_ID")
  @linkedin_client_secret System.get_env("LINKEDIN_CLIENT_SECRET")
  @facebook_client_id System.get_env("FACEBOOK_CLIENT_ID")
  @facebook_client_secret System.get_env("FACEBOOK_CLIENT_SECRET")

  def get_authorization_url(provider) do
    case provider do
      "google" ->
        params =
          URI.encode_query(%{
            client_id: @google_client_id,
            redirect_uri: "#{get_base_url()}/auth/google/callback",
            response_type: "code",
            scope:
              "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile",
            access_type: "offline",
            prompt: "consent"
          })

        "https://accounts.google.com/o/oauth2/v2/auth?#{params}"

      "linkedin" ->
        params =
          URI.encode_query(%{
            client_id: @linkedin_client_id,
            redirect_uri: "#{get_base_url()}/auth/linkedin/callback",
            response_type: "code",
            scope: "r_liteprofile r_emailaddress w_member_social"
          })

        "https://www.linkedin.com/oauth/v2/authorization?#{params}"

      "facebook" ->
        params =
          URI.encode_query(%{
            client_id: @facebook_client_id,
            redirect_uri: "#{get_base_url()}/auth/facebook/callback",
            response_type: "code",
            scope: "email public_profile pages_manage_posts"
          })

        "https://www.facebook.com/v12.0/dialog/oauth?#{params}"

      _ ->
        {:error, "Unsupported provider"}
    end
  end

  def handle_callback(provider, code) do
    case provider do
      "google" -> handle_google_callback(code)
      "linkedin" -> handle_linkedin_callback(code)
      "facebook" -> handle_facebook_callback(code)
      _ -> {:error, "Unsupported provider"}
    end
  end

  defp handle_google_callback(code) do
    # Exchange code for tokens
    token_response =
      HTTPoison.post!(
        "https://oauth2.googleapis.com/token",
        URI.encode_query(%{
          client_id: @google_client_id,
          client_secret: @google_client_secret,
          code: code,
          grant_type: "authorization_code",
          redirect_uri: "#{get_base_url()}/auth/google/callback"
        }),
        [{"Content-Type", "application/x-www-form-urlencoded"}]
      )

    {:ok,
     %{
       "access_token" => access_token,
       "refresh_token" => refresh_token,
       "expires_in" => expires_in
     }} =
      Jason.decode(token_response.body)

    # Get user info
    user_response =
      HTTPoison.get!(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        [{"Authorization", "Bearer #{access_token}"}]
      )

    {:ok, user_info} = Jason.decode(user_response.body)

    # Create or update user
    user = create_or_update_user(user_info)

    # Create or update integration
    integration = get_or_create_integration("google")

    # Create or update user integration
    create_or_update_user_integration(user, integration, %{
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
    })

    {:ok, user}
  end

  defp handle_linkedin_callback(code) do
    # Similar implementation for LinkedIn
    {:ok, "LinkedIn integration not implemented yet"}
  end

  defp handle_facebook_callback(code) do
    # Similar implementation for Facebook
    {:ok, "Facebook integration not implemented yet"}
  end

  defp create_or_update_user(user_info) do
    attrs = %{
      email: user_info["email"],
      first_name: user_info["given_name"],
      last_name: user_info["family_name"]
    }

    case Repo.get_by(User, email: user_info["email"]) do
      nil ->
        {:ok, user} = %User{} |> User.changeset(attrs) |> Repo.insert()
        user

      user ->
        {:ok, user} = user |> User.changeset(attrs) |> Repo.update()
        user
    end
  end

  defp get_or_create_integration(provider) do
    case Repo.get_by(Integration, provider: provider) do
      nil ->
        {:ok, integration} =
          %Integration{}
          |> Integration.changeset(%{
            name: String.capitalize(provider),
            provider: provider,
            description: "#{String.capitalize(provider)} integration"
          })
          |> Repo.insert()

        integration

      integration ->
        integration
    end
  end

  defp create_or_update_user_integration(user, integration, token_attrs) do
    attrs =
      Map.merge(token_attrs, %{
        user_id: user.id,
        integration_id: integration.id
      })

    case Repo.get_by(UserIntegration, user_id: user.id, integration_id: integration.id) do
      nil ->
        {:ok, _} = %UserIntegration{} |> UserIntegration.changeset(attrs) |> Repo.insert()

      user_integration ->
        {:ok, _} = user_integration |> UserIntegration.changeset(attrs) |> Repo.update()
    end
  end

  defp get_base_url do
    System.get_env("BASE_URL", "http://localhost:#{System.get_env("PORT") || "4000"}")
  end
end
