defmodule Test.Png do
  def encode(im) do
    xstride = im.xsize * im.num_channels * 8
    rows = for <<chunk::size(xstride) <- im.image>>, do: <<chunk::size(xstride)>>

    idat =
      :png.chunk(:IDAT, {:rows, rows})
      |> Enum.reduce(<<>>, fn x, acc -> acc <> x end)

    mode =
      case im.num_channels do
        1 -> :grayscale
        2 -> :grayscale_alpha
        3 -> :rgb
        4 -> :rgba
      end

    config = {:png_config, {im.xsize, im.ysize}, {mode, 8}, 0, 0, 0}

    png_data =
      [:png.header(), :png.chunk(:IHDR, config), idat, :png.chunk(:IEND)]
      |> Enum.reduce(<<>>, fn x, acc -> acc <> x end)
  end

  def uint(n, m \\ 32) do
    <<n::unsigned-integer-size(m)>>
  end

  def make_fctl(tps_num, tps_den, im) do
    width = uint(im.xsize)
    height = uint(im.ysize)
    offset = <<0, 0, 0, 0, 0, 0, 0, 0>>
    delay_num = uint(im.duration * tps_den, 16)
    delay_den = uint(tps_num, 16)

    width <> height <> offset <> delay_num <> delay_den <> <<0, 0>>
  end

  def encode_animation(frames, xsize, ysize, num_color_channels, num_loops, tps_num, tps_den) do
    xstride = xsize * num_color_channels * 8

    body =
      frames
      |> Enum.map(fn im ->
        rows = for <<chunk::size(xstride) <- im.image>>, do: <<chunk::size(xstride)>>

        {im.animation, :png.chunk(:IDAT, {:rows, rows})}
      end)
      |> case do
        [{_, idat}] ->
          {false, Enum.reduce(idat, <<>>, fn x, acc -> acc <> x end)}

        frames ->
          num_frames = uint(length(frames))
          num_plays = uint(num_loops)

          actl = "acTL" <> num_frames <> num_plays

          {im_a, idat} = frames |> Enum.at(0)

          idat =
            idat
            |> Enum.reduce(<<>>, fn x, acc -> acc <> x end)

          first_fctl = "fcTL" <> uint(0) <> make_fctl(tps_num, tps_den, im_a)

          body =
            frames
            |> Enum.drop(1)
            |> Enum.map(fn {im, idat} ->
              idat =
                Enum.map(idat, fn chunk ->
                  <<a::size(32), _::size(32), rest::binary>> = chunk
                  uint(a) <> "fDAT" <> rest
                end)

              [{:fctl, make_fctl(tps_num, tps_den, im)}] ++ idat
            end)
            |> Enum.reduce([], fn x, acc -> acc ++ x end)
            |> Enum.with_index(1)
            |> Enum.map(fn {chunk, sequence_number} ->
              case chunk do
                {:fctl, data} -> "fcTL" <> uint(sequence_number) <> data
                data -> uint(sequence_number) <> data
              end
            end)
            |> Enum.reduce(<<>>, fn x, acc -> acc <> x end)

          {true, actl <> first_fctl <> idat <> body}
      end

    mode =
      case num_color_channels do
        1 -> :grayscale
        2 -> :grayscale_alpha
        3 -> :rgb
        4 -> :rgba
      end

    config = {:png_config, {xsize, ysize}, {mode, 8}, 0, 0, 0}

    png_data =
      [:png.header(), :png.chunk(:IHDR, config), body, :png.chunk(:IEND)]
      |> Enum.reduce(<<>>, fn x, acc -> acc <> x end)
  end
end
