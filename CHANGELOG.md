# Changelog

## 1.0.0

Initial pure event-replay library: explicit deadlines, idempotency, reservation ownership, terminal states, per-unit ordering and accepted-event audit history. No runtime dependencies or persistence layer.

## 1.2.0

- Add `replay_atomic/2`: commit a complete import or retain the complete original state, with every indexed rejection.
- Retain original partial replay and duplicate-event semantics; document transaction limits and a runnable corrected-retry scenario.
