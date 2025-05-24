defmodule SocialContentGenerator.Users.User do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string

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
      :deleted_at
    ])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> unique_constraint(:email)
  end
end
