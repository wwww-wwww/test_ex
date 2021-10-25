import Config

# Do not print debug messages in production
config :logger, level: :info

config :test, TestWeb.Endpoint,
  # Possibly not needed, but doesn't hurt
  http: [port: {:system, "PORT"}],
  # url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443],
  url: [host: "embed.moe", scheme: "https", port: 443],
  #force_ssl: [rewrite_on: [:x_forwarded_proto]],
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  server: true
