defmodule Farmbot.Configurator.Watchdog do
  @moduledoc """
  Wrapper module for a watchdog behaviour.
  """

  #TODO(Connor) - Do global watchdog stuff here like DNS check etc.

  @watchdog Application.get_env(:farmbot, :behaviour)[:watchdog]
  @watchdog ||  Mix.raise("Please configure a watchdog implementation.")

  import Farmbot.System.ConfigStorage, only: [get_config_value: 3]

  use GenServer

  def kick(wd) do
    GenServer.call(wd, :kick)
  end

  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  @doc false
  def init([]) do
    {:ok, wwd} = @watchdog.start_link()
    Process.link(wwd)
    {:ok, %{watched_watchdog: wwd}}
  end

  def handle_call(:kick, _from, state) do
    {:reply, @watchdog.kick(state.watched_watchdog), state}
  end

  @doc "Tests if we can make dns queries."
  def test_dns(hostname \\ nil)

  def test_dns(nil) do
    case get_config_value(:string, "authorization", "server") do
      nil -> 'nerves-project.org'
      <<"https://" <> host :: binary>> -> test_dns(to_charlist(host))
      <<"http://"  <> host :: binary>> -> test_dns(to_charlist(host))
    end
  end

  def test_dns(hostname) do
    :inet_res.gethostbyname(hostname)
  end

  @callback start_link :: GenServer.on_start()
  @callback kick(GenServer.server()) :: :ok | {:error, term}
end
