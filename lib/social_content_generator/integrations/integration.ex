defmodule SocialContentGenerator.Integrations.Integration do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "integrations" do
    field :name, :string
    field :description, :string
    field :logo, :string
    field :provider, :string
    field :deleted_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:name, :description, :logo, :provider, :deleted_at])
    |> validate_required([:name, :provider])
  end
end
