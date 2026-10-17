# 2042 — One basic earth carry: scoping, stopped for rulings

Date: 2026-10-16 · Status: Accepted. Brendan ruled P-2042-1 to P-2042-6, all the recommended option (a), on
2026-10-16 (see "Brendan's rulings"). The scoping itself (sections 1–5) changed no code and no data; phase 2c (the
inactive data) follows in this record's later sections.

Number range: 2041–2049, the D-flight lane's ([decision 2041](2041-slice-d-flight-scoping-a-full-level-earth-timber-flight.md)).
Branch `docs/slice-d-flight`, from origin/master `c11da82e`.

## Brendan's rulings (2026-10-16)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2042-1 | **(a)**, "Stone lump, earth colour" | Earth is carried as the approved stone lump drawn in an earth colour: no new model, asset or motion |
| P-2042-2 | **(a)**, "Approve all" | 5,000 milli-U a trip, the 5,000 g every certified trip weighs |
| P-2042-3 | **(a)**, "Approve all" | Eleven derived rows (content 13) and a grip-certificate successor with three families |
| P-2042-4 | **(a)**, "Approve all" | Underground piles first; otherwise up the stair to a surface pile or tip |
| P-2042-5 | **(a)**, "Approve all" | One frames review, no packet |
| P-2042-6 | **(a)**, "Approve all" | The inactive data now in new files; activation after the activation lane and cost-2 merge |
| P-2042-5's review | **"Approve"** (2026-10-16) | Brendan reviewed the phase 2c frames (`earthcarry_check/`, the stone lump drawn earth-brown `4a3527`, down and back up the qualified stair) and approved the earth carry's look |

Indexed in `docs/handoff/RULINGS.md`.

## Brendan's direction (2026-10-16, relayed by the coordinator)

Decision 2041 P-DF-7, ruled **(a), "Qualify an earth carry"**. Qualify one basic earth carry, on the level and on the
stair, before the full-level flight's deep layers are cut. The spoil from the top metre keeps going to land piles.
The ruling adds that a new earth load model, if one is needed, is asked about separately.

The coordinator asked this lane to follow [decision 1981](1981-one-basic-stair-carry-scoping.md)'s pattern, and to
say plainly whether a new earth load model or asset is needed.

## Decision (as proposed)

**No new model, asset or motion is needed.**

- **The load.** Carry earth as the approved stone load: the procedural stone lump of ADR 1206
  (`godot/demo/tunnel/bore_dressing.gd:329` `stone_mesh()`), at stone's approved size, drawn in an earth colour.
- **What follows.** The certified grip, the lift and place, the loaded level gait, the joins and decision 1981's
  stone stair carry all hold for earth byte for byte, because the carried solid is the same.
- **The new data.** Eleven rows: stone's level rows 37–41 and stair rows 79–84, copied with their cargo words set to
  `excavated_earth`. They need a grip-certificate successor with a third family.
- **The payload.** One trip carries 5,000 milli-U (5 kg), the same mass as every certified trip.
- **The haul.** Earth goes up the stair to the surface through Delivery, with the hauler's legs reversed.
- **Paid generation.** None is involved. Only if Brendan rejects the lump (P-2042-1 (c)) would a modelled sack or
  basket be needed, and that would be asked about separately with its cost.

## 1. Findings (origin/master `c11da82e`)

**E1. Earth has no certified carry.**

- **The certificate.** `qualified-claw-runtime-v1/grip_certificate.gd:47–49` defers to
  `qualified-stone-v7/grip_certificate.gd:88–92`. That certificate finds a carry row by matching the item against
  the cargo word (`Profiles.F_CARGO`) of exactly two families: wood (rows 32–36) and stone (rows 37–41). Every other
  item returns −1.
- **The consequence.** The hauler refuses any bill for an uncertified item (`underground_entry_hauler.gd:62–75`,
  `REFUSE_ITEM`). Decision 1931 line 177 records the result: once a pile is full, the honest outcome is
  `SPOIL_OUTPUT_BLOCKED`.

