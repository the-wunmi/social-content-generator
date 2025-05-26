defmodule SocialContentGenerator.Automations.AutomationOutput do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "automation_outputs" do
    field :content, :string
    field :output_type, :string
    field :status, :string, default: "draft"
    field :metadata, :map, default: %{}
    field :deleted_at, :utc_datetime

    belongs_to :user, SocialContentGenerator.Users.User
    belongs_to :meeting, SocialContentGenerator.Meetings.Meeting
    belongs_to :automation, SocialContentGenerator.Automations.Automation

    timestamps()
  end

  @valid_output_types ["social_post", "email", "blog"]
  @valid_statuses ["draft", "posted", "scheduled"]

  @doc false
  def changeset(automation_output, attrs) do
    automation_output
    |> cast(attrs, [
      :content,
      :output_type,
      :status,
      :metadata,
      :user_id,
      :automation_id,
      :meeting_id,
      :deleted_at
    ])
    |> validate_required([:content, :output_type, :user_id, :automation_id, :meeting_id])
    |> validate_inclusion(:output_type, @valid_output_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:automation_id)
    |> foreign_key_constraint(:meeting_id)
  end
end
