import Config

if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :test, TestWeb.Endpoint, server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :test, TestWeb.Endpoint,
    url: [host: host, scheme: "https", port: 443],
    http: [port: port],
    secret_key_base: secret_key_base
end

config :nostrum,
  token: Map.fetch!(System.get_env(), "DISCORD_TOKEN"),
  num_shards: :auto

config :test,
  discord_public_key:
    Base.decode16!(Map.fetch!(System.get_env(), "DISCORD_PUBLIC_KEY"), case: :mixed)
