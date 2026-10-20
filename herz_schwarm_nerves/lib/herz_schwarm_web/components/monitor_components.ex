defmodule HerzSchwarmWeb.MonitorComponents do
  @moduledoc """
  Gemeinsame Darstellung und Aufbereitung für Monitoring/Diagnose
  (Dashboard und `/diagnose`). Die Daten kommen aus
  `HerzSchwarm.Metrics.snapshot/0` und `HerzSchwarm.EventLog.entries/0`;
  hier wird nur dargestellt, nicht bewertet (Ausnahme: Anzeige der Warnschwelle).
  """

  use Phoenix.Component

  @counter_fields [
    {:commands_sent, "Befehle"},
    {:acks, "Acks"},
    {:errors, "Fehler"},
    {:timeouts, "Timeouts"},
    {:triggers, "Trigger"},
    {:wave_starts, "Welle-Starts"},
    {:wave_stops, "Welle-Stopps"},
    {:identifies, "Identify"}
  ]

  @counter_keys [:reconnects | Enum.map(@counter_fields, &elem(&1, 0))]

  @level_rank %{debug: 0, info: 1, warn: 2, error: 3}
  @filter_min %{"all" => 0, "info" => 1, "warn" => 2, "error" => 3}
  @level_filters [
    {"all", "Alle"},
    {"info", "≥ Info"},
    {"warn", "≥ Warn"},
    {"error", "Nur Fehler"}
  ]

  @doc "Füllt einen (ggf. unvollständigen) Metrics-Snapshot mit Defaults auf."
  def normalize(snapshot) when is_map(snapshot) do
    counters = Map.get(snapshot, :counters) || %{}
    bridge = Map.get(snapshot, :bridge) || %{}

    %{
      counters: Map.merge(Map.new(@counter_keys, &{&1, 0}), counters),
      bridge:
        Map.merge(
          %{connected: false, port: nil, since: nil, uptime_s: nil, free_heap: nil},
          bridge
        ),
      badges: Map.get(snapshot, :badges) || %{}
    }
  end

  def normalize(_), do: normalize(%{})

  def counter_fields, do: @counter_fields
  def level_filters, do: @level_filters

  @doc """
  Warnungen für das Banner: Bridge getrennt, Badges offline, Badges unter der
  RSSI-Warnschwelle (mit MAC). Schwelle kommt aus `HerzSchwarm.Metrics`,
  `online` aus dem Snapshot (keine eigene Zeitberechnung).
  """
  def warnings(bridge_connected, metrics) do
    badges = metrics.badges
    threshold = HerzSchwarm.Metrics.rssi_warn_threshold()

    disconnected =
      if bridge_connected,
        do: [],
        else: ["Bridge ist getrennt – Befehle werden verworfen."]

    offline =
      for {mac, b} <- Enum.sort(badges), not online?(b) do
        "Badge #{mac} ist offline (zuletzt vor #{format_age(Map.get(b, :age_s))} gesehen)."
      end

    weak =
      for {mac, b} <- Enum.sort(badges),
          online?(b),
          is_integer(Map.get(b, :rssi_last)),
          b.rssi_last < threshold do
        "Badge #{mac} hat schwaches Signal: #{b.rssi_last} dBm (Schwelle #{threshold} dBm)."
      end

    disconnected ++ offline ++ weak
  end

  defp online?(b), do: Map.get(b, :online, false) == true

  @doc """
  Zeilen für die Badge-Tabelle: Vereinigung aus Snapshot-Badges und Peer-Liste
  (Peers ohne Snapshot-Eintrag gelten als online).
  """
  def badge_rows(peers, badges) do
    peer_by_mac = Map.new(peers, &{&1.mac, &1})
    macs = (Map.keys(badges) ++ Enum.map(peers, & &1.mac)) |> Enum.uniq() |> Enum.sort()

    Enum.map(macs, fn mac ->
      m = Map.get(badges, mac)
      p = Map.get(peer_by_mac, mac)

      %{
        mac: mac,
        fw: (m && Map.get(m, :fw)) || (p && Map.get(p, :fw)),
        rssi: (m && Map.get(m, :rssi_last)) || (p && Map.get(p, :rssi)),
        age_s: m && Map.get(m, :age_s),
        online: if(m, do: online?(m), else: p != nil),
        samples: (m && Map.get(m, :samples)) || [],
        stats: m
      }
    end)
  end

  @doc "Filtert Log-Einträge nach Mindest-Level (`all`, `info`, `warn`, `error`)."
  def filter_log(entries, level) do
    min = Map.get(@filter_min, level, 0)
    Enum.filter(entries, &(Map.get(@level_rank, &1.level, 0) >= min))
  end

  # --- Sparkline ---

  attr :samples, :list, default: []
  attr :width, :integer, default: 120
  attr :height, :integer, default: 28

  def sparkline(assigns) do
    assigns =
      assign(assigns, :points, sparkline_points(assigns.samples, assigns.width, assigns.height))

    ~H"""
    <svg
      :if={@points != ""}
      class="sparkline"
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      role="img"
      aria-label="RSSI-Verlauf"
    >
      <polyline fill="none" stroke="currentColor" stroke-width="1.5" points={@points} />
    </svg>
    <span :if={@points == ""} class="text-xs text-gray-600">–</span>
    """
  end

  @doc "Punkte für eine SVG-Polyline; höherer RSSI (näher) liegt weiter oben."
  def sparkline_points(samples, w, h) when is_list(samples) and samples != [] do
    n = length(samples)
    {lo, hi} = Enum.min_max(samples)
    range = max(hi - lo, 1)

    samples
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {v, i} ->
      x = if n > 1, do: i * w / (n - 1), else: w / 2
      y = (hi - v) / range * (h - 2) + 1
      "#{Float.round(x * 1.0, 1)},#{Float.round(y * 1.0, 1)}"
    end)
  end

  def sparkline_points(_samples, _w, _h), do: ""

  # --- Log ---

  attr :entries, :list, required: true
  attr :id, :string, default: "log-panel"

  def log_list(assigns) do
    ~H"""
    <ul id={@id} class="font-mono text-xs">
      <li :for={e <- @entries} class={"log-line #{level_class(e.level)}"}>
        <span class="text-gray-500 whitespace-nowrap">{format_time(e.at)}</span>
        <span class="log-level">{level_label(e.level)}</span>
        <span class="text-gray-400 whitespace-nowrap">{e.source}</span>
        <span class="break-all">{e.message}</span>
      </li>
    </ul>
    <p :if={@entries == []} class="text-sm text-gray-400">Keine Einträge.</p>
    """
  end

  def level_class(:error), do: "log-error"
  def level_class(:warn), do: "log-warn"
  def level_class(:info), do: "log-info"
  def level_class(_), do: "log-debug"

  def level_label(:error), do: "ERR"
  def level_label(:warn), do: "WARN"
  def level_label(:info), do: "INFO"
  def level_label(_), do: "DBG"

  # --- Tap-Counter ---

  attr :taps, :map, required: true

  def tap_card(assigns) do
    assigns = assign(assigns, :rows, Enum.sort_by(assigns.taps.badges, &elem(&1, 0)))

    ~H"""
    <div id="tap-card">
      <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
        <div>
          <p class="text-sm text-gray-400">Taps gesamt</p>
          <p id="tap-total" class="text-4xl font-mono font-bold">{@taps.total}</p>
        </div>
        <button
          id="tap-reset"
          class="btn btn-stop"
          phx-click="tap-reset"
          data-confirm="Alle Tap-Zähler auf 0 setzen? Die Badges zählen danach ab 0 weiter."
        >
          Zähler zurücksetzen
        </button>
      </div>
      <p :if={@rows == []} id="tap-empty" class="text-sm text-gray-400">Noch keine Taps.</p>
      <div :if={@rows != []} class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-gray-400">
              <th class="py-1">MAC</th>
              <th>Stand</th>
              <th>Letzter Tap (UTC)</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{mac, b} <- @rows} id={"tap-#{mac}"} class="border-t border-gray-800">
              <td class="py-1 font-mono whitespace-nowrap">{mac}</td>
              <td class="font-mono text-lg">{b.count}</td>
              <td class="font-mono text-xs text-gray-400 whitespace-nowrap">
                {format_datetime(b.last_seen)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # --- Formatierung ---

  def format_duration(s) when is_integer(s) and s >= 0 do
    h = div(s, 3600)
    m = div(rem(s, 3600), 60)
    sec = rem(s, 60)

    cond do
      h > 0 -> "#{h} h #{m} min"
      m > 0 -> "#{m} min #{sec} s"
      true -> "#{sec} s"
    end
  end

  def format_duration(_), do: "–"

  def format_age(s) when is_integer(s), do: "#{s} s"
  def format_age(_), do: "–"

  def format_heap(b) when is_integer(b), do: "#{div(b, 1024)} KB"
  def format_heap(_), do: "–"

  def format_rssi(v) when is_integer(v), do: "#{v} dBm"
  def format_rssi(_), do: "–"

  def format_avg(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 1)
  def format_avg(v) when is_integer(v), do: Integer.to_string(v)
  def format_avg(_), do: "–"

  def format_time(%DateTime{} = t), do: Calendar.strftime(t, "%H:%M:%S")
  def format_time(_), do: "–"

  def format_datetime(%DateTime{} = t), do: Calendar.strftime(t, "%d.%m.%Y %H:%M:%S")
  def format_datetime(_), do: "–"

  @doc "Tooltip mit min/Ø/max für eine Badge-Metrik."
  def stats_title(%{rssi_min: lo, rssi_max: hi} = stats) do
    "min #{format_rssi(lo)} · Ø #{format_avg(Map.get(stats, :rssi_avg))} dBm · max #{format_rssi(hi)}"
  end

  def stats_title(_), do: "keine Messwerte"
end
