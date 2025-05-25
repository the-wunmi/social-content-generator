defmodule SocialContentGenerator.Integrations.Integration do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "integrations" do
    field :name, :string
    field :description, :string
    field :logo, :string
    field :provider, :string
    field :slug, :string
    field :scopes, {:array, :string}, default: []
    field :deleted_at, :utc_datetime

    has_many :user_integrations, SocialContentGenerator.Users.UserIntegration

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:name, :description, :logo, :provider, :slug, :scopes, :deleted_at])
    |> validate_required([:name, :provider, :slug])
    |> unique_constraint(:slug, name: :integrations_slug_index)
  end
end
