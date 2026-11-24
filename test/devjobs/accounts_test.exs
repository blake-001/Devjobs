defmodule Devjobs.AccountsTest do
  use Devjobs.DataCase, async: true

  alias Devjobs.Accounts

  test "admin credentials are normalized, hashed, and persistently verifiable" do
    password = "a-long-test-password"

    assert {:ok, admin} =
             Accounts.create_admin(%{email: "  ADMIN@example.com ", password: password})

    assert admin.email == "admin@example.com"
    refute admin.password_hash == password
    assert String.starts_with?(admin.password_hash, "$2")

    assert {:ok, authenticated_admin} =
             Accounts.authenticate_admin(" ADMIN@example.com ", password)

    assert authenticated_admin.id == admin.id
  end

  test "rejects invalid admin credentials and passwords shorter than twelve characters" do
    assert {:error, changeset} =
             Accounts.create_admin(%{email: "admin@example.com", password: "short"})

    assert "must be at least 12 characters and no more than 72 bytes" in errors_on(changeset).password

    assert {:error, :invalid_credentials} =
             Accounts.authenticate_admin("missing@example.com", "a-long-test-password")

    assert {:ok, _admin} =
             Accounts.create_admin(%{
               email: "admin@example.com",
               password: "a-long-test-password"
             })

    assert {:error, :invalid_credentials} =
             Accounts.authenticate_admin("admin@example.com", "another-wrong-password")

    assert {:error, :invalid_credentials} =
             Accounts.authenticate_admin("admin@example.com", String.duplicate("x", 73))
  end

  test "updates the existing admin email and password" do
    assert {:ok, admin} =
             Accounts.create_admin(%{
               email: "old-admin@example.com",
               password: "old-long-password"
             })

    assert {:ok, updated_admin} =
             Accounts.update_admin_credentials(admin, %{
               email: "new-admin@example.com",
               password: "new-long-password"
             })

    assert updated_admin.email == "new-admin@example.com"

    assert {:ok, ^updated_admin} =
             Accounts.authenticate_admin("new-admin@example.com", "new-long-password")

    assert {:error, :invalid_credentials} =
             Accounts.authenticate_admin("old-admin@example.com", "old-long-password")

    refute Accounts.authenticated_admin?(admin.id, admin.session_token)
    assert Accounts.authenticated_admin?(updated_admin.id, updated_admin.session_token)
  end

  test "setup links are hashed, expire, and can only be used once" do
    assert {:ok, user, token} =
             Accounts.create_user_invitation(%{
               first_name: "New",
               last_name: "Staff",
               email: "new-staff@example.com"
             })

    assert is_nil(user.password_hash)
    assert user.password_token_purpose == "setup"
    refute user.password_token_hash == token
    assert Accounts.valid_user_password_token?(token)

    assert {:error, {:invalid_password, changeset}} = Accounts.set_user_password(token, "short")

    assert "must be at least 12 characters and no more than 72 bytes" in errors_on(changeset).password

    assert Accounts.valid_user_password_token?(token)

    assert {:ok, updated_user} =
             Accounts.set_user_password(token, "a-secure-new-password")

    refute Accounts.valid_user_password_token?(token)
    assert {:error, :invalid_token} = Accounts.set_user_password(token, "another-secure-password")

    assert {:ok, authenticated_user} =
             Accounts.authenticate_user(" NEW-STAFF@example.com ", "a-secure-new-password")

    assert authenticated_user.id == updated_user.id
    assert Accounts.authenticated_user?(updated_user.id, updated_user.session_token)
    refute Accounts.authenticated_user?(user.id, user.session_token)
  end

  test "expired password links cannot be used" do
    assert {:ok, user, token} =
             Accounts.create_user_invitation(%{
               first_name: "Expired",
               last_name: "Link",
               email: "expired-link@example.com"
             })

    user
    |> Ecto.Changeset.change(password_token_expires_at: ~U[2020-01-01 00:00:00Z])
    |> Devjobs.Repo.update!()

    refute Accounts.valid_user_password_token?(token)
    assert {:error, :invalid_token} = Accounts.set_user_password(token, "a-secure-new-password")
  end
end
