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
  # Possibly not needed, but doesn't hurt
  http: [port: {:system, "PORT"}],
  # url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443],
  url: [scheme: "https", host: "embed.ml", port: 443],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  server: true
