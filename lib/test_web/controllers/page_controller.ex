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
              png_data =
                GenServer.call(Test.Decoder, {:decode, body}, 30000)
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

  def jxl_png(%{path_params: %{"path" => [req | path]}} = conn, _) do
    url = "#{req}//#{path |> Enum.join("/")}?#{conn.query_string}"

    case download(url, :png) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(url)}.png\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_auto(%{path_params: %{"path" => [req | path]}} = conn, params) do
    case conn do
      %{req_headers: req_headers} ->
        case req_headers |> Enum.filter(&(elem(&1, 0) == "accept")) do
          [{"accept", accepts}] ->
            if "image/jxl" in String.split(accepts, ",") do
              jxl(conn, params)
            else
              jxl_png(conn, params)
            end

          _ ->
            jxl_png(conn, params)
        end

      _ ->
        jxl_png(conn, params)
    end
  end

  def jxl(%{path_params: %{"path" => [req | path]}} = conn, _) do
    url = "#{req}//#{path |> Enum.join("/")}?#{conn.query_string}"

    case download(url, :jxl) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(path)}\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end
end
