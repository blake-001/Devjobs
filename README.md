# Devjobs

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Admin applications

Admin credentials are stored in the database; passwords are saved as bcrypt
hashes. To set up or change the single admin login locally:

```sh
mix ecto.migrate
mix admin.credentials
mix phx.server
```

The credentials task prompts for an email and password without echoing the
password. On first run it creates the admin; on later runs it updates the
existing account, letting you rotate the email or password. Passwords must be
at least 12 characters and no more than 72 bytes. It does not create public
registration or additional admin accounts. Updating credentials invalidates
existing admin sessions.

Open [`http://localhost:4000/admin/login`](http://localhost:4000/admin/login) to
sign in. The account remains available after restarts as long as the database is
preserved. Back up the database as part of your normal deployment process. In
production, run the migration and credentials task in the deployment
environment, and serve the admin area over HTTPS. Do not store admin passwords
in source control or pass them as command-line arguments.

The dashboard shows applicant details, the job description, and download links
for uploaded CVs and cover letters. Use **Download CSV** to export application
and job details. Filter applications by job title or company, location, and
contract type; the filters are reflected in the URL and the CSV download
includes only matching applications. Use **Add new job** to create a listing
for an existing company or enter company details to create a new company with
the job.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
