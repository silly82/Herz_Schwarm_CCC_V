defmodule HerzSchwarm.EffectEngineMetricsTest do
  use ExUnit.Case, async: false

  alias HerzSchwarm.{Bridge, EffectEngine, Metrics}

  setup do
    o = :sys.get_state(Bridge)
    test_pid = self()

    :sys.replace_state(Bridge, fn st ->
      write = fn _pid, data ->
        send(test_pid, {:wire, Jason.decode!(data)})
        :ok
      end

      %{st | connected: true, uart_pid: :fake, write: write}
    end)

    EffectEngine.stop_all()
    EffectEngine.set_bpm(0)
    EffectEngine.get_state()
    flush_wire()
    Metrics.reset()

    on_exit(fn ->
      EffectEngine.stop_all()
      EffectEngine.set_bpm(0)

      :sys.replace_state(Bridge, fn st ->
        %{st | connected: o.connected, uart_pid: o.uart_pid, write: o.write, pending: %{}}
      end)
    end)

    :ok
  end

  defp flush_wire do
    receive do
      {:wire, _} -> flush_wire()
    after
      0 -> :ok
    end
  end

  # EffectEngine.get_state/0 wartet, bis der vorige Trigger verarbeitet ist. Die
  # daraus an Metrics gesendeten Casts sind damit eingereiht; der Snapshot-Call
  # danach wird erst nach ihnen bearbeitet, so dass die Zaehler vollstaendig sind.
  defp counters do
    EffectEngine.get_state()
    Metrics.snapshot().counters
  end

  test "Effekt zaehlt triggers und commands_sent" do
    EffectEngine.trigger_effect(1)
    assert %{triggers: 1, commands_sent: 1, wave_starts: 0, wave_stops: 0} = counters()
  end

  test "Welle: Start (Modus 4) und Stopp (stop_wave / Modus 10)" do
    EffectEngine.trigger_effect(4)
    EffectEngine.stop_wave()
    assert %{triggers: 2, commands_sent: 2, wave_starts: 1, wave_stops: 1} = counters()
  end

  test "stop_all stoppt laufende Welle und zaehlt wave_stops" do
    EffectEngine.trigger_effect(4)
    EffectEngine.stop_all()
    assert %{wave_starts: 1, wave_stops: 1, commands_sent: 2} = counters()
    assert_receive {:wire, %{"mode" => 4}}
    assert_receive {:wire, %{"mode" => 12, "virusID" => 0}}
  end

  test "stop_all ohne Welle sendet trotzdem Modus 12" do
    EffectEngine.stop_all()
    assert %{commands_sent: 1, wave_stops: 0} = counters()
    assert_receive {:wire, %{"cmd" => "effect", "mode" => 12, "virusID" => 0}}
  end

  test "stop_all bei getrennter Bridge crasht nicht und raeumt lokalen Zustand auf" do
    EffectEngine.trigger_effect(4)
    # Erst synchronisieren, damit der Trigger noch mit verbundener Bridge verarbeitet wird.
    EffectEngine.get_state()
    :sys.replace_state(Bridge, fn st -> %{st | connected: false} end)
    EffectEngine.stop_all()

    state = EffectEngine.get_state()
    assert state.active_mode == 0
    assert state.beat_active == false
    assert state.wave_running == false
    assert Process.whereis(EffectEngine) != nil
    # Nur der Welle-Start (Modus 4) ging raus; der Stopp wurde verworfen.
    assert %{commands_sent: 1} = counters()
    assert_receive {:wire, %{"mode" => 4}}
    refute_received {:wire, %{"mode" => 12}}
  end

  test "stop_wave sendet weiterhin Modus 10" do
    EffectEngine.trigger_effect(4)
    EffectEngine.stop_wave()
    assert_receive {:wire, %{"mode" => 4}}
    assert_receive {:wire, %{"mode" => 10}}
    refute_received {:wire, %{"mode" => 12}}
  end

  test "tap_beat zaehlt als Effekt" do
    EffectEngine.tap_beat()
    assert %{triggers: 1, commands_sent: 1} = counters()
  end

  describe "wave_running folgt dem letzten Effekt" do
    test "verdraengender Modus beendet die Welle, Beat (5) und Stopp-Logik wie spezifiziert" do
      EffectEngine.trigger_effect(4)
      assert EffectEngine.get_state().wave_running == true

      EffectEngine.trigger_effect(2)
      assert EffectEngine.get_state().wave_running == false

      EffectEngine.trigger_effect(4)
      EffectEngine.trigger_effect(5)
      assert EffectEngine.get_state().wave_running == true

      EffectEngine.stop_wave()
      assert EffectEngine.get_state().wave_running == false

      EffectEngine.trigger_effect(4)
      EffectEngine.stop_all()
      assert EffectEngine.get_state().wave_running == false
    end
  end

  test "nicht gesendete Kommandos (Bridge getrennt) zaehlen nicht als commands_sent" do
    :sys.replace_state(Bridge, fn st -> %{st | connected: false} end)
    EffectEngine.trigger_effect(2)
    assert %{triggers: 1, commands_sent: 0} = counters()
  end
end
