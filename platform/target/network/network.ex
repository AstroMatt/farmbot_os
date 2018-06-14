defmodule Farmbot.Target.Network do
  @moduledoc "Bring up network."

  @behaviour Farmbot.System.Init

  alias Farmbot.System.ConfigStorage
  alias ConfigStorage.NetworkInterface, as: NI
  alias Farmbot.Target.Network.Manager, as: NetworkManager

  use Supervisor
  use Farmbot.Logger
  @data_path Application.get_env(:farmbot, :data_path)

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
        |> List.delete("usb0") # Delete unusable entries if they exist.
        |> List.delete("lo")
        |> List.delete("sit0")
        |> List.delete("uap0")
        |> Map.new(fn(interface) ->
          {:ok, settings} = Nerves.NetworkInterface.status(interface)
          {interface, settings}
        end)
    end
  end

  def scan(ifname) do
    []
    # NetworkManager.scan(NetworkManager.name(ifname))
  end

  def start_link(_, opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    import Supervisor.Spec
    configs = ConfigStorage.get_all_network_configs()
    Logger.info(3, "Starting Networking")
    children = Enum.map(configs, fn(%{name: ifname} = config) ->
      write_interfaces_file!(config)
      worker(NetworkManager, [ifname, config])
    end)
    Supervisor.init(children, [strategy: :one_for_one])
  end

  def write_interfaces_file!(config) do
    network_interfaces_file = Path.join(@data_path, "interfaces")
    data = File.read!(network_interfaces_file)
    replace_str = "# replace-#{config.name}\n"
    rendered = String.replace(data, replace_str, render_config!(config))
    File.write!(network_interfaces_file, rendered)
  end

  def render_config!(%NI{type: "wireless", ipv4_method: "dhcp"} = config) do
    render_wpa_conf!(config)
    """
    iface #{config.name} inet dhcp
        pre-up wpa_supplicant -Dnl80211 -B -i #{config.name} -c /root/#{config.name}.wpa_supplicant.conf -dd -P /var/run/#{config.name}.wpa_supplicant.pid
        post-down kill -s SIGQUIT $(cat /var/run/#{config.name}.wpa_supplicant.pid)

    """
  end

  def render_config!(%NI{type: "wired", ipv4_method: "dhcp"} = config) do
    """
    iface #{config.name} inet dhcp

    """
  end

  def render_wpa_conf!(%NI{security: "WPA-PSK"} = config) do
    File.write!("/root/#{config.name}.wpa_supplicant.conf",
    """
    ctrl_interface=/var/run/wpa_supplicant_ctrl
    country=US

    network={
      ssid="#{config.ssid}"
      psk="#{config.psk}"
      key_mgmt=WPA-PSK
    }
    """)
  end
end
