defmodule DevjobsWeb.AdminSessionController do
  use DevjobsWeb, :controller

  def new(conn, _params) do
    conn
    |> configure_session(renew: true)
    |> render_login(nil)
  end

  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    credentials = Application.get_env(:devjobs, :admin, [])

    if valid_credentials?(credentials, email, password) do
      conn
      |> configure_session(renew: true)
      |> put_session(:admin_authenticated, true)
      |> redirect(to: ~p"/admin/applications")
    else
      conn
      |> put_status(:unauthorized)
      |> render_login("Invalid admin credentials or admin login is not configured.")
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> render_login("Invalid admin credentials or admin login is not configured.")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/admin/login")
  end

  defp render_login(conn, error) do
    render(conn, :new, csrf_token: get_csrf_token(), error: error)
  end

  defp valid_credentials?(credentials, email, password)
       when is_binary(email) and is_binary(password) do
    with configured_email when is_binary(configured_email) <- credentials[:email],
         configured_password when is_binary(configured_password) <- credentials[:password] do
      configured_email != "" and configured_password != "" and
        secure_compare(configured_email, email) and
        secure_compare(configured_password, password)
    else
      _ -> false
    end
  end

  defp valid_credentials?(_credentials, _email, _password), do: false

  defp secure_compare(left, right) when byte_size(left) == byte_size(right),
    do: Plug.Crypto.secure_compare(left, right)

  defp secure_compare(_left, _right), do: false
end
