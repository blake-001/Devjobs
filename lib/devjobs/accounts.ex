defmodule Devjobs.Accounts do
  import Ecto.Changeset
  alias Devjobs.Accounts.Admin
  alias Devjobs.Accounts.User
  alias Devjobs.Repo

  @password_min_length 12
  @password_max_length 128

  def list_admins, do: Repo.all(Admin)

  def list_users, do: Repo.all(User)

  def create_user(attrs) when is_map(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_admin(email, password)
      when is_binary(email) and is_binary(password) do
    email = email |> String.trim() |> String.downcase()

    case {Repo.get_by(Admin, email: email), byte_size(password) <= 72} do
      {%Admin{} = admin, true} ->
        if verify_password(password, admin.password_hash) do
          {:ok, admin}
        else
          {:error, :invalid_credentials}
        end

      {nil, _} ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      {%Admin{}, false} ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      _ ->
        {:error, :invalid_credentials}
    end
  end

  def authenticate_admin(_email, _password), do: {:error, :invalid_credentials}

  def authenticated_admin?(id, session_token) when is_integer(id) and is_binary(session_token) do
    case Repo.get(Admin, id) do
      %Admin{session_token: stored_token} when is_binary(stored_token) ->
        Plug.Crypto.secure_compare(stored_token, session_token)

      _ ->
        false
    end
  end

  def authenticated_admin?(_id, _session_token), do: false

  def create_admin(attrs) when is_map(attrs) do
    email = Map.get(attrs, :email) || Map.get(attrs, "email")
    password = Map.get(attrs, :password) || Map.get(attrs, "password")

    changeset =
      %Admin{}
      |> Admin.changeset(%{email: email})
      |> validate_password(password)

    persist_admin(changeset, password, &Repo.insert/1)
  end

  def update_admin_credentials(%Admin{} = admin, attrs) when is_map(attrs) do
    email = Map.get(attrs, :email) || Map.get(attrs, "email")
    password = Map.get(attrs, :password) || Map.get(attrs, "password")

    changeset =
      admin
      |> Admin.changeset(%{email: email})
      |> validate_password(password)

    persist_admin(changeset, password, &Repo.update/1)
  end

  defp persist_admin(changeset, password, persist) do
    if changeset.valid? do
      changeset
      |> put_change(:password_hash, hash_password(password))
      |> put_change(:session_token, Ecto.UUID.generate())
      |> persist.()
    else
      {:error, changeset}
    end
  end

  defp validate_password(changeset, password) when is_binary(password) do
    password_length = String.length(password)

    if password_length in @password_min_length..@password_max_length and
         byte_size(password) <= 72 do
      changeset
    else
      add_error(changeset, :password, "must be at least 12 characters and no more than 72 bytes")
    end
  end

  defp validate_password(changeset, _password) do
    add_error(changeset, :password, "is required")
  end

  defp hash_password(password), do: Bcrypt.hash_pwd_salt(password)
  defp verify_password(password, encoded_hash), do: Bcrypt.verify_pass(password, encoded_hash)
end
