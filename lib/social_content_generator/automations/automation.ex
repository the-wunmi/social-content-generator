defmodule SocialContentGenerator.Automations.Automation do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "automations" do
    field :name, :string
    field :description, :string
    field :active, :boolean, default: true
    field :deleted_at, :utc_datetime

    belongs_to :user, SocialContentGenerator.Users.User
    belongs_to :integration, SocialContentGenerator.Integrations.Integration

    timestamps()
  end

  @doc false
  def changeset(automation, attrs) do
    automation
    |> cast(attrs, [:name, :description, :active, :user_id, :integration_id, :deleted_at])
    |> validate_required([:name, :description, :user_id, :integration_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:integration_id)
  end
end
