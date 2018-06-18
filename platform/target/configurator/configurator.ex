defmodule Farmbot.Target.Configurator do
  @moduledoc """
  This init module is used to bring up initial configuration.
  If it can't find a configuration it will bring up a captive portal for a device to connect to.
  """
  @behaviour Farmbot.Configurator

  use Farmbot.Logger
  use Supervisor

  alias Farmbot.Target.Configurator
  alias Farmbot.System.ConfigStorage
  import ConfigStorage, only: [get_config_value: 3]
  import Farmbot.Target.Network.Templates

  @ifname "uap0"

  @hostapd_pid_file Path.join(["/", "var", "run", "#{@ifname}.hostapd.pid"])
  @hostapd_conf_file Path.join(["/", "root", "#{@ifname}.hostapd.conf"])

  @dnsmasq_leases_file Path.join([
                         "/",
                         "var",
                         "run",
                         "#{@ifname}.dnsmasq.leases"
                       ])
  @dnsmasq_conf_file Path.join(["/", "etc", "#{@ifname}.dnsmasq.conf"])
  @dnsmasq_log_file Path.join(["/", "tmp", "dnsmasq.log"])

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
    Logger.warn(3, "entering configuration mode: #{inspect(reason)}")
    write_config!()
    Nerves.Runtime.cmd("iw", ~w(dev wlan0 interface add uap0 type __ap), :info)
    Nerves.Runtime.cmd("kill", ["-9", "dnsmasq"], :info)
    Nerves.Runtime.cmd("ifup", [@ifname], :info)

    Nerves.Runtime.cmd(
      "hostapd",
      ["-B", "-i", @ifname, "-dd", "-P", @hostapd_pid_file, @hostapd_conf_file],
      :info
    )

    Nerves.Runtime.cmd(
      "dnsmasq",
      [
        "-K", "-q", "-8", @dnsmasq_log_file,
        "--dhcp-lease",
        @dnsmasq_leases_file,
        "-C",
        @dnsmasq_conf_file,
        "--log-dhcp",
      ],
      :info
    )

    :ok
  end

  def leave do
    Logger.success(3, "leaving configuration mode.")
    Nerves.Runtime.cmd("ifdown",  ["-f", @ifname], :info)
    Nerves.Runtime.cmd("killall", ["-s", "SIGQUIT", "hostapd"], :info)
    Nerves.Runtime.cmd("killall", ["-9", "dnsmasq"], :info)
    Nerves.Runtime.cmd("iw", ~w(dev uap0 del), :info)
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
      {Plug.Adapters.Cowboy,
       scheme: :http,
       plug: Configurator.Router,
       options: [port: 80, acceptors: 1]}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  defp loop_until_configured do
    email = get_config_value(:string, "authorization", "email")
    pass = get_config_value(:string, "authorization", "password")
    server = get_config_value(:string, "authorization", "server")
    network = !Enum.empty?(ConfigStorage.get_all_network_configs())

    if email && pass && server && network do
      Logger.success(2, "Configuration finished.")
      :ok
    else
      Process.sleep(30_000)
      loop_until_configured()
    end
  end

  defp build_ssid do
    node_str = node() |> Atom.to_string()

    case node_str |> String.split("@") do
      [name, "farmbot-" <> id] -> name <> "-" <> id
      _ -> "farmbot-UNKN"
    end
  end

  defp write_config! do
    # Delete old file just in case.
    File.rm(@hostapd_conf_file)
    # render the template.
    templ = hostapd_conf_template()
    out = EEx.eval_file(templ, ifname: @ifname, ssid: build_ssid())
    # write it.
    File.write!(@hostapd_conf_file, out)
  end
end
