defmodule HerzSchwarm.Bridge do
  @moduledoc """
  GenServer managing UART communication with the ESP32 bridge.

  Sends newline-delimited JSON commands to the bridge firmware and
  parses incoming JSON responses. Broadcasts events via PubSub.

  Reconnect strategy: exponential backoff capped at 30s, resets on success.
  Without this, a missing bridge logs every 2s indefinitely.

  Monitoring: Verbindungswechsel, `log`/`err`-Events und `pong`-Daten gehen an
  `HerzSchwarm.EventLog` bzw. `HerzSchwarm.Metrics`. Ausstehende Kommandos
  (`effect`, `identify`, ...) werden ueber ihre `seq` verfolgt: `ack` zaehlt
  `:acks`, `err` `:errors`, bleibt beides innerhalb von `:ack_timeout_ms`
  (config `:herz_schwarm`, Default 1500, max. 10 s) aus, zaehlt `:timeouts`.
  Nicht verfolgt werden `ota_*` (macht `BridgeUpdater` selbst), `status` und
  `peers` (antworten mit `pong`/`peers` statt `ack`). Eine verspaetete Antwort
  nach einem Timeout aendert keinen Zaehler mehr.
  """

  use GenServer
  require Logger

  alias Circuits.UART
  alias HerzSchwarm.{EventLog, Metrics}

  @pubsub HerzSchwarm.PubSub
  @topic "bridge:events"
  @reconnect_ms_initial 2_000
  @reconnect_ms_max 30_000
  @poll_status_ms 5_000
  @ack_timeout_default_ms 1_500
  @ack_timeout_max_ms 10_000
  @max_pending 256
  @uart_opts [
    speed: 115_200,
    active: true,
    framing: {Circuits.UART.Framing.Line, separator: "\n"}
  ]

  defstruct [
    :uart_pid,
    :port,
    :connected,
    :seq,
    :buffer,
    :reconnect_ms,
    write: &UART.write/2,
    pending: %{},
    ever_connected: false,
    fail_logged: false,
    # Poll-Kette: genau ein Timer; poll_gen verwirft Auslöser alter Ketten.
    poll_timer: nil,
    poll_gen: 0
  ]

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sendet ein Kommando an die Bridge (die `seq` wird hier vergeben).

  Gibt `{:ok, seq}` zurueck, damit Aufrufer das passende `ack`/`err` aus
  `"bridge:events"` zuordnen koennen, oder `{:error, reason}`. Bestehende
  Aufrufer duerfen den Rueckgabewert ignorieren.
  """
  def send_command(cmd) when is_map(cmd) do
    GenServer.call(__MODULE__, {:send_command, cmd})
  catch
    :exit, _ -> {:error, :bridge_down}
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

  def handle_call({:send_command, cmd}, _from, state) do
    if state.connected do
      seq = state.seq + 1
      cmd = Map.put(cmd, :seq, seq)
      json = Jason.encode!(cmd) <> "\n"

      case state.write.(state.uart_pid, json) do
        :ok ->
          {:reply, {:ok, seq}, track_command(%{state | seq: seq}, seq, cmd)}

        {:error, reason} ->
          EventLog.log(:warn, "bridge", "UART-Schreibfehler: #{inspect(reason)}")
          {:reply, {:error, reason}, %{state | seq: seq}}
      end
    else
      Logger.warning("Bridge not connected, dropping command: #{inspect(cmd)}")

      EventLog.log(
        :warn,
        "bridge",
        "Kommando verworfen (Bridge nicht verbunden): #{cmd_name(cmd)}"
      )

      {:reply, {:error, :not_connected}, state}
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

        state = log_connect_failure(state, "Keine ESP32-Bridge gefunden (kein Port antwortet)")
        schedule_reconnect(state)
        {:noreply, %{state | connected: false, reconnect_ms: next_backoff(state.reconnect_ms)}}

      port ->
        open_port(%{state | port: port})
    end
  end

  @impl true
  def handle_info({:poll_status, gen}, %{poll_gen: gen, connected: true} = state) do
    # status -> pong (Anzahl), peers -> eine "peer"-Zeile je Badge + "peers" als Ende
    seq = state.seq + 2
    state.write.(state.uart_pid, Jason.encode!(%{cmd: "status", seq: seq - 1}) <> "\n")
    state.write.(state.uart_pid, Jason.encode!(%{cmd: "peers", seq: seq}) <> "\n")
    {:noreply, schedule_poll(%{state | seq: seq})}
  end

  # Veraltete Auslöser (andere Generation oder getrennt): ignorieren.
  def handle_info({:poll_status, _stale_gen}, state) do
    {:noreply, state}
  end

  def handle_info({:circuits_uart, _port, data}, state) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, event} ->
        state = observe_event(event, state)
        broadcast({:bridge, event})
        {:noreply, state}

      {:error, _} ->
        Logger.debug("Bridge raw: #{data}")
        {:noreply, state}
    end
  end

  def handle_info({:ack_timeout, seq}, state) do
    case Map.pop(state.pending, seq) do
      {{cmd, sent_ms, _timer}, pending} ->
        waited = System.monotonic_time(:millisecond) - sent_ms
        Metrics.increment(:timeouts)

        EventLog.log(
          :warn,
          "bridge",
          "Timeout: kein ack/err fuer seq=#{seq} (#{cmd_name(cmd)}) nach #{waited} ms"
        )

        {:noreply, %{state | pending: pending}}

      {nil, _} ->
        {:noreply, state}
    end
  end

  def handle_info({:circuits_uart, _port, {:partial, partial}}, state) do
    {:noreply, %{state | buffer: state.buffer <> partial}}
  end

  def handle_info({:circuits_uart, _port, {:error, reason}}, state) do
    Logger.warning("UART error: #{inspect(reason)}")
    if state.uart_pid, do: UART.stop(state.uart_pid)
    state = state |> clear_pending() |> stop_polling() |> Map.put(:uart_pid, nil)
    Metrics.set_bridge_state(%{connected: false, port: state.port})
    EventLog.log(:warn, "bridge", "Verbindung getrennt (#{state.port}): #{inspect(reason)}")
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

        if state.ever_connected do
          Metrics.increment(:reconnects)
          EventLog.log(:info, "bridge", "Bridge wieder verbunden auf #{state.port}")
        else
          EventLog.log(:info, "bridge", "Bridge verbunden auf #{state.port}")
        end

        Metrics.set_bridge_state(%{connected: true, port: state.port})
        broadcast({:bridge, :connected})

        state = %{
          state
          | uart_pid: pid,
            connected: true,
            reconnect_ms: @reconnect_ms_initial,
            ever_connected: true,
            fail_logged: false
        }

        {:noreply, start_polling(state)}

      {:error, reason} ->
        Logger.warning("Failed to open #{state.port}: #{inspect(reason)}")
        UART.stop(pid)

        state =
          log_connect_failure(
            state,
            "Oeffnen von #{state.port} fehlgeschlagen: #{inspect(reason)}"
          )

        schedule_reconnect(state)
        {:noreply, %{state | connected: false, reconnect_ms: next_backoff(state.reconnect_ms)}}
    end
  end

  # --- Poll-Kette (status/peers alle @poll_status_ms) ---

  # Startet die Kette neu: alte Timer werden abgebrochen, neue Generation.
  # @doc false: von Tests genutzt, um Reconnects zu simulieren.
  @doc false
  def start_polling(state) do
    state |> stop_polling() |> schedule_poll()
  end

  defp stop_polling(state) do
    if state.poll_timer, do: Process.cancel_timer(state.poll_timer)
    %{state | poll_timer: nil, poll_gen: state.poll_gen + 1}
  end

  defp schedule_poll(state) do
    if state.poll_timer, do: Process.cancel_timer(state.poll_timer)
    timer = Process.send_after(self(), {:poll_status, state.poll_gen}, @poll_status_ms)
    %{state | poll_timer: timer}
  end

  # Fehlversuche wiederholen sich im Backoff-Takt; nur den ersten protokollieren,
  # sonst flutet eine fehlende Bridge das EventLog.
  defp log_connect_failure(%{fail_logged: true} = state, _msg), do: state

  defp log_connect_failure(state, msg) do
    EventLog.log(:warn, "bridge", msg)
    %{state | fail_logged: true}
  end

  # --- Kommando-Verfolgung (seq -> {cmd, gesendet_ms, timer}) ---

  defp track_command(state, seq, cmd) do
    if trackable?(cmd) do
      timeout = ack_timeout_ms()
      timer = Process.send_after(self(), {:ack_timeout, seq}, timeout)
      sent = System.monotonic_time(:millisecond)

      pending =
        state.pending
        |> drop_oldest_if_full()
        |> Map.put(seq, {cmd, sent, timer})

      %{state | pending: pending}
    else
      state
    end
  end

  # Zusaetzliche Sicherung gegen Wachstum (jeder Eintrag hat zudem einen Timer).
  defp drop_oldest_if_full(pending) when map_size(pending) < @max_pending, do: pending

  defp drop_oldest_if_full(pending) do
    {seq, {_cmd, _sent, timer}} = Enum.min_by(pending, fn {_seq, {_c, sent, _t}} -> sent end)
    Process.cancel_timer(timer)
    Map.delete(pending, seq)
  end

  defp clear_pending(state) do
    Enum.each(state.pending, fn {_seq, {_cmd, _sent, timer}} -> Process.cancel_timer(timer) end)
    %{state | pending: %{}}
  end

  # ota_* wickelt BridgeUpdater selbst ab; status/peers antworten nicht mit ack.
  defp trackable?(cmd) do
    case cmd_name(cmd) do
      "ota_" <> _ -> false
      name when name in ["status", "peers", "?"] -> false
      _ -> true
    end
  end

  defp cmd_name(cmd) do
    case Map.get(cmd, :cmd) || Map.get(cmd, "cmd") do
      name when is_binary(name) -> name
      name when is_atom(name) and not is_nil(name) -> Atom.to_string(name)
      _ -> "?"
    end
  end

  defp ack_timeout_ms do
    :herz_schwarm
    |> Application.get_env(:ack_timeout_ms, @ack_timeout_default_ms)
    |> min(@ack_timeout_max_ms)
  end

  # Wertet eingehende Events fuer Metrics/EventLog aus (Broadcast passiert danach unveraendert).
  defp observe_event(%{"evt" => "ack", "seq" => seq}, state) do
    case Map.pop(state.pending, seq) do
      {{_cmd, _sent, timer}, pending} ->
        Process.cancel_timer(timer)
        Metrics.increment(:acks)
        %{state | pending: pending}

      {nil, _} ->
        state
    end
  end

  defp observe_event(%{"evt" => "err", "seq" => seq} = evt, state) do
    msg = err_text(evt)

    case Map.pop(state.pending, seq) do
      {{_cmd, _sent, timer}, pending} ->
        Process.cancel_timer(timer)
        Metrics.increment(:errors)
        EventLog.log(:error, "bridge", "err seq=#{seq}: #{msg}")
        %{state | pending: pending}

      {nil, _} ->
        # z. B. OTA (BridgeUpdater) oder verspaetet nach Timeout: nur protokollieren
        EventLog.log(:error, "bridge", "err seq=#{inspect(seq)}: #{msg}")
        state
    end
  end

  defp observe_event(%{"evt" => "err"} = evt, state) do
    Metrics.increment(:errors)
    EventLog.log(:error, "bridge", "err: #{err_text(evt)}")
    state
  end

  defp observe_event(%{"evt" => "log"} = evt, state) do
    EventLog.log(:debug, "bridge", "log: #{err_text(evt)}")
    state
  end

  defp observe_event(%{"evt" => "pong"} = pong, state) do
    attrs =
      %{uptime_s: pong["uptime"], free_heap: pong["free_heap"]}
      |> Enum.filter(fn {_k, v} -> is_integer(v) end)
      |> Map.new()

    if attrs != %{}, do: Metrics.set_bridge_state(attrs)
    state
  end

  defp observe_event(_event, state), do: state

  defp err_text(%{"msg" => msg}) when is_binary(msg), do: msg
  defp err_text(evt), do: inspect(evt)

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
