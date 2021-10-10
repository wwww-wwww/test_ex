defmodule TestWeb.PageController do
  use TestWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def encode_png(body) do
    {basic_info, frames} = Test.Decoder.decode(body)

    case frames do
      [frame] ->
        {false, Test.Png.encode(frame)}

      frames ->
        {true, Test.Png.encode_animation(frames, basic_info)}
    end
  end

  def get_path(%{path_params: %{"path" => [req | path]}} = conn) do
    url =
      if conn.query_string |> String.length() > 0 do
        "#{req}//#{path |> Enum.join("/")}?#{conn.query_string}"
      else
        "#{req}//#{path |> Enum.join("/")}"
      end

    {url, path}
  end

  def encode_gif(body) do
    {basic_info, frames} = Test.Decoder.decode(body)

    rate = basic_info.animation.tps_denominator / basic_info.animation.tps_numerator * 10

    {:ok, encoder} = ImageEx.Gif.create(basic_info.xsize, basic_info.ysize, 8)

    Enum.reduce(frames, encoder, fn frame, encoder ->
      frame =
        frame
        |> JxlEx.Image.add_alpha!()
        |> JxlEx.Image.gray_to_rgb!()

      encoder
      |> ImageEx.Gif.add_frame!(
        frame.image,
        round(rate / frame.animation.duration)
      )
    end)
    |> ImageEx.Gif.finish!()
  end

  def decode(url, body, out) do
    case out do
      :jxl ->
        {:ok, "image/jxl", body}

      :png ->
        {_, png_data} = Test.DecodeCacheDecoder.get({url, :png}, &encode_png/1, [body])
        {:ok, "image/png", png_data}

      :gif ->
        gif_data = Test.DecodeCacheDecoder.get({url, :gif}, &encode_gif/1, [body])
        {:ok, "image/gif", gif_data}

      _ ->
        {:error, "Unsupported output format"}
    end
  end

  def download(url, out) do
    url
    |> URI.encode()
    |> HTTPoison.get()
    |> case do
      {:ok, %HTTPoison.Response{body: body}} ->
        if JxlEx.Decoder.is_jxl?(body) do
          decode(url, body, out)
        else
          {:error, "Not a valid jxl"}
        end
    end
  end

  def jxl_gif(conn, %{"q" => q}) do
    case download(q, :gif) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(q)}.gif\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_gif(conn, _) do
    {url, path} = get_path(conn)

    case download(url, :gif) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(path |> Enum.join("/"))}.gif\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_png(conn, _) do
    {url, path} = get_path(conn)

    case download(url, :png) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(path |> Enum.join("/"))}.png\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def auto(conn) do
    {url, path} = get_path(conn)

    case download(url, :jxl) do
      {:ok, _mime, body} ->
        # basic_info =
        #  JxlEx.Decoder.new!(1)
        #  |> JxlEx.Decoder.load!(body)
        #  |> JxlEx.Decoder.basic_info!()

        case decode(url, body, :png) do
          {:ok, mime, data} ->
            conn
            |> put_resp_content_type(mime)
            |> put_resp_header(
              "Content-disposition",
              "inline; filename=\"#{Path.basename(path |> Enum.join("/"))}.png\""
            )
            |> send_resp(200, data)

          {:error, err} ->
            conn |> send_resp(500, inspect(err))
        end

      err ->
        conn |> send_resp(500, inspect(err))
    end
  end

  def jxl_auto(conn, params) do
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
          auto(conn)
        else
          case req_headers |> Enum.filter(&(elem(&1, 0) == "accept")) do
            [{"accept", accepts}] ->
              if accepts == "*/*" or "image/jxl" in String.split(accepts, ",") do
                jxl(conn, params)
              else
                auto(conn)
              end

            _ ->
              auto(conn)
          end
        end

      _ ->
        jxl(conn, params)
    end
  end

  def jxl(conn, _) do
    {url, path} = get_path(conn)

    case download(url, :jxl) do
      {:ok, mime, data} ->
        conn
        |> put_resp_content_type(mime)
        |> put_resp_header(
          "Content-disposition",
          "inline; filename=\"#{Path.basename(path |> Enum.join("/"))}\""
        )
        |> send_resp(200, data)

      {:error, err} ->
        conn |> send_resp(500, inspect(err))
    end
  end
end
