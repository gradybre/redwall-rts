# 1981 — One basic stair carry: scoping, stopped for rulings

Date: 2026-10-15 · Status: Proposed. Scoping only; no code or content. Stopped for Brendan's rulings on P-1981-1 to
P-1981-6 and the coordinator's sequencing.

Number range: 1981–1989 was allocated to this lane by the coordinator, and checked free on every local and remote
ref. This is the lane record; later records of the lane take 1982 onwards. Branch `feat/stair-carry`, from
`f1d4c3a0`.

## Brendan's direction (2026-10-15, relayed by the coordinator)

- "Real digging, in full"; "I just want the basic claw stroke that digs anything" (decision 1971).
- On decision 1934's P-C22-1: **"Same-level now + basic stair carry"**. The C2 lane builds the same-level room
  Delivery. This lane is the basic stair carry: one carry motion family, in the spirit of the one claw stroke, derived
  from existing clips and rows rather than through a long motion-review pipeline.

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
