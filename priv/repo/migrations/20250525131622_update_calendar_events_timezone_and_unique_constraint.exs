defmodule SocialContentGenerator.Repo.Migrations.UpdateCalendarEventsTimezoneAndUniqueConstraint do
  use Ecto.Migration

  def change do
    # Change start_time and end_time to timestamptz (timestamp with timezone)
    alter table(:calendar_events) do
      modify :start_time, :timestamptz
      modify :end_time, :timestamptz
    end

    # Add partial unique index for integration_event_id where deleted_at is null
    create unique_index(:calendar_events, [:integration_event_id],
             where: "deleted_at IS NULL",
             name: :calendar_events_integration_event_id_unique_when_not_deleted
           )
  end
end
