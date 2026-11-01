defmodule DevjobsWeb.AdminAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_authenticated) do
      conn
    else
      conn
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    if session["admin_authenticated"] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
    end
  end
end
