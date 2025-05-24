defmodule SocialContentGenerator.Meetings.Meeting do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :status, :string
    field :transcript, :string
    field :configuration, :map
    field :deleted_at, :utc_datetime

    belongs_to :calendar_event, SocialContentGenerator.Calendars.CalendarEvent
    belongs_to :user, SocialContentGenerator.Users.User
    belongs_to :bot, SocialContentGenerator.Bots.Bot
    belongs_to :integration, SocialContentGenerator.Integrations.Integration
    has_many :attendees, SocialContentGenerator.Meetings.MeetingAttendee
    has_many :automation_outputs, SocialContentGenerator.Automations.AutomationOutput

    timestamps()
  end

  @valid_statuses ["scheduled", "in_progress", "completed", "failed"]

  @doc false
  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :transcript,
      :status,
      :configuration,
      :user_id,
      :bot_id,
      :calendar_event_id,
      :integration_id,
      :deleted_at
    ])
    |> validate_required([:calendar_event_id, :user_id, :integration_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:bot_id)
    |> foreign_key_constraint(:calendar_event_id)
    |> foreign_key_constraint(:integration_id)
  end
end
