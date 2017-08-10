defmodule Farmbot.HTTP.Supervisor do
  @moduledoc "Supervises HTTP."

  use Supervisor

  @doc "Start HTTP services."
  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    children = []
    opts = [strategy: :one_for_all]
  end

end
