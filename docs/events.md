# Event contract

`%PropertyUnitLedger.Event{}` requires nonempty `id` and `unit_id`, an atom `kind` from the fixed vocabulary and a UTC `DateTime` `at`. Optional `source` is informational. No timestamps are inferred. `:reserve` additionally requires a nonempty `reservation_id` and strictly later UTC `expires_at`. `:release` and `:expire` require a reservation ID. A sale of reserved inventory must supply the matching ID.

| Current state | Event | Result |
|---|---|---|
| Unknown | register | available |
| Available | reserve | reserved |
| Available | sell | sold |
| Available | withdraw | withdrawn |
| Reserved | release with matching ID | available |
| Reserved | expire at/after deadline, matching ID | available |
| Reserved | sell before deadline, matching ID | sold |

Other transitions fail. Registering a known unit with another event ID fails. IDs are global within a ledger; use source prefixes where upstream systems have overlapping IDs. Idempotency compares the whole event, including source metadata. Retrying a corrected event under an accepted ID is a conflict; choose a new meaningful event ID.

Error atoms are machine-readable: `invalid_event`, `invalid_event_id`, `invalid_unit_id`, `invalid_event_kind`, `invalid_event_time`, `missing_reservation_id`, `invalid_expiry`, `expiry_not_future`, `event_id_conflict`, `unknown_unit`, `out_of_order`, `already_registered`, `reservation_mismatch`, `not_yet_expired`, `reservation_expired`, `invalid_transition`.
