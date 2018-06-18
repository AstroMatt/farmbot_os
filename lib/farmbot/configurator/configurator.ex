defmodule Farmbot.Configurator do
  @moduledoc """
  Behaviour module for Farmbot's configuration utility.
  """

  @configurator Application.get_env(:farmbot, :behaviour)[:configurator]
  @configurator || Mix.raise("Please configure a configurator implementation.")

  @doc "Initial boot provisioning. Should be blocking."
  @callback provision() :: any

  @doc "Enter configuration mode."
  @callback enter(any) :: any

  @doc "Leave configuration mode."
  @callback leave() :: any

  use GenServer
  use Farmbot.Logger
  alias Farmbot.Configurator.Watchdog
  import Farmbot.System.ConfigStorage, only: [get_config_value: 3]

  @doc false
  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      [get_config_value(:bool, "settings", "first_boot")],
      name: __MODULE__
    )
  end

  @doc false
  def init([true]) do
    # This will block.
    @configurator.provision()
    init([false])
  end

  def init([false]) do
    {:ok, wd} = Watchdog.start_link()
    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :watchdog_check, 5000)
    {:ok, %{watchdog: wd, status: false, timer: timer}}
  end

  def handle_info({:EXIT, dead_wd, reason}, %{watchdog: dead_wd} = state) do
    Logger.debug(3, "Watchdog died. Entering Configurator mode.")
    {:ok, wd} = Watchdog.start_link()
    @configurator.enter(reason)
    Process.cancel_timer(state.timer)
    {:ok, %{state | watchdog: wd, status: true}}
  end

  # watchdog timer while configurator is active.
  def handle_info(:watchdog_check, %{status: true} = state) do
    state =
      case Watchdog.kick(state.watchdog) do
        :ok ->
          Logger.debug(3, "Watchdog status ok. Leaving Configurator mode.")
          @configurator.leave()
          %{state | status: false}

        _ ->
          # Configurator is already active. No need to start it again.
          state
      end

    timer = Process.send_after(self(), :watchdog_check, 5000)
    {:noreply, %{state | timer: timer}}
  end

  # watchdog timer while configurator is _not_ active.
  def handle_info(:watchdog_check, %{status: false} = state) do
    state =
      case Watchdog.kick(state.watchdog) do
        :ok ->
          state

        {:error, reason} ->
          Logger.debug(3, "Watchdog status down. Entering Configurator mode.")
          # Configurator is not active. start it.
          @configurator.enter(reason)
          %{state | status: true}
      end

    timer = Process.send_after(self(), :watchdog_check, 5000)
    {:noreply, %{state | timer: timer}}
  end
end
