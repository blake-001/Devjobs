defmodule DevjobsWeb.AdminJobLive do
  use DevjobsWeb, :live_view

  alias Devjobs.Jobs

  @impl true
  def mount(_params, _session, socket) do
    companies = Jobs.list_companies()

    {:ok,
     socket
     |> assign(:active_nav, :jobs)
     |> assign(:sidebar_collapsed?, false)
     |> assign(:company_options, [
       {"Create a new company", ""} | Enum.map(companies, &{&1.name, &1.id})
     ])
     |> assign(:form, to_form(%{}, as: :job))
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    title = if socket.assigns.live_action == :new, do: "Add a job", else: "Jobs"
    job_count = Jobs.count_jobs(%{})
    jobs = Jobs.list_jobs(%{}, limit: job_count)

    {:noreply,
     socket
     |> assign(page_title: title, job_count: job_count)
     |> stream(:jobs, jobs, reset: true)}
  end

  @impl true
  def handle_event("toggle-sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_collapsed?, &(!&1))}
  end

  @impl true
  def handle_event("create_job", %{"job" => params}, socket) do
    case Jobs.create_job(params) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Job created successfully.")
         |> push_navigate(to: ~p"/admin/jobs")}

      {:error, {:job_changeset, _changeset}} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :job))
         |> assign(
           :error_message,
           "Add a job title, contract type, location, and description before saving."
         )}

      {:error, {:company_changeset, _changeset}} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :job))
         |> assign(:error_message, "Enter a company name or select an existing company.")}

      {:error, :invalid_company} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :job))
         |> assign(:error_message, "The selected company could not be found. Choose another.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex h-screen overflow-hidden dark:bg-midnight">
        <aside
          id="admin-sidebar"
          data-state={if(@sidebar_collapsed?, do: "collapsed", else: "expanded")}
          class={[
            "hidden w-64 flex-shrink-0 flex-col border-r border-dark-grey/20 bg-white dark:bg-midnight",
            !@sidebar_collapsed? && "xl:flex"
          ]}
        >
          <div class="p-6">
            <.link
              navigate="/admin/applications"
              class="text-xl font-bold text-midnight dark:text-white"
            >
              Devjobs Admin
            </.link>
          </div>
          <nav class="flex-1 space-y-1 overflow-y-auto py-4">
            <.nav_item
              active={false}
              navigate="/admin/applications"
              icon="hero-document-text"
              label="Applications"
            />
            <.nav_item
              active={true}
              navigate="/admin/jobs"
              icon="hero-briefcase"
              label="Jobs"
            />
            <.nav_item
              active={false}
              navigate="/admin/users"
              icon="hero-user-group"
              label="Users"
            />
          </nav>
          <div class="border-t border-dark-grey/20 p-6">
            <a
              href="/admin/logout"
              class="flex items-center gap-2 text-sm font-bold text-violet hover:underline"
            >
              <.icon name="hero-logout" class="h-4 w-4" /> Sign out
            </a>
          </div>
        </aside>

        <main class="flex-1 overflow-y-auto bg-dark-grey/50 p-6 dark:bg-very-dark-blue">
          <header class="mb-8 flex items-start gap-4">
            <button
              type="button"
              id="toggle-admin-sidebar"
              phx-click="toggle-sidebar"
              aria-controls="admin-sidebar"
              aria-expanded={!@sidebar_collapsed?}
              aria-label={if(@sidebar_collapsed?, do: "Show sidebar", else: "Hide sidebar")}
              class="mt-1 hidden rounded-md p-2 text-dark-grey transition hover:bg-dark-grey/10 hover:text-violet xl:inline-flex"
            >
              <.icon name="hero-bars-3" class="h-5 w-5" />
            </button>
            <div class="flex flex-1 items-start justify-between gap-4">
              <div>
                <h1 class="text-3xl font-bold text-midnight dark:text-white">
                  {if @live_action == :new, do: "Add a new job", else: "Jobs"}
                </h1>
                <p class="mt-1 text-dark-grey/60 dark:text-dark-grey/40">
                  {if @live_action == :new,
                    do: "Create a job listing for the public job board.",
                    else: "#{@job_count} jobs found"}
                </p>
              </div>
              <.link
                :if={@live_action == :index}
                navigate="/admin/jobs/new"
                id="add-job"
                class="rounded-md bg-violet px-4 py-2 font-bold text-white transition hover:bg-light-violet"
              >
                Add new job
              </.link>
            </div>
          </header>

          <section
            :if={@live_action == :index}
            id="jobs-list"
            class="overflow-hidden rounded-lg border border-dark-grey/10 bg-white shadow-sm dark:bg-midnight"
          >
            <div id="jobs" phx-update="stream" class="divide-y divide-dark-grey/10">
              <div
                id="jobs-empty-state"
                class="hidden only:block px-5 py-10 text-center text-dark-grey"
              >
                No jobs have been added yet.
              </div>
              <div
                :for={{id, job} <- @streams.jobs}
                id={id}
                class="grid gap-2 px-5 py-4 sm:grid-cols-4 sm:items-center"
              >
                <div>
                  <p class="font-bold text-midnight dark:text-white">{job.position}</p>
                  <p class="text-sm text-dark-grey">{job.company.name}</p>
                </div>
                <p class="text-dark-grey">{job.location}</p>
                <p class="text-dark-grey">{job.contract}</p>
                <p class="text-sm text-dark-grey sm:text-right">
                  Posted {Calendar.strftime(job.posted_at, "%Y-%m-%d")}
                </p>
              </div>
            </div>
          </section>

          <section
            :if={@live_action == :new}
            class="mx-auto max-w-3xl rounded-lg bg-white p-6 shadow-sm dark:bg-midnight sm:p-8"
          >
            <p :if={@error_message} id="job-form-error" role="alert" class="mb-5 text-red-600">
              {@error_message}
            </p>

            <.form for={@form} id="job-form" phx-submit="create_job" class="space-y-5">
              <div>
                <label for="job_position" class="mb-2 block font-bold">Job title</label>
                <.input
                  field={@form[:position]}
                  type="text"
                  required
                  class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                />
              </div>

              <div class="grid gap-5 sm:grid-cols-2">
                <div>
                  <label for="job_contract" class="mb-2 block font-bold">Contract type</label>
                  <.input
                    field={@form[:contract]}
                    type="select"
                    required
                    options={[
                      {"Select contract type", ""},
                      {"Full Time", "Full Time"},
                      {"Part Time", "Part Time"},
                      {"Freelance", "Freelance"}
                    ]}
                    class="w-full rounded-md border border-dark-grey/30 bg-white px-3 py-2 text-midnight dark:bg-midnight dark:text-white"
                  />
                </div>
                <div>
                  <label for="job_location" class="mb-2 block font-bold">Location</label>
                  <.input
                    field={@form[:location]}
                    type="text"
                    required
                    placeholder="e.g. Nairobi or Remote"
                    class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                  />
                </div>
              </div>

              <div>
                <label for="job_description" class="mb-2 block font-bold">Job description</label>
                <.input
                  field={@form[:description]}
                  type="textarea"
                  required
                  rows="6"
                  class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                />
              </div>

              <section class="space-y-4 border-t border-dark-grey/20 pt-5">
                <h2 class="text-xl font-bold">Requirements</h2>
                <div>
                  <label for="job_requirements_content" class="mb-2 block font-bold">
                    Requirements introduction
                  </label>
                  <.input
                    field={@form[:requirements_content]}
                    type="textarea"
                    rows="3"
                    class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                  />
                </div>
                <div>
                  <label for="job_requirements_items" class="mb-2 block font-bold">
                    Requirement bullet points
                  </label>
                  <.input
                    field={@form[:requirements_items]}
                    type="textarea"
                    rows="4"
                    placeholder="Enter one requirement per line"
                    class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                  />
                </div>
              </section>

              <section class="space-y-4 border-t border-dark-grey/20 pt-5">
                <h2 class="text-xl font-bold">What the person will do</h2>
                <div>
                  <label for="job_role_content" class="mb-2 block font-bold">Role introduction</label>
                  <.input
                    field={@form[:role_content]}
                    type="textarea"
                    rows="3"
                    class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                  />
                </div>
                <div>
                  <label for="job_role_items" class="mb-2 block font-bold">Responsibilities</label>
                  <.input
                    field={@form[:role_items]}
                    type="textarea"
                    rows="4"
                    placeholder="Enter one responsibility per line"
                    class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                  />
                </div>
              </section>

              <div>
                <label for="job_apply_url" class="mb-2 block font-bold">Application URL</label>
                <.input
                  field={@form[:apply_url]}
                  type="url"
                  placeholder="https://example.com/careers"
                  class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                />
              </div>

              <section class="space-y-4 border-t border-dark-grey/20 pt-5">
                <div>
                  <h2 class="text-xl font-bold">Company</h2>
                  <p class="mt-1 text-sm text-dark-grey">
                    Select an existing company, or leave this blank and enter details for a new one.
                    New company fields are ignored when an existing company is selected.
                  </p>
                </div>

                <div>
                  <label for="job_company_id" class="mb-2 block font-bold">Existing company</label>
                  <.input
                    field={@form[:company_id]}
                    type="select"
                    options={@company_options}
                    class="w-full rounded-md border border-dark-grey/30 bg-white px-3 py-2 text-midnight dark:bg-midnight dark:text-white"
                  />
                </div>

                <div class="grid gap-5 sm:grid-cols-2">
                  <div>
                    <label for="job_company_name" class="mb-2 block font-bold">New company name</label>
                    <.input
                      field={@form[:company_name]}
                      type="text"
                      class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                    />
                  </div>
                  <div>
                    <label for="job_company_website" class="mb-2 block font-bold">
                      New company website
                    </label>
                    <.input
                      field={@form[:company_website]}
                      type="url"
                      placeholder="https://example.com"
                      class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                    />
                  </div>
                </div>

                <div>
                  <label for="job_company_logo_background" class="mb-2 block font-bold">
                    New company logo background
                  </label>
                  <.input
                    field={@form[:company_logo_background]}
                    type="text"
                    placeholder="#5964E0"
                    class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                  />
                </div>
              </section>

              <div class="flex flex-wrap gap-3 pt-2">
                <button
                  id="create-job-submit"
                  type="submit"
                  class="rounded-md bg-violet px-6 py-3 font-bold text-white transition hover:bg-light-violet"
                >
                  Create job
                </button>
                <.link
                  navigate="/admin/jobs"
                  class="rounded-md border border-dark-grey/30 px-6 py-3 font-bold transition hover:bg-dark-grey/10"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end
end
