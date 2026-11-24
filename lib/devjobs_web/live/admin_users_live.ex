defmodule DevjobsWeb.AdminUsersLive do
  use DevjobsWeb, :live_view

  require Logger

  alias Devjobs.Accounts
  alias Devjobs.Accounts.UserNotifier

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_nav, :users)
     |> assign(:sidebar_collapsed?, false)
     |> assign(:form, to_form(%{}, as: :user))
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    title = if socket.assigns.live_action == :new, do: "Add a user", else: "Users"
    accounts = list_directory_accounts()

    {:noreply,
     socket
     |> assign(page_title: title, account_count: length(accounts))
     |> stream(:users, accounts, reset: true)}
  end

  @impl true
  def handle_event("toggle-sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_collapsed?, &(!&1))}
  end

  @impl true
  def handle_event("create_user", %{"user" => params}, socket) do
    case Accounts.create_user_invitation(params) do
      {:ok, user, token} ->
        case UserNotifier.deliver_setup_instructions(user, token) do
          {:ok, _email} ->
            {:noreply,
             socket
             |> put_flash(:info, "User created. A password setup link was sent to their email.")
             |> push_navigate(to: ~p"/admin/users")}

          {:error, reason} ->
            Logger.error("User setup email delivery failed: #{inspect(reason)}")

            {:noreply,
             socket
             |> put_flash(
               :error,
               "The user was created, but the setup email could not be sent. They can request a password link from the sign-in page."
             )
             |> push_navigate(to: ~p"/admin/users")}
        end

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
              active={false}
              navigate="/admin/jobs"
              icon="hero-briefcase"
              label="Jobs"
            />
            <.nav_item
              active={true}
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
                  {if @live_action == :new, do: "Add a new user", else: "Users"}
                </h1>
                <p class="mt-1 text-dark-grey/60 dark:text-dark-grey/40">
                  {if @live_action == :new,
                    do: "Add a user with their first name, last name, and email.",
                    else: "#{@account_count} accounts found"}
                </p>
              </div>
              <.link
                :if={@live_action == :index}
                navigate="/admin/users/new"
                id="add-user"
                class="rounded-md bg-violet px-4 py-2 font-bold text-white transition hover:bg-light-violet"
              >
                Add user
              </.link>
            </div>
          </header>

          <section
            :if={@live_action == :new}
            class="mx-auto max-w-2xl rounded-lg bg-white p-6 shadow-sm dark:bg-midnight sm:p-8"
          >
            <p :if={@error_message} id="user-form-error" role="alert" class="mb-5 text-red-600">
              {@error_message}
            </p>

            <.form for={@form} id="user-form" phx-submit="create_user" class="space-y-5">
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
                  navigate="/admin/users"
                  class="rounded-md border border-dark-grey/30 px-6 py-3 font-bold transition hover:bg-dark-grey/10"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </section>

          <section
            :if={@live_action == :index}
            id="users-list"
            class="overflow-hidden rounded-lg border border-dark-grey/10 bg-white shadow-sm dark:bg-midnight"
          >
            <div id="users" phx-update="stream" class="divide-y divide-dark-grey/10">
              <div
                id="users-empty-state"
                class="hidden only:block px-5 py-10 text-center text-dark-grey"
              >
                No users have been added yet.
              </div>
              <div
                :for={{id, user} <- @streams.users}
                id={id}
                data-account-type={user.account_type}
                class="grid gap-2 px-5 py-4 sm:grid-cols-4 sm:items-center"
              >
                <p class="font-bold text-midnight dark:text-white">
                  {user.name}
                </p>
                <p class="text-dark-grey">{user.email}</p>
                <p class="text-sm font-semibold text-violet">{user.account_type}</p>
                <p class="text-sm text-dark-grey sm:text-right">
                  {user.status}
                </p>
              </div>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp list_directory_accounts do
    users =
      Enum.map(Accounts.list_users(), fn user ->
        %{
          id: "user-#{user.id}",
          name: "#{user.first_name} #{user.last_name}",
          email: user.email,
          account_type: "Staff user",
          status:
            if(is_nil(user.password_hash),
              do: "Setup pending",
              else: "Added #{Calendar.strftime(user.inserted_at, "%Y-%m-%d")}"
            ),
          inserted_at: user.inserted_at
        }
      end)

    admins =
      Enum.map(Accounts.list_admins(), fn admin ->
        %{
          id: "admin-#{admin.id}",
          name: "Admin account",
          email: admin.email,
          account_type: "Administrator",
          status: "Added #{Calendar.strftime(admin.inserted_at, "%Y-%m-%d")}",
          inserted_at: admin.inserted_at
        }
      end)

    Enum.sort_by(users ++ admins, & &1.inserted_at, {:desc, DateTime})
  end
end
