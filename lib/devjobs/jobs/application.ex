defmodule Devjobs.Jobs.Application do
  use Ecto.Schema
  import Ecto.Changeset

  schema "applications" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string

    belongs_to :job, Devjobs.Jobs.Job
    has_many :attachments, Devjobs.Jobs.Attachment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(application, attrs) do
    application
    |> cast(attrs, [:first_name, :last_name, :email])
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:first_name, :last_name, :email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must have a valid email")
    |> validate_length(:first_name, max: 80)
    |> validate_length(:last_name, max: 80)
    |> unique_constraint(:email,
      name: :applications_job_id_email_index,
      message: "You have already applied to this job"
    )
  end
end
