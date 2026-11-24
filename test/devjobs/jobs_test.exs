defmodule Devjobs.JobsTest do
  use Devjobs.DataCase, async: true

  alias Devjobs.Jobs
  alias Devjobs.Jobs.{Attachment, Company, Job}
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

  describe "create_job/1" do
    test "creates a job for an existing company" do
      company = company!()

      assert {:ok, job} =
               Jobs.create_job(%{
                 "position" => "Platform Engineer",
                 "contract" => "Full Time",
                 "location" => "Remote",
                 "description" => "Build platform services",
                 "requirements_items" => "Know Elixir\nUnderstand OTP\n",
                 "role_items" => "Build systems\nReview code",
                 "company_id" => to_string(company.id)
               })

      assert job.company_id == company.id
      assert job.posted_at
      assert job.requirements_items == ["Know Elixir", "Understand OTP"]
      assert job.role_items == ["Build systems", "Review code"]
    end

    test "creates a company and its job together" do
      assert {:ok, job} =
               Jobs.create_job(%{
                 "position" => "Product Designer",
                 "contract" => "Part Time",
                 "location" => "Nairobi",
                 "description" => "Design a helpful product",
                 "company_name" => "Globex",
                 "company_website" => "https://globex.test",
                 "company_logo_background" => "#5964E0"
               })

      assert Repo.get!(Company, job.company_id).name == "Globex"
    end

    test "does not leave a company behind when its job is invalid" do
      assert {:error, {:job_changeset, changeset}} =
               Jobs.create_job(%{
                 "position" => "",
                 "contract" => "Full Time",
                 "location" => "Nairobi",
                 "description" => "A job description",
                 "company_name" => "Unpublished company"
               })

      assert changeset.errors[:position]
      refute Repo.exists?(from c in Company, where: c.name == "Unpublished company")
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
        %{
          document_type: "cv",
          filename: "cv.pdf",
          path: "/tmp/cv.pdf",
          content_type: "application/pdf",
          size: 10
        },
        %{
          document_type: "cover_letter",
          filename: "cover-letter.pdf",
          path: "/tmp/cover-letter.pdf",
          content_type: "application/pdf",
          size: 20
        }
      ]

      assert {:ok, app} = Jobs.create_application(job, @valid, files)

      assert [
               %{document_type: "cover_letter", filename: "cover-letter.pdf"},
               %{document_type: "cv", filename: "cv.pdf"}
             ] =
               app
               |> Repo.preload(:attachments)
               |> Map.fetch!(:attachments)
               |> Enum.map(&%{document_type: &1.document_type, filename: &1.filename})
               |> Enum.sort_by(& &1.document_type)
    end

    test "deletes an application but never removes attachment files outside uploads", %{job: job} do
      external_path = Path.join(System.tmp_dir!(), "#{Ecto.UUID.generate()}-private.pdf")
      File.write!(external_path, "keep outside uploads")
      on_exit(fn -> File.rm(external_path) end)

      assert {:ok, application} = Jobs.create_application(job, @valid)

      Repo.insert!(%Attachment{
        application_id: application.id,
        document_type: "cv",
        filename: "private.pdf",
        path: external_path
      })

      assert {:error,
              {:file_cleanup_failed, deleted_application,
               [{"private.pdf", :outside_uploads_directory}]}} =
               Jobs.delete_application(application.id)

      assert deleted_application.id == application.id
      refute Repo.get(Devjobs.Jobs.Application, application.id)
      assert File.read!(external_path) == "keep outside uploads"
    end

    test "only accepts CV and cover letter document types" do
      attrs = %{filename: "resume.pdf", path: "/tmp/resume.pdf"}

      assert Attachment.changeset(%Attachment{}, Map.put(attrs, :document_type, "cv")).valid?

      assert Attachment.changeset(%Attachment{}, Map.put(attrs, :document_type, "cover_letter")).valid?

      refute Attachment.changeset(%Attachment{}, Map.put(attrs, :document_type, "other")).valid?
    end
  end
end
