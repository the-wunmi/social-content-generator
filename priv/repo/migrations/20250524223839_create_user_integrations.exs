defmodule SocialContentGenerator.Repo.Migrations.CreateUserIntegrations do
  use Ecto.Migration

  def change do
    create table(:user_integrations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :integration_id, references(:integrations, on_delete: :delete_all), null: false
      add :access_token, :string
      add :refresh_token, :string
      add :expires_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:user_integrations, [:user_id, :integration_id])
  end
end
