defmodule SocialContentGenerator.Users do
  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo

  alias SocialContentGenerator.Users.User

  def list_users, do: Repo.all(User.not_deleted(User))
  def get_user!(id), do: Repo.get!(User, id)
  def create_user(attrs \\ %{}), do: %User{} |> User.changeset(attrs) |> Repo.insert()
  def update_user(%User{} = user, attrs), do: user |> User.changeset(attrs) |> Repo.update()

  def delete_user(%User{} = user),
    do: Repo.update_all(User.soft_delete(User), where: [id: user.id])

  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)
end
