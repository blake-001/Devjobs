defmodule Devjobs.Jobs.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attachments" do
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
    |> cast(attrs, [:filename, :path, :content_type, :size])
    |> validate_required([:filename, :path])
  end
end
