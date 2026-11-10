defmodule DevjobsWeb.AdminJobLive do
  use DevjobsWeb, :live_view

  alias Devjobs.Jobs

  @impl true
  def mount(_params, _session, socket) do
    companies = Jobs.list_companies()

    {:ok,
     socket
     |> assign(page_title: "Add a job")
     |> assign(:company_options, [
       {"Create a new company", ""} | Enum.map(companies, &{&1.name, &1.id})
     ])
     |> assign(:form, to_form(%{}, as: :job))
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("create_job", %{"job" => params}, socket) do
    case Jobs.create_job(params) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Job created successfully.")
         |> push_navigate(to: ~p"/admin/applications")}

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
      <main class="mx-auto max-w-3xl px-6 py-10">
        <.link navigate="/admin/applications" class="font-bold text-violet hover:underline">
          &larr; Back to applications
        </.link>

        <div class="mt-6 rounded-lg bg-white p-6 shadow-sm dark:bg-midnight sm:p-8">
          <h1 class="text-3xl font-bold">Add a new job</h1>
          <p class="mt-2 text-dark-grey">Create a job listing for the public job board.</p>

          <p :if={@error_message} id="job-form-error" role="alert" class="mt-5 text-red-600">
            {@error_message}
          </p>

          <.form
            for={@form}
            id="job-form"
            phx-submit="create_job"
            class="mt-6 space-y-5"
          >
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
                navigate="/admin/applications"
                class="rounded-md border border-dark-grey/30 px-6 py-3 font-bold transition hover:bg-dark-grey/10"
              >
                Cancel
              </.link>
            </div>
          </.form>
        </div>
      </main>
    </Layouts.app>
    """
  end
end
