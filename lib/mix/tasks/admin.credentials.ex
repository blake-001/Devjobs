defmodule Mix.Tasks.Admin.Credentials do
  use Mix.Task

  alias Devjobs.Accounts

  @shortdoc "Create or update the admin login credentials"

  @impl Mix.Task
  def run([]) do
    Mix.Task.run("app.start")

    admin =
      case Accounts.list_admins() do
        [] ->
          nil

        [admin] ->
          admin

        _admins ->
          Mix.raise(
            "More than one admin exists; update accounts directly before using this task."
          )
      end

    email = prompt_email(admin)
    password = prompt_password()

    attrs = %{email: email, password: password}

    result =
      case admin do
        nil -> Accounts.create_admin(attrs)
        admin -> Accounts.update_admin_credentials(admin, attrs)
      end

    case result do
      {:ok, saved_admin} ->
        Mix.shell().info("Admin credentials saved for #{saved_admin.email}.")

      {:error, changeset} ->
        Mix.raise("Could not save admin credentials: #{inspect(changeset.errors)}")
    end
  end

  def run(_args) do
    Mix.raise("Usage: mix admin.credentials")
  end

  defp prompt_email(nil) do
    email = IO.gets("Admin email: ") |> String.trim()
    if email == "", do: Mix.raise("Admin email is required."), else: email
  end

  defp prompt_email(admin) do
    case IO.gets("Admin email [#{admin.email}]: ") |> String.trim() do
      "" -> admin.email
      email -> email
    end
  end

  defp prompt_password do
    password = read_password("New password: ")
    confirmation = read_password("Confirm password: ")

    if password != confirmation do
      Mix.raise("Passwords do not match.")
    end

    password
  end

  defp read_password(prompt) do
    Mix.shell().info(prompt)

    case :shell.start_interactive({:noshell, :raw}) do
      :ok ->
        try do
          read_hidden_password()
        after
          :shell.start_interactive({:noshell, :cooked})
        end

      {:error, :already_started} ->
        read_hidden_password()

      {:error, reason} ->
        Mix.raise("Could not enable hidden password input: #{inspect(reason)}")
    end
  end

  defp read_hidden_password do
    case :io.get_password() do
      password when is_binary(password) ->
        Mix.shell().info("")
        String.trim_trailing(password, "\r")

      password when is_list(password) ->
        Mix.shell().info("")
        password |> List.to_string() |> String.trim_trailing("\r")

      {:error, reason} ->
        Mix.raise(
          "Could not read password without echo (#{inspect(reason)}). Run this task in an interactive terminal."
        )

      other ->
        Mix.raise("Could not read password: #{inspect(other)}")
    end
  end
end
