defmodule SocialContentGenerator.Repo.Migrations.CreateAutomations do
  use Ecto.Migration

  def change do
    create table(:automations) do
      add :name, :string, null: false
      add :description, :string, null: false
      add :active, :boolean, default: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:automations, [:user_id])
    create index(:automations, [:integration_id])
    create index(:automations, [:active])
    create index(:automations, [:deleted_at])
  end
end
