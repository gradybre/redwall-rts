# 1981 — One basic stair carry: scoping, stopped for rulings

Date: 2026-10-15 · Status: Accepted. Brendan ruled P-1981-1, -2, -3 and -6, and the coordinator P-1981-4, -5 and -7,
on 2026-10-15 (see "Rulings" and "The coordinator's ruling on P-1981-7"). Phase 2 is built: content 12 is published,
data only and not active ("Phase 2 — what was built").

Number range: 1981–1989 was allocated to this lane by the coordinator, and checked free on every local and remote
ref. This is the lane record; later records of the lane take 1982 onwards. Branch `feat/stair-carry`, from
`f1d4c3a0`.

## Brendan's direction (2026-10-15, relayed by the coordinator)

- "Real digging, in full"; "I just want the basic claw stroke that digs anything" (decision 1971).
- On decision 1934's P-C22-1: **"Same-level now + basic stair carry"**. The C2 lane builds the same-level room
  Delivery. This lane is the basic stair carry: one carry motion family, in the spirit of the one claw stroke, derived
  from existing clips and rows rather than through a long motion-review pipeline.

## Rulings (2026-10-15, relayed by the coordinator)

| Proposal | Ruling | What it means here |
|---|---|---|
| P-1981-1 | Brendan, **"Approve all"**: (b) | Down and up: all 14 rows, 71–84 |
| P-1981-2 | Brendan: (a) | This lane derives the floor end of the stair: F, F′, E1/E2 and the floor proofs of rows 54/55 |
| P-1981-3 | Brendan: (a) | DEC-050's pace applies laden: 30 ticks a tread, 45 a half-turn, 90 per three-step handoff. Recorded as DEC-050's addendum of 2026-10-15 |
| P-1981-6 | Brendan: (a) | No review packet; the phase-2 frames are the review |
| P-1981-4 | Coordinator: (a) | The content-11 activation lane takes content 12's engine admission; C2.3 takes Delivery's leg-by-leg reach and the hauler's leg list. The inventory is in "Activation inventory" below |
| P-1981-5 | Coordinator: (a) | `POLICY_ROOTED_TRAVEL` = 10 lands in `underground_profiles.gd` in this lane, with its consumer pins renewed in the same commit; the edit is limited to the policy word and what loading content 12 needs |

Indexed in `docs/handoff/RULINGS.md`. Sections "Decision" to "Proposals" below are the scoping as it was put.

## Decision (as proposed)

**The stair carry is the accepted stair and handoff authors run unchanged on the carry's hold pose.**

Every accepted stair motion moves only the leg bones (1–8) of one standing key:
- the gaits, `author_stair_descent` and `author_stair_motion` (M7);
- the handoffs, `author_stair_handoffs` (ADR 1142).

The hips, the upper body and any rigid part keep that key exactly (`author_stair_motion.py` 123–127,
`author_stair_handoffs.joint_palette`). M7 ran them on the claw ready, and step 5b ran the turn the same way.

Run on the haul images' **hold** key instead, the same recipes give a mole that walks the stair with its arms and
its log or stone fixed in the root frame. That means:
- the certified two-hand grip of the hold holds on every key, unchanged;
- no recipe value, foot track, root track or arm pose is chosen.

The level carry (rows 32/37) itself cannot be reused: its feet stride 222 u ahead of the root and its hips bob
9–67 u. Its upper body is rigid to the hips, but the stair gaits own the legs.

## 1. What is derived, and from what

### The hold is a stair "ready" (measured on the committed clips)

The hold is the last key of the approved lift: `haul-handling-v1` `hold` clip, the same as the carry loop's
enter/exit endpoint. Compared with the corrected stand key 8 that M7 used:

