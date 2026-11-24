defmodule Devjobs.Accounts do
  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Devjobs.Accounts.Admin
  alias Devjobs.Accounts.User
  alias Devjobs.Repo

  @password_min_length 12
  @password_max_length 128
  @password_token_ttl_minutes 30

  def list_admins, do: Repo.all(Admin)

  def list_users, do: Repo.all(User)

  def create_user_invitation(attrs) when is_map(attrs) do
    token = generate_password_token()

    changeset =
      %User{}
      |> User.changeset(attrs)
      |> put_password_token(token, "setup")

    case Repo.insert(changeset) do
      {:ok, user} -> {:ok, user, token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_user_password_reset(email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()

    case Repo.get_by(User, email: email) do
      nil ->
        :not_found

      user ->
        token = generate_password_token()

        user
        |> change()
        |> put_password_token(token, "reset")
        |> Repo.update()
        |> case do
          {:ok, updated_user} -> {:ok, updated_user, token}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def create_user_password_reset(_email), do: :not_found

  def valid_user_password_token?(token) when is_binary(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    token_hash = hash_password_token(token)

    Repo.exists?(
      from user in User,
        where:
          user.password_token_hash == ^token_hash and
            user.password_token_purpose in ["setup", "reset"] and
            user.password_token_expires_at > ^now
    )
  end

  def valid_user_password_token?(_token), do: false

  def password_token_purpose(token) when is_binary(token) do
    hash = hash_password_token(token)

    Repo.one(
      from user in User,
        where: user.password_token_hash == ^hash,
        select: user.password_token_purpose
    )
  end

  def password_token_purpose(_token), do: nil

  def set_user_password(token, password) when is_binary(token) do
    token_hash = hash_password_token(token)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      user =
        Repo.one(
          from user in User,
            where:
              user.password_token_hash == ^token_hash and
                user.password_token_purpose in ["setup", "reset"] and
                user.password_token_expires_at > ^now,
            lock: "FOR UPDATE"
        )

      if is_nil(user), do: Repo.rollback(:invalid_token)

      changeset =
        user
        |> change()
        |> validate_password(password)

      if changeset.valid? do
        changeset =
          changeset
          |> put_change(:password_hash, hash_password(password))
          |> put_change(:session_token, Ecto.UUID.generate())
          |> put_change(:password_token_hash, nil)
          |> put_change(:password_token_purpose, nil)
          |> put_change(:password_token_expires_at, nil)

        case Repo.update(changeset) do
          {:ok, updated_user} -> updated_user
          {:error, changeset} -> Repo.rollback({:invalid_password, changeset})
        end
      else
        Repo.rollback({:invalid_password, changeset})
      end
    end)
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_user_password(_token, _password), do: {:error, :invalid_token}

  def authenticate_user(email, password)
      when is_binary(email) and is_binary(password) do
    email = email |> String.trim() |> String.downcase()

    case {Repo.get_by(User, email: email), byte_size(password) <= 72} do
      {%User{password_hash: password_hash} = user, true} when is_binary(password_hash) ->
        if verify_password(password, password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      {nil, _} ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      {%User{}, _} ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def authenticate_user(_email, _password), do: {:error, :invalid_credentials}

  def authenticated_user?(id, session_token) when is_integer(id) and is_binary(session_token) do
    case Repo.get(User, id) do
      %User{session_token: stored_token} when is_binary(stored_token) ->
        Plug.Crypto.secure_compare(stored_token, session_token)

      _ ->
        false
    end
  end

  def authenticated_user?(_id, _session_token), do: false

  def authenticate_account(email, password) do
    case authenticate_admin(email, password) do
      {:ok, admin} ->
        {:ok, :admin, admin}

      {:error, :invalid_credentials} ->
        case authenticate_user(email, password) do
          {:ok, user} -> {:ok, :user, user}
          {:error, :invalid_credentials} = error -> error
        end
    end
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

  defp put_password_token(changeset, token, purpose) do
    changeset
    |> put_change(:password_token_hash, hash_password_token(token))
    |> put_change(:password_token_purpose, purpose)
    |> put_change(
      :password_token_expires_at,
      DateTime.utc_now()
      |> DateTime.add(@password_token_ttl_minutes, :minute)
      |> DateTime.truncate(:second)
    )
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

  defp generate_password_token do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end

  defp hash_password_token(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
end
