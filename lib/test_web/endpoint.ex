# https://github.com/elixir-plug/plug/blob/master/lib/plug/parsers/json.ex
defmodule TestWeb.JSONParser do
  @moduledoc """
  Parses JSON request body.

  JSON documents that aren't maps (arrays, strings, numbers, etc) are parsed
  into a `"_json"` key to allow proper param merging.

  An empty request body is parsed as an empty map.

  ## Options

  All options supported by `Plug.Conn.read_body/2` are also supported here.
  They are repeated here for convenience:

    * `:length` - sets the maximum number of bytes to read from the request,
      defaults to 8_000_000 bytes
    * `:read_length` - sets the amount of bytes to read at one time from the
      underlying socket to fill the chunk, defaults to 1_000_000 bytes
    * `:read_timeout` - sets the timeout for each socket read, defaults to
      15_000ms

  So by default, `Plug.Parsers` will read 1_000_000 bytes at a time from the
  socket with an overall limit of 8_000_000 bytes.
  """

  @behaviour Plug.Parsers
  import Plug.Conn

  @impl true
  def init(opts) do
    {decoder, opts} = Keyword.pop(opts, :json_decoder)
    {body_reader, opts} = Keyword.pop(opts, :body_reader, {Plug.Conn, :read_body, []})
    decoder = validate_decoder!(decoder)
    {body_reader, decoder, opts}
  end

  defp validate_decoder!(nil) do
    raise ArgumentError, "JSON parser expects a :json_decoder option"
  end

  defp validate_decoder!({module, fun, args} = mfa)
       when is_atom(module) and is_atom(fun) and is_list(args) do
    arity = length(args) + 1

    if Code.ensure_compiled(module) != {:module, module} do
      raise ArgumentError,
            "invalid :json_decoder option. The module #{inspect(module)} is not " <>
              "loaded and could not be found"
    end

    if not function_exported?(module, fun, arity) do
      raise ArgumentError,
            "invalid :json_decoder option. The module #{inspect(module)} must " <>
              "implement #{fun}/#{arity}"
    end

    mfa
  end

  defp validate_decoder!(decoder) when is_atom(decoder) do
    validate_decoder!({decoder, :decode!, []})
  end

  defp validate_decoder!(decoder) do
    raise ArgumentError,
          "the :json_decoder option expects a module, or a three-element " <>
            "tuple in the form of {module, function, extra_args}, got: #{inspect(decoder)}"
  end

  @impl true
  def parse(conn, "application", subtype, _headers, {{mod, fun, args}, decoder, opts}) do
    if subtype == "json" or String.ends_with?(subtype, "+json") do
      apply(mod, fun, [conn, opts | args]) |> decode(decoder)
    else
      {:next, conn}
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp decode({:ok, "", conn}, _decoder) do
    {:ok, %{}, conn}
  end

  defp decode({:ok, body, conn}, {module, fun, args}) do
    try do
      apply(module, fun, [body | args])
    rescue
      e -> raise Plug.Parsers.ParseError, exception: e
    else
      terms when is_map(terms) ->
        {:ok, terms, put_private(conn, :raw_body, body)}

      terms ->
        {:ok, %{"_json" => terms}, put_private(conn, :raw_body, body)}
    end
  end

  defp decode({:more, _, conn}, _decoder) do
    {:error, :too_large, conn}
  end

  defp decode({:error, :timeout}, _decoder) do
    raise Plug.TimeoutError
  end

  defp decode({:error, _}, _decoder) do
    raise Plug.BadRequestError
  end
end

defmodule TestWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :test

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_test_key",
    signing_salt: "yGB5LenU"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :test,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, TestWeb.JSONParser],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(TestWeb.Router)
end
