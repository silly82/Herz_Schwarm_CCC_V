import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      Generate one: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "herz-schwarm.local"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :herz_schwarm, HerzSchwarmWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  config :herz_schwarm, :uart_device, System.get_env("UART_DEVICE", "/dev/ttyUSB0")
end
