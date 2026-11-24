defmodule Devjobs.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset

  @contracts ["Full Time", "Part Time", "Freelance"]

  schema "jobs" do
    field :position, :string
    field :contract, :string
    field :location, :string
    field :description, :string
    field :apply_url, :string
    field :requirements_content, :string
    field :requirements_items, {:array, :string}, default: []
    field :role_content, :string
    field :role_items, {:array, :string}, default: []
    field :posted_at, :utc_datetime

    belongs_to :company, Devjobs.Jobs.Company
    has_many :applications, Devjobs.Jobs.Application

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :position,
      :contract,
      :location,
      :description,
      :apply_url,
      :requirements_content,
      :requirements_items,
      :role_content,
      :role_items,
      :posted_at,
      :company_id
    ])
    |> validate_required([:position, :contract, :location, :posted_at, :company_id])
    |> validate_inclusion(:contract, @contracts)
    |> assoc_constraint(:company)
  end
end
