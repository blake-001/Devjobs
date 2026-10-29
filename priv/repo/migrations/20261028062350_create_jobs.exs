defmodule Devjobs.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :position, :string, null: false
      add :contract, :string, null: false
      add :location, :string, null: false
      add :description, :text
      add :apply_url, :string
      add :requirements_content, :text
      add :requirements_items, {:array, :string}, default: []
      add :role_content, :text
      add :role_items, {:array, :string}, default: []
      add :posted_at, :utc_datetime, null: false
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:jobs, [:company_id])
    create index(:jobs, [:contract])
    create index(:jobs, [:location])
    create index(:jobs, [:position])
  end
end
