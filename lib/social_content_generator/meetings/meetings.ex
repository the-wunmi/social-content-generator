defmodule SocialContentGenerator.Meetings do
  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo

  alias SocialContentGenerator.Meetings.Meeting

  def list_meetings, do: Repo.all(Meeting.not_deleted(Meeting))
  def get_meeting!(id), do: Repo.get!(Meeting, id)
  def create_meeting(attrs \\ %{}), do: %Meeting{} |> Meeting.changeset(attrs) |> Repo.insert()

  def update_meeting(%Meeting{} = meeting, attrs),
    do: meeting |> Meeting.changeset(attrs) |> Repo.update()

  def delete_meeting(%Meeting{} = meeting),
    do: Repo.update_all(Meeting.soft_delete(Meeting), where: [id: meeting.id])

  def change_meeting(%Meeting{} = meeting, attrs \\ %{}), do: Meeting.changeset(meeting, attrs)

  def list_user_meetings(user_id),
    do:
      from(m in Meeting, where: m.user_id == ^user_id and is_nil(m.deleted_at))
      |> Repo.all()
end
