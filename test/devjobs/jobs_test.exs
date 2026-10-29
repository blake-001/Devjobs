defmodule Devjobs.JobsTest do
  use Devjobs.DataCase, async: true

  alias Devjobs.Jobs
  alias Devjobs.Jobs.{Company, Job}
  alias Devjobs.Repo

  defp company!(name \\ "Acme") do
    Repo.insert!(%Company{name: name, logo_background: "#5964E0", website: "https://acme.test"})
  end

  defp job!(company, attrs) do
    defaults = %{
      position: "Engineer",
      contract: "Full Time",
      location: "Kenya",
      description: "desc",
      posted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      company_id: company.id
    }

    Repo.insert!(struct(Job, Map.merge(defaults, attrs)))
  end

  describe "list_jobs/2 filters" do
    test "filters by title" do
      c = company!()
      job!(c, %{position: "Elixir Developer"})
      job!(c, %{position: "Designer"})

      assert [%{position: "Elixir Developer"}] = Jobs.list_jobs(%{"search" => "elixir"})
    end

    test "filters by company name" do
      job!(company!("Scoot"), %{})
      job!(company!("Blogr"), %{})

      assert [%{company: %{name: "Scoot"}}] = Jobs.list_jobs(%{"search" => "scoot"})
    end

    test "filters by location" do
      c = company!()
      job!(c, %{location: "Kenya"})
      job!(c, %{location: "Japan"})

      assert [%{location: "Japan"}] = Jobs.list_jobs(%{"location" => "jap"})
    end

    test "filters full time only" do
      c = company!()
      job!(c, %{contract: "Full Time"})
      job!(c, %{contract: "Part Time"})

      assert [%{contract: "Full Time"}] = Jobs.list_jobs(%{"full_time" => "true"})
    end

    test "combine filters" do
      c = company!()
      job!(c, %{position: "Elixir Dev", location: "Kenya", contract: "Full Time"})
      job!(c, %{position: "Elixir Dev", location: "Japan", contract: "Full Time"})
      job!(c, %{position: "Elixir Dev", location: "Kenya", contract: "Part Time"})

      filters = %{"search" => "elixir", "location" => "kenya", "full_time" => "true"}
      assert [%{location: "Kenya", contract: "Full Time"}] = Jobs.list_jobs(filters)
    end

    test "treats % as a literal character" do
      job!(company!(), %{position: "Engineer"})
      assert Jobs.list_jobs(%{"search" => "%"}) == []
    end
  end

  describe "pagination" do
    test "returns pages and a total count" do
      c = company!()
      for i <- 1..14, do: job!(c, %{position: "Job #{i}"})

      assert length(Jobs.list_jobs()) == 12
      assert length(Jobs.list_jobs(%{}, offset: 12)) == 2
      assert Jobs.count_jobs() == 14
    end

    test "count respects filters" do
      c = company!()
      job!(c, %{contract: "Full Time"})
      job!(c, %{contract: "Part Time"})

      assert Jobs.count_jobs(%{"full_time" => "true"}) == 1
    end
  end

  describe "applications" do
    setup do
      %{job: job!(company!(), %{})}
    end

    @valid %{"first_name" => "Sam", "last_name" => "Lee", "email" => "sam@example.com"}

    test "first application succeeds", %{job: job} do
      assert {:ok, app} = Jobs.create_application(job, @valid)
      assert app.email == "sam@example.com"
    end

    test "same email on same job is rejected", %{job: job} do
      assert {:ok, _} = Jobs.create_application(job, @valid)
      assert {:error, cs} = Jobs.create_application(job, @valid)
      assert {"You have already applied to this job", _} = cs.errors[:email]
    end

    test "email case differences count as duplicates", %{job: job} do
      assert {:ok, _} = Jobs.create_application(job, @valid)
      assert {:error, _} = Jobs.create_application(job, %{@valid | "email" => "SAM@EXAMPLE.com"})
    end

    test "same email can apply to a different job", %{job: job} do
      other = job!(company!("Other"), %{})
      assert {:ok, _} = Jobs.create_application(job, @valid)
      assert {:ok, _} = Jobs.create_application(other, @valid)
    end

    test "invalid email is required", %{job: job} do
      assert {:error, cs} = Jobs.create_application(job, %{@valid | "email" => "nope"})
      assert cs.errors[:email]
    end

    test "already_applied?/2 ignores case", %{job: job} do
      refute Jobs.already_applied?(job.id, "sam@example.com")
      {:ok, _} = Jobs.create_application(job, @valid)
      assert Jobs.already_applied?(job.id, "SAM@example.com")
    end

    test "saves attachments with the application", %{job: job} do
      files = [
        %{filename: "cv.pdf", path: "/tmp/cv.pdf", content_type: "application/pdf", size: 10}
      ]

      assert {:ok, app} = Jobs.create_application(job, @valid, files)
      assert [%{filename: "cv.pdf"}] = Repo.preload(app, :attachments).attachments
    end
  end
end
