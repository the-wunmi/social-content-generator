defmodule SocialContentGeneratorWeb.SessionController do
  use SocialContentGeneratorWeb, :controller

  alias SocialContentGenerator.Users
  alias SocialContentGenerator.Auth.OAuth

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
