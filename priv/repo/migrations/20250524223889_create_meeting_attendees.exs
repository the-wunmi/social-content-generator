defmodule SocialContentGenerator.Repo.Migrations.CreateMeetingAttendees do
  use Ecto.Migration

  def change do
    create table(:meeting_attendees) do
      add :email, :string, null: false
      add :name, :string
      add :role, :string, default: "attendee"
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:meeting_attendees, [:meeting_id])
    create index(:meeting_attendees, [:email])
    create index(:meeting_attendees, [:role])
    create index(:meeting_attendees, [:deleted_at])
  end
end
