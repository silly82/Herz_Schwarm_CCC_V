defmodule HerzSchwarm.BridgeUpdaterTest do
  use ExUnit.Case, async: false

  alias HerzSchwarm.BridgeUpdater

  @pubsub HerzSchwarm.PubSub
  @max_line 255

  @moduletag :tmp_dir
  @moduletag :capture_log

  # --- reine Funktionen ---

  describe "chunk_plan/2" do
    test "lueckenlose Offsets, letzter Chunk kuerzer" do
      plan = BridgeUpdater.chunk_plan(250, 96)
      assert plan == [{0, 96}, {96, 96}, {192, 58}]
    end

    test "exaktes Vielfaches und kleine Images" do
      assert BridgeUpdater.chunk_plan(192, 96) == [{0, 96}, {96, 96}]
      assert BridgeUpdater.chunk_plan(1, 96) == [{0, 1}]
    end

    test "deckt jedes Byte genau einmal ab" do
      size = 2 * 1024 * 1024
      plan = BridgeUpdater.chunk_plan(size, 96)
      assert Enum.sum(Enum.map(plan, &elem(&1, 1))) == size

      assert plan
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [{o1, l1}, {o2, _}] -> o1 + l1 == o2 end)
    end
  end

  describe "Zeilenlaenge" do
    test "96-Byte-Chunk bleibt auch im Worst Case (2 MB, seq 10 Stellen) unter 256 Byte" do
      size = 2 * 1024 * 1024
      cmd = BridgeUpdater.chunk_command(:binary.copy(<<0xFF>>, size), size - 96, 96)
      assert cmd.data |> byte_size() == 128
      assert BridgeUpdater.wire_length(cmd) <= @max_line
      # Zeile ~190 Byte, wie spezifiziert
      assert BridgeUpdater.wire_length(cmd) < 200
    end

    test "fit_chunk_bytes verkleinert zu grosse Chunks" do
      assert BridgeUpdater.fit_chunk_bytes(96, 2_097_152) == 96
      fit = BridgeUpdater.fit_chunk_bytes(300, 2_097_152)
      assert fit < 300 and rem(fit, 3) == 0

      cmd = BridgeUpdater.chunk_command(:binary.copy(<<1>>, 2_097_152), 2_097_152 - fit, fit)
      assert BridgeUpdater.wire_length(cmd) <= @max_line
    end

    test "andere Kommandos sind kurz" do
      for cmd <- [
            %{cmd: "ota_begin", size: 2_097_152, ver: "0.3.0"},
            %{cmd: "ota_end"},
            %{cmd: "ota_abort"}
          ] do
        assert BridgeUpdater.wire_length(cmd) <= @max_line
      end
    end
  end

  # --- Zustandsautomat mit gefakter Bridge ---

  defp start_updater(opts \\ []) do
    test = self()
    counter = :counters.new(1, [])

    sender = fn cmd ->
      :counters.add(counter, 1, 1)
      seq = :counters.get(counter, 1)
      send(test, {:sent, seq, cmd})
      {:ok, seq}
    end

    name = :"updater_#{System.unique_integer([:positive])}"
    start_supervised!({BridgeUpdater, [name: name, sender: sender] ++ opts})
    [server: name]
  end

  defp write_image(dir, size \\ 250) do
    path = Path.join(dir, "bridge.bin")
    data = <<0xE9>> <> :crypto.strong_rand_bytes(size - 1)
    File.write!(path, data)
    {path, data}
  end

  defp bridge_event(evt), do: Phoenix.PubSub.broadcast(@pubsub, "bridge:events", {:bridge, evt})
  defp ack(seq), do: bridge_event(%{"evt" => "ack", "seq" => seq})

  # Naechstes gesendetes Kommando, optional mit erwarteter Art
  defp next_sent(cmd_name, timeout \\ 500) do
    assert_receive {:sent, seq, %{cmd: ^cmd_name} = cmd}, timeout
    {seq, cmd}
  end

  defp status(srv), do: BridgeUpdater.state(srv)

  # Treibt das Update bis ota_end durch und liefert alle Chunk-Kommandos
  defp ack_all_chunks(acc \\ []) do
    receive do
      {:sent, seq, %{cmd: "ota_chunk"} = cmd} ->
        ack(seq)
        ack_all_chunks([cmd | acc])
    after
      500 -> Enum.reverse(acc)
    end
  end

  test "Happy Path: begin, lueckenlose Chunks, end, done", %{tmp_dir: dir} do
    srv = start_updater()
    {path, data} = write_image(dir)
    Phoenix.PubSub.subscribe(@pubsub, BridgeUpdater.topic())

    assert {:ok, ref} = BridgeUpdater.begin_update(path, srv ++ [ver: "0.3.0"])
    assert is_reference(ref)

    {seq, begin_cmd} = next_sent("ota_begin")
    assert begin_cmd == %{cmd: "ota_begin", size: 250, ver: "0.3.0"}
    assert %{state: :running, size: 250, offset: 0} = status(srv)

    # streng sequenziell: ohne Ack kommt kein Chunk
    refute_receive {:sent, _, %{cmd: "ota_chunk"}}, 100
    ack(seq)

    chunks = ack_all_chunks()
    assert Enum.map(chunks, & &1.off) == [0, 96, 192]

    assert Enum.map(chunks, &(&1.data |> Base.decode64!() |> byte_size())) == [96, 96, 58]
    assert chunks |> Enum.map(&Base.decode64!(&1.data)) |> IO.iodata_to_binary() == data
    assert Enum.all?(chunks, &(BridgeUpdater.wire_length(&1) <= @max_line))

    {end_seq, _} = next_sent("ota_end")
    assert %{state: :running, phase: :end, offset: 250} = status(srv)
    ack(end_seq)

    assert_receive {:bridge_update, %{state: :done, percent: 100, offset: 250, size: 250}}, 500
    assert %{state: :done, error: nil, offset: 250} = status(srv)
    refute_receive {:sent, _, %{cmd: "ota_abort"}}, 50
  end

  test "wartet pro Chunk auf das Ack und ignoriert fremde seq", %{tmp_dir: dir} do
    srv = start_updater()
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")

    ack(seq + 1000)
    refute_receive {:sent, _, %{cmd: "ota_chunk"}}, 100
    ack(seq)
    {chunk_seq, %{off: 0}} = next_sent("ota_chunk")

    # Ack einer alten seq / Ack ohne seq bewegt nichts
    ack(seq)
    bridge_event(%{"evt" => "ack"})
    refute_receive {:sent, _, %{cmd: "ota_chunk"}}, 100
    ack(chunk_seq)
    assert {_, %{off: 96}} = next_sent("ota_chunk")
  end

  test "Timeout: bis zu 3 Wiederholungen desselben Chunks, dann ota_abort + Fehler", %{
    tmp_dir: dir
  } do
    srv = start_updater(chunk_timeout_ms: 30)
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    ack(seq)

    for _attempt <- 0..3 do
      assert {_, %{off: 0}} = next_sent("ota_chunk")
    end

    next_sent("ota_abort")
    refute_receive {:sent, _, %{cmd: "ota_chunk"}}, 100

    assert %{state: :error, error: error} = status(srv)
    assert error =~ "Timeout bei Offset 0"
    assert error =~ "3 Wiederholungen"
  end

  test "ein spaetes Ack des ersten Versuchs wird nach Wiederholung akzeptiert", %{tmp_dir: dir} do
    srv = start_updater(chunk_timeout_ms: 30)
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    ack(seq)

    {first, %{off: 0}} = next_sent("ota_chunk")
    {_retry, %{off: 0}} = next_sent("ota_chunk")
    ack(first)

    assert {_, %{off: 96}} = next_sent("ota_chunk")
    assert %{state: :running, offset: 96} = status(srv)
  end

  test "err mit passender seq bricht sofort ab", %{tmp_dir: dir} do
    srv = start_updater()
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    bridge_event(%{"evt" => "err", "seq" => seq, "msg" => "Bad Size Given"})

    next_sent("ota_abort")
    assert %{state: :error, error: "Bridge: Bad Size Given"} = status(srv)
  end

  test "err ohne passende seq (z. B. parse error) wird ignoriert", %{tmp_dir: dir} do
    srv = start_updater()
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    next_sent("ota_begin")
    bridge_event(%{"evt" => "err", "msg" => "json parse failed"})
    assert %{state: :running} = status(srv)
  end

  test "ota_begin-Timeout fuehrt zu Fehler und ota_abort", %{tmp_dir: dir} do
    srv = start_updater(begin_timeout_ms: 30)
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    next_sent("ota_begin")
    next_sent("ota_abort")
    assert %{state: :error, error: "Timeout beim Start (ota_begin)"} = status(srv)
  end

  test "Gesamt-Timeout", %{tmp_dir: dir} do
    srv = start_updater(total_timeout_ms: 40)
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    next_sent("ota_begin")
    next_sent("ota_abort")
    assert %{state: :error, error: "Gesamt-Timeout" <> _} = status(srv)
  end

  test "cancel sendet ota_abort und geht auf idle", %{tmp_dir: dir} do
    srv = start_updater()
    {path, _} = write_image(dir)
    assert {:error, :not_running} = BridgeUpdater.cancel(srv)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    next_sent("ota_begin")

    assert :ok = BridgeUpdater.cancel(srv)
    next_sent("ota_abort")
    assert %{state: :idle, offset: 0, error: nil} = status(srv)
  end

  test "zweites Update waehrend eines laufenden wird abgelehnt", %{tmp_dir: dir} do
    srv = start_updater()
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    assert {:error, :busy} = BridgeUpdater.begin_update(path, srv)
  end

  test "ungueltige Dateien werden vor dem Senden abgelehnt", %{tmp_dir: dir} do
    srv = start_updater()
    bad = Path.join(dir, "bad.bin")
    File.write!(bad, "kein esp image")
    empty = Path.join(dir, "empty.bin")
    File.write!(empty, "")
    big = Path.join(dir, "big.bin")
    File.write!(big, <<0xE9>> <> :binary.copy(<<0>>, 2 * 1024 * 1024))

    assert {:error, :not_an_esp_image} = BridgeUpdater.begin_update(bad, srv)
    assert {:error, :empty_image} = BridgeUpdater.begin_update(empty, srv)
    assert {:error, :image_too_large} = BridgeUpdater.begin_update(big, srv)
    assert {:error, {:read_failed, :enoent}} = BridgeUpdater.begin_update("/nope.bin", srv)
    refute_receive {:sent, _, _}, 50
    assert %{state: :idle} = status(srv)
  end

  test "Bridge nicht verbunden: Fehler ohne Zustandswechsel", %{tmp_dir: dir} do
    name = :"updater_#{System.unique_integer([:positive])}"
    start_supervised!({BridgeUpdater, name: name, sender: fn _ -> {:error, :not_connected} end})
    {path, _} = write_image(dir)
    assert {:error, :not_connected} = BridgeUpdater.begin_update(path, server: name)
    assert %{state: :idle} = status(server: name)
  end

  test "Verbindungsabbruch waehrend der Uebertragung = Fehler", %{tmp_dir: dir} do
    srv = start_updater()
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    ack(seq)
    next_sent("ota_chunk")
    bridge_event(:disconnected)
    assert %{state: :error, error: "Bridge-Verbindung getrennt"} = status(srv)
  end

  test "Verbindungsabbruch in der end-Phase ohne ota_end-Ack = Fehler, nicht done", %{
    tmp_dir: dir
  } do
    srv = start_updater()
    Phoenix.PubSub.subscribe(@pubsub, BridgeUpdater.topic())
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    ack(seq)
    ack_all_chunks()
    next_sent("ota_end")
    assert %{state: :running, phase: :end} = status(srv)

    bridge_event(:disconnected)
    assert %{state: :error, error: error} = status(srv)
    assert error =~ "nicht bestätigt"
    assert_receive {:bridge_update, %{state: :error}}, 500
    refute_received {:bridge_update, %{state: :done}}
  end

  test "ota_end-Ack mit passender seq = done, ein spaeterer Abbruch aendert das nicht", %{
    tmp_dir: dir
  } do
    srv = start_updater()
    {path, _} = write_image(dir)
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    ack(seq)
    ack_all_chunks()
    {end_seq, _} = next_sent("ota_end")
    ack(end_seq)
    assert %{state: :done, error: nil} = status(srv)

    bridge_event(:disconnected)
    assert %{state: :done} = status(srv)
  end

  test "Fortschritt wird gedrosselt veroeffentlicht", %{tmp_dir: dir} do
    srv = start_updater(publish_interval_ms: 60_000, publish_bytes: 1_000_000)
    # 50 Chunks
    {path, _} = write_image(dir, 4800)
    Phoenix.PubSub.subscribe(@pubsub, BridgeUpdater.topic())
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    ack(seq)
    assert length(ack_all_chunks()) == 50
    {end_seq, _} = next_sent("ota_end")
    ack(end_seq)
    assert_receive {:bridge_update, %{state: :done}}, 500

    # begin + Phase end + done, keine 50 Fortschrittsmeldungen
    {:messages, msgs} = Process.info(self(), :messages)
    assert Enum.count(msgs, &match?({:bridge_update, _}, &1)) <= 3
  end

  test "ungedrosselt: Fortschritt waechst monoton mit percent", %{tmp_dir: dir} do
    srv = start_updater(publish_interval_ms: 0)
    {path, _} = write_image(dir, 960)
    Phoenix.PubSub.subscribe(@pubsub, BridgeUpdater.topic())
    {:ok, _} = BridgeUpdater.begin_update(path, srv)
    {seq, _} = next_sent("ota_begin")
    ack(seq)
    ack_all_chunks()
    {end_seq, _} = next_sent("ota_end")
    ack(end_seq)
    assert_receive {:bridge_update, %{state: :done, percent: 100}}, 500

    {:messages, msgs} = Process.info(self(), :messages)
    percents = for {:bridge_update, %{percent: p}} <- msgs, do: p
    assert percents == Enum.sort(percents)
    assert Enum.max(percents) == 100
  end
end
