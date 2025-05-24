defmodule SocialContentGenerator.Repo.Migrations.CreateIntegrations do
  use Ecto.Migration

  def change do
    create table(:integrations) do
      add :name, :string, null: false
      add :description, :string
      add :logo, :string
      add :provider, :string, null: false
      add :scopes, {:array, :string}, default: [], null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:integrations, [:provider])
    create index(:integrations, [:deleted_at])
  end
end
