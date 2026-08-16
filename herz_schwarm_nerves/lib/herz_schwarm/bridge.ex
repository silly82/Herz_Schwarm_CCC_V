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
  @poll_status_ms 5_000
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
    # Resolve port: Application.get_env first (normal path), then
    # Path.wildcard auto-detect as fallback. This handles the case where
    # supervisor starts the child before dev.exs runs (Mix 1.18 timing).
    port =
      case Application.get_env(:herz_schwarm, :uart_device) do
        nil -> resolve_uart_device() || raise_uart_not_configured!()
        p when is_binary(p) -> p
        other -> raise ":uart_device must be a binary path, got: #{inspect(other)}"
      end

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
            Process.send_after(self(), :poll_status, @poll_status_ms)
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

  @impl true
  def handle_info(:poll_status, state) do
    if state.connected do
      seq = state.seq + 1
      json = Jason.encode!(%{cmd: "status", seq: seq}) <> "\n"
      UART.write(state.uart_pid, json)
      Process.send_after(self(), :poll_status, @poll_status_ms)
      {:noreply, %{state | seq: seq}}
    else
      # Not connected: drop the poll loop here, :connect restarts it on success
      {:noreply, state}
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

  # Raises with helpful instructions when no UART device can be resolved.
  defp raise_uart_not_configured! do
    raise """
    :herz_schwarm, :uart_device is not configured and no USB-serial
    device could be auto-detected.

    Fix: Set UART_DEVICE env var to your ESP32 bridge:
      UART_DEVICE=/dev/cu.usbmodem101 mix phx.server

    For XIAO ESP32-C6: usually /dev/cu.usbmodem101
    For ESP32-S3 (native USB): usually /dev/cu.usbserial-1410
    For ESP32 with CH340/CP2102: usually /dev/cu.usbmodem14101
    """
  end

  # Fallback UART-Device resolution: checks UART_DEVICE env-var first,
  # then does Path.wildcard on common macOS USB-serial patterns. On
  # Linux, defaults to /dev/ttyUSB0 (typical for CH340/CP2102). On
  # macOS, returns nil if no device found (caller raises loud).
  defp resolve_uart_device do
    case System.get_env("UART_DEVICE") do
      nil ->
        cond do
          match?({:win32, _}, :os.type()) ->
            "COM3"

          match?({:unix, :darwin}, :os.type()) ->
            # macOS: only return a port we actually found, never a Linux path
            first_found([
              "/dev/cu.usbserial-*",
              "/dev/cu.SLAB_USBtoUART",
              "/dev/cu.usbmodem*"
            ])

          true ->
            # Linux: default to ttyUSB0 (CH340/CP2102 USB-serial bridges)
            first_found([
              "/dev/ttyUSB*",
              "/dev/ttyACM*"
            ]) || "/dev/ttyUSB0"
        end

      dev ->
        dev
    end
  end

  defp first_found(patterns) do
    Enum.find_value(patterns, fn pattern ->
      case Path.wildcard(pattern) do
        [first | _] -> first
        _ -> nil
      end
    end)
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
