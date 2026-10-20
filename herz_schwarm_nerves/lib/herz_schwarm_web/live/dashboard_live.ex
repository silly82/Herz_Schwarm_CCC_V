defmodule HerzSchwarmWeb.DashboardLive do
  use HerzSchwarmWeb, :live_view

  alias HerzSchwarm.{EffectEngine, PeerTracker, Bridge, Metrics, EventLog, TapCounter}
  alias HerzSchwarmWeb.MonitorComponents

  @log_limit 20
  @default_bpm 120

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "effect:state")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "peers:count")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "bridge:events")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "metrics:state")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "eventlog")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, TapCounter.topic())
    end

    effect = EffectEngine.get_state()
    peers = PeerTracker.get_status()
    bridge_connected = Bridge.connected?()

    socket =
      socket
      |> assign(
        bridge_connected: bridge_connected,
        bridge_fw: bridge_fw(peers.last_pong),
        bridge_ota: bridge_ota(peers.last_pong),
        peer_count: peers.peer_count,
        peers: peers.peers,
        find_msg: nil,
        active_mode: effect.active_mode,
        mode_name: effect.mode_name,
        bpm: effect.bpm,
        beat_active: effect.beat_active,
        wave_active: effect.wave_running,
        color: effect.color,
        color_hex: color_to_hex(effect.color),
        metrics: MonitorComponents.normalize(Metrics.snapshot()),
        taps: TapCounter.state(),
        log: EventLog.entries() |> Enum.take(@log_limit)
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:warnings, MonitorComponents.warnings(assigns.bridge_connected, assigns.metrics))
      |> assign(:badge_rows, MonitorComponents.badge_rows(assigns.peers, assigns.metrics.badges))
      |> assign(:counter_fields, MonitorComponents.counter_fields())

    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <header class="flex flex-wrap items-center justify-between gap-3 mb-6">
        <h1 class="text-2xl font-bold text-pink-400">
          &#x2764;&#xFE0F; Herz-Schwarm Controller
        </h1>
        <div class="flex flex-wrap items-center gap-2">
          <span class={"badge #{if @bridge_connected, do: "badge-ok", else: "badge-err"}"}>
            Bridge: {if @bridge_connected, do: "verbunden", else: "getrennt"}
          </span>
          <span id="bridge-uptime" class="badge badge-info">
            &#x23F1; Uptime {MonitorComponents.format_duration(@metrics.bridge.uptime_s)}
          </span>
          <span id="bridge-heap" class="badge badge-info">
            RAM frei {MonitorComponents.format_heap(@metrics.bridge.free_heap)}
          </span>
          <span
            id="bridge-reconnects"
            class={"badge #{if @metrics.counters.reconnects > 0, do: "badge-err", else: "badge-idle"}"}
          >
            Reconnects {@metrics.counters.reconnects}
          </span>
          <.link navigate={~p"/bridge-update"} id="bridge-fw-link" class="badge badge-info">
            Bridge-FW {@bridge_fw || "?"}{bridge_ota_suffix(@bridge_ota)} &middot; Update
          </.link>
          <span class="badge badge-info">
            &#x1F4F1; Peers: {@peer_count}
          </span>
          <span class={"badge #{if @active_mode > 0, do: "badge-active", else: "badge-idle"}"}>
            {@mode_name}
          </span>
        </div>
      </header>

      <div :if={@warnings != []} id="warn-banner" class="warn-banner mb-6" role="alert">
        <p class="font-semibold mb-1">&#x26A0;&#xFE0F; Achtung</p>
        <ul class="list-disc pl-5 text-sm">
          <li :for={w <- @warnings}>{w}</li>
        </ul>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div class="card">
          <h2>&#x26A1; Effekte</h2>
          <div class="btn-grid">
            <button
              :for={{mode, name} <- effect_buttons()}
              class={"btn btn-effect #{btn_class(mode, @wave_active)}"}
              phx-click={effect_event(mode, @wave_active)}
              phx-value-mode={mode}
            >
              {effect_label(mode, name, @wave_active)}
            </button>
          </div>
        </div>

        <div class="card">
          <h2>&#x1F3B5; Beat-Steuerung</h2>
          <%!-- phx-change feuert in LiveView nur innerhalb eines <form> --%>
          <form id="bpm-form" phx-change="set-bpm" class="flex items-center gap-3 mb-3">
            <label class="text-sm text-gray-400" for="bpm-slider">BPM</label>
            <input
              id="bpm-slider"
              type="range"
              min="60"
              max="180"
              value={@bpm}
              phx-debounce="120"
              name="bpm"
              class="flex-1"
            />
            <span class="text-lg font-mono w-12 text-right">{@bpm}</span>
          </form>
          <div class="flex gap-2">
            <button class="btn btn-beat flex-1" phx-click="tap-beat">
              &#x1F449; Tap
            </button>
            <button :if={@beat_active} class="btn btn-stop flex-1" phx-click="stop-beat">
              &#x23F9; Stop
            </button>
            <button :if={!@beat_active} class="btn btn-go flex-1" phx-click="start-beat">
              &#x25B6; Start
            </button>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div class="card">
          <h2>&#x1F3A8; Ambient Farbe (Modus 7)</h2>
          <%!-- phx-change feuert in LiveView nur innerhalb eines <form> --%>
          <form id="color-form" phx-change="set-color" class="flex items-center gap-3 mb-3">
            <input
              id="color-input"
              type="color"
              value={@color_hex}
              phx-debounce="80"
              name="color"
              class="w-12 h-10 rounded cursor-pointer"
            />
            <span id="color-hex" class="font-mono text-sm text-gray-400">{@color_hex}</span>
          </form>
          <button class="btn btn-ambient w-full" phx-click="effect" phx-value-mode="7">
            Ambient senden
          </button>
        </div>

        <div class="card">
          <h2>&#x1F4E1; Schnellaktionen</h2>
          <div class="flex flex-col gap-2">
            <button class="btn btn-stop w-full" phx-click="stop-all">
              &#x23F9; Alle Effekte auf den Badges stoppen
            </button>
            <button
              :if={@wave_active}
              class="btn btn-stop w-full"
              phx-click="wave_stop"
            >
              &#x23F9; Welle stoppen
            </button>
            <button
              :if={!@wave_active}
              class="btn btn-wave w-full"
              phx-click="effect"
              phx-value-mode="4"
            >
              &#x1F30A; Welle senden
            </button>
            <button class="btn btn-virus w-full" phx-click="effect" phx-value-mode="1">
              &#x26A1; Virus senden
            </button>
          </div>
        </div>
      </div>

      <div class="card mb-6">
        <h2>&#x1F50E; Badges</h2>
        <p :if={@badge_rows == []} class="text-sm text-gray-400">
          Keine Badges in Funkreichweite der Bridge (Liste aktualisiert alle 5 s).
        </p>
        <div :if={@badge_rows != []} class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-gray-400">
                <th class="py-1">MAC</th>
                <th>RSSI</th>
                <th>Alter</th>
                <th>RSSI-Verlauf</th>
                <th>FW</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={r <- @badge_rows}
                id={"badge-#{r.mac}"}
                class={"border-t border-gray-800 #{if !r.online, do: "row-offline"}"}
              >
                <td class="py-1 font-mono whitespace-nowrap">{r.mac}</td>
                <td class="font-mono whitespace-nowrap">{MonitorComponents.format_rssi(r.rssi)}</td>
                <td class="font-mono whitespace-nowrap">{MonitorComponents.format_age(r.age_s)}</td>
                <td>
                  <span
                    class="inline-flex items-center gap-2"
                    title={MonitorComponents.stats_title(r.stats)}
                  >
                    <MonitorComponents.sparkline samples={r.samples} />
                    <span :if={r.stats} class="font-mono text-xs text-gray-500 whitespace-nowrap">
                      {MonitorComponents.format_rssi(r.stats.rssi_min)} / {MonitorComponents.format_avg(
                        r.stats.rssi_avg
                      )} / {MonitorComponents.format_rssi(r.stats.rssi_max)}
                    </span>
                  </span>
                </td>
                <td class="font-mono">{r.fw}</td>
                <td class="text-right whitespace-nowrap">
                  <button
                    :if={r.online && can_identify?(r.fw)}
                    class="btn btn-go btn-effect"
                    phx-click="identify"
                    phx-value-mac={r.mac}
                  >
                    🔎 Finden
                  </button>
                  <span :if={!r.online} class="text-xs text-gray-500">offline</span>
                  <span :if={r.online && !can_identify?(r.fw)} class="text-xs text-gray-500">
                    FW &lt; 1.3
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p :if={@find_msg} class="text-sm text-gray-400 mt-2">{@find_msg}</p>
      </div>

      <div class="card mb-6">
        <h2>&#x1F4CA; Zähler</h2>
        <dl id="counters" class="grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm">
          <div :for={{key, label} <- @counter_fields}>
            <dt class="text-gray-400">{label}</dt>
            <dd class={"font-mono text-lg #{if key == :errors and @metrics.counters.errors > 0, do: "text-red-400"}"}>
              {@metrics.counters[key]}
            </dd>
          </div>
        </dl>
      </div>

      <div class="card mb-6">
        <h2>&#x1F4AF; Tap-Counter</h2>
        <MonitorComponents.tap_card taps={@taps} />
      </div>

      <div class="card mb-6">
        <div class="flex items-center justify-between mb-3">
          <h2 class="mb-0">&#x1F4CB; Log</h2>
          <.link navigate={~p"/diagnose"} id="diagnose-link" class="badge badge-info">
            Diagnose &rarr;
          </.link>
        </div>
        <MonitorComponents.log_list entries={@log} id="log-panel" />
      </div>

      <div class="card">
        <h2>&#x1F4CB; Zone-Hinweis</h2>
        <p class="text-sm text-gray-400">
          Zonen-Farben sind compile-time im Badge-Firmware festgelegt: <span class="text-red-400">Nah (&gt; -55 dBm) = Rot</span>, <span class="text-yellow-400">Mitte (&gt; -75 dBm) = Gelb</span>, <span class="text-blue-400">Fern (&le; -75 dBm) = Blau</span>.
          Modus 6 l&ouml;st bei allen Badges gleichzeitig aus; die Farbe wird per RSSI gew&auml;hlt.
        </p>
      </div>

      <footer class="mt-8 text-center text-xs text-gray-600">
        Herz-Schwarm Nerves Controller v{Application.spec(:herz_schwarm, :vsn)} &middot; ESP-NOW Kanal 13 &middot; Bridge UART
      </footer>
    </div>
    """
  end

  # --- Events ---

  @impl true
  def handle_event("effect", %{"mode" => mode_str}, socket) do
    mode = String.to_integer(mode_str)

    case mode do
      7 ->
        EffectEngine.trigger_effect(7, color: socket.assigns.color)

      _ ->
        EffectEngine.trigger_effect(mode)
    end

    {:noreply, assign(socket, wave_active: mode == 4)}
  end

  def handle_event("wave_stop", _, socket) do
    EffectEngine.stop_wave()
    {:noreply, assign(socket, wave_active: false)}
  end

  def handle_event("set-bpm", %{"bpm" => bpm_str}, socket) do
    bpm = String.to_integer(bpm_str)
    EffectEngine.set_bpm(bpm)
    {:noreply, assign(socket, bpm: bpm)}
  end

  def handle_event("tap-beat", _, socket) do
    EffectEngine.tap_beat()
    {:noreply, socket}
  end

  def handle_event("start-beat", _, socket) do
    # Engine-Default ist bpm 0 (= aus); ohne gültigen Slider-Wert Default nehmen.
    bpm = if socket.assigns.bpm in 60..180, do: socket.assigns.bpm, else: @default_bpm
    EffectEngine.start_beat(bpm)
    {:noreply, assign(socket, bpm: bpm)}
  end

  def handle_event("stop-beat", _, socket) do
    EffectEngine.set_bpm(0)
    {:noreply, socket}
  end

  def handle_event("set-color", %{"color" => hex}, socket) do
    {r, g, b} = hex_to_rgb(hex)
    EffectEngine.set_color(r, g, b)
    {:noreply, assign(socket, color: {r, g, b}, color_hex: hex)}
  end

  def handle_event("identify", %{"mac" => mac}, socket) do
    msg =
      case PeerTracker.identify(mac) do
        :ok -> "#{mac} blinkt jetzt 10 s grün."
        {:error, :invalid_mac} -> "Ungültige MAC: #{mac}"
        {:error, reason} -> "Konnte nicht senden: #{send_error_text(reason)}"
      end

    {:noreply, assign(socket, find_msg: msg)}
  end

  def handle_event("stop-all", _, socket) do
    EffectEngine.stop_all()
    {:noreply, socket}
  end

  def handle_event("tap-reset", _, socket) do
    TapCounter.reset()
    {:noreply, socket}
  end

  # --- PubSub ---

  @impl true
  def handle_info({:effect, state}, socket) do
    {:noreply,
     assign(socket,
       active_mode: state.active_mode,
       mode_name: state.mode_name,
       bpm: state.bpm,
       beat_active: state.beat_active,
       wave_active: state.wave_running
     )}
  end

  def handle_info({:peers, status}, socket) do
    {:noreply,
     assign(socket,
       peer_count: status.peer_count,
       peers: status.peers,
       bridge_connected: status.bridge_connected,
       # Bei getrennter Bridge ist last_pong nil -> FW/OTA-Anzeige wird geleert
       bridge_fw: bridge_fw(status.last_pong),
       bridge_ota: bridge_ota(status.last_pong)
     )}
  end

  def handle_info({:bridge, :connected}, socket) do
    {:noreply, assign(socket, bridge_connected: true)}
  end

  def handle_info({:bridge, :disconnected}, socket) do
    {:noreply, assign(socket, bridge_connected: false)}
  end

  def handle_info({:bridge, _event}, socket) do
    {:noreply, socket}
  end

  def handle_info({:metrics, snapshot}, socket) do
    {:noreply, assign(socket, metrics: MonitorComponents.normalize(snapshot))}
  end

  def handle_info({:event, entry}, socket) do
    {:noreply, assign(socket, log: Enum.take([entry | socket.assigns.log], @log_limit))}
  end

  def handle_info({:taps, taps}, socket) do
    {:noreply, assign(socket, taps: taps)}
  end

  # --- Helpers ---

  # Bridge-FW >= 0.3.0 meldet "fw" und "ota" im pong; aeltere nichts (-> nil).
  defp bridge_fw(%{"fw" => fw}) when is_binary(fw), do: fw
  defp bridge_fw(_), do: nil

  defp bridge_ota(%{"ota" => ota}) when is_binary(ota), do: ota
  defp bridge_ota(_), do: nil

  defp bridge_ota_suffix(nil), do: ""
  defp bridge_ota_suffix("idle"), do: ""
  defp bridge_ota_suffix(ota), do: " (OTA: #{ota})"

  defp effect_buttons do
    [
      {1, "⚡ Virus"},
      {2, "🌈 Regenbogen"},
      {3, "✨ Primzahl"},
      {4, "🌊 Welle"},
      {5, "🎵 Beat"},
      {6, "🎯 Zone"},
      {7, "🎨 Ambient"},
      {8, "💥 Strobe"}
    ]
  end

  # Identify (Modus 9) versteht erst Badge-FW 1.3.0; Stationen (0.x) gar nicht.
  defp can_identify?(fw) when not is_binary(fw), do: false

  defp can_identify?(fw) do
    case Version.parse(fw) do
      {:ok, v} -> v.major >= 1 and Version.compare(v, Version.parse!("1.3.0")) != :lt
      :error -> false
    end
  end

  defp send_error_text(reason) when reason in [:not_connected, :bridge_down],
    do: "Bridge getrennt"

  defp send_error_text(reason), do: inspect(reason)

  # Welle (4) ist ein Toggle: läuft sie, wird der Button zum Stopp.
  defp effect_event(4, true), do: "wave_stop"
  defp effect_event(_mode, _wave_active), do: "effect"

  defp effect_label(4, _name, true), do: "⏹ Welle stoppen"
  defp effect_label(_mode, name, _wave_active), do: name

  defp btn_class(4, true), do: "btn-stop"
  defp btn_class(mode, _wave_active), do: btn_class(mode)

  defp btn_class(1), do: "btn-virus"
  defp btn_class(2), do: "btn-rainbow"
  defp btn_class(3), do: "btn-prime"
  defp btn_class(4), do: "btn-wave"
  defp btn_class(5), do: "btn-beat"
  defp btn_class(6), do: "btn-zone"
  defp btn_class(7), do: "btn-ambient"
  defp btn_class(8), do: "btn-strobe"

  defp color_to_hex({r, g, b}) do
    r_hex = r |> Integer.to_string(16) |> String.pad_leading(2, "0")
    g_hex = g |> Integer.to_string(16) |> String.pad_leading(2, "0")
    b_hex = b |> Integer.to_string(16) |> String.pad_leading(2, "0")
    "#" <> r_hex <> g_hex <> b_hex
  end

  defp hex_to_rgb("#" <> hex) do
    r = String.slice(hex, 0, 2) |> Integer.parse(16) |> elem(0)
    g = String.slice(hex, 2, 2) |> Integer.parse(16) |> elem(0)
    b = String.slice(hex, 4, 2) |> Integer.parse(16) |> elem(0)
    {r, g, b}
  end
end
