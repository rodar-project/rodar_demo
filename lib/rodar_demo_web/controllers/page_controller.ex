defmodule RodarDemoWeb.PageController do
  use RodarDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
