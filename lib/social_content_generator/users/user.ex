defmodule SocialContentGenerator.Users.User do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :bot_join_offset_minutes, :integer, default: 5

    field :deleted_at, :utc_datetime

    has_many :meetings, SocialContentGenerator.Meetings.Meeting
    has_many :automations, SocialContentGenerator.Automations.Automation
    has_many :integrations, SocialContentGenerator.Users.UserIntegration

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :first_name,
      :last_name,
      :bot_join_offset_minutes,
      :deleted_at
    ])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_number(:bot_join_offset_minutes, greater_than: 0, less_than_or_equal_to: 60)
    |> unique_constraint(:email)
  end
end
