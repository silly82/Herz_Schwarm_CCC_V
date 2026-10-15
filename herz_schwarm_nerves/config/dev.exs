import Config

config :herz_schwarm, HerzSchwarmWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_only_secret_key_base_at_least_64_bytes_long_for_herz_schwarm",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:herz_schwarm, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:herz_schwarm, ~w(--watch)]}
  ]

config :herz_schwarm, HerzSchwarmWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/herz_schwarm_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :herz_schwarm, bridge_enabled: true

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Bridge-Port: Auto-Detect in HerzSchwarm.Bridge; Override per UART_DEVICE=/dev/cu.usbmodem101.
