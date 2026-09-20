# Equipment authority lifetime — EQUIPMENT-LIFETIME-R01v1

September 20, 2026. Accepted for bounded implementation under ADR0187, using the established STOCK-C4-LIFETIME-R01 ownership pattern. This repairs collaborator lifetime, not gameplay rules or save state.

## Evidence and ownership

The source-bound public probe in `docs/validation/evidence/shutdown-leak-diagnostic-2026-09-20/` binds real Gear, Inventory and Residents, drops every external strong owner, observes all three retained, then explicitly unbinds Inventory's equipment authority and observes all three released. Gear strongly owns its collaborators; Inventory must borrow the authority through WeakRef. The composed world owns Gear. Inventory cannot be the reason Gear stays alive.

The full diagnostic passes 5,046 tests and 526,349 assertions while reporting 553 retained objects/33 resources. Printed instance entries total551; that difference is not attributed. The simple current-game boot/shutdown probe exits0 without leak warnings or engine errors. A separate existing settlement test constructs an anonymous SettlementSystem Node as an expected-value fixture and never frees it. These are two proven repair targets, not proof that all retained objects have been explained.

## Exact behavior

Change Inventory's `_equipment_authority` wiring field from Object to WeakRef. No new packed columns, flags, capacity, registry ordinal, save bytes or gameplay policy. Preserve the existing equipment authority API and live-call behavior.

1. `set_equipment_authority` retains existing refusal order: open transaction, missing attestation method, then explicit null unbind with live equipped lots. Failed binding preserves the previous binding. Successful nonnull binding stores weakref(authority); successful explicit null clears the weak wrapper. `clear()` preserves wiring as before.
2. `has_equipment_authority()` is true only when the bound target is live. Never-bound and explicitly unbound have no wrapper. A previously bound expired target retains its wrapper and is a distinct state.
3. At the existing authority gate in both `_check_detach` and `_check_attach`, no wrapper returns existing NO_EQUIPMENT_AUTHORITY; a dead target returns existing INVALID_EQUIPMENT_AUTHORITY. This precedes lot/destination checks just as the former no-authority gate did. It covers both preflight and actual operations. An expired wrapper must never satisfy the presence check and admit attach or preflight.
4. `_attests` returns false for no live target. Resolve the target to a strong local Object for the call; retain the existing `_attesting` reentrancy guard and callback semantics. Gear's production attestation is read-only. No change to attestation truth requirements, reservation/mass checks, rollback or transaction behavior.
5. Audit retains its existing equipped-placement biconditional: a detached lot without a live attestation refuses AUDIT_ORPHAN_LOT. No automatic unequip, reshelving, deletion or normalization after authority expiry. Explicit unbind while equipped lots remain still refuses EQUIPPED_LOTS_LIVE, even after the old target expires. Replacement by a live valid authority retains existing bind semantics.
6. Fix only the anonymous Node comparison fixture in `test_a_new_world_reset_leaks_no_pose_into_the_world_that_follows_it`: name the fresh fixture, obtain the same expected bytes and free it. Preserve all existing assertions and expected gameplay values.

No ownership downgrade of Gear's own Inventory/Directory/Residents references. No warning suppression, cleanup-only explicit unbind used to conceal the production cycle, private store mutation or teardown substitute for the lifetime fix.

## Concrete write ownership

Production: `godot/scripts/core/inventory.gd` only. Existing test cleanup: `godot/test/test_settlement_system.gd` only at the named fixture. New tests: `godot/test/test_equipment_authority_lifetime.gd`, `godot/test/equipment_authority_lifetime_focus.gd`, and engine-generated UID files. Planning/derived records: this contract, ADR0187, the work queue, `docs/planning/registry_capacity_audit.json` if source hashes/line numbers require regeneration, and `docs/validation/evidence/equipment-authority-lifetime-2026-09-20/`. Gear, Residents and existing Inventory/Gear tests are read-only collaborators and regression coverage.

## Required evidence

- Real Gear/Inventory/Residents all release after external owners are dropped, without explicit unbind. A live Gear still keeps its Inventory and Residents alive when external collaborator owners disappear; dropping Gear releases them.
- Live RefCounted and Node authority callbacks still attest. Clear preserves a live binding. Explicit unbind is distinguishable from expiry; invalid binding and transaction refusal preserve prior authority. Explicit unbind refuses with equipped lots.
- Expired RefCounted and explicitly freed Node authorities report unavailable and refuse detach preflight, detach, attach preflight and attach with INVALID_EQUIPMENT_AUTHORITY. Use valid fixtures to reach every gate. Capture all authoritative Inventory bytes before and after each refusal; quantities, identity, placement, mass and reserved mass remain unchanged.
- Detached lot audit after authority expiry refuses AUDIT_ORPHAN_LOT without state changes. A valid replacement restores the existing proof behavior; expiry is not simulated as an unbind.
- Existing callback reentry, equip/unequip and rollback suites remain unchanged and pass. Add a callback lifetime witness if existing coverage cannot prove strong acquisition across the call.
- Counterfactual1 restores the strong ownership edge and must fail the real mutual-release test. Counterfactual2 admits an expired wrapper at the presence gate and must fail a valid preflight/attach witness. Count semantic failures separately from parse or runtime errors; invalid executions do not establish a caught defect.
- Actual focused/full/static checks, boot and verbose shutdown diagnostics before/after, independent exact-source authority/security review, committed identity, exact-head CI and merge. Report residual warnings literally; zero warnings in these runs do not certify all native memory or release behavior.

Tests and diagnostics execute under the one-heavy-local-job limit. No new benchmark, native memory budget or release qualification claim. Local generated audit changes must contain source hash/position updates only, with no packed-state or schema delta.
