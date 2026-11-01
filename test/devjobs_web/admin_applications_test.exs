defmodule DevjobsWeb.AdminApplicationsTest do
  use DevjobsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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
