# 1193 — An installed WORK contact covers its travel profile's footing and air

Date: 2026-10-05 · Status: Accepted (Brendan chose "widen the landing"). **Revisited 2026-10-06 by ADR 1202
("split the landing"):** the mechanism below stays in force, but the `qualified-landing-v4` Frontier names source 2
as the L0 contact's travel profile. The contact is therefore H-shaped, and the 812 × 812 profile-12 footing and
turn air now belong to a separate arrival behind it, at source-local (0, 0, −664). The widening no longer applies
to L0 itself.

## Problem

After the real L0 install, the new L0 contact (Frontier selector 3, a WORK
contact) records a footing of 573 × 343 units. That is exactly the INSTALL
work stance of profiles 15, 16 and 29: `[-274..299] × [-169..174]`. The Frontier
also names all-yaw walking profile 12 as that selector's travel profile, whose
stance is 812 × 812. Since `0ea4b44a`, WorldRoutes requires an edge's profile
to fit completely inside both endpoints (ADR 1191). No travel edge can
therefore reach the L0 contact. The worker cannot stand on L0 to build T0, and
the stair toward the first Kitchen was blocked. The synthetic complete-prefix
test refused with `WORLD_ROUTE_NO_FITTING_PROFILE`.

The physical L0 deck is 2048 × 2048 (`first-entry-prefix-v1.json`, part
`L0_deck`). The narrow footing came from how runtime derived the contact,
not from the authored structure.

## Decision

`EntryBindings._timber_profile_envelope` derives the WORK contact's footing
and air from its station work profile, as before. It now also unions in the
stance and body boxes of the selector's explicit Frontier travel profile. The
contact is the arrival and departure point of that profile, so its declared
footing must hold it.

No check is relaxed:

- Locations still requires the whole footing to be covered by real `SUPPORT`
  and the whole air to be free of every obstacle.
- WorldRoutes still requires complete containment for every edge profile.
- No structural source, bill, wire or catalog byte changes.

Brendan chose "widen the landing" over authoring a new narrow stance or
re-planning the T0 station. This decision widens the landing contact's
declared footing to the size the real deck already supports. It does not
re-author the deck.

## Evidence

On the branch after this change, paid + entry_world_bindings + work_area: 45
tests, 10,946 assertions, 0 failures, 0 diagnostics, 0 leaks. That includes
`test_complete_paid_l0_t0_prefix_requires_explicit_ground_path_and_preserves_exact_ledgers`
(all six phases, both assemblies, 98,000 mWU).
