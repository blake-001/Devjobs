defmodule Devjobs.Accounts.UserNotifier do
  import Swoosh.Email

  alias Devjobs.Accounts.User
  alias Devjobs.Mailer
  alias DevjobsWeb.Endpoint

  def deliver_setup_instructions(%User{} = user, token) do
    deliver_password_link(
      user,
      token,
      "Set up your Devjobs admin account",
      "Use this one-time link to choose a password for your Devjobs admin account."
    )
  end

  def deliver_reset_instructions(%User{} = user, token) do
    deliver_password_link(
      user,
      token,
      "Reset your Devjobs admin password",
      "Use this one-time link to reset your Devjobs admin password."
    )
  end

  defp deliver_password_link(user, token, subject, introduction) do
    url = Endpoint.url() <> "/admin/password/setup/" <> token

    email =
      new()
      |> to(user.email)
      |> from(Application.fetch_env!(:devjobs, :email_from))
      |> subject(subject)
      |> text_body("""
      Hello #{user.first_name},

      #{introduction}

      This link expires in 30 minutes and can only be used once:
      #{url}

      If you did not expect this email, you can ignore it.
      """)

    Mailer.deliver(email)
  end
end
