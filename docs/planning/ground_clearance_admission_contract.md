# Ground travel clearance admission

GROUND-CLEARANCE-R01v1 · accepted bounded repair contract, September20.

Independent architecture review identified a source-proven gap: `profile_clearance_class_into` refuses every current production profile, but `begin_travel` never consults it. Consequently a caller can admit a resident using a route searched with arbitrary clearance. This change binds admission to the existing qualification boundary. It supplies no body dimensions, profiles, physical contacts, footprint offsets, modes, turns, support, leases or playable milestone.

## Exact behavior and scope

Add `Navigation.route_clearance_into(row:int,out:IntMath.IntResult)->bool` alongside route_length_into. As with other route readers, a row that is not READY (invalid/free/pending/cancelled/stale) returns false with existing REFUSE_NOT_READY in both out.error and Navigation.last_refusal, using out.refuse. A READY row returns its actual descriptor's `_d_clearance[_r_route_id[row]]`, using out.succeed, and clears Navigation.last_refusal. Read only: no phase, route reference, queue, descriptor, cache-use or packed state change. This getter is subject to the existing navigation-before-movement tick order; it does not replace missing cross-owner topology transactions or stale-request handling.

Keep existing admission gate order through profile/life-stage/mode/species/load, contact binding/live owner/current location and request readiness. Immediately after request readiness and before route-end/start checks, apply the new gate:

1. Call this Movement instance's `profile_clearance_class_into(admission.profile_id, existing caller-owned IntResult scratch)`. If it refuses, propagate its named out.error as begin_travel's refusal. Current production therefore returns REFUSE_PROFILE_CLEARANCE / PROFILE_CLEARANCE_UNSPECIFIED for an otherwise valid ready request. Do not convert failure to a default class.
2. Capture that successful integer before reusing scratch. Read Navigation.route_clearance_into. An unexpected reader refusal maps to existing REFUSE_ROUTE_NOT_READY.
3. Require exact equality of the profile class and route class. On mismatch return new REFUSE_ROUTE_CLEARANCE constant with value `ROUTE_PROFILE_CLEARANCE_MISMATCH`. Exact equality follows the current profile/graph contract; do not admit a different class under an assumed monotonicity rule.
4. Continue the existing end/start/speed gates and attachment unchanged.

All refusals occur before `_attach_route`, leaving prior motion, cursor/admission state, travelling count, Transform and navigation route ownership unchanged. Diagnostics and scratch may change as usual. Re-admitting an existing traveller with unqualified/mismatched clearance must not detach its valid current route or reset its progress.

Production `profile_clearance_class_into` retains its exact refusal behavior, all four starter profiles remain unqualified, and production code never imports a synthetic test fixture. Add no test flag, override parameter, permissive default, constructor option, alternate public admission bypass, packed field, runtime catalog, schema bump or extra mutable profile authority. Route geometry, PATH-R02 semantics, retained remainder, costs, movement reserved fields and saved-column validators stay unchanged. This changes a missing admission guard; it does not reinterpret saved fields or change graph meaning.

## Synthetic test boundary

Add `godot/test/fixtures/synthetic_ground_movement.gd`, a clearly labelled Movement subclass used only by tests. It overrides the existing profile-clearance reader to return an explicitly synthetic configurable class (default1) for a valid profile; invalid profile IDs retain the parent's refusal behavior. Keep this artificial value local to the test helper, with no production source reference to the fixture. An inherited or explicitly forwarded constructor must preserve the real collaborators and all other production methods. No fixture override of begin_travel or new guard/helper is permitted: tests must exercise real production admission.

The existing test_movement and test_movement_readmission suites can use this fixture for positive reference motion tests. Preserve every prior assertion and scenario. The existing `test_no_profile_publishes_a_clearance_class` must instantiate/test the actual production Movement class, not weaken its expectation or point it at the synthetic override. Label the suites' positive physics/history results as reference movement, not qualified physical travel. Other profile, mode, life-stage and load refusals remain production behavior under the subclass.

Add an independent new suite test_movement_clearance.gd plus a minimal inherited-runner focus script ground_clearance_focus.gd selecting the two existing movement suites and the new suite. It must not copy the whole test runner or inherit all old tests into the new suite. Helpers are typed, documented and bounded; assertions come from the contract, not values obtained from the implementation under test.

## Required witnesses

- Real production Movement on a valid placed resident, current contact and READY class1 route refuses for each of the four starter species, with PROFILE_CLEARANCE_UNSPECIFIED and no observable state/position/count or route ownership change.
- Synthetic class1 admits a real class1 route; synthetic class2 admits a real class2 route. Check actual subsequent advancement, not only return true.
- Both mismatches (profile1/route2 and profile2/route1) refuse with ROUTE_PROFILE_CLEARANCE_MISMATCH and preserve idle state.
- Start valid synthetic travel, advance at least one tick, change only the fixture's synthetic class and attempt re-admission on the mismatched route. Snapshot all available public movement/cursor/admission getters, count, Transform state_bytes and navigation request/descriptor identity/refcount before/after. Assert preservation; then restore matching fixture value and verify continuation. No private mutable accessor is added for tests; source review checks refusal-before-attachment for unexposed packed columns.
- Getter reports classes1 and2 from READY descriptors and refuses invalid, free, pending, cancelled and stale-after-navigation-service requests. Prepopulate IntResult before refusal, and verify explicit error/ok behavior. A successful read after a failed read clears Navigation.last_refusal. Read calls do not change request/route identity/refcount or cache-use state observable through public APIs.
- Refusal priority: earlier invalid profile/life-stage/contact and request-not-ready still win; the new clearance gate precedes route-end/start mismatch as declared.
- All existing motion/readmission tests still execute against the explicit synthetic fixture; real production clearance refusal test remains against the base class. No unrelated expectation deletion or blanket skip.

Parent verification: actual import/focus, exact-source independent review, full regression, specification checks, three scoped counterfactuals (bypass qualification, bypass mismatch, return a fixedclass1 instead of actual descriptor class), committed identity and exact-head CI. Parse/runtime errors are invalid mutation evidence. No native-memory/performance or first-playable claim.

## Ownership

Author edits only movement.gd, navigation.gd, test_movement.gd, test_movement_readmission.gd, the new fixture, new clearance suite and focus script. Astra owns this contract, decision0185, queue, ledger and metadata/evidence. Existing PR175 source and evidence remain frozen; this is a separate branch. No change to diagram/layout or art metadata is part of the code repair.
