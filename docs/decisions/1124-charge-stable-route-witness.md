# 1124 — Charge-stable reuse of existing route scratch
Date: 2026-10-04 · Status: Component independently accepted; timing/native qualification failed or open

## Decision

Investigate reuse of the single existing Routes proposed-path buffer for the
static live reachability query. Any reused path must still pass the complete
current endpoint, edge, profile-certificate and selected-source proof. Cold
path output and actual actor searches retain their existing Dijkstra behavior.
No per-worker path map or additional packed bank is admitted.

The returned remaining-check count is part of the caller's finite operation.
A warm result must consume the same logical work as the corresponding fresh
search. Losing derived scratch on reload must not change whether the caller
can complete its operation. Mere path validity cannot establish that property.
The unkeyed witness shortcut is therefore rejected before implementation.

## Measured boundary

The unchanged production source at `bfc414dc` was measured with the existing
actual World/Locations/graph and 256 living callers, O2048 source capacity and
one qualified three-span route. The added test breakdown changes no production
behavior. Clean evidence is in
`docs/validation/evidence/underground-connector-placements-2026-10-03/hot-witness-baseline/`.
Its three strict suites passed 145 tests / 13,840 assertions, with all strict
and raw diagnostics/leaks zero and analyzer zero warnings in five files.

The p95 per 256 calls was 21.888 ms. Two full source/store checks cost 8.347 ms,
Dijkstra 5.331 ms, final chain checks 1.326 ms and selected endpoint/source proof
3.814 ms in the separate helper measurements. These measurement boundaries do
not sum to the complete query. Static eligibility does not include the actual
Contacts owner's terrain, support, occupancy or worker proof.

## Candidate contract

A safe shortcut needs an exact scratch-mutation identity, current query and
graph/source publication keys, and the original deterministic Dijkstra work
debt. It must invalidate on another scratch-writing search, content or graph
publication, restore, mismatched endpoints, or counter exhaustion. The final
complete source proof remains current; a key never substitutes for permission.

Any new scalar controls require source census within the existing Routes and
WorldRoutes reservations before allocation. A hit must spend the same logical
search debt; a miss runs the same existing solver. Tests must compare warm and
cleared-scratch behavior at exact budget boundaries and measure distinct-path
fallback as well as repeated queries. Exact independent source review remains
required before commitment of a runtime change.

## Limits

The measured route-query time remains failed qualification. This experiment
does not adopt motion pace, qualify the first entry, prove an aggregate tick,
or measure native allocation. Source-derived gait and actual physical contact
remain separate authorities. If stable work accounting needs more state or
scope than justified by the measured saving, retain the evidence and decline
the shortcut rather than changing caller readiness.

## Implemented candidate and finite work

The resumed candidate is based on `f6d3bdb3`, after the independently accepted
1125 stationary-ground-turn component. Ownership is Routes, WorldRoutes and
Routes tests only; the parent temporarily owned the separate Locations1129
correction. No Locations/EntryBindings/Transform source change is part of1124.

Routes adds one unsaved I64 scratch serial. Every `_find_path` invocation advances
it before clearing or writing any search buffer, including cold, actor and
failed searches. At I64 exhaustion it becomes zero permanently, disabling this
optimization while preserving the original solver. WorldRoutes adds twelve I64
keys/debt values: actual graph/Space/Locations instance IDs, their three successful
publication receipts, geometry revision, scratch serial, exact profile ID and
profile/content revisions, and the successful Dijkstra work debt. It retains no
object or chain copy. The existing `_proposed_edges` array is the sole chain.

A hit requires all keys and positive receipts, plus the original start's zero
distance and settled state, every full edge generation/from/to chain, mode,
posture and current profile certificate. The final existing full-chain,
selected endpoint/section/source and actual composition checks still run.
Failure or a distinct query uses the unchanged Dijkstra implementation. Current
source truth is never inferred from a key; local physical terrain, body, support,
occupancy and worker obligations remain with actual Contacts.

