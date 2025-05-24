defmodule SocialContentGenerator.Users.UserIntegration do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "user_integrations" do
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :user, SocialContentGenerator.Users.User
    belongs_to :integration, SocialContentGenerator.Integrations.Integration

    timestamps()
  end

  @doc false
  def changeset(user_integration, attrs) do
    user_integration
    |> cast(attrs, [
      :access_token,
      :refresh_token,
      :user_id,
      :integration_id,
      :deleted_at,
      :expires_at
    ])
    |> validate_required([:access_token, :user_id, :integration_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:integration_id)
  end
end
