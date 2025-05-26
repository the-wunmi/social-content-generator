defmodule SocialContentGenerator.Users do
  import Ecto.Query, warn: false
  alias SocialContentGenerator.Repo

  alias SocialContentGenerator.Users.User
  alias SocialContentGenerator.Automations

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

  @spec get_user(binary() | number()) :: %User{} | nil
  def get_user(id) when is_binary(id) or is_number(id) do
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

  def create_user(attrs \\ %{}) do
    case %User{} |> User.changeset(attrs) |> Repo.insert() do
      {:ok, user} ->
        # Create default email follow-up automation for new users
        create_default_email_automation(user)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user(%User{} = user, attrs), do: user |> User.changeset(attrs) |> Repo.update()

  def delete_user(%User{} = user),
    do: Repo.update_all(User.soft_delete(User), where: [id: user.id])

  @doc """
  Creates the default email follow-up automation for existing users who don't have one.
  This can be called manually or in a migration for existing users.
  """
  def ensure_default_email_automation(%User{} = user) do
    # Check if user already has an email automation
    existing_email_automation =
      Automations.list_automations(user_id: user.id)
      |> Enum.find(&(&1.output_type == "email"))

    if is_nil(existing_email_automation) do
      create_default_email_automation(user)
    else
      :already_exists
    end
  end

  # Create a default email follow-up automation for new users
  defp create_default_email_automation(user) do
    automation_attrs = %{
      name: "Meeting Follow-up Email",
      description:
        "Automatically generate follow-up emails after meetings to summarize key points and next steps.",
      output_type: "email",
      example_output: """
      Subject: Follow-up from our meeting

      Hi [Name],

      Thank you for taking the time to meet with me today. I wanted to follow up on our discussion and summarize the key points we covered:

      • [Key point 1]
      • [Key point 2]
      • [Key point 3]

      Next steps:
      • [Action item 1]
      • [Action item 2]

      Please let me know if you have any questions or if there's anything I missed.

      Best regards,
      [Your name]
      """,
      active: true,
      user_id: user.id
    }

    case Automations.create_automation(automation_attrs) do
      {:ok, _automation} ->
        :ok

      {:error, _changeset} ->
        # Log the error but don't fail user creation
        require Logger
        Logger.warning("Failed to create default email automation for user #{user.id}")
        :ok
    end
  end

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