**E2. A row names one cargo item and one quantity.**

- **The quantity.** The certificate's `QUANTITY_MILLI` is 1,000, and its CARRY and unload rows carry exactly
  1,000..1,000 (`qualified-stone-v7/grip_certificate.gd:19, 129`).
- **The stair rows.** Content 12's loaded stair rows carry a cargo exactly when their mode is CARRY (decision 1981
  line 535).
- **The matching.** Decision 1972 measured a loaded descent "admitted only with the wood". So a stone row cannot
  carry earth: selection compares the actual cargo with the row's word.

**E3. Mass.**

- **The catalog.** `godot/data/item_definitions.json` gives `excavated_earth` 1,000 g/U, and wood and stone 5,000 g/U
  each. Every certified trip therefore weighs 5,000 g.
- **Earth's equivalent.** At earth's mass, the same 5,000 g is 5 U.

**E4. How much earth must move.**

- **Per cube.** Each cut cube posts 2,000 milli-U (`excavation_contract.gd:16`).
- **The flight.** The full-level flight's deep cubes are 96 for F40 (decision 2041 §2.4), or 100 for the modular
  M5 that decision 2043 proposes. At 2 U a cube that is 192–200 U of earth below the top metre.
- **A level-1 room.** A painted cell is 4 cubes, 8 U (SET-BUILD-001 §7.2). One ground pile holds 400,000 g, about
  200 cubes or 50 cells (ECON-004; decision 1931 line 177).
- **Trips.**

| Payload per trip | F40 deep spoil (192 U) | One level-1 cell (8 U) |
|---|---:|---:|
| 1,000 milli-U (as wood and stone) | 192 trips | 8 trips |
| **5,000 milli-U (the same 5,000 g)** | **39 trips** (ceil 192 / 5) | **2 trips** (ceil 8 / 5) |

**E5. The stone precedent (ADR 1206): no stone asset existed either.**

- **Brendan chose the procedural lump.** He then approved three things: its size, a new two-hand grip (R−S 576 u,
  the same stands as wood) and the motion.
- **The capture.** The lump entered the haul image through a factory capture, `native_capture_stone/`, with no
  palette bake (ADR 1206 step 1).
- **Its rows.** The stone rows 37–41 and the stone stair carry 79–84 (decision 1981) are qualified for that exact
  solid.

**E6. Decision 1981's method.** The accepted stair authors run unchanged on a hold pose. The load is a second rigid
part in every proof. So the stair carry's proofs depend on the load's geometry and the hold, not on the item's name.

**E7. Delivery moves stock downward only.**

- **Today.** The entry's hauler and C2.3's room Delivery move wood and stone from a storage (M, or a staging
  container) to a station (decisions 1202, 1935).
- **For earth.** The flow runs the other way: from an underground ground pile, up the stair, to a surface
  destination. `godot/scripts/core/spoil_tips.gd` is the ECON-004 tip ledger. A tip is exterior only.
- **The leg list.** C2.3 owns Delivery's leg-by-leg reach and the hauler's leg list (P-1981-4 (a)).

**E8. What the activation lane and cost-2 hold.**

- **The files.** Profiles (row admission, words), the stair motion owner (stair tables), the connector catalog and
  contacts, and Locations. Cost-2 also holds `underground_connector_delivery.gd` and Routes.
- **The budget.** Content 12 left `Budget.PROFILE_BYTES` 2,072 B of headroom after P-1972-2: 282,624 against
  280,552 (decision 1972, finding 3).
- **The check bound.** M-2, WorldRoutes' check bound, already overflows with content 12's extra rows, pending
  cost-2.

## 2. What is derived, and from what

- **The load.** The stone lump, at the scale and squash ADR 1206 adopted, as the earth load. **Every stone proof is
  then an earth proof:**
  - the static grip contacts;
  - star containment;
  - the four-phase lift and place;
  - the loaded gait and the joins;
  - decision 1981's terrain, flight, bottom and handoff proofs with the load as a rigid part;
  - self-clearance against the load.
  
  None depends on the item, only on the solid and the hold.
