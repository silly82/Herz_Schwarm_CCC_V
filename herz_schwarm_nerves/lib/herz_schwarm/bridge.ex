defmodule HerzSchwarm.Bridge do
  @moduledoc """
  GenServer managing UART communication with the ESP32 bridge.

  Sends newline-delimited JSON commands to the bridge firmware and
  parses incoming JSON responses. Broadcasts events via PubSub.

  Reconnect strategy: exponential backoff capped at 30s, resets on success.
  Without this, a missing bridge logs every 2s indefinitely.
  """

  use GenServer
  require Logger

  alias Circuits.UART

  @pubsub HerzSchwarm.PubSub
  @topic "bridge:events"
  @reconnect_ms_initial 2_000
  @reconnect_ms_max 30_000
  @uart_opts [speed: 115200, active: true, framing: {Circuits.UART.Framing.Line, separator: "\n"}]

  defstruct [:uart_pid, :port, :connected, :seq, :buffer, :reconnect_ms]

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_command(cmd) when is_map(cmd) do
    GenServer.cast(__MODULE__, {:send_command, cmd})
  end

  def connected? do
    GenServer.call(__MODULE__, :connected?)
  end

  def topic, do: @topic

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    port = Application.get_env(:herz_schwarm, :uart_device, "/dev/ttyUSB0")
    state = %__MODULE__{
      uart_pid: nil,
      port: port,
      connected: false,
      seq: 0,
      buffer: "",
      reconnect_ms: @reconnect_ms_initial
    }

    if Application.get_env(:herz_schwarm, :bridge_enabled, true) do
      send(self(), :connect)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, state.connected, state}
  end

  @impl true
  def handle_cast({:send_command, cmd}, state) do
    if state.connected do
      seq = state.seq + 1
      cmd = Map.put(cmd, :seq, seq)
      json = Jason.encode!(cmd) <> "\n"
      UART.write(state.uart_pid, json)
      {:noreply, %{state | seq: seq}}
    else
      Logger.warning("Bridge not connected, dropping command: #{inspect(cmd)}")
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connect, state) do
    case UART.start_link() do
      {:ok, pid} ->
        case UART.open(pid, state.port, @uart_opts) do
          :ok ->
            Logger.info("Bridge connected on #{state.port}")
            # Reset backoff on successful connect
            broadcast({:bridge, :connected})
            {:noreply, %{state | uart_pid: pid, connected: true, reconnect_ms: @reconnect_ms_initial}}

          {:error, reason} ->
            Logger.warning("Failed to open #{state.port}: #{inspect(reason)}")
            UART.stop(pid)
            schedule_reconnect(state)
            {:noreply, %{state | connected: false}}
        end

      {:error, reason} ->
        Logger.warning("Failed to start UART: #{inspect(reason)}")
        schedule_reconnect(state)
        {:noreply, %{state | connected: false}}
    end
  end

  def handle_info({:circuits_uart, _port, data}, state) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, event} ->
        broadcast({:bridge, event})

      {:error, _} ->
        Logger.debug("Bridge raw: #{data}")
    end

    {:noreply, state}
  end

  def handle_info({:circuits_uart, _port, :partial, partial}, state) do
    {:noreply, %{state | buffer: state.buffer <> partial}}
  end

  def handle_info({:circuits_uart, _port, :error, reason}, state) do
    Logger.warning("UART error: #{inspect(reason)}")
    broadcast({:bridge, :disconnected})
    # Increase backoff after an error during operation
    schedule_reconnect(%{state | reconnect_ms: next_backoff(state.reconnect_ms)})
    {:noreply, %{state | connected: false}}
  end

  defp next_backoff(current) do
    # 2s -> 4s -> 8s -> 16s -> 30s (cap)
    min(current * 2, @reconnect_ms_max)
  end

  defp schedule_reconnect(state) do
    delay = state.reconnect_ms
    Process.send_after(self(), :connect, delay)
    Logger.debug("Reconnect scheduled in #{delay}ms")
  end

  defp broadcast(msg) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, msg)
  end
end
