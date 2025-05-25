defmodule SocialContentGenerator.Calendars.CalendarEvent do
  use Ecto.Schema
  use SocialContentGenerator.Schema
  import Ecto.Changeset

  schema "calendar_events" do
    field :integration_event_id, :string
    field :title, :string
    field :description, :string
    field :start_time, :utc_datetime_usec
    field :end_time, :utc_datetime_usec
    field :location, :string
    field :meeting_url, :string
    field :note_taker_enabled, :boolean, default: false
    field :join_offset_minutes, :integer
    field :deleted_at, :utc_datetime

    belongs_to :integration, SocialContentGenerator.Integrations.Integration
    belongs_to :bot, SocialContentGenerator.Bots.Bot
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
      :bot_id,
      :deleted_at
    ])
    |> validate_required([:integration_event_id, :title, :start_time, :end_time, :integration_id])
    |> foreign_key_constraint(:integration_id)
    |> foreign_key_constraint(:bot_id)
    |> unique_constraint(:integration_event_id,
      name: :calendar_events_integration_event_id_unique_when_not_deleted
    )
    |> maybe_schedule_bot_cleanup()
  end

  # Schedule bot cleanup if note_taker_enabled is being set to false and there's a bot
  defp maybe_schedule_bot_cleanup(%Ecto.Changeset{} = changeset) do
    note_taker_change = get_change(changeset, :note_taker_enabled)

    # Only trigger cleanup if note_taker_enabled is being explicitly set to false
    if note_taker_change == false do
      # Get the calendar event ID (either from data or changes)
      calendar_event_id = changeset.data.id || get_change(changeset, :id)

      if calendar_event_id && changeset.data.bot_id do
        # Schedule cleanup asynchronously to avoid blocking the changeset
        Task.start(fn ->
          SocialContentGenerator.Workers.BotWorker.cleanup_bot_for_calendar_event(
            calendar_event_id
          )
        end)
      end
    end

    changeset
  end
end
