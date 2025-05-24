defmodule SocialContentGenerator.Calendars.CalendarEvent do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "calendar_events" do
    field :integration_event_id, :string
    field :title, :string
    field :description, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :location, :string
    field :meeting_url, :string
    field :note_taker_enabled, :boolean, default: false
    field :join_offset_minutes, :integer
    field :deleted_at, :utc_datetime

    belongs_to :integration, SocialContentGenerator.Integrations.Integration
    has_one :meeting, SocialContentGenerator.Meetings.Meeting
    has_many :attendees, SocialContentGenerator.Calendars.CalendarEventAttendee

    timestamps()
  end

  @doc false
  def changeset(calendar_event, attrs) do
    calendar_event
    |> cast(attrs, [
      :integration_event_id,
      :title,
      :description,
      :start_time,
      :end_time,
      :location,
      :meeting_url,
      :note_taker_enabled,
      :join_offset_minutes,
      :integration_id,
      :deleted_at
    ])
    |> validate_required([:integration_event_id, :title, :start_time, :end_time, :integration_id])
    |> foreign_key_constraint(:integration_id)
  end
end
