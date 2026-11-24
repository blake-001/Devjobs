defmodule Devjobs.Jobs.Company do
  use Ecto.Schema
  import Ecto.Changeset

  schema "companies" do
    field :name, :string
    field :logo_background, :string
    field :website, :string

    has_many :jobs, Devjobs.Jobs.Job

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :logo_background, :website])
    |> validate_required([:name])
  end
end
