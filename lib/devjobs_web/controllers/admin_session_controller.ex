defmodule DevjobsWeb.AdminSessionController do
  use DevjobsWeb, :controller

  alias Devjobs.Accounts

  def new(conn, _params) do
    conn
    |> configure_session(renew: true)
    |> render_login(nil, Phoenix.Flash.get(conn.assigns[:flash] || %{}, :info))
  end

  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_account(email, password) do
      {:ok, :admin, admin} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:admin_id, admin.id)
        |> put_session(:admin_session_token, admin.session_token)
        |> redirect(to: ~p"/admin/applications")

      {:ok, :user, user} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_session(:user_session_token, user.session_token)
        |> redirect(to: ~p"/admin/applications")

      {:error, :invalid_credentials} ->
        invalid_credentials(conn)
    end
  end

  def create(conn, _params) do
    invalid_credentials(conn)
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/admin/login")
  end

  defp invalid_credentials(conn) do
    conn
    |> put_status(:unauthorized)
    |> render_login("Invalid email or password.", nil)
  end

  defp render_login(conn, error, info) do
    render(conn, :new, csrf_token: get_csrf_token(), error: error, info: info)
  end
end
