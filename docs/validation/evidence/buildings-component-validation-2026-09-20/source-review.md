# Buildings owner + bridge exact-source review (ADR 0183)

Read-only review of the FINAL repaired `candidate-buildings-repaired.gd` and
`candidate-save_owner_buildings-repaired.gd` against BUILDINGS-S4-VALIDATE-R01 v1, plus a design
audit of the frozen test/mutation/metadata/allocation apparatus. Nothing was executed, imported,
compiled or measured for this document. The combined campaign was still running when the packet
was frozen; no pass, no timing and no resident-set claim is made or implied here. Counts below
are planned contract counts, not observed results.

## Verdict

The repaired predicate and bridge match the contract on every clause I could check by reading:
field set, typed clear values, borrowed constructor, refusal vocabulary, gate order, domains,
retired-versus-never-used discrimination, bounds-before-read, type-specific tier, rotated
footprints and structural-only references. The defects I found are in the surrounding evidence
apparatus and in one asymmetric source pin, not in the ordered predicate. No rearchitecture is
warranted.

## Confirmed against source

* All 29 columns exist on `Columns` with the contract's clear values: `b_origin_tile`,
  `b_construction_slot`, `b_interior_id`, `r_building_slot`, `f_room_slot`, `f_origin_tile`,
  `f_user_slot` fill to -1; the other 22 stay zero from `resize()`. The three allocator helpers
  cover 10/10/9 columns with no omission.
* `Columns._init(false)` returns before the first `resize`, leaving all 29 members empty typed
  arrays. `is_sized()` checks all 29 exact extents, so an unbound or partially bound view earns
  `COLUMN_SHAPE` before any index. This is the whole borrowed-buffer claim and it holds.
* 17 codes are declared and all 17 are reachable: SHAPE, FLAG, and ENUM/VALUE/REF/FREE/STATE per
  domain. `columns_refusal` runs shape, then the four flag buffers in the fixed contract order
  `b_present, r_present, f_present, r_valid`, then ascending building, room, furniture rows.
* Domains read correctly: type 0..29 / 0..8, tier 0..2, rotation 0..3, state 0..5, room type
  0..7, origin -1..16383, offset and count 0..16384, mask 0..511 via `(1 << 9) - 1`, occupants
  0..256, temperature ungated. `_columns_ref_ok` accepts exactly (-1,0) or slot 0..352417 with
  generation >= 1, and consults no Directory.
* Retired history is right. A tier-0 inactive building must be the exact clear row; every other
  row, present or retired, takes STATE, so a retired tier-1 row keeps type and geometry and may
  retain a stale construction reference. Retired rooms clear span/mask/valid and never reach
  STATE. The repaired furniture branch returns early only for the null-parent never-used row and
  falls through to STATE otherwise, which is exactly the fault the initial candidate missed.
* Bounds precede reads. `COLUMN_BUILDING_FOOTPRINT_X/Z[type_id]` and
  `COLUMN_FURNITURE_FLOOR_X/Z[type_id]` are only indexed after the ENUM gate has bounded the id.
  Edge furniture short-circuits on 0x0 before `_columns_extent_fits`. Coordinate arithmetic is
  int64 and `origin_tile / MAP_TILES_X` is integer division on a non-negative value.
* The bridge preloads only Buildings/Schema/Section/SaveHeader, runs the seven gates in order,
  forwards schema and shape refusals unchanged, wraps the raw column code, and keeps the two
  distinct literals `Buildings owner0 metadata:` and `Buildings owner 0 `. `_project_columns`
  performs 29 explicit assignments and calls no `duplicate`, `resize` or serializer.

## MUSTFIX-1 (high): the mutation harness does not name the suite that exists

`run_mutants.py` computes `EXPECTED` from `godot/test/test_save_owner_buildings.gd` and executes
`res://test/buildings_validation_focus.gd`, then requires `int(m[1]) == EXPECTED` for a run to
count as valid. The only owner suite evidenced in this packet is `test_buildings_owner_candidate.gd`
(both probe logs). Two concrete failures follow. If the suite lands under the candidate name, the
`read_text()` raises before the `try` block, so the source-restoration `finally` never runs and no
mutant executes. If the file exists but the focus runner discovers `test_buildings.gd` as well —
which the probe logs show it does for the owner probe — then `m[1]` is 65 against an `EXPECTED` of
6, every row is `valid_execution=False`, and the very first `assert killed if expect_failure else
passed` fails on the baseline. Either outcome is unavailable evidence, not a 75-kill campaign.
Fix by pinning one suite path used for both the count and the discovery list, and asserting that
the focus runner's discovered suite set is exactly that one file.

## MUSTFIX-2 (medium): `Catalog.ROOM_TYPE` is the one unpinned domain dictionary

`_source_state_refusal` was repaired to pin `BUILDING_STATE` by size, key existence, integer type
and exact ordinal, and `FURNITURE_KIND_COUNT` derives from the pinned
`FURNITURE_DEFINITION_COUNT`. `ROOM_TYPE_COUNT` gets neither treatment: it is an independent
literal 8 in the owner, compared to an independent literal 8 in the bridge, with no check on
`Catalog.ROOM_TYPE`'s size or membership. Counterexample: append `"SCRIPTORIUM": 8` to
`Catalog.ROOM_TYPE`. The eight pinned ordinals are unchanged, both literals still read 8, the
30/9 dictionary-size gates are unrelated, and gate 4 accepts. The predicate then refuses a
legitimately catalogued `r_type == 8` as `COLUMN_ROOM_ENUM` with no METADATA signal — the silent
domain divergence the state-ordinal repair was written to prevent. Fix: mirror the state block
with a `SOURCE_ROOM_TYPE_KEYS` array whose length is pinned to 8 before indexing, plus size, key
existence, `typeof == TYPE_INT` and exact ordinal. This adds metadata counterfactuals
(`Catalog.ROOM_TYPE-missing` / `-extra`) and therefore moves the frozen 69/621; it needs an
explicit disposition rather than a silent count change.

