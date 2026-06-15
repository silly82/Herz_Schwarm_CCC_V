import Config

config :herz_schwarm, target: Mix.target()

config :herz_schwarm, HerzSchwarmWeb.Endpoint,
  url: [host: "herz-schwarm.local"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HerzSchwarmWeb.ErrorHTML, json: HerzSchwarmWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HerzSchwarm.PubSub,
  live_view: [signing_salt: "hSchwarmLV"]

config :esbuild,
  version: "0.21.5",
  herz_schwarm: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  herz_schwarm: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, backends: [:console]

import_config "#{config_env()}.exs"
