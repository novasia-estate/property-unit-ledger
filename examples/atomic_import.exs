alias PropertyUnitLedger, as: Ledger
alias PropertyUnitLedger.Event

registration = %Event{id: "reg-A", unit_id: "A", kind: :register, at: ~U[2026-11-07 10:00:00Z]}
initial = Ledger.replay([registration]).ledger
new_unit = %{registration | id: "reg-B", unit_id: "B"}
invalid_repeat = %{registration | id: "another-registration"}
result = Ledger.replay_atomic([new_unit, invalid_repeat], initial)
false = result.committed?
^initial = result.ledger
[%{index: 1, reason: :already_registered}] = result.rejected

accepted = Ledger.replay_atomic([new_unit], initial)
true = accepted.committed?
:available = accepted.ledger.units["B"].status
IO.puts("Atomic import: rejected batch retains original inventory; corrected batch commits.")
