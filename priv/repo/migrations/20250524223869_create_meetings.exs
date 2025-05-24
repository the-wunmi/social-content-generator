defmodule SocialContentGenerator.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:calendar_events) do
      add :integration_event_id, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :location, :string
      add :meeting_url, :string
      add :note_taker_enabled, :boolean, default: false
      add :join_offset_minutes, :integer
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:calendar_events, [:start_time])
    create index(:calendar_events, [:integration_event_id])
    create index(:calendar_events, [:integration_id])
    create index(:calendar_events, [:deleted_at])

    create table(:meetings) do
      add :transcript, :text
      add :status, :string, null: false
      add :configuration, :map
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :bot_id, references(:bots, on_delete: :delete_all)
      add :calendar_event_id, references(:calendar_events, on_delete: :delete_all), null: false
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:meetings, [:user_id])
    create index(:meetings, [:bot_id])
    create index(:meetings, [:calendar_event_id])
    create index(:meetings, [:integration_id])
    create index(:meetings, [:status])
    create index(:meetings, [:deleted_at])
  end
end
