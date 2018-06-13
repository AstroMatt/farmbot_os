defmodule Farmbot.Target.Network do
  @moduledoc "Bring up network."

  @behaviour Farmbot.System.Init

  alias Farmbot.System.ConfigStorage
  alias Farmbot.Target.Network.Manager, as: NetworkManager

  use Supervisor
  use Farmbot.Logger

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
    NetworkManager.scan(NetworkManager.name(ifname))
  end

  def start_link(_, opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    configs = ConfigStorage.get_all_network_configs()
    Logger.info(3, "Starting Networking")
    children = Enum.map(configs, fn(%{name: ifname} = config) ->
      {NetworkManager, [ifname, config]}
    end)
    Supervisor.init(children, :one_for_one)
  end
end
