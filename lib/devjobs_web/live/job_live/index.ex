defmodule DevjobsWeb.JobLive.Index do
  use DevjobsWeb, :live_view
  import DevjobsWeb.JobComponents

  alias Devjobs.Jobs

  @page_size 12
  @default_filters %{"search" => "", "location" => "", "full_time" => "false"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:filters, @default_filters) |> load_jobs()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = Map.merge(@default_filters, Map.take(params, Map.keys(@default_filters)))
    {:noreply, socket |> assign(:filters, filters) |> load_jobs()}
  end

  def handle_event("load-more", _params, socket) do
    jobs =
      Jobs.list_jobs(socket.assigns.filters,
        limit: @page_size,
        offset: socket.assigns.loaded
      )

    {:noreply,
     socket
     |> assign(:loaded, socket.assigns.loaded + length(jobs))
     |> stream(:jobs, jobs)}
  end

  defp load_jobs(socket) do
    filters = socket.assigns.filters
    jobs = Jobs.list_jobs(filters, limit: @page_size)

    socket
    |> assign(:loaded, length(jobs))
    |> assign(:total, Jobs.count_jobs(filters))
    |> stream(:jobs, jobs, reset: true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.site_header />

      <div class="mx-auto max-w-[1110px] px-6 pb-16">
        <.filter_bar filters={@filters} />

        <div
          id="jobs"
          phx-update="stream"
          class="mt-16 grid grid-cols-1 gap-x-[30px] gap-y-16 md:grid-cols-2 lg:grid-cols-3"
        >
          <div
            id="jobs-empty"
            class="col-span-full hidden py-10 text-center text-dark-grey only:block"
          >
            No jobs match your filters.
          </div>
          <.job_card :for={{id, job} <- @streams.jobs} id={id} job={job} />
        </div>

        <div :if={@loaded < @total} class="mt-14 text-center">
          <button
            phx-click="load-more"
            class="cursor-pointer rounded-md bg-violet px-8 py-4 font-bold text-white transition hover:bg-light-violet"
          >
            Load More
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
