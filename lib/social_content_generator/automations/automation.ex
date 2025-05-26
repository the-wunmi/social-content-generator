defmodule SocialContentGenerator.Automations.Automation do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "automations" do
    field :name, :string
    field :description, :string
    field :output_type, :string, default: "social_post"
    field :example_output, :string
    field :active, :boolean, default: true
    field :deleted_at, :utc_datetime

    belongs_to :user, SocialContentGenerator.Users.User
    belongs_to :integration, SocialContentGenerator.Integrations.Integration

    timestamps()
  end

  @valid_output_types ["social_post", "email"]

  @doc false
  def changeset(automation, attrs) do
    automation
    |> cast(attrs, [
      :name,
      :description,
      :output_type,
      :example_output,
      :active,
      :user_id,
      :integration_id,
      :deleted_at
    ])
    |> validate_required([:name, :description, :output_type, :example_output, :user_id])
    |> validate_inclusion(:output_type, @valid_output_types)
    |> validate_integration_required_for_social_post()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:integration_id)
  end

  defp validate_integration_required_for_social_post(changeset) do
    output_type = get_field(changeset, :output_type)
    integration_id = get_field(changeset, :integration_id)

    if output_type == "social_post" and is_nil(integration_id) do
      add_error(changeset, :integration_id, "is required for social media posts")
    else
      changeset
    end
  end
end
