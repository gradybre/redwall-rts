# 2026-09-12 — ECON-002 per-contributor tool settlement (EH-03 slice of 06.4)

Task: 06_buildings_rooms_logistics.md
Date: 2026-09-12


[Decision 0110](../decisions/0110-tool-wear-settles-per-contributor-inside-the-job.md)
lands the "gear wear" half of 06.4's clause under
[SET-MOVE-ECON-001](../underground_economy_hazard_amendment.md) ECON-002.
`gear.gd` gains a preflighting and a non-releasing wear form beside the existing
end-of-job one; `work.gd` gains a per-resident tool binding, the §5.7 wear carry and
a settlement that charges each accepted contributor's own milli-WU to their own tool
on the tick the point falls due. It also prices ECON-002's two variable-q tip rows,
`ceil(q/4)` to compact and `ceil(q/2)` to reclaim, refusing `q <= 0`.

**06.4 stays unchecked and nothing else in it moved.** Hauling, output/source
reservations, storage filters/minimums/mass limits, carry/ground-pile recovery,
equipment swaps and the task-04 dispatcher integration are untouched by this change.
06.5 is untouched. **No MOVE gate is closed and task 05.1b is not complete**: the
excavation site's phase domain, its work-ready/commit-pending retry condition, its
spoil-output capacity reservation and the `excavated_earth` catalog key all belong
to other owners and do not exist yet.

Two things are owed by owners other than this change, and 06.4 cannot be checked
until they land:

- Registry/architecture rows for the six new `work.gd` columns (10752 B at 512
  residents). `state_registry_coverage.py` fails until they exist.
- ~~A non-allocating `jobs.tool_gate_into()`.~~ **Delivered** by decision 0126:
  `jobs.gd` now publishes `tool_gate_into(job_slot, out) -> bool` and
  `tool_gate_of()` delegates to it. **`work.gd` still does not call it** — that
  file was not on 0126's allowlist, so the productive tick still does not read
  §5.3's tool gate and a tool-required job whose worker holds **no** binding
  still produces work and wears nothing. The behaviour stays pinned by a test.
  What is owed now is one call site plus the header and test update in `work.gd`,
  and that is the EH-03 owner's change, not a missing API.