- **The rows.** Rows 37–41 and 79–84 copied word for word as rows 85–95. Only two things change:
  - the cargo word, from stone's item to `excavated_earth`'s;
  - the cargo quantity, from 1,000..1,000 to 5,000..5,000 under P-2042-2 (a). The rows' boxes are the stone rows'
    own.
- **The size of the change.** That is 11 rows in a content 13, appended after 84 as content 12 appended after 70.
  The boxes are the stone rows' own; their count is read from the wire in phase 2.
  - **Profile memory, estimated** by decision 1972's formula `2 × (98 × rows + 28 × boxes)`. At content 12's average
    of 5 boxes per added row, that is about 2 × (98 × 11 + 28 × 55) = **5,236 B**. That is more than the 2,072 B of
    headroom, so it needs a `PROFILE_BYTES` row through ADR 1212.
- **The certificate.** A successor of `qualified-stone-v7/grip_certificate.gd` (new file) with three families (wood,
  stone, earth) and a per-family `QUANTITY_MILLI` (1,000, 1,000, 5,000).
- **The hauler.** `units_into` reads the quantity through `Grip`, so it follows the certificate. Its loop subtracts
  `Grip.QUANTITY_MILLI`, so it needs the per-family read.
- **The pace.** DEC-050's addendum already covers "a mole carrying one unit of wood or stone". An earth trip is the
  same body, solid and clips, so P-2042-2 asks for that wording to cover earth.
- **Presentation.** The haul image binds the carried mesh per source. Earth is either the stone source with an earth
  material, or a source 8 captured with the earth-coloured lump. That is a material change only, done through the
  same factory capture as ADR 1206 step 1. No palette bake is needed, as for stone.

## 3. How it would publish (data only, inactive, as decision 1981's content 12)

| New file | What |
|---|---|
| `mole-worker/earth-carry-v1/derive_earth_rows.py` | Copies rows 37–41 and 79–84 from the content-12 wire with the cargo item and quantity replaced. Proves every other word and every box byte-identical to its stone row |
| `mole-worker/earth-carry-v1/derive_earth_tables.py` | The stair tables (UGSTRM01) for rows 90–95: stone's tables re-labelled, roots, headings and decks unchanged |
| `mole-worker/earth-carry-v1/test_*.py` | Identity to stone; the cargo and quantity words; the trip arithmetic of E4 |
| `mole-worker/publish_earth_carry_runtime.py` → `qualified-earth-carry-v14/` | Content 13 (create-only): rows 0–84 from content 12 byte for byte, 85–95 appended; the grip-certificate successor; manifest |
| `godot/test/test_mole_earth_carry_profiles.gd` | Content 13 through the real loader, as `test_mole_stair_carry_profiles.gd` does for 12 |
| Optional: `haul-handling-v1/native_capture_earth/` | Only if P-2042-1 (a) takes its own source: the earth-coloured lump through the real factory |

## 4. What Delivery needs, and who wires it

- **Upward legs.** Delivery and the hauler need a leg list from a ground pile up the stair to a surface destination:
  ground carry, the stair carry's back-up (W6), half-turn, ascents and retreat (decision 1981 "the loaded round
  trip", read upward). The legs are C2.3's (P-1981-4 (a)); Delivery is cost-2's file.
- **A destination.** A surface ground pile, or an ECON-004 tip (`spoil_tips.gd`) under P-2042-4. Tip work (prepare,
  compact) is ECON-004's own job and is not new here.
- **Profiles.** Content 13's admission is the same kind of edit as content 12's: four policy words (10–13) exist,
  and no new word is needed.

## 5. Proposals

**P-2042-1 — The earth load (the asset question).**

- **(a) The stone lump itself, at stone's approved size, drawn in an earth colour. No new model or asset, no new
  grip and no new motion: every stone proof holds byte for byte.**
