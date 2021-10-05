import Config
"""
config :test, TestWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 5005],
  url: [host: "example.com", port: 5005],
  secret_key_base: "k0PQlZzRtkyRDCZ/8/8xjjrxRSG9VF4bgboWovvRztMOMOCeXXyqlqozVYth2Lsa",
  cache_static_manifest: "priv/static/cache_manifest.json"
"""
# Do not print debug messages in production
config :logger, level: :info

config :test, TestWeb.Endpoint,
  http: [port: {:system, "PORT"}], # Possibly not needed, but doesn't hurt
  url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443],
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  server: true
