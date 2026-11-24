defmodule Devjobs.Jobs.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attachments" do
    field :document_type, :string
    field :filename, :string
    field :path, :string
    field :content_type, :string
    field :size, :integer

    belongs_to :application, Devjobs.Jobs.Application

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:document_type, :filename, :path, :content_type, :size])
    |> validate_required([:document_type, :filename, :path])
    |> validate_inclusion(:document_type, ["cv", "cover_letter"])
  end
end
