defmodule TestWeb.Router do
  use TestWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {TestWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", TestWeb do
    pipe_through(:browser)

    live("/jxl_from_tree", TreeLive)

    get("/tree", PageController, :jxl_tree)

    get("/", PageController, :index)
    get("/jxl/http*path", PageController, :jxl)
    get("/png/http*path", PageController, :jxl_png)
    get("/gif/http*path", PageController, :jxl_gif)
    get("/auto", PageController, :auto)
    get("/jxl/", PageController, :index)
    get("/png/", PageController, :index)
    get("/gif/", PageController, :index)
    get("/image.gif", PageController, :jxl_gif)
    get("/auto.gif", PageController, :jxl_auto_gif)
    get("/http*path", PageController, :jxl_auto)

    get("/attachments/*path", PageController, :proxy)
  end

  scope "/api", TestWeb do
    pipe_through(:api)

    post("/interactions", ApiController, :interaction)
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: TestWeb.Telemetry)
    end
  end
end
