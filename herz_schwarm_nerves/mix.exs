defmodule HerzSchwarm.MixProject do
  use Mix.Project

  @app :herz_schwarm
  @version "0.2.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.15",
      archives: [nerves_bootstrap: "~> 1.13"],
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      aliases: aliases(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  def application do
    [
      mod: {HerzSchwarm.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  # Muss am Ende loadconfig selbst aufrufen: der Alias ersetzt den Task.
  # Ohne diesen Aufruf wird config/*.exs nie geladen (Endpoint ohne Port,
  # Phoenix faellt auf Cowboy zurueck, :uart_device bleibt nil).
  defp bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  defp deps do
    [
      # Nerves (required on host too — bootstrap checks for it, even if targets: :rpi4)
      {:nerves, "~> 1.10", runtime: false},
      {:nerves_system_rpi4, "~> 1.27", targets: :rpi4},
      {:nerves_runtime, "~> 0.13", targets: :rpi4},
      {:nerves_pack, "~> 0.7", targets: :rpi4},

      # Phoenix / Web
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:gettext, "~> 0.26"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:telemetry_poller, "~> 1.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # UART
      {:circuits_uart, "~> 1.5"},

      # Dev/test
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp aliases do
    [
      loadconfig: [&bootstrap/1],
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind herz_schwarm", "esbuild herz_schwarm"],
      "assets.deploy": [
        "tailwind herz_schwarm --minify",
        "esbuild herz_schwarm --minify",
        "phx.digest"
      ]
    ]
  end
end
