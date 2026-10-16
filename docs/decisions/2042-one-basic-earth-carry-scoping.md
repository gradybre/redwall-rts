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

- `python3 docs/validation/decision_numbers.py`: see decision 2043's gates.
