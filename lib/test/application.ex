defmodule Test.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      TestWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Test.PubSub},
      # Start the Endpoint (http/https)
      TestWeb.Endpoint,
      Test.DecodeCache,
      Test.Decoder
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Test.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
