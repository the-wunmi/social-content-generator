defmodule SocialContentGenerator.Meetings do
  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo

  alias SocialContentGenerator.Meetings.Meeting

  @valid_filters [
    :id,
    :user_id,
    :title,
    :start_time,
    :end_time,
    :status,
    :calendar_event_id,
    :deleted_at
  ]

  @spec list_meetings() :: [%Meeting{}]
  def list_meetings, do: Repo.all(Meeting.not_deleted(Meeting))

  @spec list_meetings(keyword()) :: [%Meeting{}]
  def list_meetings(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    Meeting.not_deleted(Meeting)
    |> where(^filters)
    |> Repo.all()
  end

  @spec get_meeting(binary() | number()) :: %Meeting{} | nil
  def get_meeting(id) when is_binary(id) or is_number(id) do
    Meeting.not_deleted(Meeting)
    |> where(id: ^id)
    |> Repo.one()
  end

  @spec get_meeting(keyword()) :: %Meeting{} | nil
  def get_meeting(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    Meeting.not_deleted(Meeting)
    |> where(^filters)
    |> Repo.one()
  end

  def create_meeting(attrs \\ %{}), do: %Meeting{} |> Meeting.changeset(attrs) |> Repo.insert()

  def update_meeting(%Meeting{} = meeting, attrs),
    do: meeting |> Meeting.changeset(attrs) |> Repo.update()

  def delete_meeting(%Meeting{} = meeting),
    do: Repo.update_all(Meeting.soft_delete(Meeting), where: [id: meeting.id])

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
