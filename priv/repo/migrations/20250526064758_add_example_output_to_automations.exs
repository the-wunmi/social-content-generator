defmodule SocialContentGenerator.Repo.Migrations.AddExampleOutputToAutomations do
  use Ecto.Migration

  def change do
    alter table(:automations) do
      add :example_output, :text
    end
  end
end