- (b) A new procedural sack or basket, made by code. That costs no money, but it repeats ADR 1206's whole pipeline
  (size, grip, lift and place, loaded gait, joins, native capture, three reviews) and then decision 1981's stair
  carry.
- (c) A modelled sack or basket, from a library or by paid generation. This needs Brendan's itemised approval and
  may cost credits, plus everything in (b).

**Recommendation: (a).** A clod of earth carried in both paws reads naturally, and it is the only option with no new
motion.

**P-2042-2 — The payload of one trip.**

- **(a) 5,000 milli-U, the same 5,000 g as every certified wood or stone trip: 39 trips for F40's deep spoil, 2 per
  level-1 cell. DEC-050's laden pace applies unchanged.**
- (b) 1,000 milli-U, as wood and stone: 192 trips and 8 per cell, at 1 kg each.
- (c) 12,000 milli-U, ECON-004's illustrative payload. That is heavier than any certified hold and would need a new
  pose.

**Recommendation: (a).** Mass, not unit count, is what the hold certifies.

**P-2042-3 — How the rows carry earth.**

- **(a) Derived rows: a third family, the stone rows copied with the cargo and quantity words replaced (11 rows,
  content 13), and a grip-certificate successor.**
- (b) A Profiles cargo-class rule letting the stone rows carry earth. There are no new rows, but it edits Profiles'
  matching, which the activation lane and cost-2 both hold, and it changes every stone row's meaning.
- (c) New rows authored from a new earth hold. Only with P-2042-1 (b) or (c).

**Recommendation: (a).**

**P-2042-4 — Where hauled earth goes.**

- **(a) Underground ground piles first (ECON-003, unchanged). When none is legal, or for the flight's deep cuts, it
  goes up the stair to a surface ground pile or an ECON-004 tip, whichever the existing surface rules choose.**
- (b) Underground piles only, with no carry. That leaves decision 2041 F7 unsolved.
- (c) Always carried to a surface ground pile, never a tip, which is simpler. Tips then fill only from surface work.

**Recommendation: (a).**

**P-2042-5 — Review.**

- **(a) One frames review: the earth lump in the paws, on the level and on the stair, at 1280×720 and 1920×1080. No
  packet, as P-1981-6.**
- (b) A full review packet.
- (c) No review.

**Recommendation: (a).**

**P-2042-6 — Sequencing (for the coordinator).**

- **(a) Now, inactive:** the derivation, the identity proofs, the content-13 wire and the certificate successor, all
  in new files. **After the activation lane and cost-2 merge:** Profiles admission, the stair-table load, the
  hauler's per-family quantity, Delivery's upward legs, the `PROFILE_BYTES` row and M-2's re-measurement, in one pass
  with the pins, census and checkpoints.
- (b) Fold it into the activation lane now. That lane is mid-flight and waits on cost-2.
- (c) Wait for both merges before any of it.

**Recommendation: (a).**

## Phase 2c — the inactive data (2026-10-16)

Built under P-2042-6 (a), in new files only. Nothing is mounted or activated, and no held file was edited.

### Content 13, `mole-worker/qualified-earth-carry-v14/` (create-only, `publish_earth_carry_runtime.py`)

- **The wire:** 96 rows, 698 boxes, 10 sources, `fdfcf875…`.
  - Rows 0–84 and sources 0–7 are content 12's, byte for byte.
  - Rows 85–89 are stone's level rows 37–41 (CARRY, two loads, two unloads). Rows 90–95 are stone's stair-carry
    rows 79–84.
  - In each, the cargo becomes `excavated_earth` (compiled item 11) and a carried unit becomes 5,000 milli-U
    (P-2042-2). The load rows keep 0..0. Every other word and every box is the template's.
