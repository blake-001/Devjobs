defmodule Devjobs.Repo.Migrations.AddAuthenticationFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :password_hash, :string
      add :session_token, :string
    end
  end
end
