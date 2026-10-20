defmodule HerzSchwarm.EventLogTest do
  use ExUnit.Case, async: false

  alias HerzSchwarm.EventLog

  setup do
    EventLog.clear()
    :ok
  end

  test "leer: entries ist []" do
    assert EventLog.entries() == []
  end

  test "Eintraege: neueste zuerst, mit Pflichtfeldern" do
    EventLog.log(:info, "bridge", "eins")
    EventLog.log(:error, "effect", "zwei")

    assert [%{message: "zwei", level: :error, source: "effect", at: %DateTime{}}, e1] =
             EventLog.entries()

    assert e1.message == "eins"
    assert e1.level == :info
  end

  test "Ringpuffer ist auf 500 Eintraege begrenzt" do
    for i <- 1..650, do: EventLog.log(:info, "t", "msg #{i}")
    entries = EventLog.entries()

    assert length(entries) == 500
    assert hd(entries).message == "msg 650"
    assert List.last(entries).message == "msg 151"
  end

  test "identische Folgemeldungen innerhalb 1 s werden zusammengefasst (n) und nicht publiziert" do
    Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, EventLog.topic())

    for _ <- 1..20, do: EventLog.log(:warn, "bridge", "gleich")

    assert [%{message: "gleich", n: 20}] = EventLog.entries()
    assert_receive {:event, %{message: "gleich"}}
    refute_receive {:event, _}, 50
  end

  test "andere Meldung dazwischen unterbricht die Zusammenfassung" do
    EventLog.log(:info, "a", "x")
    EventLog.log(:info, "a", "y")
    EventLog.log(:info, "a", "x")
    assert length(EventLog.entries()) == 3
  end

  test "publiziert {:event, entry} auf Topic eventlog" do
    Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "eventlog")
    EventLog.log(:debug, "peer", "hallo")
    assert_receive {:event, %{level: :debug, source: "peer", message: "hallo"}}
  end

  test "clear leert den Puffer" do
    EventLog.log(:info, "a", "x")
    assert :ok = EventLog.clear()
    assert EventLog.entries() == []
  end

  test "ueberlange und nicht-binaere Meldungen werden begrenzt/inspiziert" do
    EventLog.log(:info, "a", String.duplicate("x", 5_000))
    EventLog.log(:info, "a", {:tuple, 1})
    [t, long] = EventLog.entries()
    assert t.message == "{:tuple, 1}"
    assert String.length(long.message) <= 501
  end
end
