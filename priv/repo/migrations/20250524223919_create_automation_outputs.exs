defmodule SocialContentGenerator.Repo.Migrations.CreateAutomationOutputs do
  use Ecto.Migration

  def change do
    create table(:automation_outputs) do
      add :content, :text, null: false
      add :output_type, :string, null: false
      add :status, :string, default: "draft", null: false
      add :metadata, :jsonb
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :automation_id, references(:automations, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:automation_outputs, [:meeting_id])
    create index(:automation_outputs, [:automation_id])
    create index(:automation_outputs, [:output_type])
    create index(:automation_outputs, [:status])
    create index(:automation_outputs, [:deleted_at])
  end
end
