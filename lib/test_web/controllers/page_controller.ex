defmodule TestWeb.PageController do
  use TestWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  defp decode_all_frames(dec) do
    case dec |> JxlEx.Decoder.next() do
      {:ok, %{animation: %{is_last: 0}} = im} -> [im] ++ decode_all_frames(dec)
      {:ok, im} -> [im]
      _ -> []
    end
  end

  def download(url, out) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{body: body}} ->
        if JxlEx.Decoder.is_jxl?(body) do
          case out do
            :jxl ->
              {:ok, "image/jxl", body}

            :png ->
              {:ok, dec} =
                JxlEx.Decoder.new!(1)
                |> JxlEx.Decoder.load(body)

              png_data =
                dec
                |> JxlEx.Decoder.next!()
                |> Test.Png.encode()

              # mime = if animated, do: "image/apng", else: "image/png"
              mime = "image/png"
              {:ok, mime, png_data}

            _ ->
              {:error, "Unsupported output format"}
          end
        else
          {:error, "Not a valid jxl"}
        end
    end
  end

  def jxl(conn, %{"q" => q, "to" => "png"}) do
    case download(q, :png) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header("Content-disposition", "inline; filename=\"#{Path.basename(q)}.png\"")
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl(conn, %{"q" => q}) do
    case download(q, :jxl) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header("Content-disposition", "inline; filename=\"#{Path.basename(q)}\"")
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_auto(conn, %{"q" => q}) do
    case conn do
      %{req_headers: req_headers} ->
        case req_headers |> Enum.filter(&(elem(&1, 0) == "accept")) do
          [{"accept", accepts}] ->
            if "image/jxl" in String.split(accepts, ",") do
              jxl(conn, %{"q" => q})
            else
              jxl(conn, %{"q" => q, "to" => "png"})
            end

          _ ->
            jxl(conn, %{"q" => q, "to" => "png"})
        end

      _ ->
        jxl(conn, %{"q" => q, "to" => "png"})
    end
  end
end
