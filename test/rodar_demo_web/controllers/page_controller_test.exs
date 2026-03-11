defmodule RodarDemoWeb.PageControllerTest do
  use RodarDemoWeb.ConnCase

  test "GET / renders the order list page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Orders"
  end
end
