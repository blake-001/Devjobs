defmodule DevjobsWeb.AdminUsersLive do
  use DevjobsWeb, :live_view

  alias Devjobs.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Add a user")
     |> assign(:form, to_form(%{}, as: :user))
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("create_user", %{"user" => params}, socket) do
    case Accounts.create_user(params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully.")
         |> push_navigate(to: ~p"/admin/applications")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:error_message, "Please fix the errors below.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-md px-6 py-10">
        <.link navigate="/admin/applications" class="font-bold text-violet hover:underline">
          &larr; Back to applications
        </.link>

        <div class="mt-6 rounded-lg bg-white p-6 shadow-sm dark:bg-midnight sm:p-8">
          <h1 class="text-3xl font-bold">Add a new user</h1>
          <p class="mt-2 text-dark-grey">Add a user with their first name, last name, and email.</p>

          <p :if={@error_message} id="user-form-error" role="alert" class="mt-5 text-red-600">
            {@error_message}
          </p>

          <.form
            for={@form}
            id="user-form"
            phx-submit="create_user"
            class="mt-6 space-y-5"
          >
            <div class="grid gap-5 sm:grid-cols-2">
              <div>
                <label for="user_first_name" class="mb-2 block font-bold">First name</label>
                <.input
                  field={@form[:first_name]}
                  type="text"
                  required
                  class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                />
              </div>
              <div>
                <label for="user_last_name" class="mb-2 block font-bold">Last name</label>
                <.input
                  field={@form[:last_name]}
                  type="text"
                  required
                  class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
                />
              </div>
            </div>

            <div>
              <label for="user_email" class="mb-2 block font-bold">Email</label>
              <.input
                field={@form[:email]}
                type="email"
                required
                placeholder="name@example.com"
                class="w-full rounded-md border border-dark-grey/30 bg-transparent px-4 py-3"
              />
            </div>

            <div class="flex flex-wrap gap-3 pt-2">
              <button
                id="create-user-submit"
                type="submit"
                class="rounded-md bg-violet px-6 py-3 font-bold text-white transition hover:bg-light-violet"
              >
                Add user
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
