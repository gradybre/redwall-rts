# 1932 — The claw down stroke (M1) cannot open an underground room

Date: 2026-10-12 · Status: Ruled. Brendan replaced P-C2-1 on 2026-10-13 and again on 2026-10-15 ("Brendan's rulings"
below); the universal stroke is decision 1971's. Two facts below are corrected by decision 1971 ("Corrections").

## Corrections (2026-10-15, from decision 1971)

Decision 1971 (commit `fef87161` on `feat/claw-front-stroke-m3`) read the same rows and found two mistakes here:

- **Rows 57/59/61/63 are the paw seating tap, not an M1 stroke 128 u up.** Content 10's dig rows, M1, are only
  56/58/60/62. Every statement below about "row 63" or "the two M1 strokes" describes the tap, not a second stroke.
- **The claws' 1,024 u came from those tap rows.** `reachable_height_u` counts the tap rows (anchor 128 u, band 0).
  It excludes the dig rows, because their anchor sits on y = 0, which is not strictly inside a band. Likewise the
  planner would pick a tap row first for a side face, and the contact proof would then refuse it.

The conclusion is unchanged, because it rests on the dig rows: M1's patch is flat at the stance plane and its
turn-recovery air rises over the patch, so M1 as published cuts only cubes under air that is already open.
Decision 1971 answers this by deriving wall-facing rows from M1's own clips.

## Brendan's rulings (2026-10-13 and 2026-10-15)

The coordinator relayed these; Brendan gave them in chat.

