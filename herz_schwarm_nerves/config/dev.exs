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

config :herz_schwarm, :uart_device, herz_schwarm_default_uart_device()
config :herz_schwarm, bridge_enabled: true

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Pick a sensible default UART device for the host platform.
# macOS:  /dev/cu.usbserial-* or /dev/cu.SLAB_USBtoUART (ESP32-S3 USB-CDC)
# Linux:  /dev/ttyUSB0 (typical for CH340/CP2102 USB-serial bridges)
# Override with: UART_DEVICE=/dev/cu.usbmodem14101 mix phx.server
defp herz_schwarm_default_uart_device do
  case System.get_env("UART_DEVICE") do
    nil ->
      cond do
        match?({:win32, _}, :os.type()) -> "COM3"
        File.exists?("/dev/cu.usbserial-1410") -> "/dev/cu.usbserial-1410"
        File.exists?("/dev/cu.SLAB_USBtoUART") -> "/dev/cu.SLAB_USBtoUART"
        true -> "/dev/ttyUSB0"
      end
    dev -> dev
  end
end
