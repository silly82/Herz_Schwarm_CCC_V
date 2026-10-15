import Config

config :herz_schwarm, target: Mix.target()

config :herz_schwarm, HerzSchwarmWeb.Endpoint,
  url: [host: "herz-schwarm.local"],
  adapter: Bandit.PhoenixAdapter,
  # Nur HTTP/1.1 (LAN-UI). HTTP/2 aus wegen EEF-CVE-2026-105659 (in Bandit 1.12.5 ungefixt);
  # die Env-Configs ergaenzen ip/port, Keyword-Listen werden gemerged.
  http: [http_2_options: [enabled: false]],
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

# Tailwind v4: app.css nutzt @import "tailwindcss" + @source (keine tailwind.config.js mehr).
config :tailwind,
  version: "4.3.0",
  herz_schwarm: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]


# Bridge-Port: kein Default hier. HerzSchwarm.Bridge ermittelt ihn zur Laufzeit
# (UART_DEVICE-Env > config :uart_device > Auto-Detect per status/pong-Probe).

import_config "#{config_env()}.exs"
