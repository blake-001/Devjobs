defmodule Devjobs.Repo.Migrations.AddSessionTokenToAdmins do
  use Ecto.Migration

  def up do
    alter table(:admins) do
      add :session_token, :string
    end

    execute("UPDATE admins SET session_token = md5(random()::text || clock_timestamp()::text)")

    alter table(:admins) do
      modify :session_token, :string, null: false
    end
  end

  def down do
    alter table(:admins) do
      remove :session_token
    end
  end
end
