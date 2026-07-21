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

# UART-Device wird in dev.exs gesetzt, ABER Application.start/2 läuft vor
# der import_config-Resolution, sodass uart_device zur Bridge-Init-Zeit leer
# sein kann. Wir setzen hier einen hartcodierten Default, der ueberschrieben
# wird, sobald dev.exs laeuft. Verwendet Path.wildcard, um den ersten
# macOS-USB-Serial-Port zu finden; faellt auf /dev/ttyUSB0 fuer Linux-Dev zurueck.
config :herz_schwarm, :uart_device,
  (case System.get_env("UART_DEVICE") do
     nil ->
       cond do
         match?({:win32, _}, :os.type()) -> "COM3"
         true ->
           case Path.wildcard("/dev/cu.usbserial-*") do
             [first | _] -> first
             [] ->
               case Path.wildcard("/dev/cu.SLAB_USBtoUART") do
                 [first | _] -> first
                 [] ->
                   case Path.wildcard("/dev/cu.usbmodem*") do
                     [first | _] -> first
                     [] -> "/dev/ttyUSB0"
                   end
               end
           end
       end
     dev -> dev
   end)

import_config "#{config_env()}.exs"
