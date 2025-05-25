defmodule SocialContentGenerator.Users do
  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo

  alias SocialContentGenerator.Users.User

  @valid_filters [:id, :email, :first_name, :last_name, :deleted_at]

  @spec list_users() :: [%User{}]
  def list_users, do: Repo.all(User.not_deleted(User))

  @spec list_users(keyword()) :: [%User{}]
  def list_users(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    User.not_deleted(User)
    |> where(^filters)
    |> Repo.all()
  end

  @spec get_user(number()) :: %User{} | nil
  def get_user(id) when is_number(id) do
    User.not_deleted(User)
    |> where(id: ^id)
    |> Repo.one()
  end

  @spec get_user(keyword()) :: %User{} | nil
  def get_user(filters) when is_list(filters) do
    validate_filters!(filters, @valid_filters)

    User.not_deleted(User)
    |> where(^filters)
    |> Repo.one()
  end

  def create_user(attrs \\ %{}), do: %User{} |> User.changeset(attrs) |> Repo.insert()
  def update_user(%User{} = user, attrs), do: user |> User.changeset(attrs) |> Repo.update()

  def delete_user(%User{} = user),
    do: Repo.update_all(User.soft_delete(User), where: [id: user.id])

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
