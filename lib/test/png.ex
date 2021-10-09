defmodule Test.Png do
  @signature <<137, 80, 78, 71, 13, 10, 26, 10>>
  def header() do
    @signature
  end

  def encode(im) do
    IO.inspect("encode")

    [header()]
    |> chunk(:IHDR, im.xsize, im.ysize, 8, im.num_channels)
    |> chunk(:IDAT, :rows, rows(im))
    |> chunk(:IEND)
    |> :erlang.list_to_binary()
  end

  # APNG Specification
  # acTL fcTL IDAT fcTL fdAT fcTL fdAT
  # fcTL: per image
  # IDAT: first image
  # fdAT: following images
  def encode_animation(frames, info) do
    [first_frame | frames] = frames

    {body, _} =
      frames
      |> Enum.reduce({[], 1}, fn frame, {acc, seq} ->
        fctl =
          chunk(
            :fcTL,
            seq,
            frame,
            frame.animation.duration,
            info.animation
          )

        {chunks, seq} = chunk(:fdAT, seq + 1, frame)
        {acc ++ [fctl] ++ chunks, seq}
      end)

    alpha_channel = if info.alpha_bits > 0, do: 1, else: 0
    num_channels = info.num_color_channels + alpha_channel

    [header()]
    |> chunk(:IHDR, info.xsize, info.ysize, 8, num_channels)
    |> chunk(:acTL, length(frames) + 1, info.animation.num_loops)
    |> chunk(:fcTL, 0, first_frame, first_frame.animation.duration, info.animation)
    |> chunk(:IDAT, :rows, rows(first_frame))
    |> Kernel.++(body)
    |> chunk(:IEND)
    |> :erlang.list_to_binary()
  end

  def uint(n, m \\ 32) do
    <<n::big-unsigned-integer-size(m)>>
  end

  def rows(im) do
    xstride = im.xsize * im.num_channels * 8
    for <<chunk::size(xstride) <- im.image>>, do: <<chunk::size(xstride)>>
  end

  def chunk(list, :IHDR, width, height, bit_depth, num_channels) when is_list(list) do
    list ++ [chunk(:IHDR, width, height, bit_depth, num_channels)]
  end

  def chunk(list, :IDAT, :rows, data) when is_list(list) do
    list ++ [chunk(:IDAT, :rows, data)]
  end

  def chunk(list, :acTL, num_frames, num_plays) when is_list(list) do
    list ++ [chunk(:acTL, num_frames, num_plays)]
  end

  def chunk(list, :IEND) when is_list(list) do
    list ++ [chunk(:IEND)]
  end

  def chunk(list, :fcTL, seq, im, duration, animation)
      when is_list(list) do
    list ++ [chunk(:fcTL, seq, im, duration, animation)]
  end

  # IHDR: Image Header
  # byte length
  #    0      4 width
  #    4      4 height
  #    8      1 bit depth
  #    9      1 color type
  #   10      1 compression method
  #   11      1 filter method
  #   12      1 interlace method
  def chunk(:IHDR, width, height, bit_depth, num_channels) do
    color_type =
      case num_channels do
        0 -> 3
        1 -> 0
        2 -> 4
        3 -> 2
        4 -> 6
      end

    [
      uint(width),
      uint(height),
      uint(bit_depth, 8),
      uint(color_type, 8),
      uint(0, 8),
      uint(0, 8),
      uint(0, 8)
    ]
    |> :erlang.list_to_binary()
    |> chunk("IHDR")
  end

  # acTL: Animation Control
  # byte length
  #    0      4 num_frames
  #    4      4 num_plays
  def chunk(:acTL, num_frames, num_plays) do
    [uint(num_frames), uint(num_plays)]
    |> :erlang.list_to_binary()
    |> chunk("acTL")
  end

  # fcTL: Frame Control
  # byte length
  #    0      4 sequence_number
  #    4      4 width
  #    8      4 height
  #   12      4 x_offset
  #   16      4 y_offset
  #   20      2 delay_num
  #   22      2 delay_den
  #   24      1 dispose_op
  #   25      1 blend_op
  def chunk(:fcTL, seq, im, duration, animation) do
    [
      uint(seq),
      uint(im.xsize),
      uint(im.ysize),
      uint(0),
      uint(0),
      uint(duration * animation.tps_denominator, 16),
      uint(animation.tps_numerator, 16),
      <<0>>,
      <<0>>
    ]
    |> :erlang.list_to_binary()
    |> chunk("fcTL")
  end

  # IDAT: Image Data
  def chunk(:IDAT, :rows, rows) do
    rows
    |> Enum.map(&[<<0>>, &1])
    |> :erlang.list_to_binary()
    |> compress()
    |> Enum.map(&chunk(:erlang.iolist_to_binary(&1), "IDAT"))
  end

  def chunk(:IEND) do
    chunk(<<>>, "IEND")
  end

  # fdAT: Frame Data
  def chunk(:fdAT, seq, frame) do
    rows(frame)
    |> Enum.map(&[<<0>>, &1])
    |> :erlang.list_to_binary()
    |> compress()
    |> Enum.reduce({[], seq}, fn part, {acc, s} ->
      c =
        :erlang.list_to_binary([uint(s), :erlang.iolist_to_binary(part)])
        |> chunk("fdAT")

      {acc ++ [c], s + 1}
    end)
  end

  def chunk(data, type) when is_binary(type) and is_binary(data) do
    typedata = type <> data
    [uint(byte_size(data)), typedata, uint(:erlang.crc32(typedata))]
  end

  def compress(data) do
    z = :zlib.open()
    :ok = :zlib.deflateInit(z)
    compressed = :zlib.deflate(z, data, :finish)
    :ok = :zlib.deflateEnd(z)
    :ok = :zlib.close(z)
    compressed
  end
end
