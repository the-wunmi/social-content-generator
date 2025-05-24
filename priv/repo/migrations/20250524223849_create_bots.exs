defmodule SocialContentGenerator.Repo.Migrations.CreateBots do
  use Ecto.Migration

  def change do
    create table(:bots) do
      add :name, :string, null: false
      add :integration_bot_id, :string, null: false
      add :status, :string, null: false
      add :configuration, :jsonb
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:bots, [:integration_id])
    create index(:bots, [:integration_bot_id])
    create index(:bots, [:status])
    create index(:bots, [:deleted_at])
  end
end
