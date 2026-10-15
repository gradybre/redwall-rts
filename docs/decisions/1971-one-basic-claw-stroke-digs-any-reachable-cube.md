# 1971 — One basic claw stroke digs any reachable cube: scoping, stopped for rulings

Date: 2026-10-15 · Status: Accepted. Brendan ruled P-1971-1 (b), P-1971-2 (a) and P-1971-3 (b) on 2026-10-15
(see "Brendan's rulings"). Phase 2 (the build) follows in this record's later sections and in 1972 onwards.

Number range: 1971–1989 was allocated to this lane by the coordinator, and checked free on every local and remote
ref and with `decision_numbers.py`. This is the lane record; later records of the lane take 1972 onwards.

## Brendan's direction (2026-10-15, in chat to the coordinator)

- Slice C: **"Real digging, in full"**. Confirm all must eventually dig in the real game.
- Then: **"I just want the basic claw stroke that digs anything."**

As relayed: one basic claw stroke, accepted for any cube within the mole's reach, whatever face it strikes, and
used for the entry, the tunnels and the rooms. It replaces ADR 1217's plan of separate stroke families (M1 down,
M3 front, M2 high). No family of strokes and no long motion-review pipeline.

## Brendan's rulings (2026-10-15, relayed by the coordinator)

| Proposal | Ruling | What it means here |
|---|---|---|
| P-1971-1 | **"Approve"**: (b) | The four wall rows are derived from M1's approved clips. M1 stays the one stroke |
| P-1971-2 | **"Approve"**: (a) | The floor scrape is allowed only into natural, unowned earth, inside the row's own 61 u below-floor stroke box |
| P-1971-3 | **"Painted height"**: (b) | Each cell's column is dug to the room's full height. The mole claws the bottom, and the upper earth is dug and paid as part of the same work, with no separate stroke. **This amends DEC-054.** Rooms must fit every species |

Recorded as Brendan's ruling in `docs/setting_decisions.md` (DEC-054, addendum of 2026-10-15) with his two direction
quotes, and indexed in `docs/handoff/RULINGS.md`.

### The painted height, from adopted values only

