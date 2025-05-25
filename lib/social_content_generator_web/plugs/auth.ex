defmodule SocialContentGeneratorWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller

  alias SocialContentGenerator.Users

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      case Users.get_user(user_id) do
        nil ->
          conn
          |> delete_session("user_id")
          |> redirect(to: "/login")
          |> halt()

        user ->
          assign(conn, :current_user, user)
      end
    else
      conn
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
