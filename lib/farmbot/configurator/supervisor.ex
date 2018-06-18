defmodule Farmbot.Configurator.Supervisor do
  use Supervisor
  @configurator_impl Application.get_env(:farmbot, :behaviour)[:configurator]
  @configurator_impl ||
    Mix.raise("Please configure a configurator implementation.")

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      {@configurator_impl, []},
      {Farmbot.Configurator, []}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
