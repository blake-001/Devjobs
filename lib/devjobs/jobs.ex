defmodule Devjobs.Jobs do
  import Ecto.Query, warn: false

  alias Devjobs.Repo
  alias Devjobs.Jobs.{Job, Application, Attachment}

  @page_size 12

  # -----listing and filtering-----

  def list_jobs(filters \\ %{}, opts \\ []) do
    limit = Keyword.get(opts, :limit, @page_size)
    offset = Keyword.get(opts, :offset, 0)

    filters
    |> base_query()
    |> order_by([j], desc: j.posted_at, desc: j.id)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([company: c], company: c)
    |> Repo.all()
  end

  def count_jobs(filters \\ %{}) do
    filters |> base_query() |> Repo.aggregate(:count, :id)
  end

  defp base_query(filters) do
    Job
    |> join(:inner, [j], c in assoc(j, :company), as: :company)
    |> filter_search(filters["search"])
    |> filter_location(filters["location"])
    |> filter_full_time(filters["full_time"])
  end

  defp filter_search(query, s) when s in [nil, ""], do: query

  defp filter_search(query, s) do
    term = "%#{escape_like(s)}%"

    where(
      query,
      [j, company: c],
      ilike(j.position, ^term) or ilike(c.name, ^term) or ilike(j.description, ^term)
    )
  end

  defp filter_location(query, l) when l in [nil, ""], do: query

  defp filter_location(query, l) do
    where(query, [j], ilike(j.location, ^"%#{escape_like(l)}%"))
  end

  defp filter_full_time(query, v) when v in [true, "true", "on"],
    do: where(query, [j], j.contract == "Full Time")

  defp filter_full_time(query, _), do: query

  # Stops users typing % or _ and changing the pattern
  defp escape_like(s) do
    s |> String.replace("\\", "\\\\") |> String.replace("%", "\\%") |> String.replace("_", "\\_")
  end

  # -----Single job-----
  def get_job!(id) do
    Job |> preload(:company) |> Repo.get!(id)
  end

  # -----Applications-----
  def change_application(%Application{} = app \\ %Application{}, attrs \\ %{}) do
    Application.changeset(app, attrs)
  end

  def already_applied?(job_id, email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()
    Repo.exists?(from a in Application, where: a.job_id == ^job_id and a.email == ^email)
  end

  def already_applied?(_job_id, _email), do: false

  def list_applications do
    Application
    |> order_by([a], desc: a.inserted_at, desc: a.id)
    |> preload([:attachments, job: :company])
    |> Repo.all()
  end

  def get_attachment(id) when is_binary(id) do
    case Integer.parse(id) do
      {attachment_id, ""} when attachment_id > 0 -> Repo.get(Attachment, attachment_id)
      _ -> nil
    end
  end

  def create_application(%Job{} = job, attrs, attachments \\ []) do
    Repo.transaction(fn ->
      changeset = Application.changeset(%Application{job_id: job.id}, attrs)

      case Repo.insert(changeset) do
        {:ok, app} ->
          Enum.each(attachments, fn file ->
            %Attachment{application_id: app.id}
            |> Attachment.changeset(file)
            |> Repo.insert!()
          end)

          app

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end
end
