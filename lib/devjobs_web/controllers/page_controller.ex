defmodule DevjobsWeb.PageController do
  use DevjobsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
