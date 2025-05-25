defmodule SocialContentGenerator.Repo.Migrations.UpdateBotIdConstraints do
  use Ecto.Migration

  def change do
    # Add bot_id column to calendar_events table (nullable)
    alter table(:calendar_events) do
      add :bot_id, references(:bots, on_delete: :nilify_all)
    end

    # Create index for the new bot_id column on calendar_events
    create index(:calendar_events, [:bot_id])

    # Make meetings.bot_id not nullable
    # The foreign key constraint already exists, so we just modify the column
    alter table(:meetings) do
      modify :bot_id, :bigint, null: false
    end
  end
end
