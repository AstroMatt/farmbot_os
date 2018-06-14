defmodule Farmbot.Target.Network.Manager do
  @moduledoc "Network manager"
  alias Farmbot.System.ConfigStorage
  import ConfigStorage, only: [get_config_value: 3]
  alias ConfigStorage.NetworkInterface, as: NI
  alias Farmbot.Target.Network.{ScanResult, Ntp}
  use Farmbot.Logger

  defmodule State do
    defstruct [:config, :ntp_timer]
  end

  def start_link(ifname, config) do
    GenServer.start_link(__MODULE__, [config], name: name(ifname))
  end

  def init([%NI{} = config]) do
    Nerves.Runtime.cmd("ifup", [config.name], :info)
    state = %State{config: %{config | ipv4_address: nil}}
    state = if config.ipv4_method == "dhcp" do
      start_dhcp_poll()
      state
    else
      state
    end
    {:ok, state}
  end

  def terminate(_reason, state) do
    Nerves.Runtime.cmd("ifdown", [state.config.name], :info)
  end

  def handle_info(:dhcp_poll, %{config: %{name: ifname, ipv4_address: old}} = state) do
    case Netinfo.ipv4_address(ifname) do
      {:ok, ^old} ->
        start_dhcp_poll()
        {:noreply, state}
      {:ok, new} ->
        start_dhcp_poll()
        Logger.debug 3, "Ip address #{old} => #{new}"
        new_state = %{state | config: %{state.config | ipv4_address: new}}
        {:noreply, handle_ip_change(new_state)}
    end
  end

  defp start_dhcp_poll() do
    Process.send_after(self(), :dhcp_poll, 5000)
  end

  defp handle_ip_change(state) do
    %{state | ntp_timer: maybe_cancel_and_reset_ntp_timer(state.ntp_timer)}
  end

  defp maybe_cancel_and_reset_ntp_timer(timer) do
    if timer do
      Process.cancel_timer(timer)
    end

    # introduce a bit of randomness to avoid dosing ntp servers.
    # I don't think this would ever happen but the default ntpd implementation
    # does this..
    rand = :rand.uniform(5000)

    case Ntp.set_time() do

      # If we Successfully set time, sync again in around 1024 seconds
      :ok -> Process.send_after(self(), :ntp_timer, 1024000 + rand)
      # If time failed, try again in about 5 minutes.
      _ ->
        if get_config_value(:bool, "settings", "first_boot") do
          Process.send_after(self(), :ntp_timer, 10_000 + rand)
        else
          Process.send_after(self(), :ntp_timer, 300000 + rand)
        end
    end
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
