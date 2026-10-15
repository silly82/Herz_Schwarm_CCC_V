defmodule HerzSchwarmWeb.DashboardLive do
  use HerzSchwarmWeb, :live_view

  alias HerzSchwarm.{EffectEngine, PeerTracker, Bridge}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "effect:state")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "peers:count")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "bridge:events")
    end

    effect = EffectEngine.get_state()
    peers = PeerTracker.get_status()
    bridge_connected = Bridge.connected?()

    socket =
      socket
      |> assign(
        bridge_connected: bridge_connected,
        peer_count: peers.peer_count,
        peers: peers.peers,
        find_msg: nil,
        active_mode: effect.active_mode,
        mode_name: effect.mode_name,
        bpm: effect.bpm,
        beat_active: effect.beat_active,
        color: effect.color,
        color_hex: color_to_hex(effect.color),
        log: []
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <header class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-pink-400">
          &#x2764;&#xFE0F; Herz-Schwarm Controller
        </h1>
        <div class="flex items-center gap-3">
          <span class={"badge #{if @bridge_connected, do: "badge-ok", else: "badge-err"}"}>
            Bridge: {if @bridge_connected, do: "verbunden", else: "getrennt"}
          </span>
          <span class="badge badge-info">
            &#x1F4F1; Peers: {@peer_count}
          </span>
          <span class={"badge #{if @active_mode > 0, do: "badge-active", else: "badge-idle"}"}>
            {@mode_name}
          </span>
        </div>
      </header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div class="card">
          <h2>&#x26A1; Effekte</h2>
          <div class="btn-grid">
            <button
              :for={{mode, name} <- effect_buttons()}
              class={"btn btn-effect #{btn_class(mode)}"}
              phx-click="effect"
              phx-value-mode={mode}
            >
              {name}
            </button>
          </div>
        </div>

        <div class="card">
          <h2>&#x1F3B5; Beat-Steuerung</h2>
          <div class="flex items-center gap-3 mb-3">
            <label class="text-sm text-gray-400">BPM</label>
            <input
              type="range"
              min="60"
              max="180"
              value={@bpm}
              phx-change="set-bpm"
              name="bpm"
              class="flex-1"
            />
            <span class="text-lg font-mono w-12 text-right">{@bpm}</span>
          </div>
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
          <div class="flex items-center gap-3 mb-3">
            <input
              type="color"
              value={@color_hex}
              phx-change="set-color"
              name="color"
              class="w-12 h-10 rounded cursor-pointer"
            />
            <span class="font-mono text-sm text-gray-400">{@color_hex}</span>
          </div>
          <button class="btn btn-ambient w-full" phx-click="effect" phx-value-mode="7">
            Ambient senden
          </button>
        </div>

        <div class="card">
          <h2>&#x1F4E1; Schnellaktionen</h2>
          <div class="flex flex-col gap-2">
            <button class="btn btn-stop w-full" phx-click="stop-all">
              &#x23F9; Alle Effekte stoppen
            </button>
            <button class="btn btn-wave w-full" phx-click="effect" phx-value-mode="4">
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
        <p :if={@peers == []} class="text-sm text-gray-400">
          Keine Badges in Funkreichweite der Bridge (Liste aktualisiert alle 5 s).
        </p>
        <table :if={@peers != []} class="w-full text-sm">
          <thead>
            <tr class="text-left text-gray-400">
              <th class="py-1">MAC</th>
              <th>RSSI</th>
              <th>FW</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={p <- @peers} class="border-t border-gray-800">
              <td class="py-1 font-mono">{p.mac}</td>
              <td class="font-mono">{p.rssi} dBm</td>
              <td class="font-mono">{p.fw}</td>
              <td class="text-right">
                <button
                  :if={can_identify?(p.fw)}
                  class="btn btn-go btn-effect"
                  phx-click="identify"
                  phx-value-mac={p.mac}
                >
                  🔎 Finden
                </button>
                <span :if={!can_identify?(p.fw)} class="text-xs text-gray-500">FW &lt; 1.3</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p :if={@find_msg} class="text-sm text-gray-400 mt-2">{@find_msg}</p>
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

    {:noreply, socket}
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
    EffectEngine.set_bpm(socket.assigns.bpm)
    {:noreply, socket}
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
      end

    {:noreply, assign(socket, find_msg: msg)}
  end

  def handle_event("stop-all", _, socket) do
    EffectEngine.stop_all()
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
       beat_active: state.beat_active
     )}
  end

  def handle_info({:peers, status}, socket) do
    {:noreply,
     assign(socket,
       peer_count: status.peer_count,
       peers: status.peers,
       bridge_connected: status.bridge_connected
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

  # --- Helpers ---

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
  defp can_identify?(fw) do
    case Version.parse(fw) do
      {:ok, v} -> v.major >= 1 and Version.compare(v, Version.parse!("1.3.0")) != :lt
      :error -> false
    end
  end

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
