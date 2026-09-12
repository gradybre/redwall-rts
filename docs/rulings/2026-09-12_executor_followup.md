# Claude executor — six Astra follow-up answers

**Resident UI addendum:** [heading geometry and four rate readers](2026-09-12_resident_header_and_need_rates.md).

2026-09-12. Start here for the four restore/layout/movement questions plus alert
profiles and seed-expiry quantity. Preserve the live executor branch and changes.
These are adopted engineering rulings; no runtime implementation or test pass is
conferred by document publication.

## Read and implement

| Question | Decision | Owning contract |
| --- | --- | --- |
| WORLD restore | One validated ten-scalar restore_runtime; no normal setters/events/ticks. Shared operational load guard, exact debt/counters/queue, BOOT publication and disk-backed rollback. | [RESTORE-R01](2026-09-12_clock_restore_and_layout_followup.md) |
| Packed serialization | Column-major for packed stores; explicit3/4/5 block framing and112-byte RNG layout. Preserve declared unused sentinels, not blanket zeroes. Existing command/Chronicle record formats remain exceptions. | [SAVE-LAYOUT-R01](2026-09-12_clock_restore_and_layout_followup.md) |
| Macro detour | Exact-start A* on every exact-start cache miss, existing exact-variant fields/arena. No threshold or nearest-point splice.160 fixture becomes48;2048 quota unchanged; remeasure latency. | [PATH-R02](2026-09-12_movement_dependency_rulings.md) |
| Five omitted dependencies | Explicit asset-envelope, resident-stage, rig/catalog, graph-proof and contact-producer owners. Fixed ADULT0/CHILD1/ELDER2 schema;16 logical rig IDs; generation-safe contact identity. Full G01/G02/G04 and PC-04 remain open where stated. | [MOVE-DEP-R01–05](2026-09-12_movement_dependency_rulings.md), [rig manifest](../planning/species_rig_identity.json) |
| Alert summary scope | NARROW always compact; STANDARD/WIDE prefer complete text with adaptive fitting/fallback in the existing zone. Preserve full selected-notice details and accessibility. | [ALERT-R02](2026-09-12_alerts_and_seed_expiry.md) |
| Expired seed quantity | Checked floor(q_milli*seed_mass/compost_mass), currently floor(q_milli/10), per lot. Remainder is decay loss; zero output retires seed. Atomic reservations and sink/source ledgers. | [STOCK-SEED-R01](2026-09-12_alerts_and_seed_expiry.md) |

The old handoff's omission of the macro detour and these dependency owners is
corrected here. A missing rig is a presentation/export gap, not authority to deny
legal simulation. A missing clearance/profile/contact contract IS a movement
admission blocker. Do not substitute one for the other.

## Dispatch with explicit file ownership

1. **Clock/save lane first:** clock coder owns sim_clock and focused tests;
   integration lead alone owns GameManager/shared restore barrier; save coder owns
   section writers/checkpoint/rollback. Implement RESTORE-R01 before claiming09.3
   continuation. File I/O/checkpoint validation work may proceed independently.
2. **Navigation lane in parallel:** owns navigation and navigation tests. Implement
   PATH-R02, retire the obsolete160 acceptance, preserve its historical evidence,
   verify Dijkstra agreement and remeasure route readiness without increasing quota.
3. **UI lane:** owns notice producers/HUD/shell/layout/details and visual fixtures.
   Implement ALERT-R02 with actual screenshot evidence. Coordinate shared UIManager
   edits with the integration lead; no competing patches to the same file.
4. **Inventory/aging lane:** owns the missing seed-expiry branch and tests; Inventory
   mutation changes remain with its owner. Verify existing transformation API first;
   reuse it rather than creating a second inventory authority.
5. **Resident/asset/contact owners:** implement the bounded fixed-stage identity
   and logical-rig bindings, then author measured envelopes and actual service
   contacts. No child/elder adult-coefficient fallback, invented clearance or fake
   rig completion. Stage/contact additions require owner/section versioning and
   measured registry/ledger updates. FullG01 planning continues in parallel.

Use the established specialized subagents and configured model tiers: capable
reasoning for architecture/integration, bounded coders for isolated modules,
economical test/log execution, independent code and user QA. Give each agent
its exact contract and allowlist; the lead resolves shared ownership.

## Required report back

Return actual files changed, focused test commands/results, codec byte vectors,
clock/queue rollback continuation, Dijkstra cost/latency evidence, alert screenshots,
seed conversion/ledger outcomes and remaining blocked acceptance. Update repository
tasks/decisions/handoffs. No full colony, save parity, asset production acceptance,
movement gate or Windows qualification may be inferred from these rulings.

Planning-only validation is in [the evidence record](2026-09-12_followup_validation.json).
Reproduce specification checks from the repository root with
`python3 docs/validation/validate_executor_followup.py`. These are document and
reference-arithmetic checks, not a substitute for the requested Godot tests.
No paid asset-generation approval is supplied by this package.
