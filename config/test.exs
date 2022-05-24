import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :test, TestWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ESfwb50EmSMlj7AFLKlYHnwHKJ1WmVZuxPgHnHiH8gt9rUpEecJEHbaS1sXOUL38",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
