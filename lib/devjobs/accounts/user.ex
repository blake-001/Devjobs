defmodule Devjobs.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Inspect, except: []}

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :email])
    |> validate_required([:first_name, :last_name, :email])
    |> update_change(:first_name, &String.trim/1)
    |> update_change(:last_name, &String.trim/1)
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> unique_constraint(:email)
  end
end
