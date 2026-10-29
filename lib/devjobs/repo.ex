defmodule Devjobs.Repo do
  use Ecto.Repo,
    otp_app: :devjobs,
    adapter: Ecto.Adapters.Postgres
end
