defmodule SocialContentGenerator.Calendars.CalendarEventAttendee do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "calendar_event_attendees" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "attendee"
    field :status, :string, default: "needs_action"
    field :deleted_at, :utc_datetime

    belongs_to :calendar_event, SocialContentGenerator.Calendars.CalendarEvent

    timestamps()
  end

  @valid_roles ["organizer", "attendee", "optional"]
  @valid_statuses ["needs_action", "accepted", "declined", "tentative"]

  @doc false
  def changeset(calendar_event_attendee, attrs) do
    calendar_event_attendee
    |> cast(attrs, [:email, :name, :role, :status, :calendar_event_id, :deleted_at])
    |> validate_required([:email, :calendar_event_id])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_inclusion(:role, @valid_roles)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:calendar_event_id)
  end
end
