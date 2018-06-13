defmodule Farmbot.Host.Configurator do
  @behaviour Farmbot.Configurator
  use Supervisor
  use Farmbot.Logger
  import Farmbot.System.ConfigStorage, only: [get_config_value: 3, update_config_value: 4]

  error = """
  Your environment is not properly configured! You will need to follow the
  directions in `config/host/auth_secret_template.exs` before continuing.
  """

  @email Application.get_env(:farmbot, :authorization)[:email]
  @email || Mix.raise error

  @pass Application.get_env(:farmbot, :authorization)[:password]
  @pass || Mix.raise error

  @server Application.get_env(:farmbot, :authorization)[:server]
  @server || Mix.raise error

  def start_link(_), do: Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  def init(_), do: :ignore

  def provision do
    Logger.busy(3, "Provision stub configurator.")
    update_config_value(:string, "authorization", "email", @email)

    # if there is no firmware hardware, default ot farmduino
    unless get_config_value(:string, "settings", "firmware_hardware") do
      update_config_value(:string, "settings", "firmware_hardware", "farmduino")
    end

    if get_config_value(:bool, "settings", "first_boot") do
      update_config_value(:string, "authorization", "password", @pass)
    end
    update_config_value(:string, "authorization", "server", @server)
    update_config_value(:string, "authorization", "token", nil)
  end

  def enter(reason) do
    Logger.error(3, "Enter stub configurator mode (this doesn't do anything) #{inspect reason}")
    :ok
  end

  def leave() do
    Logger.success(3, "Leave stub configurator mode. (this doesn't do anything)")
  end
end
