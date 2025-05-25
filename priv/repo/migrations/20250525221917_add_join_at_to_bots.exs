defmodule SocialContentGenerator.Repo.Migrations.AddJoinAtToBots do
  use Ecto.Migration

  def change do
    alter table(:bots) do
      add :join_at, :utc_datetime, null: true
    end
  end
end
