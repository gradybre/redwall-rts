# 0182 — Movement validation preserves terminal history and readmission counts

Date:2026-09-20. Status: Accepted for bounded implementation.

MOVEMENT-S4-VALIDATE-R01v1 adds a cold16i32-column image, a pure ascending-row predicate and owner8 adapter. Canonical schema order comes from FIELD_KEYS[171..186], not source declaration order. Terminal ARRIVED rows may retain their final velocity, and one-cell admission may arrive with zero targets. Stop clears active movement while retaining valid speed/grid-cell history. Inactive/reused resident rows are not normalized by this local validator.

A separate public regression demonstrates _attach_route counting a travelling row twice on successful readmission. After its last speed refusal, remove that row's old travelling contribution once before reset/attachment. Existing admission refusals remain atomic, other travellers retain their contributions, and immediate arrival clears the replacement contribution. Deferred despawn cleanup and persistent-owner protections stay unchanged. No new route APIs, gameplay modes or schema change are introduced.

Independent feasibility/contract reviews found no public writer counterexample to the local domains. Source pins,156 explicit value cases,49 shapes, every physical field/row and five public regressions are frozen before implementation. The expanded original-source probe has5tests/100assertions/4failingtests; it is defect evidence, not acceptance. The historical public probe4/98 passes.50 semantic code units and21 metadata cases/189assertions remain to run; equivalent reset-order variants are excluded.

Caller32768 plus cold defaults32768 gives65536 conservative logical packed bytes; native/transitive preload costs are unmeasured. MOVEMENT-SAVED-BINDINGS must still join saved residents, section2 cursor terms, navigation routes, transforms and loaded clock/provenance. Bulk capture/apply, connected tunnels/swimming/diving/canopy and MOVE-G01–05 gates are not closed by this milestone.
