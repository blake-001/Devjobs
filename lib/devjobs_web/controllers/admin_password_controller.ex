defmodule DevjobsWeb.AdminPasswordController do
  use DevjobsWeb, :controller

  require Logger

  alias Devjobs.Accounts
  alias Devjobs.Accounts.UserNotifier

  def forgot(conn, _params) do
    render_forgot(conn, Phoenix.Flash.get(conn.assigns[:flash] || %{}, :info))
  end

  def request_reset(conn, %{"password" => %{"email" => email}}) do
    case Accounts.create_user_password_reset(email) do
      {:ok, user, token} ->
        case UserNotifier.deliver_reset_instructions(user, token) do
          {:ok, _email} ->
            :ok

          {:error, reason} ->
            Logger.error("Password reset email delivery failed: #{inspect(reason)}")
        end

      :not_found ->
        :ok

      {:error, reason} ->
        Logger.error("Password reset token could not be created: #{inspect(reason)}")
    end

    conn
    |> put_flash(
      :info,
      "If an account exists for that email, a password reset link has been sent."
    )
    |> redirect(to: ~p"/admin/password/forgot")
  end

  def request_reset(conn, _params) do
    conn
    |> put_flash(
      :info,
      "If an account exists for that email, a password reset link has been sent."
    )
    |> redirect(to: ~p"/admin/password/forgot")
  end

  def setup(conn, %{"token" => token}) do
    if Accounts.valid_user_password_token?(token) do
      render_setup(conn, token, nil, password_token_purpose(token))
    else
      conn
      |> put_status(:gone)
      |> render_setup(token, "This password link is invalid or has expired.", "reset")
    end
  end

  def update(conn, %{"token" => token, "password" => params}) do
    password = params["password"]
    confirmation = params["password_confirmation"]

    if not Accounts.valid_user_password_token?(token) do
      conn
      |> put_status(:gone)
      |> render_setup(token, "This password link is invalid or has expired.", "reset")
    else
      update_password(conn, token, password, confirmation)
    end
  end

  def update(conn, %{"token" => token}) do
    render_setup(
      conn,
      token,
      "Enter and confirm your new password.",
      password_token_purpose(token)
    )
  end

  defp render_forgot(conn, info) do
    render(conn, :forgot, csrf_token: get_csrf_token(), info: info)
  end

  defp update_password(conn, token, password, confirmation) do
    if password != confirmation do
      render_setup(
        conn,
        token,
        "The password confirmation does not match.",
        password_token_purpose(token)
      )
    else
      case Accounts.set_user_password(token, password) do
        {:ok, _user} ->
          conn
          |> put_flash(:info, "Password saved. Sign in with your new password.")
          |> redirect(to: ~p"/admin/login")

        {:error, {:invalid_password, changeset}} ->
          message =
            changeset.errors
            |> Keyword.get(:password, {"is invalid", []})
            |> elem(0)
            |> then(&"Password #{&1}.")

          render_setup(conn, token, message, password_token_purpose(token))

        {:error, :invalid_token} ->
          conn
          |> put_status(:gone)
          |> render_setup(token, "This password link is invalid or has expired.", "reset")
      end
    end
  end

  defp render_setup(conn, token, error, purpose) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> render(:setup,
      csrf_token: get_csrf_token(),
      token: token,
      error: error,
      purpose: purpose,
      valid_link?: Accounts.valid_user_password_token?(token)
    )
  end

  defp password_token_purpose(token) do
    case Accounts.password_token_purpose(token) do
      purpose when purpose in ["setup", "reset"] -> purpose
      _ -> "reset"
    end
  end
end
