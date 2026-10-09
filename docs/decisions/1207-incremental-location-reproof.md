# 1207 — Incremental Location re-proof: a World preparation re-proves only the endpoints a change touches

Date: 2026-10-06 · Status: Accepted (implements Brendan's 2026-10-06 decision on ADR 1202 blocker 4)

## Decision

Brendan's rule for routes (ADR 1203, implemented in ADR 1205) now applies to Location refresh as well.
In a World preparation (`SurfaceAnchor.create` / `create_in_section`), `Locations.stage_refresh` **carries**
an existing endpoint when nothing that changed since its own proof touches its air (envelope) or footing
(support). Every other endpoint is re-proved in full, exactly as before. The SurfaceAnchor check budget
(`Space.MAX_CHECKS`, 1,048,576) is unchanged.

Other preparation kinds (Room confirmation, phases, installations, plain endpoint refreshes) are not
changed. They do not spend the SurfaceAnchor budget, and none of them hit their own budget.

## Why it was the budget

Every refresh in a World preparation called `_editable`, and `_editable` runs the World scope preflight.
That preflight calls `SurfaceAnchor.prepared_refusal` twice. Each call charges the full source, claim and
terrain final-fact pass, about 28,600 checks. So each live endpoint cost about 57,000 checks, although
none of that work concerns the endpoint itself. The scope's own facts are still proved:

- when the preparation begins;
- at seal;
- at the anchor's own final checks;
- at publication.

A carried endpoint skips only the redundant per-row repetition and the volume proof that the journal
makes unnecessary.

## Mechanism

### The full-view journal

SpaceOwner owns a second `underground_geometry_journal.gd` instance, `_location_journal`, allocated with
`full = true`.

- It is fed at the same single choke point as the route journal: `Journal.record` at `_commit_columns_0`,
  before the bank swap, on every publication path.
- It uses the same ring (256 sides; 64 since ADR 1212), the same overflow floor and the same out-of-sequence reset.

It differs from the route journal in one way. **Every present row is visible**, including a Room's own
reservation marker, which the traversal view omits. A World preparation proves Locations against the full
prepared image (`prepared_snapshot_leased_into`, all claims as OBSTACLE, nothing omitted), so a marker can
block an endpoint there.

The route journal is untouched, so route carrying is byte-identical.

`Journal.staged_clean` applies the same full-view comparison to a sealed stage. It walks only SpaceOwner's
own `_changed_rows`. Every staged region edit marks that index: `stage_add` and `stage_remove` are the
only staged writers of region geometry, and `_overlap_refusal` already relies on the index for soundness.

### The carry test (`Locations._carry_eligible`)

A row is carried only when all of the following hold:

1. **Exact candidate identity:**
   - the token is the open, unsealed World candidate;
   - no retention callback or contact-retirement bracket is active;
   - the original lease covers the preparation;
   - the row is live in both banks with an unchanged payload;
   - the World scope is current by its pure predicate;
   - the Space stage is this sealed token at revision + 1.
2. **Content:**
   - Locations' `_carry_content` is not −1. It is set by the last World publication or load; before either,
     everything is re-proved.
   - The content is unchanged: either the stamp equals the bound connector Catalog content revision, or the
     stamp is 0 because no Catalog was bound when it was set.
   - A *first* binding is not a content change. No earlier proof read any content, and a carried row still
     re-derives its installed witness from the content now bound (see below).
3. **Journal:** `since` is the row's persisted `GEOMETRY_REVISION`, and `floor <= since <= base`. Every
   journaled full-view side after `since`, and every staged side, misses both the envelope and the support.
   FLOOR_DATUM sides are inert, because no volume predicate reads FLOOR_DATUM. A claimed datum reads
   OBSTACLE and is not inert. The row's own section row is re-read anyway (point 5).
4. **Blocker scan:** no blocking row of the sealed full image (`BLOCKING_ROLES`, with claims as OBSTACLE)
   overlaps the envelope.
5. **Identity facts rerun.** The carried row then runs `_validate_record` with `_carry_geometry`. This keeps:
   - format, point and footing-root checks;
   - the live section row: role, claim, level, plane, owner and containment;
   - for Room endpoints, the Buildings Room kind, the Sites/installed-witness observation and the Site scope.

   It skips only the image copy, the obstacle scan and the coverage subtraction. Its `GEOMETRY_REVISION`
   becomes the target. The anchor's checks are not spent.

### Why carried results equal a full re-proof

The row passed some predicate P at `since`. P is not always the World predicate:

- a TRANSIT row may have been proved on the traversal image, which omits markers;
- a Room row may have been proved on the Site image, which omits its own Room and Project claims;
- an installation proof may have exempted the pending bearer.

**Coverage.** The cover rows are the present rows whose effective role is SUPPORTED_VOID or SUPPORT. That
set is the same in every image, because the only rows any image omits are claimed rows, and claimed rows
read OBSTACLE. The journal is clean, so no row meeting the boxes changed box, role or presence after
`since`. Coverage at the target therefore equals the coverage P accepted.

**Obstacles.** Here P and the World predicate can differ, so the blocker scan checks them directly against
the target image.

**Identity facts** are rerun.

The terrain is not an input to an existing endpoint's proof. Only the new anchor's own boxes read terrain,
and those are always proved. A terrain edit reaches existing endpoints only through Space rows, which are
journaled.

The only possible difference from a full re-proof is a refusal of Locations' own operation budget, or of
the fragment arena, that a full proof might have hit. A refusal of the World scope that `_editable` would
have raised per row is still raised, by the same predicate, at seal and at publication.

**Development oracle (removed).** A temporary oracle ran the full refresh after every carry, restoring both
budgets, and compared the codes. It made 2,433 comparisons across the paid-assembly, surface-anchor,
entry-work-area, host, haul-grip, entry-world-bindings, entry-composition, first-prefix,
entry-bindings, support-clearance, Locations, WorldRoutes, Routes, world-retirement,
connector-placements, room-approach and foot-marker suites. There was no mismatch.

## Persistence

**Rebuild, not save.**

- **The journal is not saved.** SpaceOwner restore resets `_location_journal` with its floor at the loaded
  revision, like the route journal.
- **Every live row is re-proved on load.** Locations' own load (`_loaded_rows_refusal`) re-proves each live
  row against the loaded image and then re-stamps `_carry_content`. So no history that predates the load
  is ever relied on.
- **A row whose persisted `GEOMETRY_REVISION` is below the floor** is re-proved in full on its next World
  refresh.
- **The per-row starting revision is already persisted** (`GEOMETRY_REVISION`), so no new column, wire
  byte or schema change is needed.

Registry rows: the journal's full-view instance (category 2, §1 WORLD, unsaved), and Locations' and
SurfaceAnchor's unsaved controls and measurements (category 3).

## Measured (SurfaceAnchor checks per create, of 1,048,576)

| Create | Before | After |
|---|---:|---:|
| First work-area create (no endpoints) | 433,901 | 433,901 |
| Last work-area create (11th endpoint) | 1,001,833 | 775,313 (4 carried) |
| T0 crossing survey (12th endpoint) | refused, `SURFACE_ANCHOR_CHECK_CAPACITY` | **551,353** (9 carried, 2 re-proved) |

- Work-area endpoints sit close together. Their large airs (the ±1256 source-12 sweep) overlap, so each
  new work-area endpoint still touches several older ones. The peak is now 775,313 (73.9%), at the last
  work-area create.
- The survey's air touches only two endpoints.
- A re-proved endpoint still costs about 57,000 checks and a carried one costs none. A create that touches
  k endpoints therefore costs about 434k + 57k·k, which leaves room for touching about 10 endpoints.

**Result.** `test_entry_foreman_runs_the_complete_prefix_from_the_confirmed_prefix` runs only
`Foreman.advance` and passes:

- both groups INSTALLED exactly once;
- wood 0, stone 0;
- spoil 12,000;
- 98,000 mWU;
- conservation refusals empty and audits pass;
- no live Project;
- reachability: source 12 M ↔ arrival, source 2 arrival → contact, source 6 contact → arrival, and
  source 12 refused onto the contact.

## Tests

`test_underground_surface_anchor.gd`:

- **Far create carries without checks.** One and then two carried endpoints cost exactly what a create with
  none costs. After a forced journal reset, three endpoints are re-proved, at more than 150k extra checks.
- **Touched endpoints share the budget.** An overlapping create re-proves; a far one carries both; touching
  two at a 520k budget refuses `SURFACE_ANCHOR_CHECK_CAPACITY` with no partial geometry.
- **A published blocker in an endpoint's air** carries while the blocker is far away. Once a blocker is in
  the air, the endpoint is re-proved and refused with `LOCATION_ENVELOPE_BLOCKED`.
- **A removed footing row** is re-proved and refused with `LOCATION_COVERAGE_MISSING`.
- **Journal overflow forces a full re-proof**, and the next create carries again. A different content stamp
  also forces a full re-proof.

## Rejected

- **Prove the World facts once per candidate instead of per row** (ADR 1202 option 2). Brendan chose the
  touched-only rule.
- **Retire finished endpoints** and **raise the budget** (options 3 and 4).
- **Reuse the traversal journal.** It omits Room markers, which block in the World image.
- **A per-row "proved by the World predicate" column.** The blocker scan makes the carry exact whatever
  image the older proof used, without changing the wire or the arena (228N + 256).
- **Carry without a blocker scan.** That would be inexact for an endpoint first proved on the traversal or
  Site image beside a marker or its own Room claim.
