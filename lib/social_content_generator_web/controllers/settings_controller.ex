defmodule SocialContentGeneratorWeb.SettingsController do
  use SocialContentGeneratorWeb, :controller

  alias SocialContentGenerator.Services.OAuth
  alias SocialContentGenerator.Integrations
  alias SocialContentGenerator.Automations
  alias SocialContentGenerator.Users
  alias SocialContentGenerator.Repo

  def index(conn, _params) do
    integrations =
      Integrations.list_integrations(user_id: conn.assigns.current_user.id, scopes: "automation")

    render(conn, :index, integrations: integrations)
  end

  def automations(conn, _params) do
    automations =
      Automations.list_automations(user_id: conn.assigns.current_user.id)
      |> Repo.preload([:integration])

    render(conn, :automations, automations: automations)
  end

  def new_automation(conn, _params) do
    changeset =
      SocialContentGenerator.Automations.Automation.changeset(
        %SocialContentGenerator.Automations.Automation{},
        %{}
      )

    # Get user's connected integrations for social media and email
    integrations =
      Integrations.list_integrations(user_id: conn.assigns.current_user.id)
      |> Enum.filter(fn integration ->
        "automation" in integration.scopes
      end)

    render(conn, :new_automation, changeset: changeset, integrations: integrations)
  end

  def create_automation(conn, %{"automation" => automation_params}) do
    automation_params = Map.put(automation_params, "user_id", conn.assigns.current_user.id)

    case Automations.create_automation(automation_params) do
      {:ok, _automation} ->
        conn
        |> put_flash(:info, "Automation created successfully.")
        |> redirect(to: ~p"/settings/automations")

      {:error, changeset} ->
        # Get integrations again for the form
        integrations =
          Integrations.list_integrations(user_id: conn.assigns.current_user.id)
          |> Enum.filter(fn integration ->
            "automation" in integration.scopes
          end)

        conn
        |> put_flash(:error, "Failed to create automation.")
        |> render(:new_automation, changeset: changeset, integrations: integrations)
    end
  end

  def edit_automation(conn, %{"id" => id}) do
    automation = Automations.get_automation(id: id, user_id: conn.assigns.current_user.id)

    case automation do
      nil ->
        conn
        |> put_flash(:error, "Automation not found")
        |> redirect(to: ~p"/settings/automations")

      automation ->
        changeset = SocialContentGenerator.Automations.Automation.changeset(automation, %{})

        # Get user's connected integrations for social media and email
        integrations =
          Integrations.list_integrations(user_id: conn.assigns.current_user.id)
          |> Enum.filter(fn integration ->
            "automation" in integration.scopes
          end)

        render(conn, :edit_automation,
          automation: automation,
          changeset: changeset,
          integrations: integrations
        )
    end
  end

  def update_automation(conn, %{"id" => id, "automation" => automation_params}) do
    automation = Automations.get_automation(id: id, user_id: conn.assigns.current_user.id)

    case automation do
      nil ->
        conn
        |> put_flash(:error, "Automation not found")
        |> redirect(to: ~p"/settings/automations")

      automation ->
        case Automations.update_automation(automation, automation_params) do
          {:ok, _automation} ->
            conn
            |> put_flash(:info, "Automation updated successfully.")
            |> redirect(to: ~p"/settings/automations")

          {:error, changeset} ->
            # Get integrations again for the form
            integrations =
              Integrations.list_integrations(user_id: conn.assigns.current_user.id)
              |> Enum.filter(fn integration ->
                "automation" in integration.scopes
              end)

            conn
            |> put_flash(:error, "Failed to update automation.")
            |> render(:edit_automation,
              automation: automation,
              changeset: changeset,
              integrations: integrations
            )
        end
    end
  end

  def delete_automation(conn, %{"id" => id}) do
    automation = Automations.get_automation(id: id, user_id: conn.assigns.current_user.id)

    case automation do
      nil ->
        conn
        |> put_flash(:error, "Automation not found")
        |> redirect(to: ~p"/settings/automations")

      automation ->
        {:ok, _automation} = Automations.delete_automation(automation)

        conn
        |> put_flash(:info, "Automation deleted successfully.")
        |> redirect(to: ~p"/settings/automations")
    end
  end

  def google_auth(conn, _params) do
    redirect(conn, external: OAuth.google_auth_url())
  end

  def provider_auth(conn, %{"provider" => provider}) do
    auth_url =
      case provider do
        "linkedin" ->
          OAuth.linkedin_auth_url()

        "facebook" ->
          OAuth.facebook_auth_url()

        _ ->
          conn
          |> put_flash(:error, "Unsupported provider: #{provider}")
          |> redirect(to: ~p"/settings")
          |> halt()
      end

    redirect(conn, external: auth_url)
  end

  def bot_settings(conn, _params) do
    user = conn.assigns.current_user
    changeset = SocialContentGenerator.Users.User.changeset(user, %{})
    render(conn, :bot_settings, user: user, changeset: changeset)
  end

  def update_bot_settings(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user

    case Users.update_user(user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Bot settings updated successfully.")
        |> redirect(to: ~p"/settings/bot")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Failed to update bot settings.")
        |> render(:bot_settings, user: user, changeset: changeset)
    end
  end
end
