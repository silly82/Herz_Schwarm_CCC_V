defmodule HerzSchwarm.EffectEngine do
  @moduledoc """
  GenServer that manages effect state and dispatches commands to the Bridge.

  Supports all SyncPacket modes (1-8), BPM-driven beat engine, and
  tap-tempo for manual beat triggering.
  """

  use GenServer
  require Logger
  import Bitwise

  alias HerzSchwarm.{Bridge, EventLog, Metrics}

  @pubsub HerzSchwarm.PubSub
  @topic "effect:state"

  defstruct [
    :active_mode,
    :active_id,
    :bpm,
    :beat_active,
    :beat_timer,
    :color,
    :wave_id,
    :wave_running
  ]

  # Funk-Modus 10 = Welle stoppen (ID der Welle), Modus 12 = ALLE Effekte
  # global stoppen (SYNC_MODE_STOP_ALL, virusID = 0, kein ID-Ziel).
  @mode_wave_stop 10
  @mode_stop_all 12

  # Mode names for UI
  @mode_names %{
    0 => "Normal",
    1 => "Virus",
    2 => "Regenbogen",
    3 => "Primzahl",
    4 => "Welle",
    5 => "Beat",
    6 => "Zone",
    7 => "Ambient",
    8 => "Strobe"
  }

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Trigger an effect mode (1-8). Options: beatCounter for mode 7."
  def trigger_effect(mode, opts \\ []) when mode in 1..8 do
    GenServer.cast(__MODULE__, {:trigger, mode, opts})
  end

  @doc "Manuell die laufende Welle (Modus 4) stoppen (sendet Modus 10)."
  def stop_wave do
    GenServer.cast(__MODULE__, {:trigger, @mode_wave_stop, []})
  end

  @doc """
  Setzt nur den Tempo-Wert (0-300 BPM). Startet den Beat NICHT.

  - Beat inaktiv: nur der Wert wird gespeichert, kein Timer.
  - Beat aktiv: der laufende Timer wird mit dem neuen Intervall neu geplant.
  - `0`: stoppt den Beat (Wert wird auf 0 gesetzt).
  """
  def set_bpm(bpm) when bpm >= 0 and bpm <= 300 do
    GenServer.cast(__MODULE__, {:set_bpm, bpm})
  end

  @doc "Startet den Beat mit dem angegebenen Tempo (1-300 BPM)."
  def start_beat(bpm) when bpm >= 1 and bpm <= 300 do
    GenServer.cast(__MODULE__, {:start_beat, bpm})
  end

  @doc "Manual beat trigger (tap-tempo style)."
  def tap_beat do
    GenServer.cast(__MODULE__, :tap_beat)
  end

  @doc "Set RGB color for ambient mode (mode 7)."
  def set_color(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    GenServer.cast(__MODULE__, {:set_color, r, g, b})
  end

  @doc """
  Alle Effekte auf den Badges stoppen (sendet immer Modus 12, auch ohne
  laufende Welle). Beendet zusätzlich Welle und Beat lokal.
  """
  def stop_all do
    GenServer.cast(__MODULE__, :stop_all)
  end

  @doc "Get current effect state snapshot."
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc "Get human-readable mode name."
  def mode_name(mode), do: Map.get(@mode_names, mode, "?")

  @doc "Get all mode names."
  def mode_names, do: @mode_names

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      active_mode: 0,
      active_id: 0,
      bpm: 0,
      beat_active: false,
      beat_timer: nil,
      color: {100, 150, 255},
      wave_id: nil,
      wave_running: false
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, snapshot(state), state}
  end

  @impl true
  def handle_cast({:trigger, mode, opts}, state) do
    # Stopp (10) nutzt die ID der laufenden Welle, sonst eine neue ID
    id = if mode == 10, do: state.wave_id || 0, else: System.unique_integer([:positive])

    beat_counter =
      case mode do
        7 ->
          {r, g, b} = Keyword.get(opts, :color, state.color)
          r <<< 16 ||| g <<< 8 ||| b

        _ ->
          System.os_time(:millisecond)
      end

    cmd = %{
      cmd: "effect",
      mode: mode,
      virusID: id,
      beatCounter: beat_counter
    }

    send_cmd(cmd)
    count_trigger(mode)

    # Mode 10 = Welle stoppen: danach ist kein Effekt mehr aktiv.
    # wave_id bleibt erhalten, damit mehrfaches Stoppen funktioniert.
    active_mode = if mode == @mode_wave_stop, do: 0, else: mode
    wave_id = if mode == 4, do: id, else: state.wave_id
    wave_running = wave_running_after(mode, state.wave_running)

    state = %{
      state
      | active_mode: active_mode,
        active_id: id,
        wave_id: wave_id,
        wave_running: wave_running
    }

    broadcast_state(state)

    {:noreply, state}
  end

  # Stopp: Beat aus, Tempo auf 0.
  def handle_cast({:set_bpm, 0}, state) do
    state = cancel_beat_timer(state)
    state = %{state | bpm: 0, beat_active: false}
    broadcast_state(state)
    {:noreply, state}
  end

  # Nur Tempo: startet den Beat nie. Läuft er bereits, wird der Takt angepasst.
  def handle_cast({:set_bpm, bpm}, %{beat_active: true} = state) do
    state = cancel_beat_timer(state)
    state = schedule_beat(%{state | bpm: bpm})
    broadcast_state(state)
    {:noreply, state}
  end

  def handle_cast({:set_bpm, bpm}, state) do
    state = %{state | bpm: bpm}
    broadcast_state(state)
    {:noreply, state}
  end

  # Einziger Pfad, der den Beat startet.
  def handle_cast({:start_beat, bpm}, state) do
    state = cancel_beat_timer(state)
    state = schedule_beat(%{state | bpm: bpm, beat_active: true})
    broadcast_state(state)
    {:noreply, state}
  end

  def handle_cast(:tap_beat, state) do
    id = System.unique_integer([:positive])

    cmd = %{
      cmd: "effect",
      mode: 5,
      virusID: id,
      beatCounter: System.os_time(:millisecond)
    }

    send_cmd(cmd)
    Metrics.increment(:triggers)
    state = %{state | active_mode: 5, active_id: id}
    broadcast_state(state)
    {:noreply, state}
  end

  def handle_cast({:set_color, r, g, b}, state) do
    state = %{state | color: {r, g, b}}
    broadcast_state(state)
    {:noreply, state}
  end

  def handle_cast(:stop_all, state) do
    # Modus 12 immer senden: stoppt alle Effekte und die Welle auf den Badges.
    # Fehler (z. B. Bridge getrennt) werden in send_cmd/1 geloggt, nicht geworfen.
    send_cmd(stop_all_cmd())
    if state.wave_running, do: Metrics.increment(:wave_stops)

    state = cancel_beat_timer(state)

    state = %{
      state
      | active_mode: 0,
        active_id: 0,
        beat_active: false,
        wave_running: false
    }

    broadcast_state(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:beat_tick, %{beat_active: true, bpm: bpm} = state) when bpm > 0 do
    id = System.unique_integer([:positive])

    cmd = %{
      cmd: "effect",
      mode: 5,
      virusID: id,
      beatCounter: System.os_time(:millisecond)
    }

    send_cmd(cmd)
    Metrics.increment(:triggers)

    state = schedule_beat(%{state | active_mode: 5, active_id: id})
    broadcast_state(state)
    {:noreply, state}
  end

  def handle_info(:beat_tick, state) do
    {:noreply, %{state | beat_timer: nil}}
  end

  # Plant den nächsten beat_tick gemäß state.bpm (muss > 0 sein).
  defp schedule_beat(%{bpm: bpm} = state) do
    timer = Process.send_after(self(), :beat_tick, div(60_000, bpm))
    %{state | beat_active: true, beat_timer: timer}
  end

  # Cancel any pending beat_tick, draining any already-queued message.
  # This avoids a race where :beat_tick fires after set_bpm(0) and re-arms.
  defp cancel_beat_timer(state) do
    case state.beat_timer do
      nil ->
        state

      ref ->
        Process.cancel_timer(ref)
        # Drain any :beat_tick already in the mailbox
        receive do
          :beat_tick -> :ok
        after
          0 -> :ok
        end

        %{state | beat_timer: nil}
    end
  end

  # Sendet ein Kommando und zaehlt es (nur bei erfolgreichem Versand).
  defp send_cmd(cmd) do
    case Bridge.send_command(cmd) do
      {:ok, _seq} = ok ->
        Metrics.increment(:commands_sent)
        ok

      other ->
        EventLog.log(:debug, "effect", "Kommando nicht gesendet: #{inspect(other)}")
        other
    end
  end

  defp count_trigger(mode) do
    Metrics.increment(:triggers)

    case mode do
      4 -> Metrics.increment(:wave_starts)
      10 -> Metrics.increment(:wave_stops)
      9 -> Metrics.increment(:identifies)
      _ -> :ok
    end
  end

  # Welle (4) startet sie; Stopp (10) und alle Modi, die die Welle auf den
  # Badges verdraengen ("letzter Effekt gewinnt"), beenden sie. Beat (5) und
  # Identify (9) lassen die Welle unberuehrt.
  defp wave_running_after(4, _running), do: true

  defp wave_running_after(mode, _running) when mode in [1, 2, 3, 6, 7, 8, 10, 12], do: false

  defp wave_running_after(_mode, running), do: running

  # Modus 12 = alle Effekte global stoppen, kein ID-Ziel (virusID 0).
  defp stop_all_cmd do
    %{
      cmd: "effect",
      mode: @mode_stop_all,
      virusID: 0,
      beatCounter: System.os_time(:millisecond)
    }
  end

  defp snapshot(state) do
    %{
      active_mode: state.active_mode,
      active_id: state.active_id,
      bpm: state.bpm,
      beat_active: state.beat_active,
      color: state.color,
      wave_running: state.wave_running,
      mode_name: mode_name(state.active_mode)
    }
  end

  defp broadcast_state(state) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:effect, snapshot(state)})
  end
end
