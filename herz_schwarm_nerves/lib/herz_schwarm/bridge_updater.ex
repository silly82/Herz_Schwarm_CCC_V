defmodule HerzSchwarm.BridgeUpdater do
  @moduledoc """
  Spielt eine neue ESP32-Bridge-Firmware (`.bin`, App-Image) ueber die
  bestehende UART-Verbindung ein (UART-OTA, kein WLAN, kein esptool).

  Ablauf (strikt sequenziell, immer hoechstens ein offenes Kommando):

      ota_begin -> ota_chunk (off=0) -> ota_chunk (off=96) -> ... -> ota_end

  Jedes Kommando wird erst nach dem passenden `ack` (Match ueber `seq` auf
  `"bridge:events"`) fortgesetzt. Ein `err` mit passender `seq` bricht das Update
  sofort ab. Bleibt ein Chunk-Ack aus (1000 ms), wird derselbe Chunk bis zu
  3-mal wiederholt (die Bridge bestaetigt eine Wiederholung idempotent), danach
  `ota_abort` + Fehlerzustand. `ota_begin` (Flash-Slot loeschen) und `ota_end`
  (Image-Pruefung) dauern laenger und haben eigene Timeouts ohne Wiederholung.

  Nach dem `ota_end`-Ack startet die Bridge neu; das `Bridge`-Modul verbindet
  sich ueber seine normale Reconnect-Logik wieder.

  Fortschritt wird gedrosselt auf `"bridge:update"` veroeffentlicht:
  `{:bridge_update, %{state:, phase:, offset:, size:, percent:, error:}}`.
  """

  use GenServer
  require Logger

  alias HerzSchwarm.Bridge

  @pubsub HerzSchwarm.PubSub
  @events_topic "bridge:events"
  @topic "bridge:update"

  # Chunk: 96 Rohbytes -> 128 Base64-Zeichen -> Zeile ~190 Byte (Firmware: lineBuf 256).
  @chunk_bytes 96
  # lineBuf[256] der Firmware: maximal 255 Zeichen je Zeile (ohne "\n").
  @max_line_bytes 255
  @max_seq 4_294_967_295
  @max_image_bytes 2 * 1024 * 1024
  # Erstes Byte eines ESP-App-Images (ESP_IMAGE_HEADER_MAGIC)
  @image_magic 0xE9

  @defaults %{
    chunk_timeout_ms: 1_000,
    chunk_retries: 3,
    begin_timeout_ms: 20_000,
    end_timeout_ms: 20_000,
    total_timeout_ms: 600_000,
    publish_interval_ms: 100,
    publish_bytes: 100_000
  }

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def topic, do: @topic

  @doc """
  Startet ein Update aus einer `.bin`-Datei. Optionen: `:server`, `:ver`
  (angekuendigte Version, nur informativ fuer die Bridge).
  """
  def begin_update(bin_path, opts \\ []) do
    GenServer.call(server(opts), {:begin_update, bin_path, opts[:ver]}, 30_000)
  end

  @doc "Bricht ein laufendes Update ab (`ota_abort`)."
  def cancel(opts \\ []), do: GenServer.call(server(opts), :cancel)

  @doc "Aktueller Zustand: `%{state:, phase:, size:, offset:, error:, started_at:, ref:}`."
  def state(opts \\ []), do: GenServer.call(server(opts), :state)

  defp server(opts), do: Keyword.get(opts, :server, __MODULE__)

  # --- Reine Hilfsfunktionen (ohne Hardware testbar) ---

  @doc """
  Der `ota_chunk`-Befehl fuer `size` Rohbytes ab `offset` (ohne `seq`, die vergibt `Bridge`).
  """
  def chunk_command(data, offset, size) when is_binary(data) do
    %{cmd: "ota_chunk", off: offset, data: data |> binary_part(offset, size) |> Base.encode64()}
  end

  @doc """
  Zeilenlaenge (Bytes ohne `\\n`), die dieses Kommando auf dem Draht haette,
  mit Worst-Case-`seq` (10 Stellen).
  """
  def wire_length(cmd) do
    cmd |> Map.put(:seq, @max_seq) |> Jason.encode!() |> byte_size()
  end

  @doc """
  Groesste Chunk-Groesse <= `requested` (in 3-Byte-Schritten), bei der auch der
  letzte Offset (`image_size`) noch in `#{@max_line_bytes}` Zeichen passt.
  """
  def fit_chunk_bytes(requested, image_size) do
    worst = :binary.copy(<<0xFF>>, requested)

    do_fit(
      requested,
      wire_length(%{cmd: "ota_chunk", off: image_size, data: Base.encode64(worst)})
    )
  end

  defp do_fit(size, len) when len <= @max_line_bytes or size <= 3, do: size

  defp do_fit(size, len) do
    # 3 Rohbytes = 4 Base64-Zeichen
    do_fit(size - 3, len - 4)
  end

  @doc "Alle Chunks eines Images als `{offset, laenge}` (lueckenlos, letzter ggf. kuerzer)."
  def chunk_plan(image_size, chunk_bytes) do
    0
    |> Stream.iterate(&(&1 + chunk_bytes))
    |> Enum.take_while(&(&1 < image_size))
    |> Enum.map(&{&1, min(chunk_bytes, image_size - &1)})
  end

  # --- Callbacks ---

  @impl true
  def init(opts) do
    Phoenix.PubSub.subscribe(@pubsub, @events_topic)

    cfg =
      @defaults
      |> Map.merge(Map.new(Keyword.take(opts, Map.keys(@defaults))))
      |> Map.put(:sender, Keyword.get(opts, :sender, &Bridge.send_command/1))
      |> Map.put(:chunk_bytes, Keyword.get(opts, :chunk_bytes, @chunk_bytes))

    {:ok, Map.merge(idle(), %{cfg: cfg})}
  end

  @impl true
  def handle_call(:state, _from, st), do: {:reply, public_state(st), st}

  def handle_call({:begin_update, path, ver}, _from, st) do
    with :ok <- ensure_not_running(st),
         {:ok, data} <- read_image(path),
         size = byte_size(data),
         begin_cmd =
           Map.merge(%{cmd: "ota_begin", size: size}, if(ver, do: %{ver: ver}, else: %{})),
         {:ok, seq} <- send_command(st, begin_cmd) do
      ref = make_ref()
      now = now_ms()

      st =
        %{
          st
          | status: :running,
            phase: :begin,
            ref: ref,
            data: data,
            size: size,
            offset: 0,
            error: nil,
            started_at: DateTime.utc_now(),
            chunk_bytes: fit_chunk_bytes(st.cfg.chunk_bytes, size),
            cur: 0,
            seqs: [seq],
            attempts: 0,
            last_pub_at: now,
            last_pub_offset: 0
        }
        |> arm_timer(st.cfg.begin_timeout_ms)
        |> arm_total_timer()

      publish(st)
      {:reply, {:ok, ref}, st}
    else
      {:error, reason} -> {:reply, {:error, reason}, st}
    end
  end

  def handle_call(:cancel, _from, %{status: :running} = st) do
    send_abort(st)
    st = st |> cancel_timers() |> reset_to_idle()
    publish(st)
    {:reply, :ok, st}
  end

  def handle_call(:cancel, _from, st), do: {:reply, {:error, :not_running}, st}

  @impl true
  def handle_info({:bridge, %{"evt" => "ack", "seq" => seq}}, %{status: :running} = st) do
    if seq in st.seqs, do: {:noreply, on_ack(st)}, else: {:noreply, st}
  end

  def handle_info({:bridge, %{"evt" => "err", "seq" => seq} = evt}, %{status: :running} = st) do
    if seq in st.seqs do
      {:noreply, fail(st, "Bridge: #{evt["msg"] || "unbekannter Fehler"}", true)}
    else
      {:noreply, st}
    end
  end

  # Erfolg nur mit ota_end-Ack (kommt vor dem Neustart der Bridge). Bricht die
  # Verbindung vorher ab, ist unklar, ob das Update angenommen wurde -> Fehler.
  def handle_info({:bridge, :disconnected}, %{status: :running, phase: :end} = st) do
    {:noreply,
     fail(
       st,
       "Bridge hat den Abschluss nicht bestätigt — Version nach Wiederverbindung prüfen",
       false
     )}
  end

  def handle_info({:bridge, :disconnected}, %{status: :running} = st) do
    {:noreply, fail(st, "Bridge-Verbindung getrennt", false)}
  end

  def handle_info({:step_timeout, token}, %{status: :running, timer: {token, _}} = st) do
    {:noreply, on_step_timeout(st)}
  end

  def handle_info({:total_timeout, ref}, %{status: :running, ref: ref} = st) do
    {:noreply, fail(st, "Gesamt-Timeout (#{div(st.cfg.total_timeout_ms, 60_000)} min)", true)}
  end

  def handle_info(_msg, st), do: {:noreply, st}

  # --- Zustandsautomat ---

  defp on_ack(%{phase: :begin} = st), do: send_next_chunk(st)

  defp on_ack(%{phase: :chunk} = st) do
    st = %{st | offset: st.offset + st.cur} |> maybe_publish()

    if st.offset >= st.size do
      case send_command(st, %{cmd: "ota_end"}) do
        {:ok, seq} ->
          %{st | phase: :end, seqs: [seq], attempts: 0}
          |> arm_timer(st.cfg.end_timeout_ms)
          |> tap(&publish(&1))

        {:error, reason} ->
          fail(st, "ota_end nicht gesendet: #{inspect(reason)}", true)
      end
    else
      send_next_chunk(st)
    end
  end

  defp on_ack(%{phase: :end} = st), do: finish(st)

  defp send_next_chunk(st) do
    cur = min(st.chunk_bytes, st.size - st.offset)

    case send_command(st, chunk_command(st.data, st.offset, cur)) do
      {:ok, seq} ->
        %{st | phase: :chunk, cur: cur, seqs: [seq], attempts: 0}
        |> arm_timer(st.cfg.chunk_timeout_ms)

      {:error, reason} ->
        fail(st, "Chunk bei Offset #{st.offset} nicht gesendet: #{inspect(reason)}", true)
    end
  end

  defp on_step_timeout(%{phase: :chunk} = st) do
    if st.attempts < st.cfg.chunk_retries do
      case send_command(st, chunk_command(st.data, st.offset, st.cur)) do
        {:ok, seq} ->
          Logger.debug("BridgeUpdater: Chunk @#{st.offset} Wiederholung #{st.attempts + 1}")

          %{st | seqs: [seq | st.seqs], attempts: st.attempts + 1}
          |> arm_timer(st.cfg.chunk_timeout_ms)

        {:error, reason} ->
          fail(st, "Chunk bei Offset #{st.offset} nicht gesendet: #{inspect(reason)}", true)
      end
    else
      fail(
        st,
        "Timeout bei Offset #{st.offset} nach #{st.cfg.chunk_retries} Wiederholungen",
        true
      )
    end
  end

  defp on_step_timeout(%{phase: :begin} = st),
    do: fail(st, "Timeout beim Start (ota_begin)", true)

  defp on_step_timeout(%{phase: :end} = st),
    do: fail(st, "Timeout beim Abschluss (ota_end)", true)

  defp finish(st) do
    st = st |> cancel_timers() |> Map.merge(%{status: :done, phase: nil, offset: st.size})
    Logger.info("BridgeUpdater: #{st.size} Bytes uebertragen, Bridge startet neu")
    publish(st)
    %{st | data: nil, seqs: []}
  end

  defp fail(st, reason, abort?) do
    Logger.warning("BridgeUpdater: #{reason}")
    if abort?, do: send_abort(st)
    st = st |> cancel_timers() |> Map.merge(%{status: :error, phase: nil, error: reason})
    publish(st)
    %{st | data: nil, seqs: []}
  end

  defp reset_to_idle(st), do: Map.merge(st, Map.drop(idle(), [:cfg]))

  # ota_abort ist best effort: kein Warten auf das Ack
  defp send_abort(st), do: send_command(st, %{cmd: "ota_abort"})

  defp ensure_not_running(%{status: :running}), do: {:error, :busy}
  defp ensure_not_running(_st), do: :ok

  defp read_image(path) do
    case File.read(path) do
      {:ok, <<>>} -> {:error, :empty_image}
      {:ok, data} when byte_size(data) > @max_image_bytes -> {:error, :image_too_large}
      {:ok, <<@image_magic, _::binary>> = data} -> {:ok, data}
      {:ok, _} -> {:error, :not_an_esp_image}
      {:error, reason} -> {:error, {:read_failed, reason}}
    end
  end

  defp send_command(st, cmd) do
    # Nie eine Zeile senden, die die Firmware mit "cmd too long" verwerfen wuerde.
    if wire_length(cmd) > @max_line_bytes do
      {:error, :line_too_long}
    else
      st.cfg.sender.(cmd)
    end
  end

  # --- Timer ---

  defp arm_timer(st, ms) do
    cancel_step_timer(st)
    token = make_ref()
    tref = Process.send_after(self(), {:step_timeout, token}, ms)
    %{st | timer: {token, tref}}
  end

  defp arm_total_timer(st) do
    tref = Process.send_after(self(), {:total_timeout, st.ref}, st.cfg.total_timeout_ms)
    %{st | total_timer: tref}
  end

  defp cancel_step_timer(%{timer: {_, tref}}), do: Process.cancel_timer(tref)
  defp cancel_step_timer(_), do: :ok

  defp cancel_timers(st) do
    cancel_step_timer(st)
    if st.total_timer, do: Process.cancel_timer(st.total_timer)
    %{st | timer: nil, total_timer: nil}
  end

  # --- Zustand & Publish ---

  defp idle do
    %{
      status: :idle,
      phase: nil,
      ref: nil,
      data: nil,
      size: 0,
      offset: 0,
      error: nil,
      started_at: nil,
      chunk_bytes: @chunk_bytes,
      cur: 0,
      seqs: [],
      attempts: 0,
      timer: nil,
      total_timer: nil,
      last_pub_at: 0,
      last_pub_offset: 0,
      cfg: nil
    }
  end

  defp public_state(st) do
    %{
      state: st.status,
      phase: st.phase,
      size: st.size,
      offset: st.offset,
      error: st.error,
      started_at: st.started_at,
      ref: st.ref
    }
  end

  defp maybe_publish(st) do
    now = now_ms()

    if now - st.last_pub_at >= st.cfg.publish_interval_ms or
         st.offset - st.last_pub_offset >= st.cfg.publish_bytes do
      publish(st)
      %{st | last_pub_at: now, last_pub_offset: st.offset}
    else
      st
    end
  end

  # Ungedrosselt; gedrosselt wird in maybe_publish/1 (Fortschritt), Zustandswechsel immer.
  defp publish(st) do
    payload = %{
      state: st.status,
      phase: st.phase,
      offset: st.offset,
      size: st.size,
      percent: percent(st),
      error: st.error
    }

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:bridge_update, payload})
  end

  defp percent(%{status: :done}), do: 100
  defp percent(%{size: 0}), do: 0
  defp percent(st), do: div(st.offset * 100, st.size)

  defp now_ms, do: System.monotonic_time(:millisecond)
end
