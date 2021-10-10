defmodule Mix.Tasks.Compile.Test do
  use Mix.Task

  def run(_args) do
    #File.rm_rf("msf_gif/test")
    :ok
  end
end
