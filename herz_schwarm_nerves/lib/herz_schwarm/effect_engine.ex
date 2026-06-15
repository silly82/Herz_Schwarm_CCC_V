defmodule HerzSchwarm.EffectEngine do
  @moduledoc """
  GenServer that manages effect state and dispatches commands to the Bridge.

  Supports all SyncPacket modes (1-8), BPM-driven beat engine, and
  tap-tempo for manual beat triggering.
  """

  use GenServer
  require Logger

  alias HerzSchwarm.Bridge

  @pubsub HerzSchwarm.PubSub
  @topic "effect:state"

  defstruct [:active_mode, :active_id, :bpm, :beat_active, :beat_timer, :color]

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

  @doc "Set BPM for the beat engine (60-180). Set to 0 to stop."
  def set_bpm(bpm) when bpm >= 0 and bpm <= 300 do
    GenServer.cast(__MODULE__, {:set_bpm, bpm})
  end

  @doc "Manual beat trigger (tap-tempo style)."
  def tap_beat do
    GenServer.cast(__MODULE__, :tap_beat)
  end

  @doc "Set RGB color for ambient mode (mode 7)."
  def set_color(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    GenServer.cast(__MODULE__, {:set_color, r, g, b})
  end

  @doc "Stop all effects (return to normal)."
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
      color: {100, 150, 255}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    snapshot = %{
      active_mode: state.active_mode,
      active_id: state.active_id,
      bpm: state.bpm,
      beat_active: state.beat_active,
      color: state.color,
      mode_name: mode_name(state.active_mode)
    }

    {:reply, snapshot, state}
  end

  @impl true
  def handle_cast({:trigger, mode, opts}, state) do
    id = System.unique_integer([:positive])

    beat_counter =
      case mode do
        7 ->
          {r, g, b} = Keyword.get(opts, :color, state.color)
          (r <<< 16) ||| (g <<< 8) ||| b

        _ ->
          System.os_time(:millisecond)
      end

    cmd = %{
      cmd: "effect",
      mode: mode,
      virusID: id,
      beatCounter: beat_counter
    }

    Bridge.send_command(cmd)

    state = %{state | active_mode: mode, active_id: id}
    broadcast_state(state)

    {:noreply, state}
  end

  def handle_cast({:set_bpm, 0}, state) do
    if state.beat_timer, do: Process.cancel_timer(state.beat_timer)
    state = %{state | bpm: 0, beat_active: false, beat_timer: nil}
    broadcast_state(state)
    {:noreply, state}
  end

  def handle_cast({:set_bpm, bpm}, state) do
    if state.beat_timer, do: Process.cancel_timer(state.beat_timer)
    interval_ms = div(60_000, bpm)
    timer = Process.send_after(self(), :beat_tick, interval_ms)
    state = %{state | bpm: bpm, beat_active: true, beat_timer: timer}
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

    Bridge.send_command(cmd)
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
    if state.beat_timer, do: Process.cancel_timer(state.beat_timer)
    state = %{state | active_mode: 0, active_id: 0, beat_active: false, beat_timer: nil}
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

    Bridge.send_command(cmd)

    interval_ms = div(60_000, bpm)
    timer = Process.send_after(self(), :beat_tick, interval_ms)
    state = %{state | active_mode: 5, active_id: id, beat_timer: timer}
    broadcast_state(state)
    {:noreply, state}
  end

  def handle_info(:beat_tick, state) do
    {:noreply, %{state | beat_timer: nil}}
  end

  defp broadcast_state(state) do
    snapshot = %{
      active_mode: state.active_mode,
      active_id: state.active_id,
      bpm: state.bpm,
      beat_active: state.beat_active,
      color: state.color,
      mode_name: mode_name(state.active_mode)
    }

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:effect, snapshot})
  end
end
