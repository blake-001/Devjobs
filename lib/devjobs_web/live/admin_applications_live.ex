defmodule DevjobsWeb.AdminApplicationsLive do
  use DevjobsWeb, :live_view

  alias Devjobs.Jobs

  @impl true
  def mount(_params, _session, socket) do
    applications = Jobs.list_applications()

    {:ok,
     socket
     |> assign(page_title: "Applications")
     |> assign(application_count: length(applications))
     |> stream(:applications, applications)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-6xl px-6 py-10">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold">Job applications</h1>
            <p class="mt-2 text-dark-grey">{@application_count} total applications</p>
          </div>
          <div class="flex items-center gap-4">
            <a
              href="/admin/applications.csv"
              class="rounded-md bg-violet px-5 py-3 font-bold text-white transition hover:bg-light-violet"
            >
              Download CSV
            </a>
            <a href="/admin/logout" class="font-bold text-violet hover:underline">Sign out</a>
          </div>
        </div>

        <div
          id="applications"
          phx-update="stream"
          class="mt-6 space-y-6"
        >
          <div
            id="applications-empty-state"
            class="hidden only:block rounded-lg bg-white p-8 dark:bg-midnight"
          >
            No applications have been submitted yet.
          </div>
          <section
            :for={{id, application} <- @streams.applications}
            id={id}
            class="rounded-lg bg-white p-6 shadow-sm dark:bg-midnight"
          >
            <div class="flex flex-wrap justify-between gap-4">
              <div>
                <h2 class="text-xl font-bold">
                  {application.first_name} {application.last_name}
                </h2>
                <p class="mt-1 text-dark-grey">{application.email}</p>
              </div>
              <p class="text-sm text-dark-grey">
                Submitted {Calendar.strftime(application.inserted_at, "%Y-%m-%d %H:%M UTC")}
              </p>
            </div>

            <div class="mt-5 border-t border-dark-grey/20 pt-5">
              <h3 class="font-bold">{application.job.position} at {application.job.company.name}</h3>
              <p class="mt-1 text-sm text-dark-grey">
                {application.job.location} · {application.job.contract}
              </p>
              <h4 class="mt-4 font-bold">Job description</h4>
              <p class="mt-2 whitespace-pre-wrap text-dark-grey">{application.job.description}</p>
            </div>

            <div class="mt-5 flex flex-wrap gap-3">
              <a
                :for={attachment <- application.attachments}
                href={"/admin/attachments/#{attachment.id}"}
                class="rounded-md border border-violet px-4 py-2 font-bold text-violet transition hover:bg-violet/10"
              >
                Download {document_type_label(attachment.document_type)}
              </a>
              <p :if={application.attachments == []} class="text-sm text-dark-grey">
                No documents attached.
              </p>
            </div>
          </section>
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
end
