defmodule Farmbot.Target.Configurator do
  @moduledoc """
  This init module is used to bring up initial configuration.
  If it can't find a configuration it will bring up a captive portal for a device to connect to.
  """

  @behaviour Farmbot.Configurator

  use Farmbot.Logger
  alias Farmbot.System.ConfigStorage
  import ConfigStorage, only: [get_config_value: 3]
  alias Farmbot.Target.Configurator
  use Supervisor

  @doc """
  This should block until all settings have been validated.
  It handles things such as:
  * Initial flashing of the firmware.
  * Initial configuration of network settings.
  * Initial configuration of farmbot web app settings.
  """
  def provision do
    Logger.busy(3, "Configuring Farmbot.")
    enter("initial provision")
    loop_until_configured()
    leave()
  end

  def enter(reason) do
    Logger.warn(3, "entering configuration mode: #{inspect reason}")
    Nerves.Runtime.cmd("kill", ["-9", "dnsmasq"], :info)
    Nerves.Runtime.cmd("ifup", ["-f", "uap0"], :info)
    Nerves.Runtime.cmd("hostapd", ["-B", "-i", "uap0", "-dd", "-P", "/var/run/uap0.hostapd.pid", "/etc/uap0.hostapd.conf"], :info)
    Nerves.Runtime.cmd("dnsmasq", ["-K", "--dhcp-lease", "/var/run/uap0.dnsmasq.leases", "-C", "/etc/uap0.dnsmasq.conf", "--log-dhcp"], :info)
    :ok
  end

  def leave do
    Logger.success(3, "leaving configuration mode.")
    Nerves.Runtime.cmd("ifdown", ["-f", "uap0"], :info)
    Nerves.Runtime.cmd("killall", ["-s", "SIGQUIT", "hostapd"], :info)
    Nerves.Runtime.cmd("killall", ["-9", "dnsmasq"], :info)
    :ok
  end

  @doc false
  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  def init(_) do
    :ets.new(:session, [:named_table, :public, read_concurrency: true])
    children = [
      {Plug.Adapters.Cowboy, scheme: :http, plug: Configurator.Router, options: [port: 80, acceptors: 1]}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  defp loop_until_configured do
    email = get_config_value(:string, "authorization", "email")
    pass = get_config_value(:string, "authorization", "password")
    server = get_config_value(:string, "authorization", "server")
    network = !(Enum.empty?(ConfigStorage.get_all_network_configs()))
    if email && pass && server && network do
      Logger.success 2, "Configuration finished."
      :ok
    else
      Process.sleep(30_000)
      loop_until_configured()
    end
  end

end
