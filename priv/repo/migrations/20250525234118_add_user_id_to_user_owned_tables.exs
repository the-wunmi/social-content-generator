defmodule SocialContentGenerator.Repo.Migrations.AddUserIdToUserOwnedTables do
  use Ecto.Migration

  def up do
    # Add user_id columns as nullable first
    alter table(:calendar_events) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    alter table(:bots) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    alter table(:calendar_event_attendees) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    alter table(:meeting_attendees) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    alter table(:automation_outputs) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    # Populate user_id for existing records
    # For calendar_events: get user_id from the integration's user_integration
    execute """
    UPDATE calendar_events
    SET user_id = ui.user_id
    FROM user_integrations ui
    WHERE calendar_events.integration_id = ui.integration_id
    """

    # For bots: get user_id from the integration's user_integration
    execute """
    UPDATE bots
    SET user_id = ui.user_id
    FROM user_integrations ui
    WHERE bots.integration_id = ui.integration_id
    """

    # For calendar_event_attendees: get user_id from the calendar_event
    execute """
    UPDATE calendar_event_attendees
    SET user_id = ce.user_id
    FROM calendar_events ce
    WHERE calendar_event_attendees.calendar_event_id = ce.id
    """

    # For meeting_attendees: get user_id from the meeting
    execute """
    UPDATE meeting_attendees
    SET user_id = m.user_id
    FROM meetings m
    WHERE meeting_attendees.meeting_id = m.id
    """

    # For automation_outputs: get user_id from the automation
    execute """
    UPDATE automation_outputs
    SET user_id = a.user_id
    FROM automations a
    WHERE automation_outputs.automation_id = a.id
    """

    # Now make the columns NOT NULL after populating data
    alter table(:calendar_events) do
      modify :user_id, :integer, null: false
    end

    alter table(:bots) do
      modify :user_id, :integer, null: false
    end

    alter table(:calendar_event_attendees) do
      modify :user_id, :integer, null: false
    end

    alter table(:meeting_attendees) do
      modify :user_id, :integer, null: false
    end

    alter table(:automation_outputs) do
      modify :user_id, :integer, null: false
    end

    # Create indexes for better query performance
    create index(:calendar_events, [:user_id])
    create index(:bots, [:user_id])
    create index(:calendar_event_attendees, [:user_id])
    create index(:meeting_attendees, [:user_id])
    create index(:automation_outputs, [:user_id])
  end

  def down do
    # Remove indexes
    drop index(:calendar_events, [:user_id])
    drop index(:bots, [:user_id])
    drop index(:calendar_event_attendees, [:user_id])
    drop index(:meeting_attendees, [:user_id])
    drop index(:automation_outputs, [:user_id])

    # Remove user_id columns
    alter table(:calendar_events) do
      remove :user_id
    end

    alter table(:bots) do
      remove :user_id
    end

    alter table(:calendar_event_attendees) do
      remove :user_id
    end

    alter table(:meeting_attendees) do
      remove :user_id
    end

    alter table(:automation_outputs) do
      remove :user_id
    end
  end
end
