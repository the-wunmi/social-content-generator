defmodule SocialContentGenerator.Integrations do
  @moduledoc """
  Context module for managing external integrations (Google, LinkedIn, Facebook, ...)
  and the user-specific credentials that go with them.

  ## Filtering Integrations

  The `list_integrations/1` function supports filtering by:
  - `:provider` - Filter by provider name (e.g., "google", "linkedin")
  - `:name` - Filter by integration name
  - `:slug` - Filter by unique slug (e.g., "google-auth", "google-calendar")
  - `:user_id` - Include user integration data for a specific user
  - `:scopes` - Filter by scopes (string or list of strings)

  ### Scope Filtering Examples

      # Find integrations with "auth" scope
      list_integrations(scopes: "auth")

      # Find integrations with both "auth" AND "bot" scopes
      list_integrations(scopes: ["auth", "bot"])

      # Find Google integrations with automation scope
      list_integrations(provider: "google", scopes: "automation")

      # Find integration by slug
      list_integrations(slug: "google-calendar")
  """

  import Ecto.Query, warn: false

  alias SocialContentGenerator.Repo
  alias SocialContentGenerator.Integrations.Integration
  alias SocialContentGenerator.Users.UserIntegration
  alias SocialContentGenerator.Workers.CalendarWorker
  alias Oban

  @valid_filters [:user_id, :provider, :integration_id]
  @valid_integration_filters [:provider, :name, :user_id, :scopes, :slug]

  @spec get_integration(integer()) :: %Integration{} | nil
  def get_integration(id) when is_integer(id) do
    Integration.not_deleted(Integration)
    |> where(id: ^id)
    |> Repo.one()
  end

  @spec get_integration(keyword()) :: %Integration{} | nil
  def get_integration(filters) when is_list(filters) do
    validate_filters!(filters, @valid_integration_filters)

    Integration.not_deleted(Integration)
    |> apply_filters(filters)
    |> Repo.one()
  end

  @spec list_integrations(keyword()) :: [%Integration{}]
  def list_integrations(filters \\ []) when is_list(filters) do
    validate_filters!(filters, @valid_integration_filters)

    base_query = Integration.not_deleted(Integration)

    # Check if user_id is in the filters
    case Keyword.get(filters, :user_id) do
      nil ->
        base_query
        |> apply_filters(filters)
        |> Repo.all()

      user_id ->
        from(i in base_query,
          left_join: ui in UserIntegration,
          on: ui.integration_id == i.id and ui.user_id == ^user_id and is_nil(ui.deleted_at),
          preload: [user_integrations: ui]
        )
        |> apply_filters(filters)
        |> Repo.all()
    end
  end

  @spec get_user_integration(keyword()) :: %UserIntegration{} | nil
  def get_user_integration(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    from(ui in UserIntegration,
      join: i in assoc(ui, :integration),
      where: is_nil(ui.deleted_at),
      preload: [integration: i]
    )
    |> apply_user_integration_filters(filters)
    |> Repo.one()
  end

  @spec list_user_integrations(keyword()) :: [%UserIntegration{}]
  def list_user_integrations(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    from(ui in UserIntegration,
      join: i in assoc(ui, :integration),
      where: is_nil(ui.deleted_at),
      preload: [integration: i]
    )
    |> apply_user_integration_filters(filters)
    |> Repo.all()
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:provider, provider}, query ->
        where(query, [i], i.provider == ^provider)

      {:name, name}, query ->
        where(query, [i], i.name == ^name)

      {:slug, slug}, query ->
        where(query, [i], i.slug == ^slug)

      {:scopes, scopes}, query when is_list(scopes) ->
        # Filter integrations that have ALL the specified scopes
        Enum.reduce(scopes, query, fn scope, acc_query ->
          where(acc_query, [i], ^scope in i.scopes)
        end)

      {:scopes, scope}, query when is_binary(scope) ->
        # Filter integrations that have the specified scope
        where(query, [i], ^scope in i.scopes)

      {:user_id, _user_id}, query ->
        # user_id is handled in the join logic in list_integrations
        query
    end)
  end

  defp apply_user_integration_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:user_id, user_id}, query ->
        where(query, [ui, i], ui.user_id == ^user_id)

      {:provider, provider}, query ->
        where(query, [ui, i], i.provider == ^provider)

      {:integration_id, integration_id}, query ->
        where(query, [ui, i], ui.integration_id == ^integration_id)
    end)
  end

  # Validate that all filter keys are valid fields
  defp validate_filters!(filters, valid_fields) do
    invalid_fields =
      filters
      |> Keyword.keys()
      |> Enum.reject(&(&1 in valid_fields))

    if invalid_fields != [] do
      raise ArgumentError,
            "Invalid filter fields: #{inspect(invalid_fields)}. Valid fields: #{inspect(valid_fields)}"
    end
  end

  def create_user_integration(attrs \\ %{}),
    do: %UserIntegration{} |> UserIntegration.changeset(attrs) |> Repo.insert()

  def update_user_integration(%UserIntegration{} = user_integration, attrs) do
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
