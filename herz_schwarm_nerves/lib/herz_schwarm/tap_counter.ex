defmodule HerzSchwarm.TapCounter do
  @moduledoc """
  Tap-Zaehler je Badge (Tap-Counter-Modus der Badge-FW).

  Die Bridge meldet pro Tap den neuen Hoechststand des Badges:

      {:bridge, %{"evt" => "tap", "mac" => "AA:BB:CC:DD:EE:FF", "count" => 123}}

  ## Merge

  Die Rohzaehler sind monoton. Je MAC wird deshalb ueber das **Maximum**
  gemerged: ein hoeherer Wert gewinnt, niedrigere/gleiche Werte (Doppelmeldungen,
  Weiterleitungen) werden ignoriert. `count` 0 wird ignoriert.

  Nur `AA:BB:CC:DD:EE:FF` (sechs Hex-Oktette mit Doppelpunkt, case-insensitiv)
  wird akzeptiert und kanonisiert (Grossbuchstaben). Andere Werte werden ignoriert
  und hoechstens einmal pro Sekunde im `EventLog` protokolliert.

  ## Reset-Offsets

  `reset/0` setzt keine Rohstaende zurueck, sondern merkt je MAC einen
  **Offset** (aktueller Rohstand). Angezeigt wird `raw - offset`. Weitere Taps
  zaehlen ab 0 weiter. `reset/0` setzt zusaetzlich `retired_total` auf 0.

  ## Gesamtsumme und Speicherlimit (High-Water-Mark)

  `total` ist die Summe der angezeigten Staende **aller** Badges seit dem letzten
  Reset, auch derer, die das 64er-Limit verdraengt hat. Wird ein Badge verdraengt,
  wandert sein angezeigter Stand (`raw - offset`) in das persistente Aggregat
  `retired_total`; zusaetzlich merkt sich `retired` den Rohstand dieses Badges.
  Meldet sich ein verdraengtes Badge wieder, startet es mit Offset = dem gemerkten
  Rohstand: nur Taps seit dem Verdraengen zaehlen, nichts doppelt. Die Gesamtsumme
  sinkt dadurch nie durch das Limit.

  Folge: `retired` waechst mit der Anzahl je gesehener, aber verdraengter MACs
  (ein Eintrag pro MAC, bis es sich wieder meldet oder ein Reset erfolgt).

  ## Zustand (`state/0`)

      %{total: integer,
        badges: %{mac => %{count: integer, last_seen: DateTime.t | nil}},
        updated_at: DateTime.t | nil}

  `total` = `retired_total` + Summe der `count` der aktuellen Badges.
  `count` ist der **angezeigte** Stand. `last_seen` ist der Zeitpunkt des
  letzten Taps (Anstieg des Rohstands); `nil` nur bei defekt gelesenen Daten.

  ## Persistenz

  JSON-Datei unter `:tap_store_path` (Default `~/.local/share/herz-schwarm/taps.json`,
  `nil` = keine Persistenz). Format (`version` 1): `badges` wie oben
  (`raw`, `offset`, `last_seen`), zusaetzlich `retired_total` (Integer) und
  `retired` (`mac => raw`). Fehlen die beiden Felder (aeltere Dateien), gelten
  `0` bzw. `%{}`. Laden beim Start: fehlt die Datei oder ist sie
  kaputt, startet der Zaehler leer (Warnung im Log, kein Crash). Geschrieben wird
  gedrosselt (hoechstens alle 5 s, nur bei Aenderung) und in `terminate/2`,
  atomar ueber Temp-Datei + Rename. Schreibfehler werden geloggt; der naechste
  Versuch erfolgt nach 60 s.

  ## Publikation

  `{:taps, state}` auf `"taps:state"`, hoechstens alle 500 ms; die letzte
  Aenderung geht immer raus.

  ## Speicher

  Hoechstens 64 MACs in `badges`; bei Ueberlauf fliegt das am laengsten nicht
  gesehene Badge heraus (Stand wandert nach `retired_total`, siehe oben).

  ## Meilensteine

  Statt eines Metrics-Zaehlers (Doppelmeldungen wuerden ihn verfaelschen)
  protokolliert der Zaehler im `HerzSchwarm.EventLog` je 100 Taps eines Badges.
  """

  use GenServer
  require Logger

  alias HerzSchwarm.EventLog

  @pubsub HerzSchwarm.PubSub
  @bridge_topic "bridge:events"
  @topic "taps:state"
  @save_interval_ms 5_000
  @save_retry_ms 60_000
  @publish_interval_ms 500
  @max_badges 64
  @milestone 100
  @invalid_log_interval_ms 1_000
  @default_path "~/.local/share/herz-schwarm/taps.json"

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def topic, do: @topic

  @doc "Aktueller angezeigter Zustand (siehe Moduldoku)."
  def state(server \\ __MODULE__), do: GenServer.call(server, :state)

  @doc "Setzt die angezeigten Staende auf 0 (Rohstaende bleiben als Offset erhalten)."
  def reset(server \\ __MODULE__), do: GenServer.call(server, :reset)

  @doc "Standardpfad der Persistenz-Datei (Config `:tap_store_path`)."
  def store_path do
    case Application.get_env(:herz_schwarm, :tap_store_path, @default_path) do
      nil -> nil
      path -> Path.expand(path)
    end
  end

  # --- Callbacks ---

  @impl true
  def init(opts) do
    # Damit terminate/2 bei Shutdown durch den Supervisor den Stand schreibt.
    Process.flag(:trap_exit, true)
    Phoenix.PubSub.subscribe(@pubsub, @bridge_topic)

    path = Keyword.get_lazy(opts, :path, &store_path/0)
    now = mono()

    state =
      %{
        path: path,
        dirty: false,
        invalid_warn_at: nil,
        save_interval_ms: Keyword.get(opts, :save_interval_ms, @save_interval_ms),
        publish_interval_ms: Keyword.get(opts, :publish_interval_ms, @publish_interval_ms),
        last_save: now - Keyword.get(opts, :save_interval_ms, @save_interval_ms),
        save_timer: nil,
        last_pub: now - Keyword.get(opts, :publish_interval_ms, @publish_interval_ms),
        publish_timer: nil
      }
      |> Map.merge(load(path))
      |> trim()

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, view(state), state}

  def handle_call(:reset, _from, state) do
    badges = Map.new(state.badges, fn {mac, b} -> {mac, %{b | offset: b.raw}} end)
    {:reply, :ok, changed(%{state | badges: badges, retired_total: 0})}
  end

  @impl true
  def handle_info({:bridge, %{"evt" => "tap", "mac" => mac, "count" => n}}, state)
      when is_binary(mac) and is_integer(n) and n > 0 do
    case canonical_mac(mac) do
      {:ok, canon} -> {:noreply, merge(state, canon, n)}
      :error -> {:noreply, reject_mac(state, mac)}
    end
  end

  def handle_info({:bridge, _event}, state), do: {:noreply, state}

  def handle_info(:publish, state), do: {:noreply, publish(%{state | publish_timer: nil})}

  def handle_info(:save, state), do: {:noreply, save(%{state | save_timer: nil})}

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    save(state)
    :ok
  end

  # --- Merge & Reset ---

  defp merge(state, mac, n) do
    # Ein verdraengtes Badge startet ab seinem gemerkten Rohstand (kein Doppelzaehlen).
    {old, offset} =
      case Map.fetch(state.badges, mac) do
        {:ok, b} ->
          {b.raw, b.offset}

        :error ->
          base = Map.get(state.retired, mac, 0)
          {base, base}
      end

    if n > old do
      badge = %{raw: n, offset: offset, last_seen: DateTime.utc_now()}
      log_milestone(mac, old, n)

      state
      |> Map.merge(%{
        badges: Map.put(state.badges, mac, badge),
        retired: Map.delete(state.retired, mac)
      })
      |> trim()
      |> changed()
    else
      state
    end
  end

  defp log_milestone(mac, old, n) do
    if div(n, @milestone) > div(old, @milestone) do
      EventLog.log(:info, "tap", "Badge #{mac}: #{div(n, @milestone) * @milestone} Taps erreicht")
    end
  end

  # Speicher begrenzen: das am laengsten nicht gesehene Badge verdraengen. Sein
  # angezeigter Stand wandert in retired_total, sein Rohstand in retired.
  defp trim(%{badges: badges} = state) when map_size(badges) <= @max_badges, do: state

  defp trim(%{badges: badges} = state) do
    {oldest, b} = Enum.min_by(badges, fn {_mac, b} -> sortable(b.last_seen) end)

    trim(%{
      state
      | badges: Map.delete(badges, oldest),
        retired_total: state.retired_total + b.raw - b.offset,
        retired: Map.put(state.retired, oldest, b.raw)
    })
  end

  defp sortable(nil), do: 0
  defp sortable(%DateTime{} = dt), do: DateTime.to_unix(dt, :microsecond)

  defp changed(state) do
    state
    |> Map.put(:dirty, true)
    |> Map.put(:updated_at, DateTime.utc_now())
    |> mark_publish()
    |> mark_save()
  end

  defp view(state) do
    badges =
      Map.new(state.badges, fn {mac, b} ->
        {mac, %{count: b.raw - b.offset, last_seen: b.last_seen}}
      end)

    current = badges |> Map.values() |> Enum.map(& &1.count) |> Enum.sum()
    %{total: state.retired_total + current, badges: badges, updated_at: state.updated_at}
  end

  # Ungueltige MAC: ignorieren, Protokoll hoechstens einmal pro Sekunde.
  defp reject_mac(state, mac) do
    now = mono()

    if state.invalid_warn_at == nil or now - state.invalid_warn_at >= @invalid_log_interval_ms do
      EventLog.log(:warn, "tap", "Ungueltige MAC ignoriert: #{inspect(String.slice(mac, 0, 40))}")
      %{state | invalid_warn_at: now}
    else
      state
    end
  end

  defp canonical_mac(mac) when is_binary(mac) do
    if Regex.match?(~r/\A[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}\z/, mac),
      do: {:ok, String.upcase(mac)},
      else: :error
  end

  defp canonical_mac(_mac), do: :error

  # --- Publikation (Drosselung wie HerzSchwarm.Metrics) ---

  defp mark_publish(%{publish_timer: nil} = state) do
    elapsed = mono() - state.last_pub

    if elapsed >= state.publish_interval_ms do
      publish(state)
    else
      timer = Process.send_after(self(), :publish, state.publish_interval_ms - elapsed)
      %{state | publish_timer: timer}
    end
  end

  defp mark_publish(state), do: state

  defp publish(state) do
    cancel(state.publish_timer)
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:taps, view(state)})
    %{state | publish_timer: nil, last_pub: mono()}
  end

  # --- Persistenz ---

  # Gedrosselt: sofort, wenn die letzte Speicherung lange her ist, sonst einmalig nachlaufend.
  defp mark_save(%{path: nil} = state), do: state

  defp mark_save(%{save_timer: nil} = state) do
    elapsed = mono() - state.last_save

    if elapsed >= state.save_interval_ms do
      save(state)
    else
      timer = Process.send_after(self(), :save, state.save_interval_ms - elapsed)
      %{state | save_timer: timer}
    end
  end

  defp mark_save(state), do: state

  defp save(%{dirty: false} = state), do: state
  defp save(%{path: nil} = state), do: %{state | dirty: false}

  defp save(state) do
    cancel(state.save_timer)
    now = mono()

    case write_store(state.path, state) do
      :ok ->
        %{state | dirty: false, save_timer: nil, last_save: now}

      {:error, reason} ->
        Logger.warning(
          "TapCounter: Speichern nach #{state.path} fehlgeschlagen: #{inspect(reason)}"
        )

        timer = Process.send_after(self(), :save, @save_retry_ms)
        %{state | save_timer: timer, last_save: now}
    end
  end

  defp write_store(path, state) do
    badges =
      Map.new(state.badges, fn {mac, b} ->
        {mac, %{"raw" => b.raw, "offset" => b.offset, "last_seen" => iso(b.last_seen)}}
      end)

    body =
      Jason.encode!(%{
        "version" => 1,
        "updated_at" => iso(state.updated_at),
        "badges" => badges,
        "retired_total" => state.retired_total,
        "retired" => state.retired
      })

    tmp = path <> ".tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(tmp, body) do
      File.rename(tmp, path)
    end
  end

  # Liefert die geladenen Felder (ohne trim; der Aufrufer trimmt).
  defp load(nil), do: empty_store()

  defp load(path) do
    with {:ok, bin} <- File.read(path),
         {:ok, %{"badges" => badges} = data} when is_map(badges) <- Jason.decode(bin) do
      %{
        badges: parse_badges(badges),
        updated_at: parse_time(data["updated_at"]),
        retired_total: parse_retired_total(data["retired_total"]),
        retired: parse_retired(data["retired"])
      }
    else
      {:error, :enoent} ->
        empty_store()

      other ->
        Logger.warning("TapCounter: #{path} nicht lesbar, starte leer (#{inspect(other)})")
        empty_store()
    end
  end

  defp empty_store do
    %{badges: %{}, updated_at: nil, retired_total: 0, retired: %{}}
  end

  defp parse_badges(map) do
    for {mac, %{"raw" => raw} = b} <- map,
        is_integer(raw),
        raw > 0,
        {:ok, canon} <- [canonical_mac(mac)],
        into: %{} do
      offset = if is_integer(b["offset"]) and b["offset"] in 0..raw, do: b["offset"], else: 0
      {canon, %{raw: raw, offset: offset, last_seen: parse_time(b["last_seen"])}}
    end
  end

  # Fehlt das Feld (aeltere Dateien) oder ist es defekt, gilt 0.
  defp parse_retired_total(n) when is_integer(n) and n >= 0, do: n
  defp parse_retired_total(_), do: 0

  defp parse_retired(map) when is_map(map) do
    for {mac, raw} <- map,
        is_integer(raw),
        raw > 0,
        {:ok, canon} <- [canonical_mac(mac)],
        into: %{} do
      {canon, raw}
    end
  end

  defp parse_retired(_), do: %{}

  defp parse_time(s) when is_binary(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_time(_), do: nil

  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp iso(nil), do: nil

  # --- intern ---

  defp mono, do: System.monotonic_time(:millisecond)

  defp cancel(nil), do: :ok
  defp cancel(timer), do: Process.cancel_timer(timer)
end
