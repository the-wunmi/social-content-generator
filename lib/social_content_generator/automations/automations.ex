defmodule SocialContentGenerator.Automations do
  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo

  alias SocialContentGenerator.Automations.Automation

  @valid_filters [:id, :user_id, :trigger_type, :action_type, :is_active, :deleted_at]

  @spec get_automation(number()) :: %Automation{} | nil
  def get_automation(id) when is_number(id) do
    Automation.not_deleted(Automation)
    |> where(id: ^id)
    |> Repo.one()
  end

  @spec get_automation(keyword()) :: %Automation{} | nil
  def get_automation(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    Automation.not_deleted(Automation)
    |> where(^filters)
    |> Repo.one()
  end

  @spec list_automations(keyword()) :: [%Automation{}]
  def list_automations(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    Automation.not_deleted(Automation)
    |> where(^filters)
    |> Repo.all()
  end

  def create_automation(attrs \\ %{}),
    do: %Automation{} |> Automation.changeset(attrs) |> Repo.insert()

  def update_automation(%Automation{} = automation, attrs),
    do: automation |> Automation.changeset(attrs) |> Repo.update()

  def delete_automation(%Automation{} = automation),
    do: Repo.update_all(Automation.soft_delete(Automation), where: [id: automation.id])

  # Validate that all filter keys are valid fields
  defp validate_filters!(filters, valid_fields) do
    invalid_fields =
      filters
      |> Keyword.keys()
      |> Enum.reject(&(&1 in valid_fields))

    if invalid_fields != [] do
      raise ArgumentError,
            "Invalid filter fields: #{inspect(invalid_fields)}. Valid fields: #{inspect(valid_fields)}"
    end
  end
end
