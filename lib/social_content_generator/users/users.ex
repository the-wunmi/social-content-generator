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

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def authenticate_user(email, password) do
    # This is a placeholder implementation
    # In a real app, you'd hash the password and compare with stored hash
    case Repo.get_by(User, email: email) do
      nil ->
        {:error, :invalid_credentials}

      user ->
        # For now, just check if password matches email (demo purposes)
        # In production, use proper password hashing like Argon2
        if password == "password" do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end
end
