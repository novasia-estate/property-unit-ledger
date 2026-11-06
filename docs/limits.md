# Scope and limits

The ledger describes the application's accepted inventory events, not an authoritative property register. It does not verify a seller, title deed, construction milestone, payment, legal reservation or actual developer availability. A unit may be marketed elsewhere while this component has stale information.

Expiry does not read the machine clock. Call `due/2` with a UTC instant, then create explicit expiry events through a scheduler that persists successful changes. Due results do not change state. A release may occur after the deadline; a sale through an expired reservation may not.

Sold and withdrawn are terminal in v1. Returns, cancellations after sale, reservation extensions and splitting/merging units require a separately designed event contract. Do not repurpose `register` or reuse unit IDs to hide that history. This version handles no money and includes no country-specific assumptions.