## MUSTFIX-3 (low): child-extent comparisons use literals, details use constants

`_metadata_refusal` compares `Schema.child_extent(OWNER_INDEX, 0) != 16384` and `!= 81920` while
reporting `SOURCE_ROOM_CAPACITY` / `SOURCE_FURNITURE_CAPACITY` in the detail. Correcting either
constant would leave the comparison stale and the message confidently wrong. Compare the named
constants. Related and lower: the rotation/state/room/furniture-domain detail in `_source_refusal`
prints only the expected values, never the observed ones, so a drifted `ROTATION_COUNT` yields a
diagnostic that reads as if nothing drifted.

## Test-design audit

* The 46 owner mutants each have at least one frozen witness that inverts. I traced all of them:
  the four flag mutants against `clear-*_present-2` and `clear-r_valid-2`; the priority mutants
  against `later-flag-before-building-enum`, `building-before-room`, `room-before-furniture` and
  `earlier-building-row-before-later-enum`; `first-row-only` and `even-rows-only` against the
  odd final rows 1023/16383/81919 in the sampled sweep; `flag-before-shape` against the
  `field != 0` shape cases, which deliberately set `b_present[0] = 2` while mis-sizing a
  different column; `direct-image-write` against the complete-nonmutation assertions in `_expect`;
  and `overrestrict-retired-construction` against case 171. `building-*` value mutants are killed
  because the bypassed value still reaches a STATE or REFUSE_NONE outcome distinguishable from
  the expected code. 29 projection omissions are killed by `is_sized()` alone.
* The 75 + 1 split reconciles: `run_mutants.py` asserts 77 rows and 75 kills (29 + 46), and the
  allocation unit is separate with its own oracle.
* 87 sampled field/row faults reconcile as 29 fields x 3 rows. The frozen 89 shape cases do not
  obviously reconcile with the draft, which produces 29 x 3 = 87 column resizes, 5 bucket-shape
  cases and 3 null/wrong-owner checks. Publish the mapping before freeze; do not adjust a
  dispositioned count to fit the code.
* The case table is duplicated in `parent-test-draft.gd` (`CASES`) and `frozen-witnesses.json`
  with no cross-check. Dropping one JSON entry leaves both artifacts internally valid while
  coverage silently falls below 171. Assert the case-array size equals 171 in the suite.
* The 69 metadata cases reconcile: 1 control + 46 source faults + 1 Directory sentinel + 20
  schema fault/bypass pairs + 1 forwarding = 69, with 10 bypass kills, and 9 assertions per case
  gives 621. I checked each of the 46 source faults against the candidate's gates and each is
  refused by an existing size, membership, type, ordinal or exact-value pin.
* Full-capacity and all-geometry fixtures are internally consistent: rotated origins land at
  `(128-z)*128 + (128-x)`, edge kinds use 16383, retired rooms clear span/mask/valid, retired
  furniture carries a null user, present rooms keep `offset + count <= 16384`. They are local
  storage images and prove nothing about a coherent saved world; the draft says so and should
  keep saying so.
* Cost note, not a defect: `_expect` snapshots and frames every case, so each multi-megabyte
  fixture is held three times. That is harness cost and must never be conflated with the adapter
  bound. The contract's benchmark-before-any-time-claim rule applies.

## Allocation and memory

The allocation probe fails closed on every prerequisite the contract names: missing OS methods,
non-positive or inconsistent prior readings, out-of-range or failed ballast, ballast that does
not lift current usage above the prior peak, and invalid readings after the call. `evidence` is
populated after the measurement so dictionary growth cannot pollute the increment. Ballast sizing
`prior_peak - prior_usage + LIMIT` guarantees the lift precondition. The default-constructor
mutant allocates 3298304 bytes against a 1048576 bound, so it must trip `ALLOCATION_EXTRA_OWNER`
rather than an unavailable-measurement path — the discriminator is real. It detects one extra
full image and nothing else; it is not RSS and not the 100 MB qualification.

The borrowed claim survives reading: `FramedOwner.u8_column`/`i32_column` return the stored array
without duplication, packed arrays are copy-on-write, and the predicate performs no write, so no
copy is forced. `4150272` fits inside `6417408`, and `2 * 3298304 = 6596608` exceeds it by
179200. Both are allocation arithmetic. Native, metadata and object overhead remain unmeasured.

## Harness isolation

The initial missing-shelf stop was a compile-time constant fold inside an unrelated live
accessor, not a catch; treating it as one would have been a false kill. The owned metadata clone
resolves it with an equal-valued local key in that accessor only, disables autoloads only in its
own disposable copy, and restores every byte in `finally` with a post-hoc equality assertion.
Production source and the normal focus/full runs are unchanged. That isolation is correct and
should not be generalised beyond this one counterfactual.

## Still unverified

Execution of any suite, the mutation campaign, the metadata engine and the allocation tool;
source hashes at merge; `Buildings.EntityDirectory.NULL_SLOT`-style nested constant resolution
from the bridge; native overhead; process memory; BUILDINGS-SAVED-BINDINGS (Directory self
identity, section 5 chains/arena/kind counts, section 1 tile maps and overlap, mask equality,
construction and user links, loaded tick, provenance); bulk capture/apply; occupancy policy;
live construction.
