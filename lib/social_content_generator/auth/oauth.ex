defmodule SocialContentGenerator.Auth.OAuth do
  @moduledoc """
  Handles OAuth authentication for different platforms.
  """

  alias SocialContentGenerator.Users
  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Integrations.Integration
  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Integrations
  alias SocialContentGenerator.Services.ApiClient

  defp create_or_update_user(user_info) do
    attrs = %{
      email: user_info["email"],
      first_name: user_info["given_name"],
      last_name: user_info["family_name"]
    }

    case Users.get_user(email: user_info["email"]) do
      nil ->
        {:ok, user} = Users.create_user(attrs)
        user

      user ->
        {:ok, user} = Users.update_user(user, attrs)
        user
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
end
