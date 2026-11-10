defmodule Devjobs.Jobs do
  import Ecto.Query, warn: false

  alias Devjobs.Repo
  alias Devjobs.Jobs.{Job, Application, Attachment, Company}

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

  def list_companies do
    from(c in Company, order_by: c.name)
    |> Repo.all()
  end

  def create_job(attrs) do
    Repo.transaction(fn ->
      company =
        case resolve_job_company(attrs) do
          {:ok, company} -> company
          {:error, reason} -> Repo.rollback(reason)
        end

      job_attrs =
        attrs
        |> Map.take([
          "position",
          "contract",
          "location",
          "description",
          "apply_url",
          "requirements_content",
          "requirements_items",
          "role_content",
          "role_items"
        ])
        |> Map.update("requirements_items", [], &split_lines/1)
        |> Map.update("role_items", [], &split_lines/1)
        |> Map.put("company_id", company.id)
        |> Map.put("posted_at", DateTime.utc_now() |> DateTime.truncate(:second))

      changeset =
        %Job{}
        |> Job.changeset(job_attrs)
        |> Ecto.Changeset.validate_required([:description])

      case Repo.insert(changeset) do
        {:ok, job} -> job
        {:error, changeset} -> Repo.rollback({:job_changeset, changeset})
      end
    end)
  end

  defp resolve_job_company(%{"company_id" => company_id})
       when company_id not in ["", nil] do
    case Integer.parse(company_id) do
      {id, ""} when id > 0 ->
        case Repo.get(Company, id) do
          nil -> {:error, :invalid_company}
          company -> {:ok, company}
        end

      _ ->
        {:error, :invalid_company}
    end
  end

  defp resolve_job_company(attrs) do
    company_attrs = %{
      "name" => attrs["company_name"],
      "website" => attrs["company_website"],
      "logo_background" => attrs["company_logo_background"]
    }

    changeset = Company.changeset(%Company{}, company_attrs)

    case Repo.insert(changeset) do
      {:ok, company} -> {:ok, company}
      {:error, changeset} -> Repo.rollback({:company_changeset, changeset})
    end
  end

  defp split_lines(value) when is_binary(value) do
    value
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_lines(value), do: value

  # -----Applications-----
  def change_application(app \\ %Application{}, attrs \\ %{}) do
    Application.changeset(app, attrs)
  end

  def already_applied?(job_id, email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()
    Repo.exists?(from a in Application, where: a.job_id == ^job_id and a.email == ^email)
  end

  def already_applied?(_job_id, _email), do: false

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

  # -----Applications listing-----
  def list_applications(filters \\ %{}) do
    from(a in Application,
      join: j in assoc(a, :job),
      join: c in assoc(j, :company),
      order_by: [desc: a.inserted_at],
      preload: [:attachments, job: [:company]]
    )
    |> filter_application_search(filters["search"])
    |> filter_application_location(filters["location"])
    |> filter_application_contract(filters["contract"])
    |> Repo.all()
  end

  def delete_application(id) do
    with {:ok, application_id} <- parse_application_id(id),
         %Application{} = application <-
           Repo.get(Application, application_id) |> Repo.preload(:attachments) do
      case Repo.delete(application) do
        {:ok, deleted_application} ->
          case delete_attachment_files(application.attachments) do
            :ok -> {:ok, deleted_application}
            {:error, errors} -> {:error, {:file_cleanup_failed, deleted_application, errors}}
          end

        {:error, changeset} ->
          {:error, {:delete_failed, changeset}}
      end
    else
      nil -> {:error, :not_found}
      {:error, _reason} = error -> error
    end
  end

  defp parse_application_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_application_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {application_id, ""} when application_id > 0 -> {:ok, application_id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_application_id(_id), do: {:error, :invalid_id}

  defp delete_attachment_files(attachments) do
    errors =
      Enum.reduce(attachments, [], fn attachment, errors ->
        case delete_uploaded_file(attachment.path) do
          :ok -> errors
          {:error, reason} -> [{attachment.filename, reason} | errors]
        end
      end)

    case errors do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  defp delete_uploaded_file(path) when is_binary(path) do
    uploads_dir = Path.expand("priv/uploads")
    expanded_path = Path.expand(path)
    relative_path = Path.relative_to(expanded_path, uploads_dir)

    if relative_path == expanded_path or relative_path in [".", ".."] or
         String.starts_with?(relative_path, "../") do
      {:error, :outside_uploads_directory}
    else
      case validate_upload_path(uploads_dir, Path.split(relative_path)) do
        :ok -> File.rm(expanded_path)
        :missing -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp delete_uploaded_file(_path), do: {:error, :invalid_path}

  defp validate_upload_path(uploads_dir, components) do
    case File.lstat(uploads_dir) do
      {:ok, %File.Stat{type: :directory}} -> validate_upload_components(uploads_dir, components)
      {:error, :enoent} -> :missing
      {:ok, _stat} -> {:error, :invalid_uploads_directory}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_upload_components(_directory, []), do: {:error, :invalid_path}

  defp validate_upload_components(directory, [component]) do
    case File.lstat(Path.join(directory, component)) do
      {:ok, %File.Stat{type: :regular}} -> :ok
      {:error, :enoent} -> :missing
      {:ok, _stat} -> {:error, :not_a_regular_file}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_upload_components(directory, [component | rest]) do
    case File.lstat(Path.join(directory, component)) do
      {:ok, %File.Stat{type: :directory}} ->
        validate_upload_components(Path.join(directory, component), rest)

      {:error, :enoent} ->
        :missing

      {:ok, _stat} ->
        {:error, :invalid_upload_directory}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp filter_application_search(query, search) when search in [nil, ""], do: query

  defp filter_application_search(query, search) do
    term = "%#{escape_like(search)}%"

    where(query, [_a, j, c], ilike(j.position, ^term) or ilike(c.name, ^term))
  end

  defp filter_application_location(query, location) when location in [nil, ""], do: query

  defp filter_application_location(query, location) do
    term = "%#{escape_like(location)}%"
    where(query, [_a, j, _c], ilike(j.location, ^term))
  end

  defp filter_application_contract(query, contract) when contract in [nil, ""], do: query

  defp filter_application_contract(query, contract) do
    where(query, [_a, j, _c], j.contract == ^contract)
  end

  def get_attachment(id) do
    Repo.get(Attachment, id)
  end
end
