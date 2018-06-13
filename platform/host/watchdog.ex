defmodule Farmbot.Host.Watchdog do
  @behaviour Farmbot.Configurator.Watchdog

  use GenServer

  def kick(wd) do
    GenServer.call(wd, :kick)
  end

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, :no_state}
  end

  def handle_call(:kick, _from, state) do
    {:reply, :ok, state}
  end
end
