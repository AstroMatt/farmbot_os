defmodule Farmbot.Host.Configurator do
  @behaviour Farmbot.Configurator
  
  @email Application.get_env(:farmbot, :authorization)[:email]
  @email || Mix.raise error("email")

  @pass Application.get_env(:farmbot, :authorization)[:password]
  @pass || Mix.raise error("password")

  @server Application.get_env(:farmbot, :authorization)[:server]
  @server || Mix.raise error("server")

  defp error(_field) do
    """
    Your environment is not properly configured! You will need to follow the
    directions in `config/host/auth_secret_template.exs` before continuing.
    """
  end
end
