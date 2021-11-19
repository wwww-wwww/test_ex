defmodule TestWeb.ApiController do
  use TestWeb, :controller

  def interaction(%{req_headers: req_headers} = conn, params) do
    sig =
      req_headers
      |> Enum.filter(fn {k, _v} -> k == "x-signature-ed25519" end)
      |> case do
        [{_k, v}] -> Base.decode16!(v, case: :mixed)
        _ -> nil
      end

    timestamp =
      req_headers
      |> Enum.filter(fn {k, _v} -> k == "x-signature-timestamp" end)
      |> case do
        [{_k, v}] -> v
        _ -> nil
      end

    if sig == nil || timestamp == nil do
      conn |> put_status(401) |> text("invalid request signature")
    else
      key = Application.get_env(:test, :discord_public_key)
      body = timestamp <> conn.private[:raw_body]

      if Ed25519.valid_signature?(sig, body, key) do
        do_interaction(conn, params)
      else
        conn |> put_status(401) |> text("invalid request signature")
      end
    end
  end

  def do_interaction(conn, %{"type" => 1}) do
    conn |> json(%{type: 1})
  end

  def map_to_atom(map) when is_map(map) do
    new_map = for {key, val} <- map, into: %{}, do: {String.to_atom(key), val}

    Map.keys(new_map)
    |> Enum.reduce(new_map, fn key, acc ->
      Map.put(acc, key, map_to_atom(Map.get(acc, key)))
    end)
  end

  def map_to_atom(map) do
    map
  end

  def do_interaction(conn, %{"data" => %{"name" => name}} = interaction) do
    interaction = map_to_atom(interaction)

    conn
    |> json(Test.Consumer.do_interaction(name, interaction))
  end
end
