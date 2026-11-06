# Feed adapter and persistence

The library deliberately has no JSON parser or implicit mapping of provider labels. Map input to a fixed allowed vocabulary; never call `String.to_atom/1` on arbitrary feed values. Parse ISO timestamps with `DateTime.from_iso8601/1`, retain the original source externally and use UTC events.

Persist `history/1` in order. Replaying the same accepted journal into a fresh ledger produces the same state. Preserve event IDs across retries. Rejected records belong in a separate review queue with their source record, input position and error, not in the accepted journal.

For concurrent workers use a transaction, advisory lock or compare-and-swap version check around read/apply/save. A pure in-memory value provides no distributed lock. Keep journals bounded through your own partition/snapshot policy; this library retains all accepted events for audit and duplicate detection.

The same event timestamp is allowed; the supplied order breaks ties explicitly. An upstream source with an older timestamp is rejected even if it arrived later. Repair order in an external review process rather than quietly rewriting timestamps.
