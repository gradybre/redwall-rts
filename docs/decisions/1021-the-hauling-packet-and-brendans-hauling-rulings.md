# 1021 — The hauling packet, and Brendan's hauling rulings of 2026-10-02
Date: 2026-10-02 · Status: Accepted (slice H0 of task 06.4)

Numbered from the range the brief assigned (1021–1029); none of 1021–1029 exists on any branch
or sibling worktree (checked 2026-10-02).

## Decision

1. **Task 06.4 gets its packet.** `docs/planning/construction_execution_package.md` -- owned by
   `PLAN-LIVE-CONSTRUCTION`, which did not exist -- now carries the **hauling** packet: Brendan's
   rulings, the specified haul rules with their sources, the haul's life by JobState, destinations
   and contacts, the provisional-clearance plan, the H0–H8 slice plan with file ownership and
   dependencies, acceptance for the built slices and the open questions. The packet's other
   sections (commands, material delivery, upgrades, services) are still owed and say so.
2. **Brendan's rulings of 2026-10-02**, relayed by the coordinator, are recorded here and in the
   packet's §2 as R-H1–R-H7: the provisional clearance class (R-H1, proposal in decision 1024);
   satchels per haul (R-H2) with its two derived rules, the death/departure drop (R-H2a) and the
   cancelled-mid-carry re-post (R-H2b); R1/R2 destinations (R-H3); the lowest-id edge-adjacent
   approach cell and the hall's common-room edge (R-H4); the unload worked in HAUL_OUTPUT (R-H5,
   with an ARCH-JOB-001 note); loads sized at assignment, re-proved at load, one lot per job
   (R-H6); and numbered HAUL_SOURCE / HAUL_DESTINATION purposes (R-H7).
3. **The work queue gains HAUL-H0 … HAUL-H8.** H0–H2 are `review` on `feat/hauling-h0-h2`;
   H3–H8 are `blocked` on their predecessors. H3 also depends on Brendan's confirmation of
   decision 1024 and on DEMOLITION-D6 (which merged to master as PR #219 while this branch was
   open, so that half of the dependency is met once the queue records it).
   `tools/dispatch_plan.py --validate` passes.
4. **GROUND-CLEARANCE-ADMISSION was stale.** The queue held it `in_flight`; it merged as PR #176
   (`043c4da5`, 2026-09-20). It is now `done` with its PR, merge commit and time, and a note.

## Why

- The queue had no 06.4 entry and its owner's packet did not exist, so nothing was dispatchable
  and DEMOLITION-D6's evacuation hauls were refused by name for want of it (decision 0537 P3).
- Recording the rulings in the repository is AGENTS.md's rule: a relayed ruling that lives only
  in a chat is lost the next session.
- **The unload is HAUL_OUTPUT work, not a second WORK** (R-H5): ARCH §6's lifecycle already ends
  WORK with "outputs committed → HAUL_OUTPUT", and a production job's output haul is the same
  carry; one state for both keeps `work.gd`'s WORK meaning "at the work point".

## Consequences

- H3 starts from master after Brendan confirms decision 1024; H4 owns `jobs.gd`/`work.gd`.
- DEMOLITION-D6's refused evacuation hauls become H5's D6b once H4 lands.
- `systems_architecture.md` ARCH-JOB-001 carries the haul phase note.

## Source

Brendan's rulings of 2026-10-02 (via the coordinator); task 06.4; GDD REQ-SET-030–033, 110–112,
134; BAL-CAT-010, BAL-WORK-003/004, BAL-SAFE-002/004/016; INV-GOODS-R01; DEC-043 #9; decisions
0185, 0532, 0534, 0537.
