defmodule HerzSchwarmWeb.DiagnoseLive do
  @moduledoc """
  Diagnose-Seite: Bridge-Zustand, Zähler (mit Reset), vollständiges Log
  (Level-Filter, Leeren) und Badge-Metriken.
  """

  use HerzSchwarmWeb, :live_view

  alias HerzSchwarm.{Bridge, Metrics, EventLog}
  alias HerzSchwarmWeb.MonitorComponents

  @log_limit 200

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "metrics:state")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "eventlog")
    end

    socket =
      socket
      |> assign(
        metrics: MonitorComponents.normalize(Metrics.snapshot()),
        log: EventLog.entries() |> Enum.take(@log_limit),
        level_filter: "all",
        reset_msg: nil,
        poll_msg: nil
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:visible_log, MonitorComponents.filter_log(assigns.log, assigns.level_filter))
      |> assign(:badge_rows, MonitorComponents.badge_rows([], assigns.metrics.badges))
      |> assign(:counter_fields, MonitorComponents.counter_fields())
      |> assign(:level_filters, MonitorComponents.level_filters())

    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <header class="flex flex-wrap items-center justify-between gap-3 mb-6">
        <h1 class="text-2xl font-bold text-pink-400">&#x1F9EA; Diagnose</h1>
        <.link navigate={~p"/"} id="back-link" class="badge badge-info">&larr; Dashboard</.link>
      </header>

      <div class="card mb-6">
        <h2>&#x1F50C; Bridge</h2>
        <dl class="grid grid-cols-2 sm:grid-cols-3 gap-3 text-sm">
          <div>
            <dt class="text-gray-400">Zustand</dt>
            <dd
              id="bridge-state"
              class={if @metrics.bridge.connected, do: "text-green-400", else: "text-red-400"}
            >
              {if @metrics.bridge.connected, do: "verbunden", else: "getrennt"}
            </dd>
          </div>
          <div>
            <dt class="text-gray-400">Port</dt>
            <dd id="bridge-port" class="font-mono">{@metrics.bridge.port || "–"}</dd>
          </div>
          <div>
            <dt class="text-gray-400">Verbunden seit</dt>
            <dd id="bridge-since" class="font-mono">
              {MonitorComponents.format_datetime(@metrics.bridge.since)}
            </dd>
          </div>
          <div>
            <dt class="text-gray-400">Uptime</dt>
            <dd id="bridge-uptime" class="font-mono">
              {MonitorComponents.format_duration(@metrics.bridge.uptime_s)}
            </dd>
          </div>
          <div>
            <dt class="text-gray-400">Freier Heap</dt>
            <dd id="bridge-heap" class="font-mono">
              {MonitorComponents.format_heap(@metrics.bridge.free_heap)}
            </dd>
          </div>
          <div>
            <dt class="text-gray-400">Reconnects</dt>
            <dd id="bridge-reconnects" class="font-mono">{@metrics.counters.reconnects}</dd>
          </div>
        </dl>
        <div class="flex flex-wrap items-center gap-3 mt-4">
          <button id="poll-status" class="btn btn-go btn-effect" phx-click="poll-status">
            Status jetzt abfragen
          </button>
          <span :if={@poll_msg} id="poll-msg" class="text-sm text-gray-400">{@poll_msg}</span>
        </div>
      </div>

      <div class="card mb-6">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
          <h2 class="mb-0">&#x1F4CA; Zähler</h2>
          <button
            id="reset-counters"
            class="btn btn-stop btn-effect"
            phx-click="reset-counters"
            data-confirm="Alle Zähler auf 0 zurücksetzen?"
          >
            Zähler zurücksetzen
          </button>
        </div>
        <table class="w-full text-sm">
          <tbody>
            <tr :for={{key, label} <- @counter_fields} class="border-t border-gray-800">
              <td class="py-1 text-gray-400">{label}</td>
              <td class="font-mono text-right">{@metrics.counters[key]}</td>
            </tr>
          </tbody>
        </table>
        <p :if={@reset_msg} id="reset-msg" class="text-sm text-gray-400 mt-2">{@reset_msg}</p>
      </div>

      <div class="card mb-6">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
          <h2 class="mb-0">&#x1F4CB; Log (letzte 200 Einträge)</h2>
          <div class="flex flex-wrap items-center gap-2">
            <button
              :for={{level, label} <- @level_filters}
              id={"level-#{level}"}
              class={"btn btn-effect #{if level == @level_filter, do: "btn-ambient", else: "btn-stop"}"}
              phx-click="set-level"
              phx-value-level={level}
            >
              {label}
            </button>
            <button
              id="clear-log"
              class="btn btn-stop btn-effect"
              phx-click="clear-log"
              data-confirm="Log wirklich leeren?"
            >
              Log leeren
            </button>
          </div>
        </div>
        <div class="log-scroll">
          <MonitorComponents.log_list entries={@visible_log} id="diagnose-log" />
        </div>
      </div>

      <div class="card mb-6">
        <h2>&#x1F50E; Badge-Metriken</h2>
        <p :if={@badge_rows == []} class="text-sm text-gray-400">Keine Badge-Daten vorhanden.</p>
        <div :if={@badge_rows != []} class="overflow-x-auto">
          <table id="badge-metrics" class="w-full text-sm">
            <thead>
              <tr class="text-left text-gray-400">
                <th class="py-1">MAC</th>
                <th>FW</th>
                <th>Last</th>
                <th>Min</th>
                <th>Ø</th>
                <th>Max</th>
                <th>Alter</th>
                <th>Status</th>
                <th>Verlauf</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={r <- @badge_rows}
                id={"badge-#{r.mac}"}
                class={"border-t border-gray-800 #{if !r.online, do: "row-offline"}"}
              >
                <td class="py-1 font-mono whitespace-nowrap">{r.mac}</td>
                <td class="font-mono">{r.fw || "–"}</td>
                <td class="font-mono whitespace-nowrap">{MonitorComponents.format_rssi(r.rssi)}</td>
                <td class="font-mono whitespace-nowrap">
                  {MonitorComponents.format_rssi(r.stats && Map.get(r.stats, :rssi_min))}
                </td>
                <td class="font-mono whitespace-nowrap">
                  {MonitorComponents.format_avg(r.stats && Map.get(r.stats, :rssi_avg))}
                </td>
                <td class="font-mono whitespace-nowrap">
                  {MonitorComponents.format_rssi(r.stats && Map.get(r.stats, :rssi_max))}
                </td>
                <td class="font-mono whitespace-nowrap">{MonitorComponents.format_age(r.age_s)}</td>
                <td class="whitespace-nowrap">{if r.online, do: "online", else: "offline"}</td>
                <td>
                  <MonitorComponents.sparkline samples={r.samples} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  # --- Events ---

  @impl true
  def handle_event("reset-counters", _, socket) do
    Metrics.reset_counters()

    {:noreply,
     assign(socket,
       metrics: MonitorComponents.normalize(Metrics.snapshot()),
       reset_msg: "Zähler zurückgesetzt um #{now_label()}."
     )}
  end

  def handle_event("poll-status", _, socket) do
    msg =
      case Bridge.send_command(%{cmd: "status"}) do
        {:error, reason} -> "Status-Abfrage fehlgeschlagen: #{inspect(reason)}"
        _ -> "Status-Abfrage gesendet um #{now_label()}."
      end

    {:noreply, assign(socket, poll_msg: msg)}
  end

  def handle_event("set-level", %{"level" => level}, socket) do
    {:noreply, assign(socket, level_filter: level)}
  end

  def handle_event("clear-log", _, socket) do
    EventLog.clear()
    {:noreply, assign(socket, log: [])}
  end

  # --- PubSub ---

  @impl true
  def handle_info({:metrics, snapshot}, socket) do
    {:noreply, assign(socket, metrics: MonitorComponents.normalize(snapshot))}
  end

  def handle_info({:event, entry}, socket) do
    {:noreply, assign(socket, log: Enum.take([entry | socket.assigns.log], @log_limit))}
  end

  # --- Helpers ---

  defp now_label, do: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
end
