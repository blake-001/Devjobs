# Devjobs

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Admin applications

The admin area uses environment-configured credentials. Set both variables before
starting the server; there are no built-in/default admin credentials:

```sh
export ADMIN_EMAIL="admin@example.com"
export ADMIN_PASSWORD="replace-with-a-long-random-password"
mix phx.server
```

Open [`http://localhost:4000/admin/login`](http://localhost:4000/admin/login) and
sign in to review applications. The dashboard shows applicant details, the job
description, and download links for uploaded CVs and cover letters. Use **Download
CSV** to export application and job details. Set the same environment variables
in the production runtime and serve the admin area over HTTPS.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
