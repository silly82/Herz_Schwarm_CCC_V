defmodule HerzSchwarm.BridgeTrackingTest do
  @moduledoc "ack/err/timeout-Verfolgung und Log-/Pong-Auswertung in HerzSchwarm.Bridge."
  use ExUnit.Case, async: false

  alias HerzSchwarm.{Bridge, EventLog, Metrics}

  setup do
    test = self()
    orig = :sys.get_state(Bridge)

    :sys.replace_state(Bridge, fn st ->
      write = fn _pid, data ->
        send(test, {:wrote, data})
        :ok
      end

      %{st | connected: true, uart_pid: :fake, write: write}
    end)

    prev_timeout = Application.get_env(:herz_schwarm, :ack_timeout_ms)
    Application.put_env(:herz_schwarm, :ack_timeout_ms, 100)
    Metrics.reset()
    EventLog.clear()

    on_exit(fn ->
      :sys.replace_state(Bridge, fn st ->
        %{
          st
          | connected: orig.connected,
            uart_pid: orig.uart_pid,
            write: orig.write,
            pending: %{}
        }
      end)

      Application.put_env(:herz_schwarm, :ack_timeout_ms, prev_timeout || 1_500)
    end)

    :ok
  end

  defp uart(json), do: send(Bridge, {:circuits_uart, "fake", json})
  defp sync, do: :sys.get_state(Bridge)
  defp counters, do: Metrics.snapshot().counters
  defp messages, do: Enum.map(EventLog.entries(), & &1.message)
  defp effect_cmd, do: %{cmd: "effect", mode: 1, virusID: 1, beatCounter: 1}

  test "ack mit passender seq zaehlt :acks und raeumt auf" do
    {:ok, seq} = Bridge.send_command(effect_cmd())
    assert map_size(sync().pending) == 1

    uart(~s({"evt":"ack","seq":#{seq}}))
    sync()

    assert %{acks: 1, errors: 0, timeouts: 0} = counters()
    assert sync().pending == %{}

    # Timer wurde abgebrochen -> kein spaeter Timeout
    Process.sleep(150)
    assert counters().timeouts == 0
  end

  test "ack mit unbekannter seq aendert nichts" do
    uart(~s({"evt":"ack","seq":9999}))
    sync()
    assert counters().acks == 0
  end

  test "err mit seq zaehlt :errors und schreibt ins EventLog" do
    {:ok, seq} = Bridge.send_command(effect_cmd())
    uart(~s({"evt":"err","seq":#{seq},"msg":"busy: ota"}))
    sync()

    assert %{errors: 1, acks: 0, timeouts: 0} = counters()
    assert "err seq=#{seq}: busy: ota" in messages()
    assert sync().pending == %{}

    [entry | _] = EventLog.entries()
    assert entry.level == :error and entry.source == "bridge"
  end

  test "err ohne seq zaehlt :errors und wird protokolliert" do
    uart(~s({"evt":"err","msg":"unknown cmd"}))
    sync()
    assert counters().errors == 1
    assert "err: unknown cmd" in messages()
  end

  test "ohne Antwort: Timeout wird gezaehlt und gewarnt; verspaetetes ack aendert nichts" do
    {:ok, seq} = Bridge.send_command(effect_cmd())
    Process.sleep(200)
    sync()

    assert %{timeouts: 1, acks: 0, errors: 0} = counters()
    assert sync().pending == %{}
    assert Enum.any?(EventLog.entries(), &(&1.level == :warn and &1.message =~ "seq=#{seq}"))

    uart(~s({"evt":"ack","seq":#{seq}}))
    uart(~s({"evt":"err","seq":#{seq},"msg":"spaet"}))
    sync()
    assert %{timeouts: 1, acks: 0, errors: 0} = counters()
  end

  test "ota_*-Kommandos werden nicht verfolgt (BridgeUpdater regelt das selbst)" do
    {:ok, seq} = Bridge.send_command(%{cmd: "ota_chunk", offset: 0})
    assert sync().pending == %{}

    uart(~s({"evt":"ack","seq":#{seq}}))
    sync()
    Process.sleep(150)
    assert %{acks: 0, timeouts: 0, errors: 0} = counters()
  end

  test "ack/err-Events werden weiterhin unveraendert auf bridge:events gesendet" do
    Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, Bridge.topic())
    {:ok, seq} = Bridge.send_command(effect_cmd())
    uart(~s({"evt":"ack","seq":#{seq}}))
    assert_receive {:bridge, %{"evt" => "ack", "seq" => ^seq}}
  end

  test "log-Event geht als :debug ins EventLog" do
    uart(~s({"evt":"log","msg":"bridge ready"}))
    sync()

    assert [%{level: :debug, source: "bridge", message: "log: bridge ready"} | _] =
             EventLog.entries()
  end

  test "pong liefert uptime/free_heap an Metrics" do
    uart(~s({"evt":"pong","peers":3,"uptime":4711,"free_heap":123456}))
    sync()
    assert %{uptime_s: 4711, free_heap: 123_456} = Metrics.snapshot().bridge
  end

  test "pending waechst nicht: viele unbeantwortete Kommandos verfallen" do
    for _ <- 1..50, do: Bridge.send_command(effect_cmd())
    assert map_size(sync().pending) == 50
    Process.sleep(250)
    assert sync().pending == %{}
    assert counters().timeouts == 50
  end

  test "nicht verbunden: Kommando wird verworfen und protokolliert" do
    :sys.replace_state(Bridge, fn st -> %{st | connected: false} end)
    assert {:error, :not_connected} = Bridge.send_command(effect_cmd())
    assert Enum.any?(messages(), &(&1 =~ "verworfen"))
    assert sync().pending == %{}
  end

  test "Nicht-Map-JSON bringt die Bridge nicht zum Absturz" do
    pid = Process.whereis(Bridge)
    uart("[1,2,3]")
    uart("42")
    uart("kein json")
    sync()
    assert Process.whereis(Bridge) == pid
  end
end
