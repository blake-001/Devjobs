defmodule DevjobsWeb.JobLive.ShowTest do
  use DevjobsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Devjobs.Jobs
  alias Devjobs.Jobs.{Application, Company, Job}
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

  test "application form has separate CV and cover letter upload inputs", %{conn: conn, job: job} do
    {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

    view
    |> element("#apply-top")
    |> render_click()

    assert has_element?(view, "input[type=file][name=cv]")
    assert has_element?(view, "input[type=file][name=cover_letter]")
    assert has_element?(view, "label", "CV (PDF, DOC, DOCX, max 5 MB)")
    assert has_element?(view, "label", "Cover letter (PDF, DOC, DOCX, max 5 MB)")
  end

  test "an applicant cannot submit another application for the same job", %{
    conn: conn,
    job: job
  } do
    application_params = %{
      "first_name" => "Sam",
      "last_name" => "Lee",
      "email" => "sam@example.com"
    }

    assert {:ok, _application} = Jobs.create_application(job, application_params)
    {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

    view
    |> element("#apply-top")
    |> render_click()

    view
    |> element("#apply-form")
    |> render_submit(%{"application" => application_params})

    assert has_element?(view, "#apply-form")
    assert has_element?(view, "#apply-modal", "You have already applied to this job")
    assert Repo.aggregate(Application, :count) == 1
  end
end
