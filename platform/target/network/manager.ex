defmodule Farmbot.Target.Network.Manager do
  @moduledoc "Network manager"
  alias ConfigStorage.NetworkInterface
  alias Farmbot.Target.Network.ScanResult


  def start_link([ifname, config]) do
    GenServer.start_link(__MODULE__, [ifname, config], name: name(ifname))
  end

  def init([ifname, config]) do

  end

  @doc "Scan on an interface."
  def scan(iface) do
    do_scan(iface)
    |> ScanResult.decode()
    |> ScanResult.sort_results()
    |> ScanResult.decode_security()
    |> Enum.filter(&Map.get(&1, :ssid))
    |> Enum.map(&Map.update(&1, :ssid, nil, fn(ssid) -> to_string(ssid) end))
    |> Enum.reject(&String.contains?(&1.ssid, "\\x00"))
    |> Enum.uniq_by(fn(%{ssid: ssid}) -> ssid end)
  end

  defp wait_for_results(pid) do
    Nerves.WpaSupplicant.request(pid, :SCAN_RESULTS)
    |> String.trim()
    |> String.split("\n")
    |> tl()
    |> Enum.map(&String.split(&1, "\t"))
    |> Enum.map(fn(res) ->
      case res do
        [bssid, freq, signal, flags, ssid] ->
          %{bssid: bssid,
            frequency: String.to_integer(freq),
            flags: flags,
            level: String.to_integer(signal),
            ssid: ssid
          }

        [bssid, freq, signal, flags] ->
          %{bssid: bssid,
            frequency: String.to_integer(freq),
            flags: flags,
            level: String.to_integer(signal),
            ssid: nil
          }
      end
    end)
    |> case do
      [] ->
        Process.sleep(500)
        wait_for_results(pid)
      res -> res
    end
  end

  def do_scan(iface) do
    pid = :"Nerves.WpaSupplicant.#{iface}"
    Nerves.WpaSupplicant.request(pid, :SCAN)
    wait_for_results(pid)
  end

  def name(ifname), do: :"network.#{ifname}"
end
