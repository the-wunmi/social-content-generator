defmodule SocialContentGeneratorWeb.SessionController do
  use SocialContentGeneratorWeb, :controller

  def index(conn, _params) do
    if get_session(conn, :user_id) do
      redirect(conn, to: ~p"/calendar")
    else
      redirect(conn, to: ~p"/login")
    end
  end

  def login(conn, _params) do
    render(conn, :login)
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:user_id)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end
end
