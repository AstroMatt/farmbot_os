defmodule Farmbot.Asset.Log do
  @moduledoc """
  This is _not_ the same as the API's log asset.
  """

  defmodule LogLevelType do
    @moduledoc false
    @level_atoms [:debug, :info, :error, :warn, :busy, :success]
    @level_strs ["debug", "info", "error", "warn", "busy", "success"]

    def type, do: :string

    def cast(level) when level in @level_strs, do: {:ok, level}
    def cast(level) when level in @level_atoms, do: {:ok, to_string(level)}
    def cast(_), do: :error

    def load(str), do: {:ok, String.to_existing_atom(str)}
    def dump(str), do: {:ok, to_string(str)}
  end

  use Ecto.Schema
  import Ecto.Changeset

  schema "logs" do
    field(:level, LogLevelType)
    field(:verbosity, :integer)
    field(:message, :string)
    field(:meta, Farmbot.Repo.JSONType)
    field(:function, :string)
    field(:file, :string)
    field(:line, :integer)
    field(:module, :string)
    field(:version, :string)
    field(:commit, :string)
    field(:target, :string)
    field(:env, :string)
    timestamps()
  end

  @required_fields [:level, :verbosity, :message]
  @optional_fields [:meta, :function, :file, :line, :module]

  def changeset(log, params \\ %{}) do
    log
    |> Map.put(:version, to_string(Farmbot.Project.version()))
    |> Map.put(:commit, to_string(Farmbot.Project.commit()))
    |> Map.put(:target, to_string(Farmbot.Project.target()))
    |> Map.put(:env, to_string(Farmbot.Project.env()))
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
