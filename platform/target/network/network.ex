defmodule Farmbot.Target.Network do
  @moduledoc "Bring up network."

  @behaviour Farmbot.System.Init

  alias Farmbot.System.ConfigStorage
  alias ConfigStorage.NetworkInterface, as: NI
  alias Farmbot.Target.Network.Manager, as: NetworkManager
  alias Farmbot.Target.Network.ScanResult
  import Farmbot.Target.Network.Templates

  use Supervisor
  use Farmbot.Logger
  @data_path Application.get_env(:farmbot, :data_path)
  @network_interfaces_file Path.join(@data_path, "interfaces")

  @doc "List available interfaces. Removes unusable entries."
  def get_interfaces(tries \\ 5)
  def get_interfaces(0), do: []

  def get_interfaces(tries) do
    case Nerves.NetworkInterface.interfaces() do
      ["lo"] ->
        Process.sleep(100)
        get_interfaces(tries - 1)

      interfaces when is_list(interfaces) ->
        interfaces
        # Delete unusable entries if they exist.
        |> List.delete("usb0")
        |> List.delete("lo")
        |> List.delete("sit0")
        |> List.delete("uap0")
        |> Map.new(fn interface ->
          {:ok, settings} = Nerves.NetworkInterface.status(interface)
          {interface, settings}
        end)
    end
  end

  def scan(ifname) do
    case GenServer.whereis(NetworkManager.name(ifname)) do
      nil ->
        wpa_templ_render!(ifname, "BASE", [])
        Nerves.Runtime.cmd("sh", ["-c" | [wpa_supplicant_cmdline(ifname)]], :info)
        {:ok, wpa} = Nerves.WpaSupplicant.start_link(ifname, "/var/run/wpa_supplicant_ctrl/#{ifname}")
        res = Nerves.WpaSupplicant.scan(wpa)
          |> ScanResult.decode()
          |> ScanResult.sort_results()
          |> ScanResult.decode_security()
          |> Enum.filter(&Map.get(&1, :ssid))
          |> Enum.map(&Map.update(&1, :ssid, nil, fn ssid -> to_string(ssid) end))
          |> Enum.reject(&String.contains?(&1.ssid, "\\x00"))
          |> Enum.uniq_by(fn %{ssid: ssid} -> ssid end)
        Nerves.WpaSupplicant.stop(wpa)
        Nerves.Runtime.cmd("sh", ["-c" | [kill_wpa_supplicant_cmdline(ifname)]], :info)
        File.rm_rf("/var/run/wpa_supplicant_ctrl/wlan0")
        res
      pid ->
        NetworkManager.scan(pid)
    end
  end

  def start_link(_, opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    import Supervisor.Spec
    configs = ConfigStorage.get_all_network_configs()
    Logger.info(3, "Starting Networking")

    children =
      Enum.map(configs, fn %{name: ifname} = config ->
        write_interfaces_file!(config)
        worker(NetworkManager, [ifname, config])
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def write_interfaces_file!(config) do
    data = File.read!(@network_interfaces_file)
    replace_str = "# replace-#{config.name}\n"
    rendered = String.replace(data, replace_str, render_config!(config))
    File.write!(@network_interfaces_file, rendered)
  end

  def render_config!(%NI{type: "wireless", ipv4_method: "dhcp"} = config) do
    render_wpa_conf!(config)

    """
    iface #{config.name} inet dhcp
        pre-up #{wpa_supplicant_cmdline(config.name)}
        post-down #{kill_wpa_supplicant_cmdline(config.name)}

    """
  end

  def render_config!(%NI{type: "wired", ipv4_method: "dhcp"} = config) do
    """
    iface #{config.name} inet dhcp

    """
  end

  def render_wpa_conf!(%NI{security: "WPA-PSK"} = config) do
    wpa_templ_render!(
      config.name,
      "WPA-PSK",
      ssid: config.ssid,
      psk: config.psk
    )
  end

  def render_wpa_conf!(%NI{security: "NONE"} = config) do
    wpa_templ_render!(config.name, "NONE", ssid: config.ssid)
  end

  def wpa_templ_render!(ifname, security, bindings) do
    output = EEx.eval_file(wpa_supplicant_conf_template(security), bindings)
    File.write!("/root/#{ifname}.wpa_supplicant.conf", output)
  end

  defp wpa_supplicant_cmdline(ifname) do
    "wpa_supplicant -Dnl80211 -B -i #{ifname} -c /root/#{ifname}.wpa_supplicant.conf -dd -P /var/run/#{ifname}.wpa_supplicant.pid"
  end

  defp kill_wpa_supplicant_cmdline(ifname) do
    "kill -s SIGQUIT $(cat /var/run/#{ifname}.wpa_supplicant.pid)"
  end
end
