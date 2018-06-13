defmodule Farmbot.Target.Watchdog do
  @behaviour Farmbot.Configurator.Watchdog

  use GenServer

  def kick(wd) do
    GenServer.call(wd, :kick)
  end

  def register_network_interface(wd, interface) do
    GenServer.call(wd, {:register_network_interface, interface})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do

  end

end
