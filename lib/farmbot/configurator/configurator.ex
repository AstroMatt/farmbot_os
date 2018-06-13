defmodule Farmbot.Configurator do
  @moduledoc """
  Behaviour module for Farmbot's configuration utility.
  """

  @configurator Application.get_env(:farmbot, :behaviour)[:configurator]
  @configurator ||  Mix.raise("Please configure a configurator implementation.")

  @doc "Enter configuration mode."
  @callback enter(any) :: any

  @doc "Leave configuration mode."
  @callback leave(any) :: any

  use GenServer
  use Farmbot.Logger
  alias Farmbot.Configurator.Watchdog

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    {:ok, wd} = Watchdog.start_link()
    Process.flag(:trap_exit, true)
    {:ok, %{watchdog: wd}}
  end

  def handle_info({:EXIT, pid, reason}, %{watchdog: pid}) do
  end
end
