defmodule Farmbot.Configurator.Watchdog do
  @moduledoc """
  Wrapper module for a watchdog behaviour.
  """

  #TODO(Connor) - Do global watchdog stuff here like DNS check etc.

  @watchdog Application.get_env(:farmbot, :behaviour)[:watchdog]
  @watchdog ||  Mix.raise("Please configure a watchdog implementation.")
  @configurator Application.get_env(:farmbot, :behaviour)[:configurator]
  @configurator || Mix.raise("Please configure a configurator implementation.")
  use Farmbot.Logger

  import Farmbot.System.ConfigStorage, only: [get_config_value: 3, update_config_value: 4]

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
    update_config_value(:string, "authorization", "token", nil)
    {:ok, wwd} = @watchdog.start_link()
    Process.link(wwd)
    start_dns_timer(30_000)
    {:ok, %{watched_watchdog: wwd, dns: false}}
  end

  def handle_info(:dns_timer, %{dns: false} = state) do
    if get_config_value(:string, "authorization", "server") do
      case test_dns() do
        {:ok, {:hostent, host, _, :inet, _, _}} ->
          Logger.success(1, "Farmbot was able to make dns requests to: #{host}")
          @configurator.leave()
          start_dns_timer(30_000)
          {:noreply, %{state | dns: true}}
        err ->
          IO.inspect(err, label: "DNS FAIL")
          start_dns_timer(10_000)
          {:noreply, state}
      end
    else
      start_dns_timer(30_000)
      {:noreply, state}
    end
  end

  def handle_info(:dns_timer, %{dns: true} = state) do
    case test_dns() do
      {:ok, {:hostent, _, _, :inet, _, _}} ->
        start_dns_timer(30_000)
        {:noreply, state}

      err ->
        Logger.error(1, "Farmbot is unable to reach Farmbot API.")
        @configurator.enter("Farmbot is unable to reach Farmbot API (#{inspect err})")
        start_dns_timer(10_000)
        {:noreply, %{state | dns: false}}
    end
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
    reg = ~r(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)
    if Regex.match?(reg, to_string(hostname)) do
      {:ok, {:hostent, hostname, 4, :inet, [], []}}
    else
      IO.puts "testing dns: #{inspect hostname}"
      :inet_res.gethostbyname(hostname)
    end
  end

  defp start_dns_timer(timeout) do
    Process.send_after(self(), :dns_timer, timeout)
  end

  @callback start_link :: GenServer.on_start()
  @callback kick(GenServer.server()) :: :ok | {:error, term}
end
