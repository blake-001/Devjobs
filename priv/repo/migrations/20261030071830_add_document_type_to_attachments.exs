defmodule Devjobs.Repo.Migrations.AddDocumentTypeToAttachments do
  use Ecto.Migration

  def change do
    alter table(:attachments) do
      add :document_type, :string
    end
  end
end
