defmodule Farmbot.Target.Watchdog do
  @behaviour Farmbot.Configurator.Watchdog

  use GenServer

  def kick(wd) do
    :ok
    # GenServer.call(wd, :kick)
  end

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, []}
  end

end