Both fresh and warm queries reserve `64 * configured_location_capacity` checks
before testing the witness, in addition to the unchanged entry scope and four
initialization passes. This is a conservative probe bound over the strictly
shorter-than-N proposed chain. It is charged on both paths: prior scratch can
belong to a different query of a different length, so charging that prior chain
length would make the new query's remaining allowance depend on query history.
The warm path then charges the exact debt of its original deterministic search.
Fresh search charges its normal operations and records that same debt only for a
successful path; complete-query success alone promotes the keys. This change
raises both fresh and warm admitted query cost by64N compared with1098. It raises
no capacity/operation ceiling, and does not let optimization availability change
caller readiness. Any alternative tighter charge must prove that property too.

## Source census

The reproducible source census is
`docs/validation/evidence/underground-route-witness-2026-10-04/census.py`.
It verifies the exact member additions against the accepted base and retains
individual source-derived numeric frames and nested packets in `census.json`.

| Logical item | Before | Candidate | Existing ceiling |
| --- | ---: | ---: | ---: |
| Topology fixed controls/packets |2102|2110|2112|
| WorldRoutes fixed controls/packets |862|958|4096|
| New retained packed banks |0|0|0|
| Largest reviewed numeric helper chain including48 expression bytes |—|384|512|

The retained logical delta is104 bytes:8 Routes and96 WorldRoutes. All fixed
packed arrays, canonical state, wire formats, actor state, capacities and shared
reservations remain unchanged. WorldRoutes'192 fixed I32 bytes include its
Domain, endpoint, section and five directly allocated outputs. Existing cold
proof/edge-point lifetimes stay separately charged under their original lease.
No borrowed object reference, Variant/array header, VM frame or native allocation
is being represented as measured bytes. The12 targeted analyzer annotations
explain concrete static receiver access that GDScript's `RefCounted` member
analysis cannot resolve; no dynamic observer was introduced to appease it.

## Validation and measured limits

The initial resumed run passed158 tests/14566 assertions and all strict/raw
error/leak gates, but failed the zero-warning analyzer on those12 static-member
false positives. It remains under `hot-witness-resumed-1`; it is not accepted
validation. The next clean run, `hot-witness-resumed-2`, passed165 tests/15300
assertions, zero strict/raw diagnostics/leaks and analyzer0/5 with source,
project and assets unchanged/restored.

Seven additional actual-owner regressions exercise warm/fresh exact-budget
agreement, real cold scratch replacement and graph recertification, two real
same-image restore paths, distinct zero-span endpoints, serial exhaustion,
current mask/full-edge/source changes, and distinct-query fallbacks. The current
Routes module has no completed canonical save API; this is not a claim of whole
route save/load closure. Losing only the derived keys, and the existing actual
Space/Locations restore APIs, preserve the observed finite-query outcome/debt.

The same-run diagnostic has256 actual living residents and O2048 source capacity.
Immutable body/profile certificate flags and explicit test geometry remain
synthetic component fixtures. Twenty256-query batches yielded:

| Workload | Minimum ms | Median ms | p95 ms | Maximum ms |
| --- | ---: | ---: | ---: | ---: |
| Three spans, force a fresh search each call |22.161|22.540|22.892|22.964|
| Same three-span query repeated |17.189|17.379|17.516|17.665|
|256 distinct ordered pairs on a16-endpoint directed ring |36.836|37.690|38.524|38.757|

The ring uses an actual configured32-node graph, real16-edge certificate
publication and zero-through15-span paths; every query advances the scratch
serial, proving fallback rather than an accidental cache hit. It is broader
than the repeated three-span fixture, but is not maximum graph/path qualification.
**All timing qualification remains failed.** This saving does not justify full
searches on every productive worker, a complete simulation tick, target Windows
hardware, or runtime/native-memory acceptance. Independent root review accepted all three final pins, re-ran the source census,
and found no remaining high/medium issue in this bounded candidate. The reviewer
did not duplicate engine execution. This acceptance retains every timing/native
limitation above.
