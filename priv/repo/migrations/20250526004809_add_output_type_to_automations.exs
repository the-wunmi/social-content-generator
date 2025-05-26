defmodule SocialContentGenerator.Repo.Migrations.AddOutputTypeToAutomations do
  use Ecto.Migration

  def change do
    alter table(:automations) do
      add :output_type, :string, null: false, default: "social_post"
    end

    create index(:automations, [:output_type])
  end
end
