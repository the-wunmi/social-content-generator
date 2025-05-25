defmodule SocialContentGenerator.Integrations do
  @moduledoc """
  Context module for managing external integrations (Google, LinkedIn, Facebook, ...)
  and the user-specific credentials that go with them.
  """

  import Ecto.Query, warn: false

  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Integrations.Integration
  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Workers.CalendarWorker
  alias Oban

  @doc """
  Return all integrations (with credential info) that belong to a given user.
  """
  def list_integrations_by_user(user_id) do
    from(ui in UserIntegration,
      where: ui.user_id == ^user_id and is_nil(ui.deleted_at),
      join: i in assoc(ui, :integration),
      preload: [integration: i]
    )
    |> Repo.all()
  end

  @doc """
  Fetch a specific integration for a user by provider (e.g. "google", "linkedin").
  Returns the `UserIntegration` record (preloaded with its `Integration`) or `nil`.
  """
  def get_integration_by_user_and_provider(user_id, provider) do
    from(ui in UserIntegration,
      join: i in assoc(ui, :integration),
      where: ui.user_id == ^user_id and i.provider == ^provider and is_nil(ui.deleted_at),
      preload: [integration: i]
    )
    |> Repo.one()
  end

  @doc """
  Create a new user-integration pair (and the provider-level Integration record if it
  doesn't exist yet).
  Expects a map that contains at least `provider`, `user_id`, and oauth token fields.
  """
  def create_integration(%{provider: provider} = attrs) do
    Repo.transaction(fn ->
      integration =
        Repo.get_by(Integration, provider: provider) ||
          %Integration{}
          |> Integration.changeset(%{
            name: String.capitalize(provider),
            provider: provider,
            description: "#{String.capitalize(provider)} integration"
          })
          |> Repo.insert!()

      attrs = Map.put(attrs, :integration_id, integration.id)

      %UserIntegration{}
      |> UserIntegration.changeset(attrs)
      |> Repo.insert()
      |> after_successful_upsert()
    end)
  end

  @doc """
  Update an existing `UserIntegration` row with fresh tokens.
  """
  def update_integration(%UserIntegration{} = user_integration, attrs) do
    user_integration
    |> UserIntegration.changeset(attrs)
    |> Repo.update()
    |> after_successful_upsert()
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------
  defp after_successful_upsert({:ok, ui} = result) do
    schedule_calendar_worker(ui.integration_id)
    result
  end

  defp after_successful_upsert(other), do: other

  defp schedule_calendar_worker(integration_id) do
    %{integration_id: integration_id}
    |> CalendarWorker.new()
    |> Oban.insert()
  end
end