- **Two new sources, not one: a change from §2.**
  - **Why.** Profiles keys rows within each source and refuses a source whose rows are out of key order
    (`underground_profiles.gd` `_validate_stage`, `PROFILE_KEY_ORDER`). Item 11 sorts before stone's 53, so an earth
    row appended to source 3 or 7 would be refused.
  - **What was done.** Source 8 (level) repeats source 3's digest, the stone haul image v10. Source 9 (stair)
    repeats source 7's, the stone stair-carry image. The images carry geometry, never a material
    (`compile_native_program_v9.stone_part`), so the same image serves; the earth colour is presentation's.
  - **The test.** `test_earth_rows_cannot_share_the_stone_sources` shows the loader refusing both alternatives.
- **Ground paces:** content 12's 26 caps, plus row 85 with row 37's cap, at revision 13.
- **Motion bank:** content 12's, rebound to revision 13 and the new wire.
- **The accessor** names `EARTH_ITEM` 11, `EARTH_QUANTITY_MILLI` 5,000, `EARTH_LEVEL_ROWS` 85–89 and
  `EARTH_STAIR_ROWS` 90–95. The manifest says `runtime_admitted: false`.
- **Not built as separate scripts.** §3 named `earth-carry-v1/derive_earth_rows.py` and `derive_earth_tables.py`. The
  publishers derive the copies themselves, because there is nothing to author: the identity to stone is checked
  inside them and in their tests.

### The stair tables, `mole-worker/qualified-earth-carry-motion-v1/` (create-only, `publish_earth_carry_motion.py`)

- **The wire:** content 12's 14 programs (rows 71–84), then rows 90–95, which are stone's programs 79–84 with only
  the row, source (9) and group changed.
- **The format:** `UGSTRM01` at revision 13 and the content-13 wire's digest; 20 programs, 2,360 keys, 26 decks,
  48,856 B.

### The certificate successor, `qualified-earth-carry-v14/grip_certificate.gd` (new file)

- **Three families:**
  - wood, rows 32–36, source 2;
  - stone, rows 37–41, source 3;
  - earth, rows 85–89, source 8.
- **Trips:** 1,000, 1,000 and 5,000 milli-U a trip (`quantity_of(item)`; the table is `FAMILY_QUANTITY_MILLI`).
- **Drop-in names.** `QUANTITY_MILLI` stays the int 1,000 that every caller reads today, and `stock_offset` and `turn`
  pass through. So the successor can replace `qualified-claw-runtime-v1/grip_certificate.gd` where it is preloaded.
- **Any other content is handed on.** A bank of content 6, 9 or 10 goes to `qualified-claw-runtime-v1`, as that
  certificate hands content 6 to its own parent. The certificate follows the loaded content, and switching the preload
  before content 13 is mounted changes nothing.
- **The earth family** repeats stone's words, with the source, the cargo and its own first boxes (637, 644, 662). It
  also repeats stone's boxes, contact cells and transform S = R + (0, 0, −576). Its source digest must be the stone
  image's.
- **Not preloaded.** Nothing loads it until phase 2b.

### Tests

- **`godot/test/test_mole_earth_carry_profiles.gd`:** 8 tests, through the real Profiles loader and validator. It
  covers:
  - content 12's rows unchanged;
  - the earth rows against their templates;
  - item 11 being `excavated_earth`, with 5,000 milli-U equal to 5,000 g;
  - the rooted earth rows not being selectable;
  - all fifteen certified rows;
  - six certificate refusals, each on a wire that still loads: trip, revision, max quantity, source, a widened box,
    content 12;
  - the key-order seam;
  - the station transform at both headings.
- **`mole-worker/test_publish_earth_carry_runtime.py`:** 13 tests. Both publishers rebuild byte for byte. The identity
  to stone, the item ids, the ground and motion rebinding, the accessor, the manifest and five refusals are checked
  on what the publishers build now.

### Frames (P-2042-5 (a), for Brendan's review)

- **The capture.** A scratch capture adapted from decision 1981's. It is not committed:
  `scratchpad/earthcarry_frames/run_frames.py` and `capture_frames.gd`.
- **What it shows.** The actual stone stair-carry image on the actual body, posed by the actual Actor over the derived
  stair fixture. The stone lump is drawn in an earth colour (`4a3527`); the carried solid is unchanged.
