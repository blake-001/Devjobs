defmodule DevjobsWeb.AdminAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Devjobs.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    if authenticated_session?(fn key -> get_session(conn, key) end) do
      conn
    else
      redirect_to_login(conn)
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    if authenticated_session?(fn key -> session[Atom.to_string(key)] end) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
    end
  end

  defp authenticated_session?(session_value) do
    Accounts.authenticated_admin?(
      session_value.(:admin_id),
      session_value.(:admin_session_token)
    ) or
      Accounts.authenticated_user?(
        session_value.(:user_id),
        session_value.(:user_session_token)
      )
  end

  defp redirect_to_login(conn) do
    conn
    |> redirect(to: "/admin/login")
    |> halt()
  end
end