- **The height.** SET-BUILD-001 §3 and §7.2 adopt the level pack's clear height, `clear_height_u` 4,096 u
  (`godot/data/underground/initial_level_pack.json`; DEC-061 Q6's 5 m spacing, 4 m clear and a 1 m band).
  A painted underground cell is therefore dug to **4,096 u = 4 quanta**. No new constant is introduced.
- **Every species fits** (DEC-039). The badger is 2,611 u, leaving 1,485 u of headroom; the otter is 1,526 u, the
  squirrel 1,178 u, the mouse 1,024 u and the mole 922 u.
- **The bill per painted cell**, at DEC-059's rates (BAL-UG-001), is SET-BUILD-001 §7.2's table, now the actual
  price rather than a ceiling:

| Per painted underground cell | Arithmetic | Value |
|---|---|---|
| Wood | 4 × 250 | 1,000 milli-U |
| Stone | 4 × 250 | 1,000 milli-U |
| Work | 4 × (940 + 1,880 + 1,410) | 16,920 milli-WU |
| Earth output | 4 × 2,000 | 8,000 milli-U `excavated_earth` |

  So a 2 × 2 Passage patch is 16 quanta: wood and stone 4,000 milli-U each, 67,680 milli-WU and 32,000 milli-U of
  earth.

### Column digging (engineering, derived)

The ruling is implemented as a rule about **which cube the claws strike** (the struck cube) versus **which cube is
paid** (the target):

- **Direct.** When the work row's anchor lies inside the target cube's own band, the struck cube is the target. This
  is every top-face dig, every floor-band wall dig, and the dormant pick's HIGH and FRONT digs.
- **Column.** When the target lies above the floor band of its column, at a whole number of quanta above the stance
  floor, and the anchor lies in the floor band, the struck cube is the column's floor-band cube. The planner places
  the station for that cube, and WorkFace proves the contact and patch on it.
- **Bottom-up.** The struck cube and every cube of the column below the target must already be open
  (SUPPORTED_VOID). So a column is dug from the floor up: the claws strike the bottom cube while it is earth, and the
  upper quanta are then worked from the same station with the same stroke. The frontier's key order is already
  bottom-up (`key = (y·Z + z)·X + x`).
- **What is still proved for an upper quantum.** Everything in the physical part of WorkFace: support, body,
  approach and recovery in open air, the stroke in open air or the target, the floor scrape's limits, and the
  protected roof band. What is not physically met is only the upper quantum itself, which is what the ruling
  accepts ("the upper earth is dug and paid as part of the same work, without a separate stroke").
- **`reachable_height_u`.** It returns `UNLIMITED_HEIGHT_U` (`Space.I32_MAX`, "the stroke sets no limit") once the
  identity has a side-face dig row whose anchor lies strictly inside the floor band. Every caller already clamps with
  the level's clear height (`modular_runtime.gd` `dug_height_u` = min(clear, reach)), and `_level_refusal` keeps a
  Room inside its level, so the price and the plan follow the painted height with no caller edit. On content 10 only,
  a branch labelled LEGACY keeps the pre-1971 band rule (see "The interim" below).

Sections "Decision" to "Proposals for Brendan" below are the scoping as it was put to Brendan; "Phase 2" at the end
records what was built.

## Decision (as proposed, now ruled)

**The one stroke is M1, the approved two-paw claw stroke (ADR 1217 step 1b, candidate pa).** It is not
re-authored. What changes is how it is qualified against a side face:

1. **Wall rows derived from M1's own clips.** Four new WORK rows (one per yaw) are derived from the same approved
   dig clips and the same native image, for a wall ahead of the mole instead of a top face below it. Nothing is
   authored, reviewed as motion or captured again. The rows differ from M1's top-face rows (56/58/60/62) only in
   their derived boxes: the paws in every clip are the stroke, and the contact lies on the wall plane.
2. **One guard is relaxed:** the claws may scrape the earth below the stance plane, inside the stroke's own published
   below-plane box (61 u), when that earth is natural and unowned. M1 always rakes 60 u below the stance plane, so
   at a wall the claws scratch the floor at its foot.
3. **Two predicates are tightened** in the room planner and in `reachable_height_u`: a row counts for a face only if
   its contact patch lies flat on that face. Today both are fooled by the paw seating tap (see "Corrections").

The top-face rows and the entry are unchanged. One motion, one clip set and one image dig every face the claws
reach: top faces through rows 56/58/60/62, and side faces through the four wall rows. Bottom faces (ceilings) are
out of reach: the paws never rise above 484 u.

Brendan rules on P-1971-1 to P-1971-3 below before anything is built.

## 1. Why M1 as published cannot strike a wall: the guards and the geometry

### Measured geometry

Two sources were used:

- **Boxes.** Content 10's actual wire, `first-entry-prefix-v1/qualified-stairs-v9/mole-worker.ugprof`. Yaw 0,
  forward is −z, and units are 1/1024 m.
- **Float probe.** A scratch probe, not committed, skinned the approved clips (`stand-walk-v2/.../dig-pa/`, ready =
  corrected stand key 8) on the open-paw body (`all-cast-v9.ugpal`, `5b368eb3…`). Paws are the triangles weighted
  to bones 15 and 19, as in `derive_claw_rows.py`.

The probe is a decision aid only. Every value that enters a row is re-derived exactly in sub-step 2.

| Part | Forward reach (u) | Height (u) | Source |
|---|---|---|---|
| Rest of body, ready | ≤ 328 | ≤ 839 | probe |
| Rest of body, stroke (`BODY_HELD_LOAD` 462) | ≤ 461 | ≤ 474 | probe, row 56 |
| Rest of body, entry/recovery | ≤ 465 | ≤ 839 | probe |
| Paws, stroke (`WORK_STROKE` 239–589) | 282–588 | −60 to 348 | probe, row 56 |
| Paws below the stance plane | 420–558 | −60 to 0 | probe (row box 415–561, −61) |
| Paws, entry/recovery (inside `TURN_RECOVERY` 597) | up to 596 | 10 to 484 | probe, row 56 |
| Narrow approach / retreat body (rows 43–50) | 521 | ≤ 930 | row 43 |

### Guard by guard (rooms: `underground_work_face.gd`, the room planner, the world bindings)

| Guard | What it protects | What M1 at a wall does | Under this proposal |
|---|---|---|---|
| `patch_refusal`: the whole patch flat on the struck face | The stroke really meets the face it is paid for, with an area, not a point | M1's patch is flat in y at the stance plane. At a wall its anchor sits on the target's *bottom* face, and `_ordinary_contact_face` derives face 2 | **Kept unchanged.** The wall rows carry a patch flat on the wall plane: each claw tip's exact crossing of it (`prove_cardinal_profiles.contact_patch`, axis z, which the helper already takes) |
| `box_refusal`: only `WORK_STROKE` may enter the target; body, approach and recovery need open air | No body or limb inside solid earth | `TURN_RECOVERY` is the union of the entry's body and paws. Its paws reach 596, past the stroke's 588, so recovery always enters the wall ahead of the stroke (1932's reason 2). A runtime cannot tell paws from body in that union | **Kept unchanged.** The wall rows put the entry and recovery paws into `WORK_STROKE`, as the derivation already does for the work clip. Body boxes stay open-air boxes |
| `stroke_refusal`: the stroke may enter only the target; any SUPPORT, or solid outside the target, refuses | No claw cuts the floor, timber or a second cube | M1's paws rake 60 u below the stance plane at 420–558 forward, under the open cell's floor and under the target. That is never the target | **Relaxed** (P-1971-2): stroke volume below the stance plane may lie in natural, unowned earth, within the row's own below-plane stroke box. Installed timber (SUPPORT owned by a Room), protected access, water, resource, occupants and any other claim still refuse. Above the stance plane nothing changes |
| Planner `_fits`: air in void, the stroke also in the target, everything below the floor in SUPPORT | The planned station matches what the contact proof will accept | Below the floor the scrape is in SUPPORT under the open cell. Under the target, the role is still to be measured (sub-step 1) | Unchanged if the earth under a room cell is SUPPORT. Otherwise relaxed exactly like `stroke_refusal` |
| Planner `ROOM_STATION_VERTICAL_FACE` (faces ±Y refuse) | Room stations stand on the Room floor only | Nothing | **Kept.** Rooms are dug from the side. A room's top layer lies under protected earth (ADR 1220), and ceilings are out of reach |
| Planner `_work_row` / `_anchor` / `_reaches` | The work row's anchor is ahead of the stance and inside the cube's band | Accepts the paw seating tap (row 57/59/61/63, anchor 128 u) for a side face; the contact proof then refuses its y-flat patch | **Tightened:** the row's CONTACT_PATCH must be flat on the face's axis |
| `reachable_height_u`: band of a dig row's anchor | DEC-054's height derived from published rows | Counts only the tap rows (anchor 128 → 1,024 u); M1's anchors at 0 are excluded | **Tightened** with the same patch-on-a-side-face predicate. For claws it becomes 1,024 u from the wall rows |
| Body air, Location air, the 930 u travel body and the protected roof band | No swing through earth or the roof band | All ≤ 840 u, under a 1,024 u room's own top | Unchanged |

### Where the mole stands: derived, not chosen

The station is the nearest place where every box except the stroke stays out of the wall. Two candidates bound it:

- the arriving travel row, the narrow approach (rows 43–46), whose body reaches **521 u** forward;
- the dig row's own body: 462 u at work, about 465 in entry and recovery.

So the wall stands 521 u ahead of the root. Sub-step 2 re-derives the value exactly from the rows the planner selects.

**What it looks like there (probe):**

- **Stroke:** the paws enter the wall up to 67 u, on all 33 stroke keys, from the floor to 283 u up.
- **Entry and recovery:** the paws enter up to 75 u, from 10 u to 374 u up.
- **Floor scrape:** the claws rake 60 u into the floor along forward 420–558, from 101 u in front of the wall foot to
  37 u under it.
- **Posture:** the mole is M1's: leaned 70°, head lifted, raking at the base of the wall.

Whether that reads as digging a wall is for Brendan, from the frames (phase 2 gate).

## 2. Room height and the bill

With one floor-level stroke, the claws meet only the cube band from the floor to 1,024 u. DEC-054 ("a Room is
excavated only as high as the dig strokes reach") therefore gives **1 quantum per painted cell, a room 1,024 u
high**.

The per-quantum bill is BAL-UG-001 at DEC-059's rates:

| Per painted cell | Wood | Stone | Work | `excavated_earth` out |
|---|---:|---:|---:|---:|
| 1 quantum | 250 milli-U | 250 milli-U | 940 + 1,880 + 1,410 = **4,230 milli-WU** | 2,000 milli-U |
| Example: 2 × 2 Kitchen, 4 quanta | 1,000 | 1,000 | 16,920 | 8,000 |
| Example: Passage 2 wide × 10 long, 20 quanta | 5,000 | 5,000 | 84,600 | 40,000 |

**Consequence Brendan must see.** By DEC-039's heights:

| Species | Height (u) | In a 1,024 u room |
|---|---:|---|
| Mole | 922 | Fits; its travel body is 930 u |
| Mouse | 1,024 | Exactly the room's height, no headroom |
| Squirrel | 1,178 | Does not fit |
| Otter | 1,526 | Does not fit |
| Badger | 2,611 | Does not fit |

DEC-061 adopted 5 m levels with 4 m clear. Under the literal DEC-054 rule, every underground room and passage is
mole-height. P-1971-3 asks whether that is acceptable.

## 3. The entry, the descent and the tunnels

- **First-entry prefix and descent trench.** These are L0/T0's six cubes and the eight trench cubes, rows 4–7. They
  are dug on top faces from the surface stations at ±1,430 u with rows 56/58/60/62, through
  `underground_connector_contacts.gd`, not WorkFace. They already use the one stroke, and nothing in their
  qualification changes. Their bundle still needs a mechanical successor, because adding rows changes the profile
  wire it links (sub-step 4).
- **Treads and the sill.** These are fitted by paw (row 64, DEC-060). That is not digging, and nothing changes.
- **Tunnels.** Under DEC-061 Q4, tunnels are painted Passages, which are rooms. They are dug through the room path
  with the wall rows, 1 quantum high under P-1971-3 (a).
- **Shafts or stairs to a lower level** (slice D). A cube below an open cell is dug on its top face from the floor of
  an adjacent open cell, which is exactly M1's top-face geometry. Rows 56–62 serve it unchanged.

## 4. The authoring and presentation path

**How M1 was made** (ADR 1217 steps 1–6, `mole-worker/claw-work-v1/`):

1. `author_claw_stroke.py` / `author_claw_pair.py`: the pose recipe. It uses the open paw and the corrected stand
   key 8, a lean and hip drop, and a fixed-length arm solve aimed at the claw tip. A 33-key elliptical rake loop runs
   from 80 u above the face to 60 u below (`TOP_U`, `DEPTH_U` constants), with a 31-key entry and its exact reverse.
2. `probe_claw_pair.py`: a bounded search.
3. `prove_claw_pair.py`: exact Q24 provers for the contact crossing and patch, the below-face hull inside the target,
   world prisms with sole support, and self-clearance.
4. `render_claw_pair.py`: the review packet; Brendan approved pa.
5. The corrected ready re-proof (`stand-walk-v2/dig-pa`).
6. The native capture (`native_claw_stairs.py`, image `b85f9195…`).
7. `derive_claw_rows.py`: the rows.
8. `publish_*`: the content.

**Can the packet re-qualify the stroke? Yes, without authoring.**

- Rows: `derive_claw_rows.py`'s helpers (`endpoint`, `rows_of`, `masks`, `stance`) are reused unchanged. Its
  `contact` searches the work clip for a downward crossing. A successor searches the entry for the claw tips' forward
  crossing of the wall plane, with the same `contact_patch` at axis z. `dig_roles` gains the variant that moves the
  entry and ready paws into `WORK_STROKE`. The capacity check (≤ 12 boxes) still holds: the rows grow from 11 to at
  most 12 boxes.
- Proof: `prove_claw_pair.py`'s world-prism prover is run against a wall fixture. The fixture is the target cube at
  the derived distance, the open cell's floor support, and the earth under the target. Its rules change as the
  runtime's do: the paws may lie in the target, and below the stance plane only within the stroke's box in natural
  earth; every other triangle stays in open air, with sole support. Self-clearance is already proved: the clips are
  the same.
- No new motion means no motion review, and no new image means no native capture.

**Presentation.** The per-source actor (ADR 1201/1211) draws source 4, the open-paw claw image, from the row the
simulation selects, through the claw program's row-to-clip map. The wall rows map to the existing dig clips, so:

- there is no new actor, image or body;
- the open paw is already the claw image's body;
- only the row map changes: the runtime program successor, and `mole_claw_program.gd` if the demo mirror names rows.

The phase 2 frames come from a capture script outside `demo/`, as `claw-work-v1/native/capture_claw_native.gd`
did, so no demo file is edited.

## 5. Sub-steps, after the rulings (for P-1971-1 (b))

1. **Measure** on the ADR 1161 room fixture and the planned level authoring:
   - the Space role under a room cell's floor;
   - whether the Space owner's phase qualification accepts a below-plane ENVELOPE row over natural SUPPORT.

   If the answer is no, the scrape needs a Space-owner change (`underground_space_owner.gd`, not this lane's file),
   and the coordinator is told before going on.
2. **Offline rows and proof** (`claw-work-v1/`):
   - `derive_claw_wall_rows.py`: the wall distance, the paw split, the wall contact and the quarter turns;
   - `prove_claw_wall.py`: the wall fixture;
   - `test_*.py`: byte-for-byte rebuilds.
3. **Content 11** (`mole-worker/publish_claw_wall_runtime.py` → a create-only `qualified-claw-wall-v12/`):
   - content 10 plus the four wall rows in source 4's block;
   - if the sort moves paw handling 65/66, the publisher renames them, as content 9 did;
   - Python publisher tests and a Godot loader test (`test_mole_claw_wall_profiles.gd`).
4. **Runtime successor:**
   - `qualified-claw-runtime-v3/claw_program.gd`, with the row map;
   - the catalog source pins;
   - the bundle successor `first-entry-prefix-v1/qualified-stairs-v10/`: content 11, same geometry;
   - activation in Catalog/Session;
   - `tools/renew_source_pins.py --write`;
   - the memory census: the profile bank grows by about 3.5 KB inside `PROFILE_BYTES` 278,528, to be measured;
   - ADR 1240 checkpoint fixtures regenerated.

   **The Routes dispatch by digest is in the routes module, which the cost lane owns.** The coordinator sequences
   it.
5. **Guards** (this lane's files):
   - `underground_work_face.gd` `stroke_refusal` and `FinishCheck.stroke_blocked`: the scrape allowance;
   - `underground_room_station_planner.gd` `_work_row`: the patch-on-face predicate;
   - `_fits`: if sub-step 1 requires it;
   - `underground_room_approach.gd` `reachable_height_u`: the side-face predicate.

   Each gets tests and mutation tests. The synthetic room-approach and modular-access fixtures (anchor 512 u) must
   be checked: if their patch is y-flat they lose their height, and their tests change.
6. **Fixture proof:** the ADR 1213 loop on content 11 with the claw identity. A 1-quantum room is dug cell by cell
   with exact ledgers. It drives the planner and WorkFace only, not C2.1's foreman.
7. **Frames:** the stroke on a top face (an entry station) and on a wall, at 1280×720 and 1920×1080, into
   `scratchpad/claw_check/`.
8. **Gates:** as listed in the lane brief.

`underground_room_world_bindings.gd` is not expected to change, because the wall rows satisfy
`_ordinary_contact_face` as published. If it does, the coordinator is told first.

## Corrections to decisions 1931/1932 (on `feat/room-foreman-slice-c2`; for the coordinator to merge)

- Content 10's rows 57/59/61/63 are the **paw seating tap** (INSTALL; anchor (128, 128, −448), as pick row 16), not
  an M1 stroke 128 u up. The dig rows are 56/58/60/62 (`qualified-claw-stairs-v11/catalog_source.gd`
  `CLAW_DIG_ROWS`). 1932's row-63 column is the tap.
- `reachable_height_u` reports 1,024 u for the claw identity **because of the tap rows**. The dig rows' anchors at
  y 0 are excluded by its `anchor % 1024 != 0` test.
- For a side face, the planner would plan the tap row first (row 57 precedes any appended wall row), and the
  contact proof would then refuse it. Sub-step 5 closes this.

1932's three reasons stand for M1 as published. This record answers them with derived rows, not new motion.

## Proposals for Brendan

**P-1971-1 — How the one stroke digs a wall.**

- **(a) Relax the runtime only, keeping M1's published rows.** Accept the y-flat patch at a wall. Let recovery and
  approach boxes into the target for rows 56–62, under an offline certificate (as `Handling.tap_certified`). Allow
  the scrape. There is no content change, but the excuse must be repeated in every owner that proves air:
  - WorkFace;
  - the planner;
  - station publication and Locations;
  - the world bindings' approach rows;
  - `_ordinary_contact_face`.

  Several of these are other lanes' files. A runtime can never check the paw/body split it relies on.
- **(b) Recommended: M1 unchanged, with derived wall rows (above).** There is no new motion, review or capture, and
  one guard is relaxed (P-1971-2). It costs a content successor and a bundle successor, as contents 7–10
  were.
- **(c) A shallower re-pose of M1 for walls** (the same recipe, the rake stopped at the stance plane). No guard is
  relaxed, but it means a second clip set, a review packet and a native capture. Either the entry keeps M1, which
  makes two near-identical motions, or the entry moves to the re-pose with top faces accepted by touch, plus a
  Frontier successor.

**P-1971-2 — The floor scrape** (needed by (a) and (b)).

- **(a) Recommended:** allow it. The claws may enter natural, unowned earth below the stance plane, only within the
  row's own below-plane stroke box (61 u). Never installed timber, protected access, water, resource, occupants or
  another claim. This follows DEC-060's tolerance: "does not need to line up perfectly", with physical safety kept
  for the body.
- **(b)** Refuse it, and take P-1971-1 (c).

**P-1971-3 — Room height with one floor-level stroke.**

- **(a) Recommended for this slice:** the literal DEC-054 rule. Rooms and passages are 1 quantum (1,024 u) high and
  billed as in §2. Only moles (and, without headroom, mice) fit.
- **(b) Column digging to the painted height.** From the floor station of a cell, the same stroke works every
  quantum of that cell's column, bottom first. The claws physically meet only the bottom quantum, and the upper ones
  are paid without contact. This amends DEC-054. It needs a no-contact mode for the upper quanta in WorkFace and the
  planner, in the spirit of DEC-060. The bill scales with the painted height: 4 quanta per cell for a 4 m clear
  level, 16,920 milli-WU per cell.
- **(c)** A second, higher stroke. This contradicts "one stroke". The claws reach at most about 1,060 u (ADR
  1217), so it still could not honestly reach 2 m.

## Consequences

- No code or content is changed until the rulings. The lane stops here.
- ADR 1217's motion plan carries a note: M2 and M3 are not authored. The one stroke is M1 (this record).
- The C1 ledger and C3's order route (P-C2-3 (a)) price rooms with the claw identity at the height P-1971-3 gives.
  That is their change, not this lane's.

## Source

- Brendan's direction of 2026-10-15, as relayed by the coordinator.
- DEC-039, DEC-052, DEC-054, DEC-059, DEC-060 and DEC-061 (`docs/setting_decisions.md`).
- ADRs 1188, 1201, 1211, 1213, 1215, 1217, 1220, 1229 and 1240, and decisions 1931/1932 (branch
  `feat/room-foreman-slice-c2`).
- The code at `84393c21`: `underground_work_face.gd`, `underground_room_station_planner.gd`,
  `underground_room_approach.gd`, `underground_room_world_bindings.gd` and `underground_connector_contacts.gd`.
- Content 10's wire, decoded with a scratch reader (not committed).
- The float probe of the approved dig clips (scratch, not committed; method in §1).

## Phase 2 — what was built (2026-10-15)

Scope, set by the coordinator: content 11 published but **not active**, the guards landed, and the cleared one-call
changes B, C and D. Activating content 11 is a separate, ADR-1229-sized lane that starts after the cost lane merges
(its inventory is below).

### The wall rows (offline, `claw-work-v1/`)

- `derive_claw_wall_rows.py` → `evidence/claw-wall-rows-v1/rows.json`.
  - It applies `derive_claw_rows.py`'s accepted derivation to M1's approved clips (`stand-walk-v2/dig-pa`) and the
    content-10 claw image.
  - The entry's paws join `WORK_STROKE` (12 boxes per row).
  - **W = 521 u, derived** from the narrow approach and retreat rows 43–50. The row's own non-stroke boxes reach
    only 466 u.
  - The contact is each claw tip's first forward crossing of the wall plane, through `contact_patch` on axis z. The
    right tip crosses in the entry; the left, half a cycle behind, crosses in the stroke.
  - Yaw 0: the anchor is (210, 177, −521); the patch is x −225..211, y 71..177, z −521.
- `prove_claw_wall.py` → `evidence/claw-wall-proof-v1/proof.json`: **clear**. It uses the accepted Q24 hulls, the
  sole rule and `separated_box`.
  - The fixture is a wall: the target cube is centred in the lateral window that holds the whole stroke box, with
    the cell's floor support, the earth under the target, the neighbours, the cube row beyond, and the earth above.
  - Stroke: 11,229 pairs, of which 384 are soles, 9,024 are paw-in-target and 1,821 are paw scrape; none is
    unresolved.
  - Entry: 4,325 pairs, of which 484 are soles and 3,841 are paw-in-target; none is unresolved.
  - With the target open (an upper quantum's work), the pairs are a subset and are also clear.
  - Limb self-clearance is the approved `dig_pa` record of the same clips.
- `test_claw_wall.py`: 10 tests, including byte-for-byte rebuilds of both records.

### Content 11 (`mole-worker/qualified-claw-wall-v12/`, create-only, data only)

- `publish_claw_wall_runtime.py`: content 10, plus the wall rows **67–70** (yaws 0..49152) with M1's words.
  - The rows are appended after source 5, so no published row ID moves. Profiles orders keys within each source
    only (ADR 1198), and source 4's same-key run is 13 of the 16 allowed.
  - Wire `2913e9ba…`: 71 rows and 595 boxes. The paired bank is 47,684 B, 3,472 B more than content 10's.
  - The accessor publishes `CLAW_WALL_ROWS`. The manifest says `runtime_admitted: false`.
- Tests: `test_publish_claw_wall_runtime.py` (6), and `godot/test/test_mole_claw_wall_profiles.gd`, which runs
  through the actual loader and validator and covers the height rule on contents 10 and 11.

### The guards (this lane's files)

- **`underground_work_face.gd`.**
  - `Check.struck` and `struck_origin`: the column rule.
  - `column_refusal` → `WORK_FACE_COLUMN_UNOPENED`: the cubes of the column below the target must be finished
    void.
  - Contact and patch are proved on the struck cube.
  - `stroke_refusal` admits a stroke box lying wholly at or below the stance plane through `scrape_refusal`. What
    the box leaves after void and the target must pass `Terrain.natural_support_refusal` (original dry footing: no
    water, resource or foundation) and lie in quanta no Site ever cut (`ever_cut`, read directly from Sites'
    columns). That excludes installed timber and backfill, which stand in cut quanta.
  - "Natural, unowned" therefore means what the data can prove: never cut and naturally dry. The Room-lifetime floor
    protections are SUPPORT rows owned by the Room, exactly like timber, so ownership alone cannot tell them apart;
    cut history can.
- **`underground_room_station_planner.gd`.**
  - `_patch_on_face`: a row qualifies only if its patch is flat on the face's axis, so the seating tap is never
    planned as a dig.
  - `_reaches` uses the struck cube.
  - `_fits` leaves a stroke's below-floor part to WorkFace. The face refusal is unchanged.
- **`underground_room_approach.gd`.** `reachable_height_u` uses the side-face rule, with the LEGACY branch for
  content 10 only.

### The cleared changes in other lanes' files

- **B: `underground_room_world_bindings.gd` `_ordinary_contact_face`.** The face is derived against
  `Face.struck_origin`.
- **C: `underground_room_frontier.gd` `_face`.** The same change.
- **D: `underground_space_authority.gd` `_contacts_refusal`.** `_on_face` reads the struck cube.

**A latent pre-1971 bug that column digging exposed.** `_face` (C) and `_ordinary_contact_face` (B) pair every WORK
location with every WORK profile.
- A deep cube's station stands inside the near column's dug floor and strikes the plane the two columns share.
- Both functions read that as a strike on the near cube's far face, so a second contact appears: the refusal is
  `ROOM_FRONTIER_AMBIGUOUS_CONTACT` or `ROOM_PHASE_CONTACT`.
- WorkFace's `contact_refusal` would refuse such a pair, because it requires the station to stand outside the face it
  strikes. The two face derivations never checked that.
- It stayed hidden because the near column was always finished before any deep station existed.
- **Fix:** both now apply WorkFace's rule. For a min face, station[axis] < plane; for a max face,
  station[axis] ≥ plane. The coordinator cleared both.

### Results on the dormant pick fixture (content 6)

The only room-loop fixture is ADR 1213's pick fixture. Its FRONT rows strike a side face in the floor band, so it
takes the painted height too.

- **The Kitchen grows from 8 to 16 Sites.** It is 2 × 2 cells to 4,096 u.
- **The loop digs all 16 cubes** with exact ledgers and no refusal: 16 × 250 wood and stone, 16 × 2,000 earth, and
  16 × 4,230 milli-WU.
  - Each column is dug bottom-up: the two lower levels in the old order, then levels 2–3 in key order.
  - Every upper quantum is worked from its column's floor FRONT station. No HIGH station and no per-motion air are
    used in the loop. ADR 1215's per-motion air is still proved by the planner-direct test.
  - The peaks are 71,628 route checks at publication and 254,022 (24 %) at a phase, with 539 Location checks.
- **Tests changed to follow the ruling:**
  - `test_underground_room_station_planner.gd`: `KITCHEN_SITES` is 16. The loop's order and ledgers changed, and
    the confirmation test is now `test_confirmation_digs_the_painted_height`. The v3 upper cube and the
    no-step upper cube now plan the column strike from the floor.
  - `test_underground_room_frontier.gd`: 16 claims.
  - `test_underground_room_approach.gd` and `test_modular_access.gd`: they set their plan heights with an explicit
    clamp, the level's 4,096 u (or one quantum for two capacity measurements), instead of the raw reach.

### The interim (honest): until activation, the game prices 1 quantum

Content 10 stays active, and its claw crew has no side-face row. `reachable_height_u` keeps content 10's pre-1971
band rule in a branch labelled LEGACY, so:
- the demo keeps pricing and drawing **1 quantum (1,024 u) per cell**, from the seating tap's band;
- Brendan's "painted height" ruling **takes effect at activation**, when content 11's wall rows make the claw crew
  report no stroke limit: 4 quanta, wood 1,000, stone 1,000, 16,920 milli-WU and earth 8,000 a cell. This matches
  SET-BUILD-001 §7.2, and the 4,096 u clear height fits the badger's 2,611 u.

The activation lane deletes the LEGACY branch.

### Frames (gate)

`scratchpad/claw_check/` holds frames at 1280×720 and 1920×1080, rendered by a scratch capture script that is not
committed. They show the actual claw image (`b85f9195…`) on the original body, at four keys (entry middle, stroke
start, middle and late), both opaque and with a see-through target.
- **Top face:** the mole at the entry geometry, leaned over the cube's top face.
- **Wall:** the mole 521 u from a wall, its paws in the wall's foot.

The pose reads as clawing at the base of the wall. The step-1b squared shoulder shows a small mesh spike at the
right shoulder in the wall views, as it does on the top face.

### Activation inventory (for the activation lane; file:line at this branch)

Content 10 is bound by revision, row range or digest here:

- **Routes and WorldRoutes:**
  - `scripts/core/underground_routes.gd`: 32 (Claw2 preload); dispatch at 2333, 2359, 2544, 3277, 3697 and 3707.
    This is the **cost lane's file**, near its 262,144-character cap.
  - `scripts/core/underground_world_routes.gd`: 1996.
- **Entry, motion and composition:**
  - `scripts/core/underground_entry_bindings.gd`: 1606.
  - `scripts/core/underground_connector_contacts.gd`: 35.
  - `scripts/core/underground_entry_foreman.gd`: 25.
  - `scripts/core/underground_entry_site.gd`: 10.
  - `scripts/core/underground_entry_composition.gd`: 16.
  - `scripts/core/underground_motion_catalog.gd`: 10.
  - `scripts/core/underground_stair_motion.gd`: 11.
  - `scripts/core/underground_route_composition.gd`: 14 (the bundle).
  - `scripts/core/underground_session.gd`: source digests and `Catalog.CONTENT_REVISION`.
- **Room height:** `scripts/core/underground_room_approach.gd`: 32 and 684 (`LEGACY_CONTENT` and the legacy branch,
  to delete).
- **Content-10 programs and certificates** (successors needed):
  - `data/underground/mole-worker/qualified-claw-runtime-v2/`: `claw_program.gd` (12, 13; row range 42–64),
    `paw_program.gd` (11, 12, 14), `stair_program.gd` (14–16) and `paw_physical_certificate.gd` (23);
  - `qualified-claw-certificate-v2/endpoint_certificate.gd`: 14, 17;
  - `qualified-claw-runtime-v1/grip_certificate.gd`: 15;
  - `qualified-claw-stair-motion-v1/catalog_source.gd`: 7.
- **Catalog and presentation:**
  - `data/underground/mole-worker/mole_profile_catalog.gd`: 13, 16;
  - `mole_claw_program.gd`: 11;
  - `mole_presentation.gd`: 24.
- **Bundle:** `data/underground/first-entry-prefix-v1/qualified-stairs-v9/catalog_source.gd`: 23. The bundle
  successor `qualified-stairs-v10` needs content 11's wire and the same geometry.
- **Demo:** `demo/burrow/modular_runtime.gd`: 20 (`ClawPins` → content 11's accessor). This is the
  **rounded-walls lane's file**.
- **Tests bound to content 10** (about 15):
  - `test_claw_stair_programs`, `test_claw_tread_programs`, `test_mole_claw_stairs_profiles`,
    `test_underground_entry_work_area`, `test_underground_haul_grip`, `test_underground_motion_catalog`,
    `test_underground_paid_assembly_handling`, `test_underground_stair_routes`,
    `test_underground_stairs_bundle_source` and `test_underground_support_clearance`;
  - plus the checkpoints (ADR 1240), the source pins and the memory census.

### Memory (ADR 1212)

- `underground_work_face.gd` and `underground_space_authority.gd` became **projected census inputs**. Their
  manifest-3 bytes are archived under `underground-memory-census-2026-10-06/reviewed-sources/`, and
  `PROJECTION_SHA` and `REVIEWED_SHA` are bumped.
- Reviewed deltas:
  - WorkFace: one retained packet, `Check.struck`, 6 ints, 24 B, carried by its 2,048 B `CONTROL_BYTES`;
  - the space authority: none.
- The frontier and world bindings deltas are unchanged: `{}`.
- The pack is regenerated, and only line numbers move: live with reserve is 100,250,607 B, with 49,749,393 B of
  headroom.
- Content 11's profile bank (+3,472 B) is counted at activation, inside `PROFILE_BYTES` 278,528 (content 10 uses
  262,128).

