import Config

config :herz_schwarm, HerzSchwarmWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
