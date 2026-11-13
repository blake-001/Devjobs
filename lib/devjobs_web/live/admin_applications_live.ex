defmodule DevjobsWeb.AdminApplicationsLive do
  use DevjobsWeb, :live_view

  alias Devjobs.Jobs
  alias Devjobs.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Applications")
     |> assign(:active_nav, :applications)
     |> load_stats()
     |> load_recent_applications(%{})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = normalize_filters(params)
    query = filters |> Enum.reject(fn {_key, value} -> value == "" end) |> URI.encode_query()
    csv_url = "/admin/applications.csv" <> if(query == "", do: "", else: "?" <> query)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:csv_url, csv_url)
     |> assign(:has_filters?, Enum.any?(filters, fn {_key, value} -> value != "" end))
     |> load_stats()
     |> load_recent_applications(filters)}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters = normalize_filters(params)
    query = filters |> Enum.reject(fn {_key, value} -> value == "" end) |> URI.encode_query()
    path = "/admin/applications" <> if(query == "", do: "", else: "?" <> query)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:csv_url, "/admin/applications.csv" <> if(query == "", do: "", else: "?" <> query))
     |> assign(:has_filters?, Enum.any?(filters, fn {_key, value} -> value != "" end))
     |> load_stats()
     |> load_recent_applications(filters)
     |> push_patch(to: path)}
  end

  @impl true
  def handle_event("delete-application", %{"id" => id}, socket) do
    case Jobs.delete_application(id) do
      {:ok, application} ->
        {:noreply,
         socket
         |> remove_application(application)
         |> load_stats()
         |> put_flash(:info, "Application deleted.")}

      {:error, {:file_cleanup_failed, application, errors}} ->
        filenames = Enum.map_join(errors, ", ", fn {filename, _reason} -> filename end)

        {:noreply,
         socket
         |> remove_application(application)
         |> load_stats()
         |> put_flash(
           :error,
           "Application deleted, but these uploaded files could not be removed: #{filenames}."
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Application not found. Refresh the dashboard.")}

      {:error, {:delete_failed, _changeset}} ->
        {:noreply,
         socket |> put_flash(:error, "Application could not be deleted. Please try again.")}

      {:error, :invalid_id} ->
        {:noreply,
         socket
         |> put_flash(:error, "Application could not be identified. Refresh the dashboard.")}
    end
  end

  defp load_stats(socket) do
    total = Jobs.total_application_count() || 0
    today = Jobs.today_application_count() || 0
    jobs = Jobs.count_jobs(%{}) || 0
    users = Accounts.list_users() |> length()

    assign(socket,
      total_applications: total,
      today_applications: today,
      job_count: jobs,
      user_count: users
    )
  end

  defp load_recent_applications(socket, filters) do
    applications =
      Jobs.list_applications(filters)
      |> Enum.take(10)

    socket
    |> assign(:application_count, length(applications))
    |> stream(:applications, applications, reset: true)
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
      <div class="flex h-screen overflow-hidden dark:bg-midnight">
        <aside class="hidden w-64 flex-shrink-0 flex-col border-r border-dark-grey/20 bg-white dark:bg-midnight xl:flex">
          <div class="p-6">
            <.link
              navigate="/admin/applications"
              class="text-xl font-bold text-midnight dark:text-white"
            >
              Devjobs Admin
            </.link>
          </div>
          <nav class="flex-1 overflow-y-auto py-4 space-y-1">
            <.nav_item
              active={@active_nav == :applications}
              navigate="/admin/applications"
              icon="hero-document-text"
              label="Applications"
            />
            <.nav_item
              active={@active_nav == :jobs}
              navigate="/admin/jobs/new"
              icon="hero-briefcase"
              label="Jobs"
            />
            <.nav_item
              active={@active_nav == :users}
              navigate="/admin/users/new"
              icon="hero-user-group"
              label="Users"
            />
          </nav>
          <div class="p-6 border-t border-dark-grey/20">
            <a
              href="/admin/logout"
              class="flex items-center gap-2 text-sm font-bold text-violet hover:underline"
            >
              <.icon name="hero-logout" class="w-4 h-4" /> Sign out
            </a>
          </div>
        </aside>

        <main class="flex-1 overflow-y-auto bg-dark-grey/50 dark:bg-very-dark-blue p-6">
          <header class="mb-8">
            <h1 class="text-3xl font-bold text-midnight dark:text-white">Job applications</h1>
            <p class="mt-1 text-dark-grey/60 dark:text-dark-grey/40">
              {@application_count} applications found
            </p>
          </header>

          <!-- Stat cards -->
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-8">
            <.stat_card
              label="Total applications"
              value={@total_applications}
              icon="hero-document-text"
              trend="+12% vs last month"
            />
            <.stat_card
              label="Today"
              value={@today_applications}
              icon="hero-arrow-trending-up"
              trend="+5% vs yesterday"
            />
            <.stat_card
              label="Active jobs"
              value={@job_count}
              icon="hero-briefcase"
              trend="Open positions"
            />
            <.stat_card
              label="Users"
              value={@user_count}
              icon="hero-user-group"
              trend="Staff accounts"
            />
          </div>

          <!-- Filters + actions -->
          <div class="flex flex-col gap-4 md:flex-row md:items-center mb-6">
            <.form
              for={@filter_form}
              id="application-filters"
              phx-change="filter"
              class="flex-1 gap-4 flex flex-col sm:flex-row"
            >
              <div class="flex-1">
                <label for="filters_search" class="mb-1 block text-sm font-bold text-dark-grey">Job or company</label>
                <.input
                  field={@filter_form[:search]}
                  type="search"
                  placeholder="Search title or company"
                  phx-debounce="300"
                  class="w-full rounded-md border border-dark-grey/30 bg-transparent px-3 py-2"
                />
              </div>
              <div class="flex-1">
                <label for="filters_location" class="mb-1 block text-sm font-bold text-dark-grey">Location</label>
                <.input
                  field={@filter_form[:location]}
                  type="search"
                  placeholder="Search location"
                  class="w-full rounded-md border border-dark-grey/30 bg-transparent px-3 py-2"
                />
              </div>
              <div class="flex-1">
                <label for="filters_contract" class="mb-1 block text-sm font-bold text-dark-grey">Contract type</label>
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
                  class="text-sm font-bold text-violet hover:underline"
                >
                  Clear filters
                </.link>
              </div>
            </.form>

            <div class="flex gap-2">
              <.link
                navigate="/admin/jobs/new"
                id="add-job"
                class="rounded-md bg-violet px-4 py-2 font-bold text-white transition hover:bg-light-violet"
              >
                Add new job
              </.link>
              <a
                href={@csv_url}
                class="rounded-md bg-violet px-4 py-2 font-bold text-white transition hover:bg-light-violet"
              >
                Download CSV
              </a>
              <.link
                navigate="/admin/users/new"
                class="rounded-md border border-dark-grey/30 px-4 py-2 font-bold text-dark-grey transition hover:bg-dark-grey/10"
              >
                Add user
              </.link>
            </div>
          </div>

          <!-- Applications table -->
          <div class="rounded-lg bg-white shadow-sm dark:bg-midnight border border-dark-grey/10 overflow-hidden">
            <div id="applications-table" class="overflow-x-auto">
              <table id="applications-table-inner" class="w-full min-w-[900px] text-left">
                <thead class="border-b border-dark-grey/20 bg-dark-grey/50 dark:bg-dark-grey/80 text-sm text-dark-grey">
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
                      <h2 class="font-bold text-midnight dark:text-white">
                        {application.first_name} {application.last_name}
                      </h2>
                      <p class="mt-1 text-sm text-dark-grey">{application.email}</p>
                    </td>
                    <td class="max-w-sm px-5 py-4">
                      <h3 class="font-bold text-midnight dark:text-white">
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
          </div>
        </main>
      </div>
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
