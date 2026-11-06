alias PropertyUnitLedger, as: Ledger
alias PropertyUnitLedger.Event
events = [
  %Event{id: "register", unit_id: "DEMO-A12", kind: :register, at: ~U[2026-11-06 09:00:00Z]},
  %Event{id: "reserve", unit_id: "DEMO-A12", kind: :reserve, at: ~U[2026-11-06 10:00:00Z], reservation_id: "hold-1", expires_at: ~U[2026-11-06 12:00:00Z]},
  %Event{id: "double", unit_id: "DEMO-A12", kind: :reserve, at: ~U[2026-11-06 11:00:00Z], reservation_id: "hold-2", expires_at: ~U[2026-11-06 13:00:00Z]},
  %Event{id: "expiry", unit_id: "DEMO-A12", kind: :expire, at: ~U[2026-11-06 12:00:00Z], reservation_id: "hold-1"}
]
result = Ledger.replay(events)
IO.inspect(result.rejected, label: "Rejected updates")
IO.inspect(result.ledger.units, label: "Current inventory")
unless result.rejected == [%{index: 2, reason: :invalid_transition}], do: raise("unexpected rejection report")
unless result.ledger.units["DEMO-A12"].status == :available, do: raise("expiry failed")
