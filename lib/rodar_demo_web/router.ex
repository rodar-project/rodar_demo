defmodule RodarDemoWeb.Router do
  use RodarDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RodarDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RodarDemoWeb do
    pipe_through :browser

    live "/", OrderLive.Index, :index
    live "/orders/new", OrderLive.Index, :new
    live "/orders/:id", OrderLive.Show, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", RodarDemoWeb do
  #   pipe_through :api
  # end
end
