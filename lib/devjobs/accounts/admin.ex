defmodule Devjobs.Accounts.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Inspect, except: [:password_hash, :session_token]}

  schema "admins" do
    field :email, :string
    field :password_hash, :string, redact: true
    field :session_token, :string, redact: true

    timestamps(type: :utc_datetime)
  end

  def changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email])
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> unique_constraint(:email)
  end
end
