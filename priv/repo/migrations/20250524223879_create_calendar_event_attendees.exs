defmodule SocialContentGenerator.Repo.Migrations.CreateCalendarEventAttendees do
  use Ecto.Migration

  def change do
    create table(:calendar_event_attendees) do
      add :email, :string, null: false
      add :name, :string
      add :role, :string, default: "attendee"
      add :status, :string, default: "needs_action"
      add :calendar_event_id, references(:calendar_events, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:calendar_event_attendees, [:calendar_event_id])
    create index(:calendar_event_attendees, [:email])
    create index(:calendar_event_attendees, [:role])
    create index(:calendar_event_attendees, [:status])
    create index(:calendar_event_attendees, [:deleted_at])
  end
end
