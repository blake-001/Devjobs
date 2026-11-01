defmodule DevjobsWeb.AdminApplicationsController do
  use DevjobsWeb, :controller

  alias Devjobs.Jobs

  def export(conn, _params) do
    csv =
      [
        [
          "submitted_at",
          "first_name",
          "last_name",
          "email",
          "job_title",
          "company",
          "location",
          "contract",
          "job_description",
          "cv_filename",
          "cover_letter_filename"
        ]
      ] ++ Enum.map(Jobs.list_applications(), &application_row/1)

    body = Enum.map_join(csv, "\r\n", fn row -> Enum.map_join(row, ",", &csv_cell/1) end)

    conn
    |> put_resp_content_type("text/csv", "utf-8")
    |> put_resp_header("content-disposition", ~s(attachment; filename="applications.csv"))
    |> send_resp(:ok, body)
  end

  def download(conn, %{"id" => id}) do
    case Jobs.get_attachment(id) do
      nil ->
        send_resp(conn, :not_found, "Attachment not found")

      attachment ->
        uploads_dir = Path.expand("priv/uploads")
        path = Path.expand(attachment.path)
        relative_path = Path.relative_to(path, uploads_dir)

        if relative_path != path and not String.starts_with?(relative_path, "..") and
             File.regular?(path) do
          conn
          |> put_resp_content_type(attachment_content_type(attachment.content_type))
          |> put_resp_header("x-content-type-options", "nosniff")
          |> send_download({:file, path}, filename: Path.basename(attachment.filename))
        else
          send_resp(conn, :not_found, "Attachment not found")
        end
    end
  end

  defp application_row(application) do
    attachments = Map.new(application.attachments, &{&1.document_type, &1.filename})

    [
      DateTime.to_iso8601(application.inserted_at),
      application.first_name,
      application.last_name,
      application.email,
      application.job.position,
      application.job.company.name,
      application.job.location,
      application.job.contract,
      application.job.description,
      attachments["cv"],
      attachments["cover_letter"]
    ]
  end

  defp csv_cell(nil), do: ""

  defp csv_cell(value) do
    value =
      value
      |> to_string()
      |> protect_spreadsheet_formula()
      |> String.replace("\"", "\"\"")

    ~s("#{value}")
  end

  defp protect_spreadsheet_formula(value) do
    if String.starts_with?(String.trim_leading(value), ["=", "+", "-", "@", "\t", "\r"]) do
      "'" <> value
    else
      value
    end
  end

  defp attachment_content_type("application/pdf"), do: "application/pdf"
  defp attachment_content_type("application/msword"), do: "application/msword"

  defp attachment_content_type(
         "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
       ),
       do: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

  defp attachment_content_type(_), do: "application/octet-stream"
end
