defmodule Farmbot.Target.Network.Templates do
  def wpa_supplicant_conf_template(security),
    do: template("wpa_supplicant.#{security}.conf.eex")

  def hostapd_conf_template, do: template("hostapd.conf.eex")

  defp template(file),
    do: Path.join([:code.priv_dir(:farmbot), "network", file])
end
