defmodule HerzSchwarmWeb.Router do
  use HerzSchwarmWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HerzSchwarmWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", HerzSchwarmWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/bridge-update", BridgeUpdateLive, :index
    live "/badge-update", BadgeUpdateLive, :index
    live "/diagnose", DiagnoseLive, :index
  end

  # Funk-Update: die Badges holen sich hier ihre Firmware (kein Browser, keine Session).
  scope "/firmware", HerzSchwarmWeb do
    get "/badge.bin", FirmwareController, :badge
  end

  if Application.compile_env(:herz_schwarm, :dev_routes, false) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: HerzSchwarmWeb.Telemetry
    end
  end
end
