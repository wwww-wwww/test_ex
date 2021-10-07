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

    get("/", PageController, :index)
    get("/jxl/jxl/*path", PageController, :jxl)
    get("/jxl/png/*path", PageController, :jxl_png)
    get("/jxl/auto/*path", PageController, :jxl_auto)
    get("/jxl/*path", PageController, :jxl_auto)
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: TestWeb.Telemetry)
    end
  end
end
