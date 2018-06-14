defmodule Netinfo do
  def ipv4_address(ifname) do
    case Enum.find(addrs(), &Kernel.==(elem(&1, 0), ifname)) do
      nil -> {:error, :unknown_ifname}
      {^ifname, %{ipv4_address: {_,_,_,_} = ipv4}} ->
        {:ok, tup_to_ipv4(ipv4)}
      _ -> {:error, :no_ipv4_address}
    end
  end

  def addrs do
    {:ok, info} = :inet.getifaddrs()
    Map.new(info, fn({ifname, info}) ->
      {to_string(ifname), Map.new(info, &convert_info(&1))}
    end)
  end

  defp convert_info({:addr, {_,_,_,_} = ipv4}), do: {:ipv4_address, ipv4}
  defp convert_info({:addr, {_,_,_,_,_,_,_,_} = ipv6}), do: {:ipv6_address, ipv6}

  defp convert_info({:netmask, {_,_,_,_} = ipv4}), do: {:ipv4_netmask, ipv4}
  defp convert_info({:netmask, {_,_,_,_,_,_,_,_} = ipv6}), do: {:ipv6_netmask, ipv6}

  defp convert_info({:broadaddr, {_,_,_,_} = ipv4}), do: {:ipv4_broadaddr, ipv4}
  defp convert_info({:broadaddr, {_,_,_,_,_,_,_,_} = ipv6}), do: {:ipv6_broadaddr, ipv6}

  defp convert_info({key, val}) do
    {key, val}
  end

  def tup_to_ipv4({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  def tup_to_ipv6({_,_,_,_,_,_,_,_}), do: :fixme
end
