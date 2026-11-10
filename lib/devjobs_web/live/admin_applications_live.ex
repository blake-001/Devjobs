defmodule DevjobsWeb.AdminApplicationsLive do
  use DevjobsWeb, :live_view

  alias Devjobs.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Applications")
     |> assign(application_count: 0)
     |> stream(:applications, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = normalize_filters(params)
    applications = Jobs.list_applications(filters)
    query = filters |> Enum.reject(fn {_key, value} -> value == "" end) |> URI.encode_query()
    csv_url = "/admin/applications.csv" <> if(query == "", do: "", else: "?" <> query)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:csv_url, csv_url)
     |> assign(:has_filters?, Enum.any?(filters, fn {_key, value} -> value != "" end))
     |> assign(:application_count, length(applications))
     |> stream(:applications, applications, reset: true)}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters = normalize_filters(params)
    query = filters |> Enum.reject(fn {_key, value} -> value == "" end) |> URI.encode_query()
    path = "/admin/applications" <> if(query == "", do: "", else: "?" <> query)

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("delete-application", %{"id" => id}, socket) do
    case Jobs.delete_application(id) do
      {:ok, application} ->
        {:noreply,
         socket
         |> remove_application(application)
         |> put_flash(:info, "Application deleted.")}

      {:error, {:file_cleanup_failed, application, errors}} ->
        filenames = Enum.map_join(errors, ", ", fn {filename, _reason} -> filename end)

        {:noreply,
         socket
         |> remove_application(application)
         |> put_flash(
           :error,
           "Application deleted, but these uploaded files could not be removed: #{filenames}."
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Application not found. Refresh the dashboard.")}

      {:error, {:delete_failed, _changeset}} ->
        {:noreply,
         put_flash(socket, :error, "Application could not be deleted. Please try again.")}

      {:error, :invalid_id} ->
        {:noreply,
         put_flash(socket, :error, "Application could not be identified. Refresh the dashboard.")}
    end
  end

  defp remove_application(socket, application) do
    socket
    |> stream_delete(:applications, application)
    |> update(:application_count, &max(&1 - 1, 0))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-6xl px-6 py-10">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold">Job applications</h1>
            <p class="mt-2 text-dark-grey">{@application_count} applications found</p>
          </div>
          <div class="flex items-center gap-4">
            <.link
              navigate="/admin/jobs/new"
              id="add-job"
              class="rounded-md bg-violet px-5 py-3 font-bold text-white transition hover:bg-light-violet"
            >
              Add new job
            </.link>
            <a
              href={@csv_url}
              class="rounded-md bg-violet px-5 py-3 font-bold text-white transition hover:bg-light-violet"
            >
              Download CSV
            </a>
            <a href="/admin/logout" class="font-bold text-violet hover:underline">Sign out</a>
          </div>
        </div>

        <.form
          for={@filter_form}
          id="application-filters"
          phx-change="filter"
          class="mt-8 grid gap-4 rounded-lg bg-white p-5 shadow-sm dark:bg-midnight sm:grid-cols-2 lg:grid-cols-4"
        >
          <div>
            <label for="filters_search" class="mb-2 block text-sm font-bold">Job or company</label>
            <.input
              field={@filter_form[:search]}
              type="search"
              placeholder="Search title or company"
              phx-debounce="300"
              class="w-full rounded-md border border-dark-grey/30 bg-transparent px-3 py-2"
            />
          </div>
          <div>
            <label for="filters_location" class="mb-2 block text-sm font-bold">Location</label>
            <.input
              field={@filter_form[:location]}
              type="search"
              placeholder="Search location"
              class="w-full rounded-md border border-dark-grey/30 bg-transparent px-3 py-2"
            />
          </div>
          <div>
            <label for="filters_contract" class="mb-2 block text-sm font-bold">Contract type</label>
            <.input
              field={@filter_form[:contract]}
              type="select"
              options={[
                {"All contract types", ""},
                {"Full Time", "Full Time"},
                {"Part Time", "Part Time"},
                {"Freelance", "Freelance"}
              ]}
              class="w-full rounded-md border border-dark-grey/30 bg-white px-3 py-2 text-midnight dark:bg-midnight dark:text-white"
            />
          </div>
          <div class="flex items-end">
            <.link
              :if={@has_filters?}
              patch="/admin/applications"
              id="clear-application-filters"
              class="font-bold text-violet hover:underline"
            >
              Clear filters
            </.link>
          </div>
        </.form>

        <div class="mt-6 overflow-x-auto rounded-lg bg-white shadow-sm dark:bg-midnight">
          <table id="applications-table" class="w-full min-w-[900px] text-left">
            <thead class="border-b border-dark-grey/20 text-sm text-dark-grey">
              <tr>
                <th scope="col" class="px-5 py-4 font-bold">Applicant</th>
                <th scope="col" class="px-5 py-4 font-bold">Job</th>
                <th scope="col" class="px-5 py-4 font-bold">Location</th>
                <th scope="col" class="px-5 py-4 font-bold">Contract</th>
                <th scope="col" class="px-5 py-4 font-bold">Submitted</th>
                <th scope="col" class="px-5 py-4 font-bold">Documents</th>
                <th scope="col" class="px-5 py-4 font-bold">Actions</th>
              </tr>
            </thead>
            <tbody id="applications" phx-update="stream" class="divide-y divide-dark-grey/10">
              <tr id="applications-empty-state" class="hidden only:table-row">
                <td colspan="7" class="px-5 py-10 text-center text-dark-grey">
                  {if @has_filters?,
                    do: "No applications match these filters.",
                    else: "No applications have been submitted yet."}
                </td>
              </tr>
              <tr
                :for={{id, application} <- @streams.applications}
                id={id}
                class="align-top transition hover:bg-light-grey/70 dark:hover:bg-very-dark-blue/50"
              >
                <td class="px-5 py-4">
                  <h2 class="font-bold">{application.first_name} {application.last_name}</h2>
                  <p class="mt-1 text-sm text-dark-grey">{application.email}</p>
                </td>
                <td class="max-w-sm px-5 py-4">
                  <h3 class="font-bold">
                    {application.job.position} at {application.job.company.name}
                  </h3>
                  <p class="mt-1 line-clamp-2 text-sm text-dark-grey">
                    {application.job.description}
                  </p>
                </td>
                <td class="whitespace-nowrap px-5 py-4">{application.job.location}</td>
                <td class="whitespace-nowrap px-5 py-4">{application.job.contract}</td>
                <td class="whitespace-nowrap px-5 py-4 text-sm text-dark-grey">
                  {Calendar.strftime(application.inserted_at, "%Y-%m-%d %H:%M UTC")}
                </td>
                <td class="px-5 py-4">
                  <div :if={application.attachments != []} class="flex flex-col items-start gap-2">
                    <a
                      :for={attachment <- application.attachments}
                      href={"/admin/attachments/#{attachment.id}"}
                      class="font-bold text-violet hover:underline"
                    >
                      Download {document_type_label(attachment.document_type)}
                    </a>
                  </div>
                  <p :if={application.attachments == []} class="text-sm text-dark-grey">
                    No documents
                  </p>
                </td>
                <td class="px-5 py-4">
                  <button
                    type="button"
                    id={"delete-application-#{application.id}"}
                    phx-hook="ConfirmDeleteApplication"
                    data-application-id={application.id}
                    data-confirm-message="Delete this application and its uploaded documents? This cannot be undone."
                    class="rounded-md border border-red-500/40 px-3 py-2 text-sm font-bold text-red-600 transition hover:bg-red-500/10 dark:text-red-400"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </main>
    </Layouts.app>
    """
  end

  defp document_type_label(nil), do: "Document"

  defp document_type_label(document_type) do
    document_type
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp normalize_filters(params) do
    contract = params["contract"]

    %{
      "search" => normalize_text(params["search"]),
      "location" => normalize_text(params["location"]),
      "contract" =>
        if(contract in ["Full Time", "Part Time", "Freelance"], do: contract, else: "")
    }
  end

  defp normalize_text(value) when is_binary(value), do: String.trim(value)
  defp normalize_text(_value), do: ""
end
