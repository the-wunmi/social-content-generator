defmodule SocialContentGeneratorWeb.SettingsController do
  use SocialContentGeneratorWeb, :controller

  alias SocialContentGenerator.Services.OAuth
  alias SocialContentGenerator.Integrations
  alias SocialContentGenerator.Automations
  alias SocialContentGenerator.Users

  def index(conn, _params) do
    integrations =
      Integrations.list_integrations(user_id: conn.assigns.current_user.id, scopes: "automation")

    render(conn, :index, integrations: integrations)
  end

  def automations(conn, _params) do
    automations = Automations.list_automations(user_id: conn.assigns.current_user.id)
    render(conn, :automations, automations: automations)
  end

  def new_automation(conn, _params) do
    render(conn, :new_automation)
  end

  def create_automation(conn, %{"automation" => automation_params}) do
    automation_params = Map.put(automation_params, "user_id", conn.assigns.current_user.id)

    case Automations.create_automation(automation_params) do
      {:ok, _automation} ->
        conn
        |> put_flash(:info, "Automation created successfully.")
        |> redirect(to: ~p"/settings/automations")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to create automation.")
        |> render(:new_automation)
    end
  end

  def edit_automation(conn, %{"id" => id}) do
    automation = Automations.get_automation(id)
    render(conn, :edit_automation, automation: automation)
  end

  def update_automation(conn, %{"id" => id, "automation" => automation_params}) do
    automation = Automations.get_automation(id)

    case Automations.update_automation(automation, automation_params) do
      {:ok, _automation} ->
        conn
        |> put_flash(:info, "Automation updated successfully.")
        |> redirect(to: ~p"/settings/automations")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to update automation.")
        |> render(:edit_automation, automation: automation)
    end
  end

  def delete_automation(conn, %{"id" => id}) do
    automation = Automations.get_automation(id)
    {:ok, _automation} = Automations.delete_automation(automation)

    conn
    |> put_flash(:info, "Automation deleted successfully.")
    |> redirect(to: ~p"/settings/automations")
  end

  def google_auth(conn, _params) do
    redirect(conn, external: OAuth.google_auth_url())
  end

  def linkedin_auth(conn, _params) do
    redirect(conn, external: OAuth.linkedin_auth_url())
  end

  def facebook_auth(conn, _params) do
    redirect(conn, external: OAuth.facebook_auth_url())
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