- **The frames.** Eleven at each size, in
  `/private/tmp/claude-501/-Users-brendan-Developer-redwall-rts/dbd322db-eba7-4c50-8879-3d1bb8099e65/scratchpad/earthcarry_check/{1280x720,1920x1080}/`:
  - `01_down_approach_on_L0` and `02_down_approach_on_L0_mid` (level ground);
  - `03`–`05`: descents L0 → T0, T2 → T3 and T6 → floor;
  - `06_down_walk_off_floor` and `07_up_back_up_floor` (level floor);
  - `08_up_turn_floor`;
  - `09`–`10`: ascents floor → T6 and T3 → T2;
  - `11_up_retreat_on_L0`.
- **How they read.** A mole holds a dark-brown clod across its chest in both paws, on the level and on the treads,
  with its feet on the decks.

### The seams phase 2b must cross (held files; nothing here edits them)

1. **Mounting content 13.** Today the activation lane mounts content 12 at revision 12. Phase 2b needs:
   - `underground_session.gd` and `underground_route_composition.gd`: the revision, and `GROUND_PACE_COUNT` + 1 for
     row 85's cap;
   - `runtime_files.gd`: the paths.
2. **Programs and certificates admitting revision 13.** P-1972-1's "content 10 or its successor 12" predicate becomes
   "… or 13". It lives in `qualified-claw-runtime-v2/claw_program.gd`, `stair_program.gd` and `paw_program.gd`, and in
   the runtime-v1/v2 endpoint and grip certificates (activation lane).
   - `stair_program.gd` must also own rows 90–95 on source 9.
3. **The grip certificate.** Callers switch their `Grip` preload to `qualified-earth-carry-v14/grip_certificate.gd`.
   Each place that reads the per-trip quantity must read `quantity_of(item)` for earth's 5,000:
   - `underground_entry_hauler.gd` `units_into` and its trips (`Grip.QUANTITY_MILLI`), lines 74, 229 and 242, and `stock_offset` at
     347;
   - `underground_connector_delivery.gd` (cost-2): `Grip.QUANTITY_MILLI` at 440, 444 and 695, `stock_offset` at 724,
     and `_reach_stands`;
   - `underground_room_builder.gd`: `stock_offset` at 505.

   Line numbers are at master `c11da82e`. The names are kept, so the switch compiles. Only the quantity reads change
   behaviour.
4. **Connector paces for rows 90–95.**
   - `underground_connector_catalog.gd` `_pace_row_refusal` ties authored paces to source 4. Decision 1981 already
     lists narrowing it for sources 6 and 7, and the bundle's DEC-050 paces for rows 71–84, as activation work.
   - Phase 2b extends both to source 9 and rows 90–95: 30 ticks a tread, 45 the half-turn, 90 a handoff.
5. **The stair motion owner.** `underground_stair_motion.gd` `load_carry_file` (activation lane) loads
   `qualified-earth-carry-motion-v1` for content 13, whose pins it does not yet know.
6. **The budget.**
   - Content 13's profile bank is 2 × (98 × 96 + 28 × 698 + 32 × 10 + 32) + 32,768 = 91,376 B, which is 5,700 B more
     than content 12's 85,676. That is beyond the 2,072 B left under `Budget.PROFILE_BYTES` 282,624 (decision 1972),
     so it needs a `PROFILE_BYTES` row through ADR 1212.
   - The stair tables grow from 33,856 to 48,856 B.
   - The census and pack are re-run, as is M-2's check-bound measurement, because 11 more rows enter every
     per-profile loop.
7. **Presentation.**
   - `mole_haul_program.gd` `program_into` serves sources 2 and 3 only; source 8 must map to the stone haul clips.
   - `mole_presentation.gd` `present_stair` (activation lane): source 9.
   - `demo/cast/underground_content_set.gd` `MAX_SOURCES`: 8 → 10.
   - The earth material for the lump.
