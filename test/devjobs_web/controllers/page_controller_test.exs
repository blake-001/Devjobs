defmodule DevjobsWeb.PageControllerTest do
  use DevjobsWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET / displays the public job search and listing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#filter-form")
    assert has_element?(view, "input[name='search'][placeholder^='Filter by title']")
    assert has_element?(view, "input[name='location'][placeholder^='Filter by location']")
    assert has_element?(view, "#jobs")
    assert has_element?(view, "#jobs-empty", "No jobs match your filters.")
  end
end
