defmodule SocialContentGenerator.Automations do
  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo

  alias SocialContentGenerator.Automations.Automation

  def list_automations, do: Repo.all(Automation.not_deleted(Automation))
  def get_automation!(id), do: Repo.get!(Automation, id)

  def create_automation(attrs \\ %{}),
    do: %Automation{} |> Automation.changeset(attrs) |> Repo.insert()

  def update_automation(%Automation{} = automation, attrs),
    do: automation |> Automation.changeset(attrs) |> Repo.update()

  def delete_automation(%Automation{} = automation),
    do: Repo.update_all(Automation.soft_delete(Automation), where: [id: automation.id])

  def change_automation(%Automation{} = automation, attrs \\ %{}),
    do: Automation.changeset(automation, attrs)

  def list_automations_by_user(user_id),
    do:
      from(a in Automation, where: a.user_id == ^user_id and is_nil(a.deleted_at))
      |> Repo.all()
end
