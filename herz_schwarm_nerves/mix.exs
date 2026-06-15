defmodule HerzSchwarm.MixProject do
  use Mix.Project

  @app :herz_schwarm
  @version "0.1.0"
  @all_targets [:rpi4]

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
      preferred_cli_target: [run: :host, test: :host],
      aliases: [loadconfig: [&bootstrap/1]]
    ]
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

  defp bootstrap(args) do
    Application.start(:nerves_bootstrap)
    args
  end

  defp deps do
    [
      # Nerves
      {:nerves, "~> 1.10", runtime: false, targets: @all_targets},
      {:nerves_system_rpi4, "~> 1.27", targets: :rpi4},
      {:nerves_runtime, "~> 0.13", targets: @all_targets},
      {:nerves_pack, "~> 0.7", targets: @all_targets},

      # Phoenix / Web
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"},
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
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
