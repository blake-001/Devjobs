defmodule Devjobs.Repo.Migrations.AddPasswordSetupTokensToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :password_token_hash, :string
      add :password_token_purpose, :string
      add :password_token_expires_at, :utc_datetime
    end

    create unique_index(:users, [:password_token_hash])
  end
end
