defmodule DevjobsWeb.JobComponents do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  # ---------- Helpers ----------

  def time_ago(%DateTime{} = dt) do
    s = DateTime.diff(DateTime.utc_now(), dt)

    cond do
      s < 3_600 -> "#{max(div(s, 60), 1)}m ago"
      s < 86_400 -> "#{div(s, 3_600)}h ago"
      s < 604_800 -> "#{div(s, 86_400)}d ago"
      s < 2_592_000 -> "#{div(s, 604_800)}w ago"
      true -> "#{div(s, 2_592_000)}mo ago"
    end
  end

  def initials(name) do
    case String.split(name) do
      [one] -> one |> String.slice(0, 2) |> String.upcase()
      words -> words |> Enum.take(2) |> Enum.map_join(&String.first/1) |> String.upcase()
    end
  end

  # ---------- Header ----------

  def site_header(assigns) do
    ~H"""
    <header class="relative h-32 overflow-hidden rounded-bl-[100px] bg-violet md:h-[136px]">
      <div class="absolute -top-20 left-[12%] size-64 rounded-full bg-white/10"></div>
      <div class="absolute -right-10 top-6 size-56 rounded-full bg-white/10"></div>
      <div class="relative mx-auto flex max-w-[1110px] items-center justify-between px-6 pt-10 md:pt-12">
        <a href="/" class="text-[32px] font-bold leading-none text-white">devjobs</a>
        <.theme_switch />
      </div>
    </header>
    """
  end

  def theme_switch(assigns) do
    ~H"""
    <div class="flex items-center gap-4">
      <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="white"
        stroke-width="2"
        stroke-linecap="round"
      >
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
      </svg>
      <button
        type="button"
        phx-click={JS.dispatch("toggle-theme")}
        aria-label="Toggle dark mode"
        class="group relative h-6 w-12 cursor-pointer rounded-full bg-white"
      >
        <span class="absolute left-1 top-1 size-4 rounded-full bg-violet transition-transform group-hover:bg-light-violet dark:translate-x-6"></span>
      </button>
      <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="white"
        stroke-width="2"
        stroke-linecap="round"
      >
        <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
      </svg>
    </div>
    """
  end

  # ---------- Filter bar ----------

  attr :filters, :map, required: true

  def filter_bar(assigns) do
    ~H"""
    <form
      id="filter-form"
      phx-change="filter"
      phx-submit="filter"
      class="group relative z-10 -mt-10 flex items-center rounded-md bg-white shadow-lg md:h-20 dark:bg-midnight"
    >
      <%!-- Title (always visible) --%>
      <label class="flex flex-1 items-center gap-4 px-6 md:border-r md:border-dark-grey/20">
        <svg
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#5964E0"
          stroke-width="2.5"
          stroke-linecap="round"
          class="shrink-0"
        >
          <circle cx="10.5" cy="10.5" r="7" /><path d="M16 16l5 5" />
        </svg>
        <input
          type="text"
          name="search"
          value={@filters["search"]}
          phx-debounce="300"
          placeholder="Filter by title, companies, expertise…"
          class="w-full min-w-0 truncate bg-transparent py-5 outline-none placeholder:text-midnight/50 dark:text-white dark:placeholder:text-white/50"
        />
      </label>

      <%!-- Mobile-only buttons --%>
      <div class="flex items-center gap-4 pr-4 md:hidden">
        <button
          type="button"
          aria-label="More filters"
          phx-click={JS.set_attribute({"data-open", ""}, to: "#filter-form")}
          class="cursor-pointer text-dark-grey transition hover:text-violet"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M3 4h18l-7 8.5V20l-4-2v-5.5z" />
          </svg>
        </button>
        <button
          type="submit"
          aria-label="Search"
          class="flex size-12 cursor-pointer items-center justify-center rounded-md bg-violet transition hover:bg-light-violet"
        >
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="white"
            stroke-width="2.5"
            stroke-linecap="round"
          >
            <circle cx="10.5" cy="10.5" r="7" /><path d="M16 16l5 5" />
          </svg>
        </button>
      </div>

      <%!-- Location + full time: a modal on phones, inline on md+ --%>
      <div class="max-md:hidden max-md:group-data-[open]:fixed max-md:group-data-[open]:inset-0 max-md:group-data-[open]:z-40 max-md:group-data-[open]:flex max-md:group-data-[open]:items-center max-md:group-data-[open]:justify-center max-md:group-data-[open]:bg-black/50 max-md:group-data-[open]:p-6 md:contents">
        <div class="w-full max-w-[400px] overflow-hidden rounded-md bg-white md:contents dark:bg-midnight">
          <label class="flex items-center gap-4 border-b border-dark-grey/20 px-6 md:flex-1 md:border-b-0 md:border-r">
            <svg width="18" height="24" viewBox="0 0 18 24" fill="#5964E0" class="shrink-0">
              <path d="M9 0C4 0 0 4 0 9c0 6.5 9 15 9 15s9-8.5 9-15c0-5-4-9-9-9zm0 12.5a3.5 3.5 0 110-7 3.5 3.5 0 010 7z" />
            </svg>
            <input
              type="text"
              name="location"
              value={@filters["location"]}
              phx-debounce="300"
              placeholder="Filter by location…"
              class="w-full min-w-0 bg-transparent py-5 outline-none placeholder:text-midnight/50 dark:text-white dark:placeholder:text-white/50"
            />
          </label>

          <div class="flex flex-col gap-6 px-6 py-6 md:flex-row md:items-center md:justify-between md:py-0">
            <label class="flex cursor-pointer items-center gap-3 font-bold dark:text-white">
              <input type="hidden" name="full_time" value="false" />
              <input
                type="checkbox"
                name="full_time"
                value="true"
                checked={@filters["full_time"] == "true"}
                class="size-6 cursor-pointer accent-violet"
              /> Full Time Only
            </label>
            <button
              type="submit"
              phx-click={JS.remove_attribute("data-open", to: "#filter-form")}
              class="cursor-pointer rounded-md bg-violet px-8 py-4 font-bold text-white transition hover:bg-light-violet md:mr-6"
            >
              Search
            </button>
          </div>
        </div>
      </div>
    </form>
    """
  end

  # ---------- Job card ----------

  attr :id, :string, required: true
  attr :job, :map, required: true

  def job_card(assigns) do
    ~H"""
    <article
      id={@id}
      class="relative rounded-md bg-white px-8 pb-8 pt-12 transition hover:shadow-lg dark:bg-midnight"
    >
      <div
        class="absolute -top-6 left-8 flex size-[50px] items-center justify-center rounded-2xl text-sm font-bold text-white"
        style={"background-color: #{@job.company.logo_background}"}
      >
        {initials(@job.company.name)}
      </div>
      <p class="flex items-center gap-3 text-dark-grey">
        <span>{time_ago(@job.posted_at)}</span>
        <span class="size-1 rounded-full bg-dark-grey"></span>
        <span>{@job.contract}</span>
      </p>
      <h3 class="mt-3 text-xl font-bold">
        <.link
          navigate={"/jobs/#{@job.id}"}
          class="transition after:absolute after:inset-0 hover:text-dark-grey"
        >
          {@job.position}
        </.link>
      </h3>
      <p class="mt-3 text-dark-grey">{@job.company.name}</p>
      <p class="mt-10 text-sm font-bold text-violet">{@job.location}</p>
    </article>
    """
  end
end
