import Config

config :herz_schwarm, HerzSchwarmWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_for_herz_schwarm_test",
  server: false

config :logger, level: :warning
config :herz_schwarm, bridge_enabled: false
# Tests schreiben nie in ~/.local/share (Persistenz in Tests ueber start_supervised mit :path).
config :herz_schwarm, tap_store_path: nil
