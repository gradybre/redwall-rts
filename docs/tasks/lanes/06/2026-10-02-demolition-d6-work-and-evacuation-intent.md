# 2026-10-02 — demolition D6: work under BUILD and the evacuate-then-demolish intent

Task: 06_buildings_rooms_logistics.md (06.2's demolition; REQ-SET-127/128; blocker 4)
Date: 2026-10-02
Ruling: [DEMO-CONTAIN-R01](../../../rulings/2026-10-01_demolition_containment.md)'s D6 row
Decision: [0537](../../../decisions/0537-demolition-work-is-a-build-job-and-evacuation-waits-for-hauling.md)

- **Demolition work is a BUILD Job.** Every admitted removal -- a building's demolition or one
  piece's removal -- gets one BUILD Job (`godot/scripts/core/demolition_work.gd`), posted in the
  planner slot on the tick after admission. Its productive ticks are credited to the project in
  the same tick (`construction.add_work_mwu_into()`, new), refused before anything is consumed
  unless Job and project hold the same outstanding work. When the Job completes, the coordinator
  commits through `complete_demolition()` / `complete_furniture_removal()`; a commit-pending
  refusal is retried on the hour. Cancellation, the stranded-claim door, completion, a building
  gone, a paused project and a player's CANCEL_JOB all retire the Job.
- **"Evacuate, then demolish" is a recorded order.** `order_evacuate_then_demolish()` admits if it
  can; refused for goods or a claim (stages 3 and 5), it records the order and keeps the stranded
  lots in the report. On every hour crossing the order is retried once every container anchored
  on the footprint holds no lot and no claim. Classified UNRESOLVED for saving, like the admission
  record (CONSTRUCTION-SAVED-BINDINGS).
- **Refused, by name: the evacuation HAUL jobs.** Task 06.4 physical hauling does not exist in the
  settlement layer: no resident has a satchel container and no rule says when one is made,
  nothing moves a Job out of RESERVED, and INV-GOODS-R01 forbids teleporting goods. 0537's P3
  asked Brendan how to proceed; he ruled that hauling (06.4) is built next, in its own lane.
- **In the running game** a removal Job is posted, offered and reserved, but never worked:
  nothing writes JOB_STATE_WORK until settlement movement is composed. The bridge, the commit and
  the retries are proven by tests that stand in for arrival.

Brendan ruled on 2026-10-02: P1, P2, P4, P5 and P6 (retry cadence, solo builder, CANCEL_JOB, an
order with nothing to evacuate, a claim-only refusal) approved as recommended; no tool wear for
demolition work for now; P3 "Build hauling (06.4) next" -- a separate lane builds 06.4, and the
HAUL clause stays refused and waiting on it. Memory +16384 B.

No checklist box in task 06 closes with this step: 06.4 is the hauling this step waits for.
