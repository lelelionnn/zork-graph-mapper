defmodule ZorkMapWeb.Router do
  use ZorkMapWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZorkMapWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ZorkMapWeb do
    pipe_through :browser

    live "/", MapIndexLive, :index
    live "/maps/:id", MapEditorLive, :edit
  end
end
