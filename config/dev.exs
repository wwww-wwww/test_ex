import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :test, TestWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 5005],
  url: [host: "test.grass.moe", scheme: "https", port: 443],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "k0PQlZzRtkyRDCZ/8/8xjjrxRSG9VF4bgboWovvRztMOMOCeXXyqlqozVYth2Lsa",
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]

# Watch static and templates for browser reloading.
config :test, TestWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/test_web/(live|views)/.*(ex)$",
      ~r"lib/test_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
