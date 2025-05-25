defmodule SocialContentGenerator.Repo.Migrations.AddSlugToIntegrations do
  use Ecto.Migration

  def change do
    # Now make the column NOT NULL
    alter table(:integrations) do
      modify :slug, :string, null: false
    end

    # Create a unique index on slug where deleted_at is null (partial unique index)
    create unique_index(:integrations, [:slug], where: "deleted_at IS NULL")
  end
end