- **2026-10-13, P-C2-1 replaced: "One basic front stroke".** Author one claw front stroke M3 (one family, made at
  one heading and rotated to the other three, under ADR 1217's review), and dig rooms one quantum (1 m) high. Per
  cell: wood 250, stone 250, 4,230 milli-WU and earth 2,000. M2 may add the second metre later.
- **2026-10-13, the C2.1 add-on: "Yes, tests only".** C2.1 may test the foreman's dispatch logic on the ADR 1213
  content-6 retired-pick fixture. It never takes a height or a price from the pick, and production stays claw-only.
- **2026-10-15: "Real digging, in full".** Slice C goes all the way: C2.1 → C2.2 → C2.3 → slice D → C3.
- **2026-10-15: "I just want the basic claw stroke that digs anything."** This replaces the per-face plan (M1 down,
  M3 front, M2 high). There is one basic claw stroke, accepted for any cube within reach, for the entry, tunnels
  and rooms. The `feat/claw-front-stroke-m3` lane (decisions 1971–1989) owns:
  - the stroke content and its profile rows;
  - the work-face qualification (`patch_refusal` and `box_refusal` as they apply to digging);
  - the planner's face choice and `ROOM_STATION_VERTICAL_FACE`;
  - `reachable_height_u`.
- **2026-10-15, room height: "Painted height".** Each cell's column is dug to the room's full height. The mole
  claws the bottom, and the earth above is dug and paid as part of the same work. This amends DEC-054, and rooms
  must fit every species. The stroke lane publishes the quanta per cell and the bill; the foreman schedules a cell
  as several stacked cubes, bottom up (decision 1931, C2.1).

The per-cell table at the end of this record is therefore historical. The bill follows decision 1971's result,
read through the one place P-C2-3 names.

## Decision

Brendan ruled P-C2-1 on 2026-10-12: "Dig rooms with the down stroke" (M1, content 10 rows 56–63). The ruling asked
this lane to design the geometry: where the mole stands, the order of cells and layers, the access face, and how the
room reaches its height. If M1 alone cannot do it, the lane was to stop and report.

**It cannot.** The finding holds whatever the stance, the order, the access face or the room height:

- an M1 stroke can cut only a cube whose top face lies under air that is already open;
- the top layer of every underground room lies under protected earth;
- so the first cube of a room can never be struck, and every lower cube needs the cube above it cut first.

That includes a room one quantum high, whose only layer is its top layer, and digging from the floor of a cell
already cut, which needs a first cell. P-C2-1 therefore needs a new ruling (options below).

## Why: the geometry, from the published boxes and the contact proof

Row 62 (M1) and row 63 (the paw seating tap, see "Corrections") at yaw 49152 are below; rows 56–61 are the same
two rows at the other yaws. Boxes are relative
to the stance, with +x forward and y up. They were read from the loaded content-10 rows.

| Role | Row 62 (anchor at the stance plane) | Row 63 (anchor 128 u up) |
|---|---|---|
| CONTACT_POINT | (544, 0, 224) | (448, 128, 128) |
| CONTACT_PATCH | x 543..545, **y 0..0**, z −225..225 | x 447..449, **y 128..128**, z −129..129 |
| TURN_RECOVERY (air) | x −238..**597**, y 0..**840**, z −478..415 | x −234..**578**, y 0..**840**, z −478..443 |
| BODY (air) | x −206..462, y 0..474 | x −219..409, y 0..666 |
| WORK_APPROACH (air) | x −234..329, y 0..840 | x −234..329, y 128..840 |
| WORK_STROKE (may enter the target) | x 239..589, y 0..370; x 415..561, y −61..0 | x 213..524, y 128..425; x 330..461, y 112..128 |
| STANCE_SUPPORT | x −175..169, y −1..0 | x −175..169, y −1..0 |

The proof (`underground_work_face.gd`):

1. **`patch_refusal`.** The whole patch must lie on the struck face: `low == high == plane` on the face's axis, with
   a positive span inside the face on the other two. Both patches are flat in y, so M1 can strike only a **top or
   bottom face**. Its plane is at the stance plane (row 62) or 128 u above it (row 63).
2. **`box_refusal`.** Every role except STANCE_SUPPORT, the contact point, the contact patch and WORK_STROKE must be
   unblocked open space (`proof.blocked(...)`, `body_covered`). Only the stroke may enter the target cube.
3. **The air over the patch.** TURN_RECOVERY contains the whole patch footprint: row 62 spans x −238..597 ⊇
   543..545 and z −478..415 ⊇ −225..225; row 63 spans x −234..578 ⊇ 447..449 and z −478..443 ⊇ −129..129. It rises
   from the patch plane to 840 u above the stance. So open air is required **directly over the patch**, inside the
   column above the struck face, 712–840 u high.

What that rules out:

- **A bottom face.** The air box would lie inside the solid target itself, and step 2 refuses it. Raking the base of
  a wall is not available.
- **A top face.** The cube directly above the target must already be open. Room geometry is whole 1,024 u cubes
  (`Contract.QUANTUM_SIDE_U`), so that means the whole cube above.
- **Row 63 also needs a stance 128 u below a cube plane.** Room floors lie on cube planes, so it fits only a
  stair tread.

The top of every underground room is protected earth. Room admission and phase structure keep the band from the
room's top to the level's `protected_above_high_u` solid (`underground_room_bindings.gd` `_room_band_refusal`,
ADR 1220 "Lower Rooms inside an authored level"). A full-height room's top is the level roof. So:

| Candidate geometry | Result |
|---|---|
| Mole in the access, striking the side or top of the first room cube | The side is not strikable (step 1). The top has earth above it (step 3) |
| Mole standing on the target's own top face | Same air requirement above the target (step 3) |
| The room dug top layer first, then down through its cells | The top layer has protected earth above it, so it never opens |
| A room one quantum high | Its only layer is its top layer, so the same |
| Digging from the floor of the cell already cut | The next cube's top face is 1,024 u above that floor, beyond the 0 u or 128 u anchor. Its bottom face fails step 2. And there is no first cell |
| A room below the access floor (a pit under the corridor's level) | The cube above the pit cell is level earth, not open (step 3). Rooms must also start on the level floor (ADR 1220) |

**What M1 can dig.** Only cubes under air that is already open: under the open sky (how the entry trench is dug,
1,024 u deep), or under a cube already cut. Underground, no open cube exists that M1 itself did not open from the
sky, so no room on levels 1–4 can be started.

`reachable_height_u` (ADR 1220) reads only the anchor height. On content 10 it reports 1,024 u for the claw identity.
That number is not a height a claw crew can cut in a room. Under the rule P-C2-3 (a) asks for ("the right face for
the stroke being used"), the claws' room height today is **0 quanta**.

## Options for P-C2-1, with a recommendation

- **(a) Author one claw front stroke (M3), a side-face stroke in the floor band, and dig rooms one quantum high
  with it.** It is "basic claw strokes": one stroke family, authored at yaw 0 and rotated into the four yaws, as M1
  was, under ADR 1217's derivation and review. The room's height follows its anchor (DEC-054): one quantum. A later
  M2 (high wall) would add the second metre. This is the earlier P-C2-1 (a) cut down to its minimum.
- **(b) Rooms are open pits dug down from the sky with M1.** They are roofless and on the surface, and they never
  reach levels 1–4. This contradicts DEC-061's room model (rooms on five levels at 5 m), so it is not a real option
  for underground rooms.
- **(c) M1 only deepens space that is already open** (a "lower the floor" order). Nothing underground is open, so it
  digs nothing.
- **(d) The pick front and high rows.** Excluded by Brendan ("keep basic claw strokes"; the pick rows are never used to
  justify a height). Listed only so the list is complete.

**Recommendation: (a).** It is the smallest new content that makes any underground room diggable. Until it lands:

- C1's ledger should show rooms as not yet diggable rather than price them;
- C2.1 can still build the foreman, the breadth-first order, the builders, spoil and the tick wiring, proved on the
  ADR 1213 content-6 fixture as a test of the dispatch logic only, never of a height or a price. That needs
  Brendan's leave, since it runs the retired pick rows in a test.

## Per-cell quanta and bill for C1's ledger

The bill is BAL-UG-001 / DEC-059 per quantum: wood 250 and stone 250 milli-U, 940 + 1,880 + 1,410 = 4,230 milli-WU,
and 2,000 milli-U `excavated_earth` out.

| Content the claws have | Quanta per cell | Wood | Stone | Work | Earth |
|---|---:|---:|---:|---:|---:|
| Today, M1 only | **0**: rooms cannot be dug | — | — | — | — |
| With M3 (option (a)) | 1 | 250 | 250 | 4,230 | 2,000 |
| With M3 and M2 | 2 | 500 | 500 | 8,460 | 4,000 |

## Consequences

- No room foreman can be proven on the active content until P-C2-1 is re-ruled and, under (a), M3 is published.
- ADR 1217's Room rows (M2, M3) carry a note pointing here.
- DEC-054 (`setting_decisions.md`) is Brendan's log, and this lane changes no ruling in it, so it is not edited. If
  option (a) is chosen, its "if claw strokes don't match that height that is Ok" then means rooms one quantum high
  until M2.

## Source

DEC-052, DEC-054 and DEC-061 (`docs/setting_decisions.md`); Brendan's P-C2-1 ruling (decision 1931); ADR 1217
(M1–M3), ADR 1220 (reachable height, protected band); `underground_work_face.gd` `patch_refusal`, `box_refusal`;
`underground_room_bindings.gd` `_room_band_refusal`; content 10's
`first-entry-prefix-v1/qualified-stairs-v9/mole-worker.ugprof` rows 56–63, read with a scratch probe that is not
committed.
