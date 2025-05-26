defmodule SocialContentGenerator.Repo.Migrations.MakeIntegrationIdNullableOnAutomations do
  use Ecto.Migration

  def change do
    alter table(:automations) do
      modify :integration_id, :integer, null: true
    end
  end
end