8. **Delivery's upward legs and the earth destination** (P-2042-4): `underground_connector_delivery.gd` (cost-2), and
   C2.3's `underground_room_builder.gd` haul stage and the hauler's leg list.
9. **Pins, census and checkpoints,** in one pass with the above.

### Mutation testing

**GDScript certificate.** 44 single-site mutants: 31 in the first pass, 6 rerun after fixes, and 7 on the review's
fixes.

- **First pass, 8 survived.**
  - Four were killed after tests were added: `uses()`'s row offset, the max-quantity check, the source word and the
    boxes check.
  - `is_load`'s guard was redundant and has been removed (its replacement mutant is killed).
- **The review found a non-equivalent survivor the first record missed:** the source-digest check (`return true`
  passed every test). `test_the_earth_source_must_be_the_stone_image` now kills it. It swaps the wood image into
  source 8, which still loads, and checks that every earth row is refused.
- **The review's fixes.** All of them are killed: the delegation to the previous certificate, the allocation-free hex
  decode, the per-family quantity and the digest choice.
  - One survivor, an earth-row guard in the delegation, was redundant (the previous certificate refuses rows 85–89),
    and the guard has been removed.
- **Three survivors remain, each with a reason:**
  - **The source-count bound** in `profile_refusal`. A defensive bound: a revision-13 wire with fewer than nine
    sources cannot carry rows 85–89, which name source 8, so the loader already refuses it.
  - **The heading check in `station_refusal`.** Equivalent by geometry: at the wrong heading the turned contact cells
    leave the row's boxes, so the contact check refuses anyway. The templates keep the same line.
  - **The final stock-in-stroke check.** Equivalent under the exact transform: S is fixed relative to R, and S lies in
    every certified row's stroke box. The template's line is the same.
  - **Note:** the review found the contact loop of `station_refusal` equivalent for the same reason.

**Python publishers.** The rebuild tests are set aside, as decision 1981 did, because a publisher pins its own bytes.
The other tests judge what the publishers build now.

- `publish_earth_carry_runtime.py`: 13 mutants, 12 killed.
  - The one survivor is equivalent: the item-id sort. For wood, stone and `excavated_earth` the catalog's file order
    and its ascending-ASCII order give the same ids (60, 53, 11).
- `publish_earth_carry_motion.py`: 4 mutants, 4 killed.

### Review (independent `code-reviewer`)

No CRITICAL, 1 HIGH and 4 MEDIUM.

**HIGH, fixed: no test exercised the certificate's source-digest check.** See the mutation testing above.

**MEDIUM.**

- **Fixed.** The successor's names are now a drop-in replacement; every caller is listed in seam 3.
- **Fixed.** Other contents are handed to the previous certificate.
- **Fixed.** `_digest_matches` no longer allocates a String per byte.
- **Added as seam 4.** The connector paces for rows 90–95.

**LOW, fixed.**

- The stair-table publisher now parses the content-13 wire and checks that rows 90–95 are source-9 copies of 79–84.
- The motion rebind refuses any byte changed outside its four ranges (`MOTION_FOREIGN_DELTA`), and the test checks
  the I64 revisions.
- The certificate reads `Pins.EARTH_LEVEL_SOURCE` and `Pins.EARTH_QUANTITY_MILLI` instead of retyping them.
- `module_translation` documents that its (0, 1, 0) means no module.

**LOW, answered, not changed.**

- `landing_stop_into` keeps its name. It exists only for M5's landings, and the `layout` argument is its first.
- Both publishers were republished after these edits, because each pins its own bytes. The content-13 wire is
  byte-identical (`fdfcf875…`).

## After the activation merge (#272, 2026-10-17)

Merging #272 (content 12 mounted, decision 1972) into #271 broke two expectations in
`test_mole_earth_carry_profiles.gd`. **Both were stale, not defects.**

- **Rooted rows are selectable now.** Activation made Profiles select the rooted words 10–13, so rows 90–95 select
  10/12/12/13/10/11, exactly as their stone templates 79–84 do. The test now asserts that equality, and that a stale
  content revision selects nothing. It used to assert −1, "never selected yet".
