# Property Unit Ledger

A small event-sourced inventory component for Elixir applications that receive property-unit availability from several people or systems. It detects double reservations, rejects the wrong reservation holder and preserves exactly which updates were accepted.

It is a pure library: no database, HTTP client, credentials, telemetry or runtime dependencies. Supply events in your chosen order and persist the accepted journal in your own system. Buyer names, prices and contracts do not belong in these records; use opaque IDs.

## Install

Elixir 1.15+:

```elixir
defp deps, do: [{:property_unit_ledger, "~> 1.0"}]
```

Then `mix deps.get`. ExDoc is only a development dependency of this source project; applications consuming the package have no runtime dependency on it.

## A reservation that cannot be sold twice

```elixir
alias PropertyUnitLedger, as: Ledger
alias PropertyUnitLedger.Event

registered = %Event{id: "feed-1", unit_id: "BUILDING-A/1203",
  kind: :register, at: ~U[2026-11-06 09:00:00Z]}
reserved = %Event{id: "feed-2", unit_id: "BUILDING-A/1203",
  kind: :reserve, at: ~U[2026-11-06 10:00:00Z],
  reservation_id: "hold-72", expires_at: ~U[2026-11-07 10:00:00Z]}

result = Ledger.replay([registered, reserved])
result.rejected # []
result.ledger.units["BUILDING-A/1203"].status # :reserved
Ledger.due(result.ledger, ~U[2026-11-07 10:00:00Z]) # one due reservation
```

`due/2` reports a deadline without silently freeing inventory. Apply an explicit `:expire` event identifying `hold-72`, then a new reservation can be accepted. A sale at the exact expiry instant is already too late. A sale while reserved must identify the matching unexpired reservation.

## What makes a feed update unsafe?

* A second reservation for a unit that is already reserved.
* A release or sale identifying a different reservation.
* An event older than the last accepted update for that unit.
* A new payload reusing an existing event ID.
* A deadline that does not follow the reservation time.
* Reopening a sold or withdrawn unit through an unrelated event.

Exact duplicates return the existing ledger unchanged. `replay/2` continues after invalid events and returns their input indices and reasons. Failed events do not enter the accepted journal. For all-or-nothing imports, discard a replay result that has any rejections rather than saving its partial state.

## Use in an agency backend

Map external statuses into the documented event vocabulary, keep the source's event ID and timestamp, and attach an optional source label. Reconcile conflicting feeds with a human policy before replay. Do not sort equal-time events arbitrarily: input order determines the result. Serialize writers or use a database transaction/version check around read/apply/save; two independent in-memory ledgers cannot lock the same apartment.

This library does not establish availability at the developer, validate a deposit, enforce a contract, infer ownership or make a booking legally binding. It keeps your own integration's state consistent with the accepted events.

## Documentation and development

* [Events and transitions](docs/events.md)
* [Persistence, concurrency and feed integration](docs/integration.md)
* [Limits and time semantics](docs/limits.md)
* [Runnable conflict scenario](https://github.com/novasia-estate/property-unit-ledger/blob/main/examples/conflict_review.exs)

`mix test` runs behavioral tests. `mix run examples/conflict_review.exs` demonstrates rejected double booking and explicit expiry. `mix docs` generates reference documentation; `mix hex.build` creates a publishable package.

## Maintainer

Developed by [NovAsia Estate](https://novasia.estate/), which publishes property research and guides for Cambodia, Thailand and Bali. The state machine is jurisdiction-independent and contains no inventory or personal data. MIT licensed; contributions with minimal synthetic reproductions are welcome.

For a separate pre-import validation stage, see [Listing Import Guard](https://github.com/novasia-estate/listing-import-guard). It checks incoming CSV fields; this component handles subsequent inventory events.
