defmodule Farmbot.System.UpdateTimerTest do
  use ExUnit.Case, async: false
  alias Farmbot.System.ConfigStorage

  test "Opting into beta updates should refresh token" do
    Farmbot.System.Registry.subscribe(self())

    old = ConfigStorage.get_config_value(:string, "authorization", "token")

    ConfigStorage.update_config_value(:bool, "settings", "beta_opt_in", false)
    ConfigStorage.update_config_value(:bool, "settings", "beta_opt_in", true)

    assert_receive {Farmbot.System.Registry, {:config_storage, {"settings", "beta_opt_in", true}}}
    assert_receive {Farmbot.System.Registry, {:authorization, :new_token}}, 1000

    new = ConfigStorage.get_config_value(:string, "authorization", "token")
    assert old != new
  end
end
