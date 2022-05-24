defmodule TestWeb.PageController do
  use TestWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def get_path(%{path_params: %{"path" => [req | path]}} = conn) do
    path = path |> Enum.join("/")

    url =
      if conn.query_string |> String.length() > 0 do
        "#{req}//#{path}?#{conn.query_string}"
      else
        "#{req}//#{path}"
      end

    {url, path}
  end

  def encode_png(body) do
    case Test.Decoder.decode(body) do
      {_, [frame]} ->
        ImageEx.Png.encode(frame)

      {basic_info, frames} ->
        ImageEx.Png.encode_animation(frames, basic_info)
    end
  end

  def encode_gif(body) when is_bitstring(body) do
    Test.Decoder.decode(body)
    |> encode_gif()
  end

  def encode_gif({basic_info, frames}) do
    rate = basic_info.animation.tps_denominator / basic_info.animation.tps_numerator * 100

    {:ok, encoder} = ImageEx.Gif.create(basic_info.xsize, basic_info.ysize, 8)

    Enum.reduce(frames, encoder, fn frame, encoder ->
      frame =
        frame
        |> JxlEx.Image.add_alpha!()
        |> JxlEx.Image.gray_to_rgb!()

      encoder
      |> ImageEx.Gif.add_frame!(
        frame.image,
        round(rate * frame.animation.duration)
      )
    end)
    |> ImageEx.Gif.finish!()
  end

  def encode_auto(body) do
    case Test.Decoder.decode(body) do
      {_, [frame]} ->
        {:png, ImageEx.Png.encode(frame)}

      {basic_info, frames} ->
        {:gif, encode_gif({basic_info, frames})}
    end
  end

  def decode({:ok, body}, url, out), do: decode(body, url, out)

  def decode(body, url, out) when is_bitstring(body) do
    case out do
      :auto ->
        case Test.DecodeCacheDecoder.get({url, :auto}, &encode_auto/1, [body]) do
          {:png, data} ->
            {:ok, "image/png", "png", data}

          {:gif, data} ->
            {:ok, "image/gif", "gif", data}
        end

      :png ->
        png_data = Test.DecodeCacheDecoder.get({url, :png}, &encode_png/1, [body])
        {:ok, "image/png", "png", png_data}

      :gif ->
        gif_data = Test.DecodeCacheDecoder.get({url, :gif}, &encode_gif/1, [body])
        {:ok, "image/gif", "gif", gif_data}

      _ ->
        {:error, "Unsupported output format"}
    end
  end

  def decode(err, _, _), do: err

  def download(url) do
    url
    |> HTTPoison.get()
    |> case do
      {:ok, %HTTPoison.Response{body: body}} ->
        if JxlEx.Decoder.is_jxl?(body) do
          {:ok, body}
        else
          {:error, "Not a valid jxl"}
        end

      err ->
        {:error, inspect(err)}
    end
  end

  def jxl_gif(conn, %{"q" => q}) do
    download(q)
    |> decode(q, :gif)
    |> case do
      {:ok, mime, ext, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(q)}.#{ext}\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_gif(conn, _) do
    {url, path} = get_path(conn)

    download(url)
    |> decode(url, :gif)
    |> case do
      {:ok, mime, ext, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(path)}.#{ext}\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_png(conn, _) do
    {url, path} = get_path(conn)

    download(url)
    |> decode(url, :png)
    |> case do
      {:ok, mime, ext, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(path)}.#{ext}\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_supported?(conn) do
    case conn do
      %{req_headers: req_headers} ->
        user_agent = req_headers |> Enum.filter(&(elem(&1, 0) == "user-agent"))

        bot =
          case user_agent do
            [{"user-agent", user_agent}] ->
              user_agent |> String.downcase() |> String.contains?("discord")

            _ ->
              false
          end

        if bot do
          false
        else
          case req_headers |> Enum.filter(&(elem(&1, 0) == "accept")) do
            [{"accept", accepts}] ->
              if accepts == "*/*" or "image/jxl" in String.split(accepts, ",") do
                true
              else
                false
              end

            _ ->
              false
          end
        end

      _ ->
        true
    end
  end

  def jxl_auto(conn, {url, path}) do
    case download(url) do
      {:ok, body} ->
        if jxl_supported?(conn) do
          conn
          |> put_resp_content_type("image/jxl")
          |> put_resp_header(
            "Content-disposition",
            "inline; filename=\"#{Path.basename(path)}\""
          )
          |> send_resp(200, body)
        else
          case decode(body, url, :auto) do
            {:ok, mime, ext, data} ->
              conn
              |> put_resp_content_type(mime)
              |> put_resp_header(
                "Content-disposition",
                "inline; filename=\"#{Path.basename(path)}.#{ext}\""
              )
              |> send_resp(200, data)

            err ->
              conn |> send_resp(500, inspect(err))
          end
        end

      err ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_auto_gif(conn, %{"q" => q}) do
    jxl_auto(conn, {q, q})
  end

  def jxl_auto(conn, _) do
    jxl_auto(conn, get_path(conn))
  end

  def jxl(conn, %{"only" => only}) do
    {url, path} = get_path(conn)

    {only, _} = Integer.parse(only)

    if only > 0 do
      download(url)
      |> case do
        {:ok, body} ->
          only = min(only, byte_size(body))
          <<truncated::binary-size(only), _rest::binary>> = body

          conn
          |> put_resp_content_type("image/jxl")
          |> put_resp_header(
            "Content-disposition",
            "inline; filename=\"#{Path.basename(path)}\""
          )
          |> send_resp(200, truncated)

        {:error, err} ->
          conn |> send_resp(500, inspect(err))
      end
    else
      conn |> send_resp(400, "Bad range.")
    end
  end

  def jxl(conn, _) do
    {url, path} = get_path(conn)

    download(url)
    |> case do
      {:ok, body} ->
        conn
        |> put_resp_content_type("image/jxl")
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(path)}\""
        )
        |> send_resp(200, body)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_tree(conn, %{"gzip" => data}) do
    case Base.decode64(data) do
      {:ok, tree_data} ->
        try do
          case :zlib.gunzip(tree_data) |> JxlEx.Base.jxl_from_tree() do
            {:ok, data} ->
              conn
              |> put_resp_content_type("image/jxl")
              |> put_resp_header(
                "Content-disposition",
                "inline; filename=\"jxl_from_tree.jxl\""
              )
              |> send_resp(200, data)

            {:error, err} ->
              conn |> send_resp(500, inspect(err))

            err ->
              conn |> send_resp(500, inspect(err))
          end
        catch
          err ->
            conn |> send_resp(500, inspect(err))
        end

      err ->
        conn |> send_resp(500, inspect(err))
    end
  end
end
