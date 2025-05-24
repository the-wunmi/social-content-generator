defmodule SocialContentGenerator.Meetings.MeetingAttendee do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "meeting_attendees" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "attendee"
    field :deleted_at, :utc_datetime

    belongs_to :meeting, SocialContentGenerator.Meetings.Meeting

    timestamps()
  end

  @valid_roles ["organizer", "attendee", "optional"]

  @doc false
  def changeset(meeting_attendee, attrs) do
    meeting_attendee
    |> cast(attrs, [:email, :name, :role, :meeting_id, :deleted_at])
    |> validate_required([:email, :meeting_id])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_inclusion(:role, @valid_roles)
    |> foreign_key_constraint(:meeting_id)
  end
end
