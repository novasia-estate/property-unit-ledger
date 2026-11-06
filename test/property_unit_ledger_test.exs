defmodule PropertyUnitLedgerTest do
  use ExUnit.Case, async: true
  alias PropertyUnitLedger, as: Ledger
  alias PropertyUnitLedger.Event
  defp event(kind, id, extra \\ []), do: struct!(Event, [kind: kind, id: id, unit_id: "A-12", at: ~U[2026-11-06 10:00:00Z]] ++ extra)
  defp registered do
    {:ok, l} = Ledger.apply_event(%Ledger{}, event(:register, "reg"))
    l
  end
  defp reserved do
    {:ok, l} = Ledger.apply_event(registered(), event(:reserve, "hold", reservation_id: "R1", expires_at: ~U[2026-11-06 11:00:00Z]))
    l
  end
  test "register, reserve, sell and chronological audit trail" do
    {:ok, l} = Ledger.apply_event(reserved(), event(:sell, "sale", reservation_id: "R1", at: ~U[2026-11-06 10:30:00Z]))
    assert l.units["A-12"].status == :sold
    assert Enum.map(Ledger.history(l), & &1.id) == ["reg", "hold", "sale"]
  end
  test "double reservation rejected without changing previous state" do
    l = reserved()
    assert Ledger.apply_event(l, event(:reserve, "double", reservation_id: "R2", expires_at: ~U[2026-11-06 12:00:00Z])) == {:error, :invalid_transition}
    assert l.units["A-12"].reservation_id == "R1"
  end
  test "idempotency and colliding event identity" do
    e = event(:register, "reg")
    l = registered()
    assert Ledger.apply_event(l, e) == {:ok, l}
    assert Ledger.apply_event(l, %{e | source: "different"}) == {:error, :event_id_conflict}
  end
  test "expiration is explicit and deadline equality is expired" do
    l = reserved()
    assert Ledger.due(l, ~U[2026-11-06 10:59:59Z]) == []
    assert length(Ledger.due(l, ~U[2026-11-06 11:00:00Z])) == 1
    assert l.units["A-12"].status == :reserved
    assert Ledger.apply_event(l, event(:expire, "early", reservation_id: "R1")) == {:error, :not_yet_expired}
    {:ok, expired} = Ledger.apply_event(l, event(:expire, "expiry", reservation_id: "R1", at: ~U[2026-11-06 11:00:00Z]))
    assert expired.units["A-12"].status == :available
  end
  test "sale after reservation deadline is rejected" do
    assert Ledger.apply_event(reserved(), event(:sell, "late", reservation_id: "R1", at: ~U[2026-11-06 11:00:00Z])) == {:error, :reservation_expired}
  end
  test "wrong reservation cannot sell or release" do
    for kind <- [:sell, :release, :expire] do
      assert Ledger.apply_event(reserved(), event(kind, Atom.to_string(kind), reservation_id: "R2")) == {:error, :reservation_mismatch}
    end
  end
  test "late updates cannot travel backwards in unit time" do
    assert Ledger.apply_event(reserved(), event(:release, "old", reservation_id: "R1", at: ~U[2026-11-06 09:00:00Z])) == {:error, :out_of_order}
  end
  test "required fields and UTC times validated" do
    assert Ledger.apply_event(%Ledger{}, %{}) == {:error, :invalid_event}
    assert Ledger.apply_event(%Ledger{}, event(:register, "")) == {:error, :invalid_event_id}
    assert Ledger.apply_event(%Ledger{}, event(:foo, "bad")) == {:error, :invalid_event_kind}
    assert Ledger.apply_event(%Ledger{}, event(:register, "bad", at: "2026-11-06")) == {:error, :invalid_event_time}
    assert Ledger.apply_event(registered(), event(:reserve, "bad", reservation_id: "R", expires_at: ~U[2026-11-06 10:00:00Z])) == {:error, :expiry_not_future}
  end
  test "unknown unit and repeat registration" do
    assert Ledger.apply_event(%Ledger{}, event(:sell, "sale")) == {:error, :unknown_unit}
    assert Ledger.apply_event(registered(), event(:register, "second")) == {:error, :already_registered}
  end
  test "terminal states cannot be reserved or silently reopened" do
    {:ok, l} = Ledger.apply_event(registered(), event(:withdraw, "withdraw"))
    assert Ledger.apply_event(l, event(:sell, "sale")) == {:error, :invalid_transition}
    {:ok, sold} = Ledger.apply_event(registered(), event(:sell, "sale"))
    assert Ledger.apply_event(sold, event(:release, "reopen", reservation_id: "R")) == {:error, :invalid_transition}
  end
  test "replay retains accepted work and reports every error" do
    result = Ledger.replay([event(:sell, "unknown"), event(:register, "reg"), event(:register, "again")])
    assert result.rejected == [%{index: 0, reason: :unknown_unit}, %{index: 2, reason: :already_registered}]
    assert result.ledger.units["A-12"].status == :available
  end
  test "release permits a new reservation" do
    {:ok, l} = Ledger.apply_event(reserved(), event(:release, "release", reservation_id: "R1"))
    assert {:ok, _} = Ledger.apply_event(l, event(:reserve, "next", reservation_id: "R2", expires_at: ~U[2026-11-06 12:00:00Z]))
  end
end
