defmodule HerzSchwarm.Metrics do
  @moduledoc """
  Laufende Kennzahlen: Zaehler, Bridge-Zustand und RSSI-Historie je Badge.

  Alles lebt nur im Speicher (keine Persistenz) und ist begrenzt:
  je Badge die letzten 60 RSSI-Werte, hoechstens 64 Badges (bei Ueberlauf
  fliegt das am laengsten nicht gesehene Badge heraus).

  ## Snapshot

      %{counters: %{commands_sent:, acks:, errors:, timeouts:, reconnects:,
                    triggers:, wave_starts:, wave_stops:, identifies:},
        bridge: %{connected:, port:, since:, uptime_s:, free_heap:},
        badges: %{mac => %{rssi_last:, rssi_min:, rssi_avg:, rssi_max:,
                           samples:, last_seen:, age_s:, fw:, online:}}}

  `samples` ist **aelteste zuerst** (neuester Wert zuletzt). Badges ohne
  Messwert (nur `mark_seen/1`) haben `nil` bei den RSSI-Feldern und `[]`.
  Offline-Badges bleiben mit `online: false` erhalten.

  ## Publikation

  Aenderungen werden als `{:metrics, snapshot}` auf `"metrics:state"`
  publiziert, hoechstens alle 500 ms (die erste Aenderung nach Ruhe geht sofort
  raus, weitere werden zu einer nachlaufenden Meldung zusammengefasst).
  Wechselt `bridge.connected`, wird sofort publiziert.

  ## Zeit

  Alterswerte nutzen die monotone Uhr (robust gegen NTP-Spruenge auf dem Pi);
  `last_seen` wird daraus relativ zu `DateTime.utc_now/0` berechnet.

  ## Konfiguration (`config :herz_schwarm`)

    * `:rssi_warn_threshold` (Default `-85`) – siehe `rssi_warn_threshold/0`
    * `:badge_offline_after_s` (Default `20`)
  """

  use GenServer

  @pubsub HerzSchwarm.PubSub
  @topic "metrics:state"
  @publish_interval_ms 500
  @tick_ms 1_000
  @rssi_samples 60
  @max_badges 64
  @counters [
    :commands_sent,
    :acks,
    :errors,
    :timeouts,
    :reconnects,
    :triggers,
    :wave_starts,
    :wave_stops,
    :identifies
  ]
  @bridge_keys [:connected, :port, :uptime_s, :free_heap]

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def topic, do: @topic

  @doc "Liste der bekannten Zaehlernamen."
  def counter_names, do: @counters

  @doc "Aktuelle Warnschwelle fuer RSSI (dBm), Default -85."
  def rssi_warn_threshold, do: Application.get_env(:herz_schwarm, :rssi_warn_threshold, -85)

  @doc "Sekunden ohne Lebenszeichen, nach denen ein Badge als offline gilt (Default 20)."
  def badge_offline_after_s, do: Application.get_env(:herz_schwarm, :badge_offline_after_s, 20)

  @doc "Vollstaendiger Snapshot (auch bei leerem Zustand gueltig)."
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @doc "Erhoeht einen Zaehler (asynchron)."
  def increment(counter, n \\ 1) when counter in @counters and is_integer(n) do
    GenServer.cast(__MODULE__, {:increment, counter, n})
  end

  @doc "Setzt alle Zaehler auf 0."
  def reset_counters, do: GenServer.call(__MODULE__, :reset_counters)

  @doc """
  Verbucht einen RSSI-Messwert fuer ein Badge (Ringpuffer, letzte 60 Werte).

  `age_ms` (optional) ist das von der Bridge gemeldete Alter der letzten
  Sichtung; damit wird `last_seen` entsprechend zurueckdatiert, sodass
  veraltete Bridge-Eintraege nicht als online gelten.
  """
  def add_rssi(mac, rssi, fw \\ nil, age_ms \\ nil) when is_binary(mac) do
    GenServer.cast(__MODULE__, {:add_rssi, String.upcase(mac), rssi, fw, age_ms})
  end

  @doc "Markiert ein Badge als soeben gesehen (ohne RSSI-Wert)."
  def mark_seen(mac) when is_binary(mac) do
    GenServer.cast(__MODULE__, {:add_rssi, String.upcase(mac), nil, nil, nil})
  end

  @doc "`true`, wenn das Badge bekannt und innerhalb von `:badge_offline_after_s` gesehen wurde."
  def badge_online?(mac) when is_binary(mac) do
    GenServer.call(__MODULE__, {:badge_online?, String.upcase(mac)})
  end

  @doc "MAC-Adressen aller bekannten, aktuell offline Badges."
  def offline_badges, do: GenServer.call(__MODULE__, :offline_badges)

  @doc """
  Setzt/merged den Bridge-Zustand. Erlaubte Schluessel: `:connected`, `:port`,
  `:uptime_s`, `:free_heap`. Beim Wechsel von `connected` wird `since` gesetzt
  (bzw. bei Trennung samt `uptime_s`/`free_heap` auf `nil`) und sofort
  publiziert.
  """
  def set_bridge_state(%{} = attrs) do
    GenServer.cast(__MODULE__, {:set_bridge_state, Map.take(attrs, @bridge_keys)})
  end

  @doc """
  Setzt Zaehler und Badge-Historie zurueck. Der Verbindungszustand der Bridge
  (`connected`, `port`, `since`) bleibt erhalten, da er keine Messgroesse ist;
  `uptime_s`/`free_heap` werden geleert.
  """
  def reset, do: GenServer.call(__MODULE__, :reset)

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    Process.send_after(self(), :tick, @tick_ms)

    state = %{
      counters: zero_counters(),
      bridge: %{connected: false, port: nil, since: nil, uptime_s: nil, free_heap: nil},
      badges: %{},
      offline_sig: MapSet.new(),
      last_pub: mono() - @publish_interval_ms,
      timer: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, build_snapshot(state), state}

  def handle_call(:reset_counters, _from, state) do
    {:reply, :ok, mark_dirty(%{state | counters: zero_counters()})}
  end

  def handle_call(:reset, _from, state) do
    bridge = %{state.bridge | uptime_s: nil, free_heap: nil}
    state = %{state | counters: zero_counters(), badges: %{}, bridge: bridge}
    {:reply, :ok, mark_dirty(%{state | offline_sig: MapSet.new()})}
  end

  def handle_call({:badge_online?, mac}, _from, state) do
    online =
      case Map.fetch(state.badges, mac) do
        {:ok, badge} -> online?(badge, mono())
        :error -> false
      end

    {:reply, online, state}
  end

  def handle_call(:offline_badges, _from, state) do
    {:reply, state |> offline_set(mono()) |> Enum.sort(), state}
  end

  @impl true
  def handle_cast({:increment, counter, n}, state) do
    {:noreply, mark_dirty(%{state | counters: Map.update!(state.counters, counter, &(&1 + n))})}
  end

  def handle_cast({:add_rssi, mac, rssi, fw, age_ms}, state) do
    now = mono()
    seen = if is_integer(age_ms) and age_ms >= 0, do: now - age_ms, else: now

    badge =
      case Map.fetch(state.badges, mac) do
        {:ok, b} -> b
        :error -> %{samples: [], fw: nil, seen_mono: seen}
      end

    badge = %{
      badge
      | seen_mono: max(badge.seen_mono, seen),
        fw: fw || badge.fw,
        samples:
          if(is_integer(rssi),
            do: Enum.take([rssi | badge.samples], @rssi_samples),
            else: badge.samples
          )
    }

    badges = state.badges |> make_room(mac) |> Map.put(mac, badge)
    {:noreply, mark_dirty(%{state | badges: badges})}
  end

  def handle_cast({:set_bridge_state, attrs}, state) do
    old = state.bridge
    bridge = Map.merge(old, attrs)

    bridge =
      case attrs do
        %{connected: true} when old.connected != true ->
          %{bridge | since: DateTime.utc_now()}

        %{connected: false} when old.connected != false ->
          %{bridge | since: nil, uptime_s: nil, free_heap: nil}

        _ ->
          bridge
      end

    state = %{state | bridge: bridge}

    if bridge.connected != old.connected do
      {:noreply, publish(state)}
    else
      {:noreply, mark_dirty(state)}
    end
  end

  @impl true
  def handle_info(:publish, state), do: {:noreply, publish(%{state | timer: nil})}

  # Offline-Wechsel entstehen mit der Zeit, nicht durch Events -> periodisch pruefen.
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, @tick_ms)
    sig = offline_set(state, mono())

    if sig == state.offline_sig do
      {:noreply, state}
    else
      {:noreply, mark_dirty(%{state | offline_sig: sig})}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # --- intern ---

  defp zero_counters, do: Map.new(@counters, &{&1, 0})

  defp mono, do: System.monotonic_time(:millisecond)

  defp offline_after_ms, do: badge_offline_after_s() * 1000

  defp online?(badge, now), do: now - badge.seen_mono <= offline_after_ms()

  defp offline_set(state, now) do
    for {mac, badge} <- state.badges, not online?(badge, now), into: MapSet.new(), do: mac
  end

  # Neues Badge bei vollem Speicher: das am laengsten nicht gesehene verdraengen.
  defp make_room(badges, mac) do
    if Map.has_key?(badges, mac) or map_size(badges) < @max_badges do
      badges
    else
      {oldest, _} = Enum.min_by(badges, fn {_mac, b} -> b.seen_mono end)
      Map.delete(badges, oldest)
    end
  end

  # Drosselung: Leading-Edge nach Ruhe, sonst genau eine nachlaufende Meldung.
  defp mark_dirty(%{timer: nil} = state) do
    elapsed = mono() - state.last_pub

    if elapsed >= @publish_interval_ms do
      publish(state)
    else
      %{state | timer: Process.send_after(self(), :publish, @publish_interval_ms - elapsed)}
    end
  end

  defp mark_dirty(state), do: state

  defp publish(state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:metrics, build_snapshot(state)})
    %{state | timer: nil, last_pub: mono()}
  end

  defp build_snapshot(state) do
    now = mono()
    now_dt = DateTime.utc_now()

    badges =
      Map.new(state.badges, fn {mac, b} ->
        samples = Enum.reverse(b.samples)
        age_ms = max(now - b.seen_mono, 0)

        {mac,
         %{
           rssi_last: List.first(b.samples),
           rssi_min: if(samples == [], do: nil, else: Enum.min(samples)),
           rssi_avg:
             if(samples == [], do: nil, else: Float.round(Enum.sum(samples) / length(samples), 1)),
           rssi_max: if(samples == [], do: nil, else: Enum.max(samples)),
           samples: samples,
           last_seen: DateTime.add(now_dt, -age_ms, :millisecond),
           age_s: div(age_ms, 1000),
           fw: b.fw,
           online: online?(b, now)
         }}
      end)

    %{counters: state.counters, bridge: state.bridge, badges: badges}
  end
end
