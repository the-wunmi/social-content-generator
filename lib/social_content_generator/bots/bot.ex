defmodule SocialContentGenerator.Bots.Bot do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "bots" do
    field :name, :string
    field :integration_bot_id, :string
    field :status, :string
    field :configuration, :map
    field :join_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :integration, SocialContentGenerator.Integrations.Integration
    has_many :meetings, SocialContentGenerator.Meetings.Meeting
    has_many :calendar_events, SocialContentGenerator.Calendars.CalendarEvent

    timestamps()
  end

  @valid_statuses ["active", "inactive", "deleted"]

  @doc false
  def changeset(bot, attrs) do
    bot
    |> cast(attrs, [
      :name,
      :integration_bot_id,
      :status,
      :configuration,
      :join_at,
      :integration_id,
      :deleted_at
    ])
    |> validate_required([:name, :integration_bot_id, :integration_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:integration_id)
  end
end
