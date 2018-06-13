defmodule Farmbot.Configurator.Watchdog do
  @moduledoc """
  Wrapper module for a watchdog behaviour.
  """

  @watchdog Application.get_env(:farmbot, :behaviour)[:watchdog]
  @watchdog ||  Mix.raise("Please configure a watchdog implementation.")
end
