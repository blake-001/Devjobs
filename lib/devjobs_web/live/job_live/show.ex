defmodule DevjobsWeb.JobLive.Show do
  use DevjobsWeb, :live_view
  import DevjobsWeb.JobComponents

  alias Devjobs.Jobs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job = Jobs.get_job!(id)

    {:ok,
     socket
     |> assign(job: job, page_title: job.position)
     |> assign(show_apply: false, applied: false)
     |> assign(form: to_form(Jobs.change_application(), as: :application))
     |> allow_upload(:cv,
       accept: ~w(.pdf .doc .docx),
       max_entries: 1,
       max_file_size: 5_000_000
     )
     |> allow_upload(:cover_letter,
       accept: ~w(.pdf .doc .docx),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def handle_event("open-apply", _params, socket) do
    {:noreply,
     socket
     |> assign(show_apply: true, applied: false)
     |> assign(form: to_form(Jobs.change_application(), as: :application))}
  end

  def handle_event("close-apply", _params, socket) do
    {:noreply, assign(socket, show_apply: false)}
  end

  def handle_event("validate", %{"application" => params}, socket) do
    changeset =
      Jobs.change_application(%Devjobs.Jobs.Application{}, params)
      |> maybe_add_duplicate_error(socket.assigns.job.id, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :application))}
  end

  def handle_event("cancel-upload", %{"field" => "cv", "ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cv, ref)}
  end

  def handle_event("cancel-upload", %{"field" => "cover_letter", "ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cover_letter, ref)}
  end

  def handle_event("apply", %{"application" => params}, socket) do
    job = socket.assigns.job

    changeset =
      Jobs.change_application(%Devjobs.Jobs.Application{}, params)
      |> maybe_add_duplicate_error(job.id, params)
      |> Map.put(:action, :insert)

    if changeset.valid? do
      files =
        consume_upload(socket, :cv, "cv", job.id) ++
          consume_upload(socket, :cover_letter, "cover_letter", job.id)

      case Jobs.create_application(job, params, files) do
        {:ok, _app} ->
          {:noreply, assign(socket, applied: true)}

        {:error, %Ecto.Changeset{} = changeset} ->
          Enum.each(files, &File.rm(&1.path))

          {:noreply,
           assign(socket, form: to_form(Map.put(changeset, :action, :insert), as: :application))}
      end
    else
      {:noreply, assign(socket, form: to_form(changeset, as: :application))}
    end
  end

  defp consume_upload(socket, upload_name, document_type, job_id) do
    consume_uploaded_entries(socket, upload_name, fn %{path: tmp}, entry ->
      dir = Path.join(["priv", "uploads", to_string(job_id)])
      File.mkdir_p!(dir)
      dest = Path.join(dir, "#{Ecto.UUID.generate()}-#{Path.basename(entry.client_name)}")
      File.cp!(tmp, dest)

      {:ok,
       %{
         document_type: document_type,
         filename: entry.client_name,
         path: dest,
         content_type: entry.client_type,
         size: entry.client_size
       }}
    end)
  end

  defp maybe_add_duplicate_error(changeset, job_id, params) do
    email = params["email"]

    if changeset.errors[:email] == nil and Jobs.already_applied?(job_id, email) do
      Ecto.Changeset.add_error(changeset, :email, "You have already applied to this job")
    else
      changeset
    end
  end

  defp upload_error(:too_large), do: "File is too large (max 5 MB)"
  defp upload_error(:not_accepted), do: "Only PDF, DOC or DOCX files"
  defp upload_error(:too_many_files), do: "Only one file allowed"
  defp upload_error(_), do: "Upload failed"

  defp host(nil), do: ""
  defp host(url), do: URI.parse(url).host || url

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.site_header />

      <div class="mx-auto max-w-[730px] px-6 pb-32">
        <%!-- Company card --%>
        <section class="relative z-10 -mt-10 flex flex-col items-center overflow-hidden rounded-md bg-white text-center shadow-lg sm:h-[140px] sm:flex-row sm:text-left dark:bg-midnight">
          <div
            class="flex h-[140px] w-full items-center justify-center text-3xl font-bold text-white sm:w-[140px]"
            style={"background-color: #{@job.company.logo_background}"}
          >
            {initials(@job.company.name)}
          </div>
          <div class="flex flex-1 flex-col items-center gap-6 px-6 py-6 sm:flex-row sm:justify-between sm:px-10 sm:py-0">
            <div>
              <h2 class="text-2xl font-bold">{@job.company.name}</h2>
              <p class="mt-2 text-dark-grey">{host(@job.company.website)}</p>
            </div>
            <a
              href={@job.company.website}
              target="_blank"
              rel="noopener"
              class="rounded-md bg-violet/10 px-6 py-4 font-bold text-violet transition hover:bg-violet/30 dark:bg-white/10 dark:text-white dark:hover:bg-white/25"
            >
              Company Site
            </a>
          </div>
        </section>

        <%!-- Job details --%>
        <section class="mt-8 rounded-md bg-white p-8 sm:p-12 dark:bg-midnight">
          <div class="flex flex-col gap-8 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p class="flex items-center gap-3 text-dark-grey">
                <span>{time_ago(@job.posted_at)}</span>
                <span class="size-1 rounded-full bg-dark-grey"></span>
                <span>{@job.contract}</span>
              </p>
              <h1 class="mt-3 text-[28px] font-bold leading-tight">{@job.position}</h1>
              <p class="mt-3 text-sm font-bold text-violet">{@job.location}</p>
            </div>
            <button
              id="apply-top"
              type="button"
              phx-click="open-apply"
              class="cursor-pointer rounded-md bg-violet px-8 py-4 text-center font-bold text-white transition hover:bg-light-violet"
            >
              Apply Now
            </button>
          </div>

          <p class="mt-10 leading-[1.7] text-dark-grey">{@job.description}</p>

          <h2 class="mt-10 text-xl font-bold">Requirements</h2>
          <p class="mt-6 leading-[1.7] text-dark-grey">{@job.requirements_content}</p>
          <ul class="mt-6 space-y-2">
            <li :for={item <- @job.requirements_items} class="flex gap-8 leading-[1.7] text-dark-grey">
              <span class="mt-[11px] size-1 shrink-0 rounded-full bg-violet"></span>
              <span>{item}</span>
            </li>
          </ul>

          <h2 class="mt-10 text-xl font-bold">What You Will Do</h2>
          <p class="mt-6 leading-[1.7] text-dark-grey">{@job.role_content}</p>
          <ol class="mt-6 space-y-2">
            <li
              :for={{item, i} <- Enum.with_index(@job.role_items, 1)}
              class="flex gap-6 leading-[1.7] text-dark-grey"
            >
              <span class="w-3 shrink-0 font-bold text-violet">{i}</span>
              <span>{item}</span>
            </li>
          </ol>
        </section>
      </div>

      <%!-- Sticky apply bar --%>
      <footer class="fixed inset-x-0 bottom-0 z-20 bg-white py-5 shadow-[0_-4px_20px_rgba(0,0,0,0.05)] dark:bg-midnight">
        <div class="mx-auto flex max-w-[730px] items-center justify-between gap-6 px-6">
          <div class="hidden sm:block">
            <p class="text-xl font-bold">{@job.position}</p>
            <p class="mt-1 text-dark-grey">{@job.company.name}</p>
          </div>
          <button
            id="apply-bottom"
            type="button"
            phx-click="open-apply"
            class="w-full cursor-pointer rounded-md bg-violet px-8 py-4 text-center font-bold text-white transition hover:bg-light-violet sm:w-auto"
          >
            Apply Now
          </button>
        </div>
      </footer>

      <div
        :if={@show_apply}
        id="apply-modal"
        class="fixed inset-0 z-30 flex items-center justify-center bg-black/60 p-4"
        phx-window-keydown="close-apply"
        phx-key="escape"
      >
        <div class="max-h-full w-full max-w-[480px] overflow-y-auto rounded-md bg-white p-8 dark:bg-midnight">
          <%= if @applied do %>
            <div class="text-center">
              <h2 class="text-2xl font-bold">Application sent!</h2>
              <p class="mt-4 text-dark-grey">
                Thanks for applying to {@job.position} at {@job.company.name}.
              </p>
              <button
                type="button"
                phx-click="close-apply"
                class="mt-8 cursor-pointer rounded-md bg-violet px-8 py-4 font-bold text-white transition hover:bg-light-violet"
              >
                Close
              </button>
            </div>
          <% else %>
            <div class="flex items-start justify-between gap-4">
              <h2 class="text-2xl font-bold">Apply for {@job.position}</h2>
              <button
                type="button"
                phx-click="close-apply"
                aria-label="Close"
                class="cursor-pointer text-2xl leading-none text-dark-grey transition hover:text-violet"
              >
                &times;
              </button>
            </div>

            <.form
              for={@form}
              id="apply-form"
              phx-change="validate"
              phx-submit="apply"
              class="mt-6 space-y-5"
            >
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label for={@form[:first_name].id} class="font-bold">First name</label>
                  <input
                    type="text"
                    name={@form[:first_name].name}
                    id={@form[:first_name].id}
                    value={@form[:first_name].value}
                    phx-debounce="300"
                    class="mt-2 w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3 outline-none focus:border-violet dark:text-white"
                  />
                  <p
                    :for={{msg, _} <- @form[:first_name].errors}
                    :if={@form.source.action}
                    class="mt-1 text-sm text-red-500"
                  >
                    {msg}
                  </p>
                </div>

                <div>
                  <label for={@form[:last_name].id} class="font-bold">Last name</label>
                  <input
                    type="text"
                    name={@form[:last_name].name}
                    id={@form[:last_name].id}
                    value={@form[:last_name].value}
                    phx-debounce="300"
                    class="mt-2 w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3 outline-none focus:border-violet dark:text-white"
                  />
                  <p
                    :for={{msg, _} <- @form[:last_name].errors}
                    :if={@form.source.action}
                    class="mt-1 text-sm text-red-500"
                  >
                    {msg}
                  </p>
                </div>
              </div>

              <div>
                <label for={@form[:email].id} class="font-bold">Email</label>
                <input
                  type="email"
                  name={@form[:email].name}
                  id={@form[:email].id}
                  value={@form[:email].value}
                  phx-debounce="300"
                  class="mt-2 w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3 outline-none focus:border-violet dark:text-white"
                />
                <p
                  :for={{msg, _} <- @form[:email].errors}
                  :if={@form.source.action}
                  class="mt-1 text-sm text-red-500"
                >
                  {msg}
                </p>
              </div>

              <div :for={{field, label} <- [cv: "CV", cover_letter: "Cover letter"]}>
                <label for={@uploads[field].ref} class="font-bold">
                  {label} (PDF, DOC, DOCX, max 5 MB)
                </label>
                <div class="mt-2 rounded-md border border-dashed border-dark-grey/40 p-4">
                  <.live_file_input upload={@uploads[field]} class="w-full text-sm" />
                </div>
                <p
                  :for={err <- upload_errors(@uploads[field])}
                  class="mt-1 text-sm text-red-500"
                >
                  {upload_error(err)}
                </p>
                <div :for={entry <- @uploads[field].entries} class="mt-3">
                  <div class="flex items-center justify-between gap-4 text-sm">
                    <span class="truncate">{entry.client_name}</span>
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-field={field}
                      phx-value-ref={entry.ref}
                      class="cursor-pointer text-dark-grey transition hover:text-red-500"
                    >
                      Remove
                    </button>
                  </div>
                  <div class="mt-1 h-1 rounded bg-dark-grey/20">
                    <div class="h-1 rounded bg-violet" style={"width: #{entry.progress}%"}></div>
                  </div>
                  <p
                    :for={err <- upload_errors(@uploads[field], entry)}
                    class="mt-1 text-sm text-red-500"
                  >
                    {upload_error(err)}
                  </p>
                </div>
              </div>

              <button
                type="submit"
                class="w-full cursor-pointer rounded-md bg-violet px-8 py-4 font-bold text-white transition hover:bg-light-violet"
              >
                Submit Application
              </button>
            </.form>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
