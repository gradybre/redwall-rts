# 1195 — Mounting the first-entry owners in the real settlement

Date: 2026-10-06 · Status: Accepted (UG24 composition step; dispatch and demo UI remain)

## Decision

1. **Route composition selects the ADR 1190 entry structure.**
   `underground_route_composition.gd` loads
   `qualified-handling-v1/structure.ugconn` instead of ground-only
   `ground-pace.ugconn`. The structure carries the same twelve ground paces
   plus the L0/T0 variant and regions. The choice is final before the first
   WorldRoutes binding, as ADR 1190 requires. The old "zero regions" header
   loop is dropped, because the exact four-word digest check already pins
   every header field.
2. **`EntryComposition.construct(session, host)` is the fixed wrapper.** It
   loads the bundle's recipes, partition and revision-2 Frontier against the
   mounted Catalog and Profiles, then runs the ADR 1184 stages (prefixes
   10→17). No caller supplies a path or digest.
3. **`UndergroundSession.compose_entry_owners(host)`** and
   **`SettlementSystem.compose_underground_entry_owners()`** mirror the
   surface-anchor step. A refusal before the first retained owner restores
   the surface-ready state; any later refusal stops the Session for
   whole-World retirement. The Session's packet check, `surface_anchor()` and
   `compose_surface_anchor()` now recognise prefix 17.

## Evidence

`test_underground_host.gd::test_actual_entry_owners_compose_from_the_fixed_bundle_without_gameplay_change`
uses the real SettlementSystem. It reaches prefix 17 with Placements,
Contacts, ConnectorWork, Workpieces and Delivery retained, grants no endpoint,
leaves all gameplay bytes unchanged, and is idempotent. Host, session, route
composition, entry composition and UI suites: 159 tests, 0 failures.

## Open

- Nothing in the demo calls `compose_underground_entry_owners()` yet.
- Worker dispatch of the entry episodes on fixed ticks is not wired.
- Row 29 presentation (ADR 1194) is still missing.
- No memory census was taken for the composed readers.
