# Status gate review: death equivalence for Needs section-4 restore

Read-only. No production edit is made or authorized here; nothing was run. Scope is `needs`
(section 4, owner index 9, owner version 2) only. Sources: `godot/scripts/core/needs.gd`,
`godot/test/test_needs_columns.gd`, `status-consistency-observation.md` with
`status_probe.gd`/`status-probe.log`, `authority-excerpts.md` (GDD 302-330, registry 487-509).

## 1. Why extraction alone is insufficient (accepted)

The public witness stands on its own terms: a present row restored with `health = 0` and
`status = STATUS_ACTIVE` is accepted today, `_rebuild_counters` counts it living, and the next
`tick_all()` leaves `status = 5` with `living_count() == 1`. `_integrate_health` decrements only
on a `>0 -> 0` transition, so the counter is never corrected. GDD line 329 requires DEAD at
health 0, so the accepted image is not a legal settlement. Behaviour-preserving extraction of
`_restore_column_refusal` therefore cannot close this owner's semantic gap, and the earlier
feasibility report should not be read as claiming it does.

## 2. The proposed gate

Proposed: for every row with `present == 1`, refuse unless `(health == 0) == (status ==
STATUS_DEAD)`, with a new `COLUMN_HEALTH_STATUS` code, after `_column_free_row_refusal` and
before the living-cap count.

**Placement is sound.** The free-row rule reads only `present == 0` rows; this rule reads only
`present == 1` rows. The two are disjoint, so neither can mask the other and the existing
first-refusal ladder (shape -> byte domains -> value domains -> free rows) is unchanged with the
new code inserted as the fifth rung. Running it before the cap is correct and also cheaper: an
image that fails it never reaches the count.

**It repairs the witnessed counter without touching the counter.** With the gate, the probe's
image refuses; a legal `health = 0` row must carry DEAD, `_living_row_count` excludes it, and
`tick_all()` skips it. The refusal must leave the target byte-identical by `state_bytes()` and
the input `Columns` byte-identical -- never repair the status or recount after publication.

## 3. Is any reachable valid image wrongly refused?

I found none produced by this module's public API.

- `_refresh_status` writes DEAD only under `health <= HEALTH_MIN`, so present + DEAD implies
  health 0. The other direction: health reaches 0 only through `_apply_health_event_checked`
  (which calls `_refresh_status` before returning) or `_integrate_health`, which is the last
  integration in `_tick_resident` and is followed unconditionally by `_refresh_status` when it
  succeeds. `_write_spawn_row` sets health 100 / ACTIVE. `despawn()` clears `present`, so its
  rows are the free-row rule's business.
- The ARCH-SAVE-006 dying-resident fixture (`test_a_dead_but_present_row_survives...`, slot 6
  at health 0, DEAD, present) satisfies the gate and stays accepted.
- No setter (`set_activity`, `set_size_class`, `set_clothing_tier`, `set_airless`, ...) moves
  health, so no setter can desynchronise a row from its last refresh.

One forward risk, not a present defect: `STATUS_LEAVING` and `STATUS_TRANSFERRED` have no writer
anywhere, and the byte-domain rule accepts them. If a later departure owner ever writes
TRANSFERRED on a health-0 row, this gate refuses it. That is a legitimate future conflict to
record, not a reason to weaken the rule now, and it is not grounds to invent departure mechanics
here.

## 4. Other owner-local relationships, and three traps

GDD 329's remaining precedence is owner-local (health, `injury_state`, `activity` are all
columns here), but a partial transcription of it would refuse legal images:

1. `_refresh_status` requires `health < HEALTH_MAX` for INJURED, so a **full-health resident with
   an active injury is ACTIVE**. "Injury implies INJURED" would wrongly refuse.
2. An injured sleeper at health 16..99 is INJURED while `activity != AWAKE`. "RESTING iff not
   awake" would wrongly refuse.
3. `starving_ticks > 0` with hunger above 0 is normal history after feeding; no refusal belongs
   there. Likewise `cold_milli_hours` is unbounded above and carries no status relationship.

A total rule (`status == expected_status(health, injury_state, activity)`) would be exact for
reachable images, but it also forbids LEAVING and TRANSFERRED outright -- a tightening of an
accepted byte domain. **Recommendation: land the death equivalence only in this slice**; route
the total precedence rule to a named follow-up with its own decision record, because it changes
what a save may contain rather than only what a save may mean.

## 5. Purity, helper count, lifetimes

The gate needs one new function, argument-only, reading `present`, `health`, `status` and the
constants `STATUS_DEAD`/`HEALTH_MIN`. It converts to `static` like the existing eight, taking
the call graph to nine helpers plus the root (the earlier report's "eight" miscounted; the
observation note's correction is adopted). `columns_refusal(columns)` must still begin with the
null guard before any dereference, and the new rule must sit behind the shape check, since it
indexes three columns.

It allocates nothing: walk with `present.find(1, i)` as `_living_row_count` does, no `duplicate()`
and no sort. The conservative projection is therefore unchanged at 2 x 57344 bytes for the
transitional Columns plus the largest single 20480-byte i64 sort copy. Those sort copies live in
returning helper calls and are sequential; do not charge them as coexistent, and do not present
any of this as a measured RSS figure.

## 6. What this slice can and cannot certify

**Can certify:** the owner-9 column-image predicate -- shape, byte domains, value domains, free
row residue, death equivalence, living cap -- its first-refusal order, that a refusal mutates
neither the target store nor the input image, that no live store or world is constructed, and
that the public static predicate and `restore_columns()` agree on a fixture matrix.

**Cannot certify, and must not be read as certifying:** any other owner, SAVE-S4-SEMANTICS,
SAVE-S4-CODEC, a full-world restore or a release save. Four separately named follow-ups:
`NEEDS-LIVING-COUNT-TICK-R01` (the tick-time decrement path the gate refuses to reach but does
not fix), `NEEDS-STATUS-PRECEDENCE-R01` (total status rule and the LEAVING/TRANSFERRED question),
`NEEDS-DEPARTURE-DOMAIN-R01`, `NEEDS-DOMAIN-SCAN-R01` (min/max scan replacing the sort copies).

Tests owed beyond the earlier list: health 0 with each of the six non-DEAD statuses on a present
row (refuse); health 1 and health 100 with DEAD (refuse); health 0 with DEAD present (accept);
full-health-with-injury ACTIVE (accept); injured sleeper INJURED (accept); and a precedence case
proving a free-row fault still outranks a health/status fault.
