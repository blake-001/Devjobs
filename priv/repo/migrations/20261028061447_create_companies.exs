defmodule Devjobs.Repo.Migrations.CreateCompanies do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :string, null: false
      add :logo_background, :string
      add :website, :string

      timestamps(type: :utc_datetime)
    end
  end
end
