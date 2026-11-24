defmodule Devjobs.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments) do
      add :filename, :string, null: false
      add :path, :string, null: false
      add :content_type, :string
      add :size, :integer
      add :application_id, references(:applications, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:attachments, [:application_id])
  end
end
