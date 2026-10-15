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
  @uart_opts [
    speed: 115_200,
    active: true,
    framing: {Circuits.UART.Framing.Line, separator: "\n"}
  ]

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
    # Port wird erst beim :connect aufgeloest (und bei jedem Reconnect neu),
    # damit eine spaeter eingesteckte oder umbenannte Bridge gefunden wird.
    state = %__MODULE__{
      uart_pid: nil,
      port: nil,
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
    case resolve_port() do
      nil ->
        Logger.warning(
          "Keine ESP32-Bridge gefunden (kein Port antwortet auf status). " <>
            "Fester Port: UART_DEVICE=/dev/... setzen."
        )

        schedule_reconnect(state)
        {:noreply, %{state | connected: false, reconnect_ms: next_backoff(state.reconnect_ms)}}

      port ->
        open_port(%{state | port: port})
    end
  end

  @impl true
  def handle_info(:poll_status, state) do
    if state.connected do
      # status -> pong (Anzahl), peers -> eine "peer"-Zeile je Badge + "peers" als Ende
      seq = state.seq + 2
      UART.write(state.uart_pid, Jason.encode!(%{cmd: "status", seq: seq - 1}) <> "\n")
      UART.write(state.uart_pid, Jason.encode!(%{cmd: "peers", seq: seq}) <> "\n")
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

  def handle_info({:circuits_uart, _port, {:partial, partial}}, state) do
    {:noreply, %{state | buffer: state.buffer <> partial}}
  end

  def handle_info({:circuits_uart, _port, {:error, reason}}, state) do
    Logger.warning("UART error: #{inspect(reason)}")
    if state.uart_pid, do: UART.stop(state.uart_pid)
    state = %{state | uart_pid: nil}
    broadcast({:bridge, :disconnected})
    # Increase backoff after an error during operation
    state = %{state | connected: false, reconnect_ms: next_backoff(state.reconnect_ms)}
    schedule_reconnect(state)
    {:noreply, state}
  end

  defp open_port(state) do
    {:ok, pid} = UART.start_link()

    case UART.open(pid, state.port, @uart_opts) do
      :ok ->
        Logger.info("Bridge connected on #{state.port}")
        broadcast({:bridge, :connected})
        Process.send_after(self(), :poll_status, @poll_status_ms)
        {:noreply, %{state | uart_pid: pid, connected: true, reconnect_ms: @reconnect_ms_initial}}

      {:error, reason} ->
        Logger.warning("Failed to open #{state.port}: #{inspect(reason)}")
        UART.stop(pid)
        schedule_reconnect(state)
        {:noreply, %{state | connected: false, reconnect_ms: next_backoff(state.reconnect_ms)}}
    end
  end

  # Reihenfolge: UART_DEVICE-Env > config :uart_device > Auto-Detect.
  defp resolve_port do
    System.get_env("UART_DEVICE") ||
      Application.get_env(:herz_schwarm, :uart_device) ||
      detect_bridge()
  end

  # Auto-Detect: nur USB-Seriell-Chips, die als Bridge in Frage kommen, und
  # davon der erste, der auf {"cmd":"status"} mit "pong" antwortet. Badges und
  # Basisstation haben dieselbe Espressif-VID, lesen aber kein Serial -> kein pong.
  # Espressif (natives USB: C3/S3/C6), Silicon Labs CP210x, WCH CH340/CH9102, FTDI
  @bridge_vids [0x303A, 0x10C4, 0x1A86, 0x0403]
  @probe_timeout_ms 1_500

  defp detect_bridge do
    UART.enumerate()
    |> Enum.filter(fn {_name, info} -> Map.get(info, :vendor_id) in @bridge_vids end)
    |> Enum.map(fn {name, _info} -> name end)
    |> Enum.sort()
    |> Enum.map(&normalize_path/1)
    |> Enum.find(&probe/1)
  end

  # enumerate liefert unter Linux "ttyACM0", unter macOS "/dev/cu.usbmodem…".
  defp normalize_path("/dev/" <> _ = path), do: path
  defp normalize_path(name), do: "/dev/" <> name

  defp probe(path) do
    {:ok, pid} = UART.start_link()

    try do
      case UART.open(pid, path, Keyword.put(@uart_opts, :active, false)) do
        :ok ->
          UART.write(pid, ~s({"cmd":"status","seq":0}\n))
          deadline = System.monotonic_time(:millisecond) + @probe_timeout_ms
          found = await_pong(pid, deadline)
          Logger.debug("Bridge-Probe #{path}: #{if found, do: "pong", else: "keine Antwort"}")
          found

        {:error, reason} ->
          Logger.debug("Bridge-Probe #{path}: #{inspect(reason)}")
          false
      end
    after
      UART.stop(pid)
    end
  end

  defp await_pong(pid, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      false
    else
      case UART.read(pid, remaining) do
        {:ok, line} when is_binary(line) and line != "" ->
          String.contains?(line, ~s("evt":"pong")) or await_pong(pid, deadline)

        {:ok, _} ->
          await_pong(pid, deadline)

        {:error, _} ->
          false
      end
    end
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