- **Content 12 is certified now.** `qualified-claw-runtime-v1/grip_certificate.gd` admits content 12 since #272
  (P-1972-1). The successor hands any content other than 13 to that certificate, by design, so it now certifies
  content 12's wood and stone as well. The test asserts that it agrees with the previous certificate, and that
  content 12 has no earth family. It used to assert "content 12 refused".

**One republication.** #272 renewed the consumer digests in content 12's accessor, which content 13's publisher pins
as an input. Content 13 was republished: only its accessor's consumer digests and its manifest's input hash moved. The
wire (`fdfcf875…`), ground paces, motion bank and stair tables are byte-identical. #271 is unmerged, so nothing
published on master moves.

**Gates after the merge:**

- the lane's three suites: 32 tests, 0 failures;
- the analyzer on port 6503: 0 warnings in 1,614 files;
- `decision_numbers`: PASS, 569 records;
- the publisher tests: OK;
- the full suite CI-style: `ok: 12904 tests, 1451699 assertions, 0 failures`, 0 unexpected errors or warnings, 0
  leaks.

## Consequences

- **Not this lane's.** The earth carry serves the flight's deep spoil and every level-1 room past its first pile.
  Moving earth from the surface back down (backfill inputs, ECON-005) uses the same rows down the stair, but its
  Delivery wiring is a later slice's.
- **If P-2042-1 (a) is rejected,** the asset question goes to Brendan with costs before anything is made.
- **The earth carry gates the flight's deep layers** (decision 2043's construction order). It must activate before
  layer 2 is cut.

## Source

- **Brendan's ruling.** Decision 2041 P-DF-7 (a).
- **The precedents.** ADR 1206 (the stone lump, its grip and motion); decisions 1981 (the stair carry, content 12),
  1972 (content 12's admission, `PROFILE_BYTES`, M-2), 1931 (spoil), 1935 (room Delivery) and 1936 (P-1981-4's
  owners).
- **Contracts.** SET-MOVE-ECON-001 ECON-003/004/005; SET-BUILD-001 §7.2; DEC-050 and its addendum.
- **The code.** `godot/data/item_definitions.json`; `excavation_contract.gd`; `qualified-stone-v7/grip_certificate.gd`;
  `qualified-claw-runtime-v1/grip_certificate.gd`; `underground_entry_hauler.gd`; `spoil_tips.gd`;
  `bore_dressing.gd`.

## Gates run (this record)

Phase 2c, on the final code after the review's fixes:

- **Full suite, CI-style.** `godot/demo/assets` was moved aside and `godot/.godot` deleted. The import ran (exit 0),
  then `./tools/run_tests.sh`, then the assets were restored. The result was `ok: 12838 tests, 1437865 assertions,
  0 failures`:
  - `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 278 expected, 456 tolerated; leaked at exit: 0
    object(s), 0 resource(s)`;
  - `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s)`.
- **Analyzer:** `python3 tools/gdscript_warnings.py --max 0 --port 6503`, `0 GDScript warning(s) in 0 of 1609
  file(s)`.
- **Movement:** `test_movement_profile_policy: PASS -- 148 check(s)` and `test_movement_envelopes: PASS -- 191
  check(s)`.
- **Python:** `test_publish_earth_carry_runtime.py` 13 OK. Decision 1981's `test_publish_stair_carry_runtime.py` and
  `test_publish_stair_carry_motion.py` are unchanged and OK. `test_probe_rise_160.py` 7 OK.
- **Contracts:**
  - `decision_numbers: PASS -- 567 records`;
  - `lane_notes`, `dispatch_plan`, `astra_inbox`, `merge_gate`, `ready07_arithmetic`, `state_registry_coverage` and
    the canonical state table: PASS;
  - `underground_memory_budget.py --check`: unchanged, because nothing new is mounted.
- **Mutation and review:** above.
