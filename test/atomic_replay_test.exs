defmodule PropertyUnitLedger.AtomicReplayTest do
  use ExUnit.Case, async: true
  alias PropertyUnitLedger, as: Ledger
  alias PropertyUnitLedger.Event
  defp register(id, unit), do: %Event{id: id, unit_id: unit, kind: :register, at: ~U[2026-11-07 10:00:00Z]}

  test "valid multi-unit batch commits with the original event order" do
    events = [register("a", "A"), register("b", "B")]
    result = Ledger.replay_atomic(events)
    assert result.committed?
    assert result.rejected == []
    assert Ledger.history(result.ledger) == events
    assert Map.keys(result.ledger.units) |> Enum.sort() == ["A", "B"]
  end

  test "one rejection rolls back units, seen IDs and accepted journal together" do
    initial = Ledger.replay([register("original", "A")]).ledger
    events = [register("new", "B"), register("duplicate-register", "A")]
    result = Ledger.replay_atomic(events, initial)
    refute result.committed?
    assert result.ledger == initial
    assert result.rejected == [%{index: 1, reason: :already_registered}]
    assert Ledger.apply_event(result.ledger, register("new", "B")) |> elem(0) == :ok
  end

  test "all indexed errors retained without exposing simulated successes" do
    events = [%{}, register("reg", "A"), register("again", "A")]
    result = Ledger.replay_atomic(events)
    refute result.committed?
    assert result.ledger == %Ledger{}
    assert result.rejected == Ledger.replay(events).rejected
    assert result.rejected == [%{index: 0, reason: :invalid_event}, %{index: 2, reason: :already_registered}]
  end

  test "identical retries commit idempotently; changed event IDs reject the whole batch" do
    e = register("reg", "A")
    initial = Ledger.replay([e]).ledger
    assert Ledger.replay_atomic([e, e], initial) == %{ledger: initial, rejected: [], committed?: true}
    result = Ledger.replay_atomic([register("new", "B"), %{e | source: "different"}], initial)
    refute result.committed?
    assert result.ledger == initial
    assert result.rejected == [%{index: 1, reason: :event_id_conflict}]
  end

  test "empty batch preserves state and default replay still retains valid work" do
    assert Ledger.replay_atomic([]) == %{ledger: %Ledger{}, rejected: [], committed?: true}
    events = [register("reg", "A"), %{}]
    assert Ledger.replay(events).ledger.units["A"].status == :available
    assert Ledger.replay_atomic(events).ledger.units == %{}
  end
end
