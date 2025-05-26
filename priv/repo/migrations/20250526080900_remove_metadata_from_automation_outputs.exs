defmodule SocialContentGenerator.Repo.Migrations.RemoveMetadataFromAutomationOutputs do
  use Ecto.Migration

  def change do
    alter table(:automation_outputs) do
      remove :metadata, :map
    end
  end
end
