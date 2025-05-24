defmodule SocialContentGenerator.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
