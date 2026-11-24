defmodule DevjobsWeb.AdminApplicationsTest do
  use DevjobsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Devjobs.Accounts
  alias Devjobs.Jobs
  alias Devjobs.Jobs.{Attachment, Company, Job}
  alias Devjobs.Repo

  setup %{conn: conn} do
    company =
      Repo.insert!(%Company{
        name: "Acme",
        logo_background: "#5964E0",
        website: "https://acme.test"
      })

    job =
      Repo.insert!(%Job{
        position: "Engineer",
        contract: "Full Time",
        location: "Kenya",
        description: "Build useful software",
        posted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        company_id: company.id
      })

    assert {:ok, _admin} =
             Accounts.create_admin(%{
               email: "test-admin@example.com",
               password: "test-admin-password"
             })

    %{conn: conn, job: job}
  end

  test "admin routes redirect unauthenticated visitors to the sign-in page", %{conn: conn} do
    conn = get(conn, ~p"/admin/applications.csv")

    assert redirected_to(conn) == "/admin/login"
  end

  test "admin sign-in requests an email address", %{conn: conn} do
    conn = get(conn, ~p"/admin/login")

    assert html_response(conn, 200) =~ ~s(type="email" name="admin[email]" autocomplete="email")
  end

  test "newly invited user can set a password and sign in to the admin dashboard", %{conn: conn} do
    assert {:ok, user, token} =
             Accounts.create_user_invitation(%{
               first_name: "Staff",
               last_name: "Member",
               email: "staff@example.com"
             })

    conn = get(conn, ~p"/admin/password/setup/#{token}")
    assert html_response(conn, 200) =~ "Set your password"
    [_, csrf_token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, response(conn, 200))

    conn =
      post(conn, ~p"/admin/password/setup/#{token}", %{
        "_csrf_token" => csrf_token,
        "password" => %{
          "password" => "a-secure-staff-password",
          "password_confirmation" => "a-secure-staff-password"
        }
      })

    assert redirected_to(conn) == "/admin/login"

    assert {:error, :invalid_token} =
             Accounts.set_user_password(token, "another-secure-password")

    conn = get(conn, ~p"/admin/login")
    html = html_response(conn, 200)
    [_, csrf_token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html)

    conn =
      post(conn, ~p"/admin/login", %{
        "_csrf_token" => csrf_token,
        "admin" => %{
          "email" => user.email,
          "password" => "a-secure-staff-password"
        }
      })

    assert redirected_to(conn) == "/admin/applications"

    conn = get(conn, ~p"/admin/applications.csv")
    assert response(conn, 200) =~ "\"submitted_at\",\"first_name\""
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
  end

  test "user can request and consume a one-time password reset link", %{conn: conn} do
    assert {:ok, user, setup_token} =
             Accounts.create_user_invitation(%{
               first_name: "Reset",
               last_name: "Member",
               email: "reset-member@example.com"
             })

    assert {:ok, _user} = Accounts.set_user_password(setup_token, "an-initial-password")

    conn = get(conn, ~p"/admin/password/forgot")
    assert html_response(conn, 200) =~ "Reset your password"
    [_, csrf_token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, response(conn, 200))

    conn =
      post(conn, ~p"/admin/password/forgot", %{
        "_csrf_token" => csrf_token,
        "password" => %{"email" => user.email}
      })

    assert redirected_to(conn) == "/admin/password/forgot"

    assert_email_sent(fn email ->
      assert email.subject == "Reset your Devjobs admin password"
      assert email.to == [{"", user.email}]

      assert [_, reset_token] =
               Regex.run(~r{/admin/password/setup/([A-Za-z0-9_-]+)}, email.text_body)

      Process.put(:reset_token, reset_token)
      true
    end)

    conn = get(conn, ~p"/admin/password/forgot")
    assert html_response(conn, 200) =~ "If an account exists for that email"

    reset_token = Process.delete(:reset_token)

    conn = get(conn, ~p"/admin/password/setup/#{reset_token}")
    assert html_response(conn, 200) =~ "Reset your password"
    [_, csrf_token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, response(conn, 200))

    conn =
      post(conn, ~p"/admin/password/setup/#{reset_token}", %{
        "_csrf_token" => csrf_token,
        "password" => %{
          "password" => "a-replacement-password",
          "password_confirmation" => "a-replacement-password"
        }
      })

    assert redirected_to(conn) == "/admin/login"

    assert {:ok, _user} =
             Accounts.authenticate_user(user.email, "a-replacement-password")

    assert {:error, :invalid_credentials} =
             Accounts.authenticate_user(user.email, "an-initial-password")
  end

  test "password reset request does not reveal whether an email belongs to a user", %{conn: conn} do
    conn = get(conn, ~p"/admin/password/forgot")
    [_, csrf_token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, response(conn, 200))

    conn =
      post(conn, ~p"/admin/password/forgot", %{
        "_csrf_token" => csrf_token,
        "password" => %{"email" => "not-a-user@example.com"}
      })

    assert redirected_to(conn) == "/admin/password/forgot"
    conn = get(conn, ~p"/admin/password/forgot")

    assert html_response(conn, 200) =~
             "If an account exists for that email, a password reset link has been sent."

    refute_email_sent()
  end

  test "admin sign-in rejects an incorrect password", %{conn: conn} do
    conn = get(conn, ~p"/admin/login")
    html = html_response(conn, 200)
    [_, csrf_token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html)

    conn =
      post(conn, ~p"/admin/login", %{
        "_csrf_token" => csrf_token,
        "admin" => %{
          "email" => "test-admin@example.com",
          "password" => "incorrect-password"
        }
      })

    assert response(conn, 401) =~ "Invalid email or password."
  end

  test "admin sessions are rejected after the admin account is removed", %{conn: conn} do
    conn = admin_login(conn)
    Repo.delete!(Repo.get_by!(Devjobs.Accounts.Admin, email: "test-admin@example.com"))

    conn = get(conn, ~p"/admin/applications.csv")

    assert redirected_to(conn) == "/admin/login"
  end

  test "admin can create a job for a new company from the dashboard", %{conn: conn} do
    conn = admin_login(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/applications")

    assert has_element?(view, "#add-job", "Add new job")
    assert has_element?(view, "#nav-Jobs[href='/admin/jobs']")

    {:ok, job_view, _html} = live(conn, ~p"/admin/jobs/new")
    assert has_element?(job_view, "#job-form")
    assert has_element?(job_view, "#job_company_id")

    job_view
    |> form("#job-form",
      job: %{
        "position" => "Platform Engineer",
        "contract" => "Full Time",
        "location" => "Remote",
        "description" => "Build platform services",
        "apply_url" => "https://globex.test/careers",
        "company_id" => "",
        "company_name" => "Globex",
        "company_website" => "https://globex.test",
        "company_logo_background" => "#5964E0"
      }
    )
    |> render_submit()

    assert_redirect(job_view, "/admin/jobs")
    assert [%{company: %{name: "Globex"}}] = Jobs.list_jobs(%{"search" => "Platform Engineer"})

    {:ok, jobs_view, _html} = live(conn, ~p"/admin/jobs")
    assert has_element?(jobs_view, "#jobs-list")
    assert has_element?(jobs_view, "#jobs p", "Platform Engineer")
    assert has_element?(jobs_view, "#jobs p", "Globex")
    assert has_element?(jobs_view, "#jobs p", "Remote")
  end

  test "admin can hide and show the applications sidebar", %{conn: conn} do
    conn = admin_login(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/applications")

    assert has_element?(view, "#admin-sidebar[data-state='expanded']")
    assert has_element?(view, "#toggle-admin-sidebar")

    view
    |> element("#toggle-admin-sidebar")
    |> render_click()

    assert has_element?(view, "#admin-sidebar[data-state='collapsed']")
    assert has_element?(view, "#toggle-admin-sidebar")

    view
    |> element("#toggle-admin-sidebar")
    |> render_click()

    assert has_element?(view, "#admin-sidebar[data-state='expanded']")
    assert has_element?(view, "#toggle-admin-sidebar")
  end

  test "admin can add a user and see the new user in the users list", %{conn: conn} do
    conn = admin_login(conn)
    {:ok, applications_view, _html} = live(conn, ~p"/admin/applications")

    assert has_element?(applications_view, "#nav-Users[href='/admin/users']")

    {:ok, users_view, _html} = live(conn, ~p"/admin/users")
    assert has_element?(users_view, "#users-list")

    assert has_element?(
             users_view,
             "#users [data-account-type='Administrator']",
             "test-admin@example.com"
           )

    refute has_element?(users_view, "#users p", "Taylor Jordan")

    assert has_element?(users_view, "#add-user[href='/admin/users/new']")
    {:ok, form_view, _html} = live(conn, ~p"/admin/users/new")

    form_view
    |> form("#user-form",
      user: %{
        "first_name" => "Taylor",
        "last_name" => "Jordan",
        "email" => "taylor.jordan@example.com"
      }
    )
    |> render_submit()

    assert_redirect(form_view, "/admin/users")

    assert_email_sent(fn email ->
      email.subject == "Set up your Devjobs admin account" and
        email.to == [{"", "taylor.jordan@example.com"}] and
        email.text_body =~ "/admin/password/setup/"
    end)

    {:ok, users_view, _html} = live(conn, ~p"/admin/users")

    assert has_element?(users_view, "#users-list")

    assert has_element?(
             users_view,
             "#users [data-account-type='Administrator']",
             "test-admin@example.com"
           )

    assert has_element?(users_view, "#users p", "Taylor Jordan")
    assert has_element?(users_view, "#users p", "taylor.jordan@example.com")
    assert has_element?(users_view, "#users [data-account-type='Staff user']")
  end

  test "authenticated admin can review applications and export their details", %{
    conn: conn,
    job: job
  } do
    application_params = %{
      "first_name" => "Sam",
      "last_name" => "Lee",
      "email" => "sam@example.com"
    }

    assert {:ok, _application} = Jobs.create_application(job, application_params)

    assert {:ok, _formula_application} =
             Jobs.create_application(job, %{
               "first_name" => "=1+1",
               "last_name" => "Formula",
               "email" => "formula@example.com"
             })

    conn = admin_login(conn)

    {:ok, view, _html} = live(conn, ~p"/admin/applications")

    assert has_element?(view, "#applications-table")
    assert has_element?(view, "#applications-table th", "Applicant")
    assert has_element?(view, "#applications-table th", "Job")
    assert has_element?(view, "#applications-table th", "Documents")
    assert has_element?(view, "#applications")
    assert has_element?(view, "h2", "Sam Lee")
    assert has_element?(view, "p", "sam@example.com")
    assert has_element?(view, "p", "Build useful software")
    assert has_element?(view, "a[href='/admin/applications.csv']", "Download CSV")

    conn = get(conn, ~p"/admin/applications.csv")
    csv = response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert csv =~ "\"submitted_at\",\"first_name\",\"last_name\",\"email\""
    assert csv =~ "sam@example.com"
    assert csv =~ "Build useful software"
    assert csv =~ "\"'=1+1\""
  end

  test "admin can delete an application after confirmation and uploaded files are removed", %{
    conn: conn,
    job: job
  } do
    upload_dir = Path.join("priv/uploads", Ecto.UUID.generate())
    File.mkdir_p!(upload_dir)
    on_exit(fn -> File.rm_rf!(upload_dir) end)

    cv_path = Path.join(upload_dir, "cv.pdf")
    File.write!(cv_path, "sample cv")

    assert {:ok, application} =
             Jobs.create_application(
               job,
               %{
                 "first_name" => "Sam",
                 "last_name" => "Lee",
                 "email" => "sam@example.com"
               },
               [
                 %{
                   document_type: "cv",
                   filename: "cv.pdf",
                   path: cv_path,
                   content_type: "application/pdf",
                   size: 9
                 }
               ]
             )

    conn = admin_login(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/applications")

    assert has_element?(view, "button[phx-hook='ConfirmDeleteApplication']", "Delete")
    assert has_element?(view, "#delete-application-#{application.id}[data-confirm-message]")
    assert has_element?(view, "p", "1 applications found")

    render_hook(view, "delete-application", %{"id" => to_string(application.id)})

    refute has_element?(view, "tr", "Sam Lee")
    assert has_element?(view, "p", "0 applications found")
    assert File.exists?(cv_path) == false
    assert Repo.get(Devjobs.Jobs.Application, application.id) == nil
    assert Repo.get_by(Attachment, application_id: application.id) == nil
  end

  test "admin can filter applications by job, location, and contract and export the results", %{
    conn: conn,
    job: job
  } do
    assert {:ok, _application} =
             Jobs.create_application(job, %{
               "first_name" => "Sam",
               "last_name" => "Lee",
               "email" => "sam@example.com"
             })

    company =
      Repo.insert!(%Company{
        name: "Globex",
        logo_background: "#5964E0",
        website: "https://globex.test"
      })

    designer_job =
      Repo.insert!(%Job{
        position: "Designer",
        contract: "Part Time",
        location: "Nairobi",
        description: "Design a helpful product",
        posted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        company_id: company.id
      })

    assert {:ok, _application} =
             Jobs.create_application(designer_job, %{
               "first_name" => "Rae",
               "last_name" => "Kim",
               "email" => "rae@example.com"
             })

    conn = admin_login(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/applications")

    assert has_element?(view, "h2", "Sam Lee")
    assert has_element?(view, "h2", "Rae Kim")

    for selected_filters <- [
          %{"search" => "Designer"},
          %{"search" => "Globex"},
          %{"location" => "Nairobi"},
          %{"contract" => "Part Time"},
          %{"search" => "Designer", "location" => "Nairobi", "contract" => "Part Time"}
        ] do
      filters = Map.merge(%{"search" => "", "location" => "", "contract" => ""}, selected_filters)

      render_change(view, "filter", %{"filters" => filters})

      assert_patch(view)
      assert has_element?(view, "h2", "Rae Kim")
      refute has_element?(view, "h2", "Sam Lee")
    end

    assert has_element?(view, "#clear-application-filters")

    assert has_element?(
             view,
             "a[href='/admin/applications.csv?contract=Part+Time&location=Nairobi&search=Designer']"
           )

    view
    |> element("#clear-application-filters")
    |> render_click()

    assert has_element?(view, "h2", "Sam Lee")
    refute has_element?(view, "#clear-application-filters")

    conn =
      get(
        conn,
        "/admin/applications.csv?search=Designer&location=Nairobi&contract=Part+Time"
      )

    csv = response(conn, 200)
    assert csv =~ "rae@example.com"
    refute csv =~ "sam@example.com"
  end

  test "admin can download an uploaded application attachment", %{conn: conn, job: job} do
    upload_dir = Path.join("priv/uploads", Ecto.UUID.generate())
    File.mkdir_p!(upload_dir)
    on_exit(fn -> File.rm_rf!(upload_dir) end)

    cv_path = Path.join(upload_dir, "cv.pdf")
    File.write!(cv_path, "sample cv")

    assert {:ok, application} =
             Jobs.create_application(
               job,
               %{
                 "first_name" => "Sam",
                 "last_name" => "Lee",
                 "email" => "sam@example.com"
               },
               [
                 %{
                   document_type: "cv",
                   filename: "cv.pdf",
                   path: cv_path,
                   content_type: "application/pdf",
                   size: 9
                 }
               ]
             )

    [attachment] = Repo.preload(application, :attachments).attachments
    conn = admin_login(conn)
    conn = get(conn, ~p"/admin/attachments/#{attachment.id}")

    assert response(conn, 200) == "sample cv"
    assert get_resp_header(conn, "content-type") == ["application/pdf"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
  end

  test "admin applications page handles attachments without a document type", %{
    conn: conn,
    job: job
  } do
    assert {:ok, application} =
             Jobs.create_application(job, %{
               "first_name" => "Sam",
               "last_name" => "Lee",
               "email" => "sam@example.com"
             })

    Repo.insert!(%Attachment{
      application_id: application.id,
      filename: "legacy.pdf",
      path: "priv/uploads/legacy.pdf"
    })

    conn = admin_login(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/applications")

    assert has_element?(view, "a", "Download Document")
  end

  defp admin_login(conn) do
    conn = get(conn, ~p"/admin/login")
    html = html_response(conn, 200)
    [_, csrf_token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html)

    post(conn, ~p"/admin/login", %{
      "_csrf_token" => csrf_token,
      "admin" => %{
        "email" => "test-admin@example.com",
        "password" => "test-admin-password"
      }
    })
    |> then(fn conn ->
      assert redirected_to(conn) == "/admin/applications"
      conn
    end)
  end
end