- **Matches:** the hips and the left leg (0.0 u, 0.0°).
- **Right leg:** 1.1–1.5° different; the right foot is 3.4 u lower.
- **Upper body:** Spine02 is turned 12° from the stand (wood hold; the lift's own lean). The arms differ by up to
  226 u and 85°, because they hold the load. The stone hold was not measured; it gets the same check in phase 2.

So the leg tracks start from almost the same feet. The upper body is a different, already approved pose.

### The geometry that decides which moves are needed

Source-local, u = 1/1024 m. The stair is ADR 1209's.

| Fact | Value | Source |
|---|---|---|
| L0 deck | z [−2048, 0], y 0 | prefix artifact |
| Tread T_k | rise 128, run 512; T6 is the sill, its top 64..128 u above the floor at z [−5632, −5120] | ADR 1209 D1 |
| Floor, end wall | y −1024 from z −5632; end wall at z −7168 (D2's seventh row) | ADR 1209 |
| Trench | x ±1024, open above (no roof) | prefix artifact |
| A, the descent start/arrival | the far edge + 169 u. On L0: z −1879. The floor arrival F is z −5975 | ADR 1209, `tread_geometry.gd` |
| U, the ascent start/end | the far edge + 343 u. On L0: z −1705. Floor ascent start: −5801 (169 u before the sill) | the same |
| Row 32 (wood carry), yaw 0 | stance z −222..222; log z −504..−217, y 447..704 | `haul-rows-v1/rows.json` |
| Row 32, as published (YAW_ALL) | body ±679, stance ±375, load ±714 | content 11 wire, decoded |
| Row 37 (stone carry, YAW_ALL) | body ±556, stance ±375, load ±598, y 447..821 | the same |

Consequences:

- **The level carry cannot reach the stair's top step.** Its all-yaw stance (±375 u) overhangs L0's edge at A
  (169 u) and even at U (343 u). It fits from z −1536 (512 u from the edge).
- **It cannot leave the floor arrival either.** At F, its all-yaw body (±679) reaches over the sill.
- **The empty claw path has the same limit, so nobody can stand on the floor today.** Its tread stops and edges
  end at T5 (`underground_entry_stair_path.gd`), the crew finishes at T5's station, and the empty ascent from the
  floor was never proved: M7's bottom proof is the descent only. A room on the Kitchen level cannot be supplied or
  dug until the floor end of the stair exists. This is not specific to carrying.

### The move set (each an accepted author, run unchanged)

The ADR 1142 handoffs fit the gaps exactly, with no new control values:
- the **approach** runs z −1536 → −1879 (to A on L0), heading 0;
- the **retreat** runs −1705 → −1536 (from U on L0), heading 32768;
- the **turn** runs A → U on a tread (+174 u).

Translated to the floor:
- the approach takes F (−5975) to F′ (−6318), where row 32's all-yaw body clears the sill by 7 u (686 against 679);
- the turn takes F to the floor ascent start (−5801).

| Move | Author and recipe | Edge(s) | Wood | Stone | Empty |
|---|---|---|---|---|---|
| Approach (343 u) | handoff `approach`, unchanged | H (L0, −1536) → A(L0); F → F′ (walk-off) | W1 | S1 | E1 (walk-off only) |
| Descent | M7 recipe (`stair-descent-v7` case 0) | A → A, L0 … T5 → T6 → F | W2 | S2 | row 53 (exists) |
| Ascent | M7 recipe (`stair-motion-v15` case 0) | floor start → U(T6) … U(T0) → U(L0) | W3 | S3 | row 54 (exists) |
| Half-turn | handoff `turn`, unchanged | F → floor ascent start | W4 | S4 | row 55 (exists) |
| Retreat (169 u) | handoff `retreat`, unchanged | U(L0) → H | W5 | S5 | row 45 serves today |
| Back-up (343 u) | the approach clip, exactly reversed (as each recovery reverses its entry) | F′ → F | W6 | S6 | E2 |

- **The loaded round trip.**
  - Down: ground carry (row 32/37) to H; W1; W2 eight times; W1 again as the walk-off; ground carry to the room's
    stand.
  - Up: ground carry to F′, turning in place to heading 0 (row 32 is all-yaw); W6; W4; W3 eight times; W5; ground
    carry on.
- **The empty return.**
  - Ground walk to F′; E2; rows 55 and 54 on the floor and the sill; row 45 at the top.
  - E1/E2 are authored on the haul images' stand key 8, on the closed paw, with a body-only clip mask. ADR 1198
    did the same for the haul images' empty stand/walk. The switch to the claw rows at F is a paw-shape change at
    rest, which Brendan accepted (DEC-052 follow-up 3).
- **Rows:** 12 loaded rows (W1–W6, S1–S6) and 2 empty rows (E1, E2), appended after row 70 as content 11
  appended 67–70. No published row moves.
- **Arm swing is not allowed.** M7 needed 3° of right-arm swing because the hanging paw brushed the lifting thigh.
  A swing would break the grip, so the loaded authors run with 0°.

### What has to be proved (the accepted provers; the load is a second rigid part)

The terrain and sequence provers already require two parts (body and tool). The load takes the tool's slot
natively (palette column 24, binds 0), so, unlike M7, no census patch is needed.

1. **Exact endpoints and joins.** Every loaded clip's first and last keys equal the item's hold, byte for byte. The
   empty clips' endpoints equal stand key 8. These give cross-image joins to sources 2 and 3, as the stone image's
   join to wood v10 was checked.
2. **Grip invariance.** In every key, bones 0 and 9–23 and the load column equal the hold exactly. The certified
   grip contacts (C − S, `CONTACT_HAUL_GRIP`) then hold by identity. `prove_carried_grip.actual_contact` is re-run on
   the hold for the record.
3. **Terrain** (`prove_stair_terrain`): both decks, every triangle of body and load, with full-foot contact
   witnesses.
4. **Flight** (`prove_stair_sequence` over `prove_descent_flight.derivation`): L0 ↔ T5, descent and ascent, with
   the load.
5. **Bottom** (`prove_descent_flight.bottom(spec, 7)`):
   - T5 → T6 → floor for the loaded descents;
   - **new runs:** floor → T6 → T5 for the ascents, loaded and empty (row 54);
   - the turn at F, loaded and empty (row 55).
6. **Handoffs** (the ADR 1142 handoff prover):
   - the approach and retreat on the L0/T0 fixture;
   - the approach, back-up and turn on the bottom fixture (sill, floor, side walls and the seventh row's end wall).
7. **Self-clearance and the load.**
   - `prove_claw_pair.self_rows` for the arms against the rest.
   - `prove_loaded_gait`'s separation for every non-grip body triangle against every load triangle, on every
     interval. This is the "leg against log" question on the ascent's lead lift (50 u, rise 128).
   - The level carry never had body self-clearance proved (ADR 1199 closed it for stand/walk only). The stair carry
     proves it.
8. **MOVE-REQ-005 load_fit.** Proved by 3–6: the load is a part in every world proof. The trench is ±1024 u wide
   and open above, the yaw-0 log spans x −425..505, and the structure envelope's top is y +1,192.
9. **Native capture.** Two new images on the real Metal backend (0 failures, 0 coefficient mismatches; the exact
   joins of item 1). This needs the demo art staged (the lane brief's clone).
10. **Rows.** `derive_stair_rows`' accepted cardinal derivation: `rooted_row` for the gaits; the handoff prover's
    interval enclosures, as `turn_row` does, for the handoffs. The capacity is ≤ 12 boxes per row.

### What cannot be derived (each is a proposal below)

- **The laden pace.** DEC-050 "assigns no timing to laden workers".
- **The handoffs' pace.** No pace was ever adopted for approach or retreat: content 10 used the short steps
  instead.
- **Whether every proof clears.** If a loaded proof refuses, for example the ascent's knee meeting the log, the
  only fixes are a new pose (a raised hold) or a new recipe. Both are new motion. The lane stops and reports rather
  than tune.
- **The runtime policy word.** Profiles admits stair rows only as WALK with no cargo (ADR 1229 constraint 4,
  `underground_profiles.gd` 415–417).

## 2. How it publishes (data only, inactive, as content 11)

**Content 12, built on content 11**, so the activation lane switches both on together. Proposed files, all
create-only:

| File | What |
|---|---|
| `mole-worker/stair-carry-v1/author_stair_carry.py`, `prove_stair_carry.py`, `derive_stair_carry_rows.py`, `native_stair_carry.py` (+ `native/` capture), `test_stair_carry.py` | Offline: the hold readies, the authors (re-run), the proofs, the rows and the two images. Byte-for-byte rebuild tests. Evidence goes in `stair-carry-v1/evidence/` |
| `mole-worker/publish_stair_carry_runtime.py` → `qualified-stair-carry-v13/` | Content 12: content 11's sources 0–5 and rows 0–70 byte for byte, **source 6** (the wood stair-carry image), **source 7** (stone), rows 71–84. Manifest `runtime_admitted: false`. The accessor publishes `STAIR_CARRY_ROWS` and `STAIR_EMPTY_FLOOR_ROWS` |
| `mole-worker/publish_stair_carry_motion.py` → `qualified-stair-carry-motion-v1/` | The stair tables (UGSTRM01 format) for rows 71–84: root, heading and deck per key; the image clip ordinal. The gait twins' roots are the content-10 gait tables (the same recipes). The claw tables stay as they are |
| `test_publish_stair_carry_runtime.py`, `test_publish_stair_carry_motion.py`, `godot/test/test_mole_stair_carry_profiles.gd` | Publisher tests and a Godot test through the real loader (see P-1981-5) |

- **Why new sources and not successor haul images.** Replacing sources 2/3 would move the haul digests. Those are
  pinned by the grip certificate, the haul program, the presentation set and every content-10/11 consumer. New
  sources 6/7 move nothing published.
- **The per-source block.** A pace catalog's source binding and Profiles' per-source key order both work by source,
  and `MAX_SOURCES` is 64.
- **Memory (estimate; measured at publication).**
  - The profile bank grows by about 6 KB. That fits the 12,928 B left inside `PROFILE_BYTES` (278,528 B) after
    content 11.
  - The new stair tables are about 33 KB of retained rows at activation.
  - The two images add about 1.6 MB to the presentation set.

## 3. What Delivery needs, and who wires it

C2.2 names the gap `ROOM_HAUL_NO_STAIR_CARRY`. Retiring it needs four things, none of them data-only.

**Engine admission (at activation).**
- **Profiles:** the new policy (P-1981-5).
- **The connector catalog's pace rule** (`_pace_row_refusal`, line 540): authored paces are bound to `header[10]`,
  source 4, and to the variant's mode (549). Either:
  - add a CARRY variant, which needs a Placement that binds more than its one `H_CATALOG_ROW`; or
  - narrow the rule so that a source-6/7 row that is the loaded twin of a source-4 stair row may pace the WALK
    variant's stair.

  Recommended: the second, the smaller change.
- **The stair program and stair motion owner:** successors that own rows 71–84 by digest.
- **Routes:** dispatches to them. The switch at rest is at the hold hub (loaded) or the stand hub (empty).
- **WorldRoutes:** qualifies CARRY stair edges. `_kind_matches` already compares the descriptor's mode with the
  edge's.
- **The stair path publisher** (`underground_entry_stair_path.gd`):
  - the stops H, F, F′ and the floor ascent start;
  - the CARRY edges;
  - a mode-aware `_joined`.
- **The grip certificate:** admits content 12.
- **Presentation:** `present_stair` for sources 6/7.
- **The bundle successor:** paces and the floor stops.

**Delivery** (`underground_connector_delivery.gd`).
- Admission reaches the destination today with one CARRY profile over the whole path (`_reach` → WorldRoutes
  `profile_reachability_refusal`, mode-filtered, rows 32/37 with family mask 0). It becomes a leg-wise reach:
  1. ground carry to H;
  2. the stair-carry legs, checked by a static per-leg edge certificate, as Contacts' `_stair_reach_refusal` checks
     the WALK legs;
  3. ground carry from F′ to the room's stand.
- The C2 room branch's `_room_material_leaf` supplies the destination.

**The hauler** (`underground_entry_hauler.gd`).
- `STAGE_CARRY` becomes a leg list, as the installer's `downs`:
  - automatic CARRY to H;
  - explicit W1, W2 (one route over the descent edges), W1;
  - automatic CARRY to the stand.
- The return is the empty list: walk to F′, E2, 55, 54, 45, walk.
- The plan comes from a stateless helper over the live graph, the stair path publisher's twin. The leg list and its
  cursor go in the hauler's save record: a `Progress.MAX_WIRE_BYTES` and section-6 bump, with a census row.

**Who owns it.** See P-1981-4.

## 4. Proposals

**P-1981-1 — Scope of the basic stair carry (for Brendan).**

- **(a) Down only:** W1, W2, S1, S2, and the empty climb (E2 plus the floor proofs of rows 54/55). That is 5 rows.
  It is the smallest set that lets a hauler take wood or stone down to a room and come back for the next unit.
- **(b) Recommended: down and up,** all 14 rows of §1. The authors and provers are the same runs, and up adds only
  more clips and rows. Up is what moves unused stock back to the surface.
- **(c) Descent rows only (W2, S2)**, with no way on or off the stair. This does not supply a room.

**P-1981-2 — The floor end of the stair (for Brendan and the coordinator).** Nobody can stand on the Kitchen level's
floor today, empty or loaded.

- **(a) Recommended:** this lane derives the floor end with the carry: the stops F and F′, E1/E2, and the bottom
  proofs of rows 54/55. The derivation is the same and the bundle successor is the same.
- **(b)** Leave it to slice D. The stair carry is then publishable but unusable until slice D lands.

**P-1981-3 — Pace (for Brendan; DEC-050 excludes laden workers).**

- **(a) Recommended:** the laden stair takes DEC-050's unladen pace: 30 ticks a tread and 45 a half-turn. The
  handoffs take DEC-050's "1 second per step": 3 steps, 90 ticks. The loaded clips have the same keys, feet and
  root tracks as the unladen ones. On the ground, the adopted rule already gives carry the same pace as walk
  (rows 31 and 32 share Movement's cap, ADR 1198).
- **(b)** A laden slowdown factor, which Brendan names (a new balance number in `docs/gameplay_balance.md`).

**P-1981-4 — Who wires it (for the coordinator).**

- **(a) Recommended:**
  - The **content-11 activation lane** takes the engine admission (§3, first block). It already edits Routes,
    WorldRoutes, the catalog, the Session, the stair motion owner and the bundle (`qualified-stairs-v10`), and it
    runs after the cost lane. Doing both contents in one activation means one pin renewal, one checkpoint
    regeneration and one census pass.
  - **C2.3** takes Delivery's leg-wise reach and the hauler's leg list. Delivery is C2's file, and C2.2's room
    builder is the hauler's new caller. C2.3 retires `ROOM_HAUL_NO_STAIR_CARRY`.
- **(b)** A separate stair-carry activation lane after content 11's. It is cleaner to review, but it renews the
  same pins and regenerates the same checkpoints a second time.

**P-1981-5 — The Profiles word (for the coordinator; `underground_profiles.gd` is shared core).**

- **(a) Recommended:**
  - One new policy, `POLICY_ROOTED_TRAVEL` = 10, for all 14 rows: a source-proved rooted motion read from stair
    tables; YAW_EXACT; tool −1; WALK with cargo −1 or CARRY with a cargo; any family mask, 0 meaning ground.
  - POLICY_STAIR's live rule is untouched.
  - It lands in this lane's phase 2, as ADR 1229's increment 1 preceded content 10, so the Godot test loads content
    12 through the real loader. No active content has such a row, so it changes no live behaviour.
  - It renews `underground_profiles.gd`'s consumer pins (`tools/renew_source_pins.py --write`), which needs the
    coordinator's clearance.
- **(b)** Extend POLICY_STAIR/STAIR_TURN to CARRY, and the handoffs to ground families. This changes a live rule.
- **(c)** Defer the word to activation. The Godot test then only decodes the wire, and the real loader refuses the
  rows until activation.

**P-1981-6 — Review (for Brendan).**

- **(a) Recommended:** no review packet stop. The recipes and the hold are approved and unchanged, as for 1971. The
  phase-2 frames (a mole carrying wood down and up the stair, 1280×720 and 1920×1080) are the review.
- **(b)** Stop with a review packet (overview, hands and motion) before the native capture, as M7 did.

## Consequences

- No code or content is changed until the rulings. The lane stops here.
- If any proof in §1 refuses, the lane stops and reports. It does not tune poses or recipes.
- If P-1981-2 (b) is chosen, the stair carry's runtime use waits for slice D. The C2 lane should know.

## Source

- Brendan's direction of 2026-10-15, as relayed.
- DEC-050, DEC-052, DEC-059 and DEC-060 (`docs/setting_decisions.md`).
- `docs/movement_direction_amendment.md`: MOVE-REQ-005, the load_fit condition.
- ADRs 1142, 1144, 1198, 1199, 1206, 1209, 1217 (M7, step 5b), 1229; decisions 1934 (branch
  `feat/room-foreman-c2-2`) and 1971.
- The code at `f1d4c3a0`:
  - `underground_profiles.gd` (402–417, 604–617);
  - `underground_connector_catalog.gd` (358–374, 532–553);
  - `underground_entry_stair_path.gd`, `underground_entry_hauler.gd` and `underground_connector_delivery.gd`
    (548–603);
  - `stair_program.gd`, `underground_stair_motion.gd`;
  - `author_claw_stairs.py`, `author_stair_handoffs.py` (`episode_controls`, `joint_palette`), `derive_stair_rows.py`.
- Content 11's wire, decoded with a scratch reader (not committed).
- The hold-versus-stand comparison: a read-only NumPy measurement of the committed `haul-handling-v1` and
  `stand-walk-v2` clips (scratch, not committed).

## Phase 2 — first proofs (2026-10-15): stopped at the loaded handoffs

Following the rulings, the accepted authors were run on the holds, and every proof of §1 was tried before any
content was built. The runs used scratch scripts (`scratchpad/staircarry_probe/`, not committed), with the
palettes staged from the frozen `redwall-rts-codex-ug-space` worktree against their pins, as in ADR 1217.

### Clear

- **The loaded gaits** (wood and stone, M7's recipes unchanged on the hold):
  - Bones 0 and 9–23 and the load column equal the hold bit for bit on every key, and both endpoints equal the
    hold.
  - Terrain: clear.
  - Flight L0 ↔ T5: descent 4,128 pairs, ascent 4,788 pairs; 0 unresolved.
  - Bottom: descent T5 → T6 → floor 1,376 pairs; **ascent floor → T6 → T5** (new run) 1,596 pairs; 0 unresolved.
  - Arm self-clearance: clear.
  - Body against load: wood 0 broad-phase pairs; stone 4,500 pairs, 0 unresolved.
  - Two-hand grip: continuous on every interval.
- **The empty floor end:**
  - E1 (the approach on the closed-paw stand) on the floor fixture: 869 checks, clear, and self-clear.
  - Claw row 55 (the half-turn) on the floor: 2,190 checks, clear.
  - Claw row 54 (the ascent) floor → T6 → T5: 1,562 pairs, clear.
- **The loaded handoffs, against the load and the body:** self-clearance, body-against-load separation and the
  grip all clear.

### Refused: the loaded handoffs against the deck

The approach and retreat on L0, and the approach and turn on the floor, each refuse for wood and stone:

- 14 unresolved SOLID pairs at interval 0, all **right-foot** triangles against the standing deck;
- approach 1,156 checks, retreat 1,161, turn 2,485.

**The cause.** `author_stair_handoffs.frame_track` hard-codes the support program at the two endpoint keys as
"left foot only" (`mask = 1`). It records the reason: "Exact ready has the right foot slightly raised; no invented
second contact". That is true of the stand ready. It is not true of the hold:

- the lift ends with both feet down, the left foot's lowest exact vertex 0.0018 u and the right foot's 0.0020 u above the
  floor (wood and stone holds alike);
- so the right foot lies inside the prover's conservative padding;
- it is not excused, because it is not declared planted.

There is no penetration in the source.

**Diagnostic only (not adopted).** Declaring both feet planted at the two endpoint keys, which is what the hold is,
makes all eight handoff runs clear (wood and stone):

| Handoff | Checks | Unresolved |
|---|---:|---:|
| Approach on L0 | 883 | 0 |
| Approach on the floor | 883 | 0 |
| Retreat on L0 | 888 | 0 |
| Turn on the floor | 2,212 | 0 |

Each planted foot still had to show the prover's continuous contact witness.

Nothing was published. Per the coordinator's instruction ("If a proof refuses … stop and report"), the lane stops
here for a ruling (P-1981-7, below).

### P-1981-7 — The handoffs' endpoint support on the hold (for the coordinator, or for Brendan)

- **(a) Recommended:** derive each endpoint's planted feet from the ready pose instead of the stand-specific
  constant. A foot is planted at an endpoint when its lowest source vertex lies in the prover's contact cell.
  - The stand ready gives "left only", exactly as today. The hold gives both feet.
  - It is applied by a wrapper in the stair-carry author; the accepted `author_stair_handoffs.py` is not edited.
  - The prover is unchanged, and still requires a continuous contact witness for every planted foot.
  - No pose, recipe value, foot track or root track changes.
- **(b)** Treat the refusal as final. The loaded mole then cannot step on or off the stair at the top or the
  floor. The gaits alone cannot supply a room (P-1981-1 (c)).
- **(c)** A new on/off motion for the loaded mole, or a re-posed hold. This is new motion with a review, against
  "keep it basic".

### The coordinator's ruling on P-1981-7 (2026-10-15)

**(a).** The planted feet at each handoff's first and last keys are decided from the starting pose: a foot is
planted when its lowest point lies within the checker's contact distance. This is done in a wrapper inside the
stair-carry author. `author_stair_handoffs.py` and the checker are left unchanged, and every planted foot must still
show continuous contact.

The coordinator's reason: it changes no pose, recipe, foot path or body path. It corrects the proof's configuration,
reproduces "left only" for the standing pose, and keeps the check as strict as before.

**Where the failure came from.** It came from the approved author's single-planted-foot assumption at its endpoints,
not from the motion. The diagnostic table above is the evidence.

**A correction found by the independent review: the prover alone does not witness an endpoint-only foot.**
`prove_stair_handoffs` requires a contact witness only for a foot planted at both keys of an interval
(`mask = pair[0] & pair[1]`), but excuses deck contact for a foot planted at either key. The hold's right foot is
planted at the two endpoint keys only, so in the first and last intervals it was excused but never witnessed: the
check was not "as strict as before" for that foot.
- **What closes it.** `prove_stair_carry.endpoint_support` checks every planted foot at both endpoint keys of every
  handoff run:
  - an exact source vertex in the [0, 1) u contact cell of the standing deck's top;
  - every vertex of the foot strictly over the deck's extent.
- **Results** (`*_endpoints` rows in `proof-v1.json`, all clear):
  - the hold's feet are 0.0018 u (left) and 0.0020 u (right) above the deck;
  - the right foot, the endpoint-only one, lies at least 105 u inside the deck's edges in every run;
  - the left foot, which the prover already covers exactly, is 0.7 u inside L0's edge at A.
- `source_above_plane` still forbids any penetration.

## Phase 2 — what was built (2026-10-15)

Everything below is data only and **not active**. The activation inventory is at the end.

### The clips (`mole-worker/stair-carry-v1/`)

**`stair_carry_source.py`: the pinned closure.**
- The closed-paw body.
- The log, and the stone exactly as the stone image draws it.
- Each item's approved `hold` key, pinned by the digests the v10 haul images record.
- The corrected stand key 8.
- Each item's certified grip witnesses.

**`author_stair_carry.py`: the accepted authors, unchanged, on the hold.**
- M7's descent and ascent recipes.
- ADR 1142's approach, retreat and turn.
- The back-up is the approach exactly reversed.
- The empty walk-off and back-up are the same handoffs on the stand.

The P-1981-7 wrapper (`endpoint_support`) only records the derived endpoint mask. Its rule (`planted_mask`) is: a foot
is planted when its lowest exact source vertex lies in [0, 1) u of the floor. That gives both feet for each hold and
the left foot alone for the stand, which is the author's own value.

Results:
- Hips, bones 9–23 and the load column equal the hold bit for bit on every key of every loaded clip.
- No arm swing.
- Clips: 6 per item (91 keys each, the turn 271) and the empty pair (91 each), in `evidence/clips-v1/`.

**`prove_stair_carry.py` → `evidence/proof-v1.json`: clear, all 62 proof rows.**

| Proof | Wood | Stone |
|---|---|---|
| Descent: terrain, flight L0 → T5, bottom T5 → T6 → floor | 688, 4,128 and 1,376 pairs | the same |
| Ascent: terrain, flight T5 → L0, **bottom floor → T6 → T5** | 798, 4,788 and 1,596 pairs | the same |
| Approach on L0 and on the floor; retreat on L0; turn on the floor (handoff prover) | 883, 883, 888 and 2,212 checks | the same |
| Arm self-clearance, every clip | clear | clear |
| Body against load, every clip | 0 broad-phase pairs | 4,500 pairs (turn 13,500), 0 unresolved; star containment: no key |
| Continuous two-hand grip, every interval of every clip | clear | clear |

- **Back-ups.** Each back-up is proved by its approach's runs: every rendered interval is the same pair of keys.
- **Endpoint support** (P-1981-7, see the correction above): every planted foot at both endpoint keys of every handoff
  run, ten runs, clear.
- **The empty floor end:**
  - the walk-off on the floor: 869 checks, and self-clear;
  - claw row 55 on the floor: 2,190 checks;
  - claw row 54 from the floor up to T5: 781 terrain pairs and 1,562 bottom pairs.
  - The claw clips were rebuilt from their own authors and checked against their stored bytes.

The handoff fixtures are the bottom fixture (L0, T0–T5, the sill, the floor and the seventh row):
- translated so that F stands at the approach's start, or at T0's A for the turn;
- with the floor slab swapped in as the standing deck;
- the turn is translated as step 5b translated it per tread.

**`native_stair_carry.py`: two images.** It uses the accepted encoder, runner, capture scripts and verifier equations.
Both ran on the real Metal backend:

| Image (source) | Clips | Content | Rows | Mismatches | Max vertex error (u) |
|---|---|---|---:|---:|---|
| wood (6) | hold, the six loaded clips, the empty pair (mask body only, the S fixture stock hidden) | `b7092e0c…` (1,096,408 B) | 10,839 | 0 | 0.00013 body, 0.00087 log |
| stone (7) | hold, the six loaded clips | `606936a1…` (877,184 B) | 8,673 | 0 | 0.00008 body, 0.00086 stone |

Each image's verification also covered:
- 17,346 exact two-hand witnesses;
- every clip's ends on its hub;
- the back-ups as exact reversals;
- cross-image joins with the v10 haul images (the hold, and stand key 8 for the empty pair);
- a floor gap of at least 0.00095 u on every flat clip.

The descent and ascent are root-local: their support is proved on the terrain, flight and bottom fixtures.

**`derive_stair_carry_rows.py` → `evidence/rows-v1.json`: rows 71–84.** Each row has 3 boxes (body and load,
stance, recovery). The derivations follow `derive_stair_rows`:
- the gaits: `rooted_row` over the body and the load, each with its native cardinal residual;
- the handoffs: `turn_row`, from the prover's interval enclosures of every part;
- the back-ups: the approach rebased to its end.

For example, the wood descent's body box is [−424, −130, −949, 434, 850, 235].

**`derive_stair_carry_tables.py` → `evidence/tables-v1.json`: root, heading and deck per key.** The loaded gaits and
the turn equal content 10's rows 53, 54 and 55 key for key; the tool refuses otherwise.

### Engineering choices (recorded so they are not undone by accident)

1. **Four rooted words, not one.** Profiles' `_overlap_keys` makes two rows ambiguous when they share policy, physical
   key and heading.
   - At yaw 0 a loaded item has four rows: approach, descent, turn and back-up. At yaw 32768 it has two: ascent and
     retreat.
   - So one word cannot hold them. The family is `POLICY_ROOTED_TRAVEL` (10, the forward handoffs, the name the
     coordinator cleared), `POLICY_ROOTED_BACKWARD` (11), `POLICY_ROOTED_STAIR` (12) and `POLICY_ROOTED_TURN` (13),
     mirroring the short-step, stair and stair-turn split.
   - The edit stays within "the policy word and what loading content 12 needs".
2. **Every new row names connector family 0 (EARTH_TIMBER), the approach and back-ups included.**
   - DEC-050's 90 ticks for a handoff (P-1981-3) can only be an authored connector pace.
   - A ground edge (family −1) takes Movement's cap, which would cross 343 u in 4 ticks.
   - So the stair carry's edges belong to the stair's Placement.
3. **`selection_policy_leaf` is unchanged.** Rooted rows read as policy −1, unselectable, until activation, so no live
   caller can select them even if content 12 were loaded.
4. **New sources rather than successor haul images.** No published image digest moves.
5. **The images carry the hold.** It is the loaded rows' READY hub and the target of the cross-image join.
6. **The tables keep the claw tables' wire, version 1.** Their last program field is the clip ordinal in the row's
   own image (source 6 or 7).

### Content 12 (`mole-worker/qualified-stair-carry-v13/`) and its tables

- **`publish_stair_carry_runtime.py`.** Content 11 plus sources 6 and 7 and rows 71–84:
  - the empty pair takes row 31's words, wood row 32's and stone row 37's;
  - each row's yaw is exact, its family is EARTH_TIMBER, and its policy word is 10–13;
  - wire `fa96acbe…`: 85 rows, 637 boxes, 8 sources;
  - the paired bank is 52,908 B, 5,224 B more than content 11's;
  - the ground caps are content 11's at revision 12, and the motion bank is rebound;
  - the manifest says `runtime_admitted: false`.
- **`publish_stair_carry_motion.py` → `qualified-stair-carry-motion-v1/`:** 14 programs, 1,634 keys and 18 decks,
  33,856 B. The claw tables stay as they are.
- **`underground_profiles.gd`** (cleared, P-1981-5):
  - the four constants;
  - `is_rooted_policy` and `_policy_mode`;
  - the policy checks move into `_policy_refusal`, which shortens `_profile_refusal`;
  - a rooted row is YAW_EXACT, holds no tool, and carries a cargo exactly when its mode is CARRY;
  - the uncertified bound moves from 9 to 13;
  - no other rule changes.
- **Consumer pins renewed** (`renew_source_pins.py --write`, contents 10 and 11). Two tests that used 10 as "the first
  unknown policy" now use `POLICY_ROOTED_TURN + 1`.
- **The memory census.**
  - Profiles' reviewed row records the four constants (no storage), and `REVIEWED_SHA` is bumped.
  - The pack is regenerated: live with reserve is still 100,250,607 B.
  - Content 12's profile bank (+5,224 B) is charged at activation: 270,824 of `PROFILE_BYTES` 278,528, leaving 7,704 B.
- **Checkpoints.** The two ADR 1240 checkpoints (`underground_entry`, `underground_spare`) were regenerated. Their
  saves are byte-identical; only their manifests moved (the fingerprint and the source digests of
  `underground_profiles.gd` and content 10's renewed `catalog_source.gd`).

### Tests

- `godot/test/test_mole_stair_carry_profiles.gd` (17 tests) loads content 12 through the actual loader and validator.
  - Rows 0–70 are unchanged.
  - The new rows' words, units, headings, families and policy words.
  - The derived load box.
  - Rooted rows are not selectable.
  - The predicates.
  - Ten negative edits through the real loader: no cargo; cargo when walking; a tool; free heading; WORK mode; a
    loaded row under POLICY_STAIR or a short-step word; an ambiguous key; policy 14; and item 0 admitted.
- Python tests:
  - `test_publish_stair_carry_runtime.py` (10);
  - `test_publish_stair_carry_motion.py` (8);
  - `stair-carry-v1/test_stair_carry.py` (14). Its rebuild tests re-author every clip and re-derive the rows and
    tables byte for byte.

### Frames (gate)

`scratchpad/staircarry_check/{1280x720,1920x1080}/` holds ten frames each. They come from a scratch capture script,
not committed: the actual wood image on the actual body, posed by the actual Actor at the derived roots over the
bottom fixture's boxes, with the near trench wall hidden so the camera sees in.

- **Down:** the approach on L0, the descent L0 → T0, T2 → T3, T6 → floor, and the walk-off.
- **Up:** the back-up, the turn on the floor, the ascent floor → T6, T3 → T2, and the retreat on L0.

They read as a mole walking the stair with the log held across its chest in both paws. The feet are on the treads
and the log is clear of the steps both ways.

### Mutation testing

**25 mutants, 25 killed** (scratch runner, one mutant per run).
- The Godot suites run without the pin preflight, which would otherwise refuse every mutated consumer before a test
  ran.
- A publisher pins its own bytes into its outputs, so its rebuild test fails for any edit. Publisher mutants are
  therefore judged by the other tests only.

The mutants:
- **Profiles (14):** the bound, the predicate's ends, the tool, cargo and mode rules, the WORK modes, the constant,
  and the moved stair cargo clause.
- **The publishers (7):** ambiguity, key order, row grouping, deck index, root frame, the verification's image digest
  and the template's unit.
- **The author (4):** the contact cell, the floor and support refusals, the wrapper's restore.

Survivors of earlier passes, now killed by new tests:
- A01, the contact cell widened to 3 u: a boundary test lifts a hold 1.5 u and requires the refusal.
- The stair cargo clause, which the review found: a test now edits content 10's descent to name a cargo.
- The publishers' image-digest and template checks, once the self-pin was set aside: two refusal tests.

### Review (independent `code-reviewer`)

**No CRITICAL or HIGH.** The reviewer confirmed:
- live safety: rooted rows are inert to automatic lookup, selection and admission;
- the four-word reasoning;
- the fixture translations, the reversal argument, the ascent orientation and the record's numbers.

**MEDIUM, all fixed:**
1. The stair-cargo test could not fail for its clause. It now edits a WALK stair row.
2. The P-1981-7 strictness claim: the endpoint support check above, and this record corrected.
3. A unit error in this record (1.87 u for 0.0018 u).
4. The tables gave floor-only rows (71, 72, 78, 84) L0's deck. Each handoff row's deck is now its own run's standing
   deck, read from the fixture, and the L0 literal is gone.
5. The fixture shifts were hand-entered. They are now derived from the floor arrival and each handoff's first
   control, and the dead constants are removed.
6. The four-word departure from P-1981-5 was not surfaced. It is now noted in `RULINGS.md` and reported to the
   coordinator.
7. The activation inventory lacked three seams. They are added below.

**LOW, fixed:**
- the native verification now carries and must match the image digest;
- the template cargo check reads the template;
- a test docstring;
- `assertRaisesRegex`;
- the accessor is rebuild-compared with its consumer digests masked;
- the cross-image join count is a real counter;
- the checkpoint wording.

**LOW, kept:**
- Rooted stair and turn words accept family mask 0, unlike POLICY_STAIR. Every published rooted row names family 1;
  ground handoffs remain possible if activation wants them.
- `stair_carry_source.CARGO` stays as a documented closure field.

The images were recaptured and re-verified after the verifier change. Their compile records pin the verifier, so
their digests moved. Content 12 and its tables were republished from the re-run proofs, rows and tables. The wire
bytes are identical apart from the two source digests.

## Activation inventory for content 12 (P-1981-4 (a))

**The content-11 activation lane** switches content 12 on with content 11:

- **Catalog and Session:**
  - `mole_profile_catalog.gd`: content 12's accessor; `SOURCE_COUNT` 8;
  - the image census and pins of sources 6 and 7;
  - `PROFILE_BYTES` accounting (+5,224 B).
- **Presentation:**
  - `mole_presentation.gd` / ContentSet: load the two images;
  - a stair presenter for sources 6/7 (today `present_stair` refuses any source but the claw's);
  - the empty pair's body-only mask;
  - stage the images for the demo pack (decision 1841).
- **Profiles selection:**
  - `selection_policy_leaf` returns 10–13;
  - `_matches`' heading exemption covers `POLICY_ROOTED_TURN` as it covers `POLICY_STAIR_TURN`
    (`underground_profiles.gd`, the heading test in `_matches`);
  - WorldRoutes' backward-heading rule (`underground_world_routes.gd` about l. 1205) adds `POLICY_ROOTED_BACKWARD`
    beside `READY_BACKWARD` and `SHORT_BACKWARD`, or the back-up edges fail `WORLD_ROUTE_PROFILE_HEADING`;
  - Routes' `policy <= POLICY_AUTOMATIC` legacy branch (`underground_routes.gd` about l. 2350) must not take rooted
    rows;
  - `query_travel_profile_into` admits the rooted words with the mode the caller asks for: WALK, or CARRY with the
    actor's committed cargo.
- **Routes** (cost lane's file):
  - dispatch rows 71–84 to a rooted stair program (`qualified-stair-carry-runtime-v1/stair_program.gd`, the twin of
    runtime-v2's);
  - `refresh_travel_actor` for CARRY;
  - the switch at rest at the hold hub (loaded) and at the stand hub (empty).
- **The stair motion owner:** a successor of `underground_stair_motion.gd` that also loads
  `qualified-stair-carry-motion-v1/` (14 programs; census +33,856 B).
- **WorldRoutes:** qualify CARRY stair edges for rooted rows from the tables, as for rows 51–55:
  - `_kind_matches` already compares modes;
  - the floor stops' decks are the trench floor's, not installed timber.
- **The connector catalog** (`_pace_row_refusal`):
  - authored paces for rows on sources 6/7, which today must be on `header[10]` (source 4);
  - CARRY rows on the stair's WALK variant (P-1981 §3's narrowing, or a second variant).
- **The bundle successor** (`qualified-stairs-v10`):
  - DEC-050's paces for rows 71–84: 30 ticks a tread, 45 the turn, 90 each handoff;
  - the stops H (L0, −1536), F (−5975), F′ (−6318) and the floor's ascent start (−5801);
  - the T6 and floor stops' footing.
- **`underground_entry_stair_path.gd`:**
  - the new stops and CARRY edges;
  - the edges below T5 (empty: 53 down to the floor, 54 up from it, 55 on the floor, rows 71/72);
  - a mode-aware `_joined`.
- **The grip certificate:** admits content 12 and the rooted CARRY rows at the hold (the grip is the hold's).
- **Tests and fixtures:**
  - the stair route fixtures;
  - pins (`renew_source_pins.py`);
  - checkpoints;
  - the memory census row for the tables.

**C2.3** binds Delivery and the hauler, and retires `ROOM_HAUL_NO_STAIR_CARRY`:

- **`underground_connector_delivery.gd`:** the leg-by-leg reach. Ground carry (32/37) to H, the rooted stair-carry
  legs by a static per-leg edge certificate check, then ground carry from F′ to the room's stand. The destination is
  the room branch's storage.
- **`underground_entry_hauler.gd`:** the loaded leg list and the empty return list, from a stateless helper over the
  live graph. The save record changes: `Progress.MAX_WIRE_BYTES`, the section-6 `max_count`, and a census row.

### Gates (phase 2)

- **The full CI-style run** (art aside, `godot/.godot` deleted, a fresh import, `./tools/run_tests_parallel.sh`, 10
  shards, at `86a11d5c`): **12,556 tests, 1,232,892 assertions, 0 failures, 0 unexpected errors or warnings, 0
  leaks**. Verify passed: 506 suites, each exactly once.
- **The analyzer** (`tools/gdscript_warnings.py --max 0`): 0 warnings in 1,549 files.
- **The contracts:** `decision_numbers`, `ready07_arithmetic`, `merge_gate`, `state_registry_coverage`,
  `lane_notes`, `dispatch_plan --validate`, `generate_canonical_state_table --check`, `astra_inbox --check`,
  `setting_contract`, `renew_source_pins --check` (contents 10, 11 and 12), and `underground_memory_budget.py --check`
  with the census tool tests: all pass.
- **The Python tests:** `test_stair_carry.py` (14, including the byte-for-byte rebuilds),
  `test_publish_stair_carry_runtime.py` (10) and `test_publish_stair_carry_motion.py` (8): all pass.
- **Mutation testing:** 25 of 25 killed. **The independent review:** no CRITICAL or HIGH (above).
