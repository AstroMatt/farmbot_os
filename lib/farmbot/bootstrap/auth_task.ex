defmodule Farmbot.Bootstrap.AuthTask do
  @moduledoc "Background worker that refreshes a token every 30 minutes."
  use GenServer
  use Farmbot.Logger
  alias Farmbot.System.ConfigStorage
  import ConfigStorage, only: [update_config_value: 4, get_config_value: 3]

  @configurator Application.get_env(:farmbot, :behaviour)[:configurator]
  @configurator || Mix.raise("Please configure a configurator implementation.")

  # 30 minutes.
  @refresh_time 1.8e+6 |> round()
  # @refresh_time 5_000

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def force_refresh do
    GenServer.call(__MODULE__, :force_refresh)
  end

  def init([]) do
    timer = Process.send_after(self(), :refresh, @refresh_time)
    {:ok, %{timer: timer, last: true}, :hibernate}
  end

  def terminate(reason, _state) do
    unless reason == {:shutdown, :normal} do
      Logger.error 1, "Token Refresh failed: #{inspect reason}"
    end
  end

  defp do_refresh(state) do
    auth_task = Application.get_env(:farmbot, :behaviour)[:authorization]
    {email, pass, server} = {fetch_email(), fetch_pass(), fetch_server()}
    # Logger.busy(3, "refreshing token: #{email} - #{server}")
    Farmbot.System.GPIO.Leds.led_status_err()
    case auth_task.authorize(email, pass, server) do
      {:ok, token} ->
        # Logger.success(3, "Successful authorization: #{email} - #{server}")
        update_config_value(:bool, "settings", "first_boot", false)
        update_config_value(:string, "authorization", "token", token)
        Farmbot.System.GPIO.Leds.led_status_ok()
        if get_config_value(:bool, "settings", "auto_sync") do
          # Force an auto sync
          Farmbot.Repo.sync(2)
        end

        if state.last == false do
          Logger.success(1, "Token reauthorized.")
          restart_transports()
          @configurator.leave()
        end
        Farmbot.System.Registry.dispatch :authorization, :new_token
        refresh_timer(%{state | last: true}, self())
      {:error, err} ->
        if state.last do
          msg = "Token failed to reauthorize: #{email} - #{server} #{inspect err}"
          Logger.error(1, msg)
          @configurator.enter(msg)
        end
        # If refresh failed, try again more often
        refresh_timer(%{state | last: false}, self(), 15_000)
    end
  end

  def handle_info(:refresh, state) do
    do_refresh(state)
  end

  def handle_call(:force_refresh, _, state) do
    Logger.info 1, "Forcing a token refresh."
    if Process.read_timer(state.timer) do
      Process.cancel_timer(state.timer)
    end
    send self(), :refresh
    {:reply, :ok, %{state | timer: nil}}
  end

  defp restart_transports do
    bootstrap_sup = Farmbot.Bootstrap.Supervisor
    transport_sup = Farmbot.BotState.Transport.Supervisor
    :ok = Supervisor.terminate_child(bootstrap_sup, transport_sup)
    {:ok, _} = Supervisor.restart_child(bootstrap_sup, transport_sup)
  end

  defp refresh_timer(state, pid, ms \\ @refresh_time) do
    timer = Process.send_after(pid, :refresh, ms)
    {:noreply, %{state | timer: timer}, :hibernate}
  end

  defp fetch_email do
    email = get_config_value(:string, "authorization", "email")
    email || raise "No email provided for token refresh."
  end

  defp fetch_pass do
    pass = get_config_value(:string, "authorization", "password")
    pass || raise "No password provided for token refresh."
  end

  defp fetch_server do
    server = get_config_value(:string, "authorization", "server")
    server || raise "No server provided for token refresh."
  end
end
