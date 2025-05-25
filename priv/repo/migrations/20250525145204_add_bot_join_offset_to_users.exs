defmodule SocialContentGenerator.Repo.Migrations.AddBotJoinOffsetToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :bot_join_offset_minutes, :integer, default: 5
    end
  end
end
