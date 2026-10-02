# 0623 — The infirmary is its own building: GDD §5.9's Infirmary, placed, built, and where the hurt rest and heal
Date: 2026-10-01 · Status: Accepted (Brendan's ruling on 0622, 2026-10-01). Supersedes 0622 P2 and P5.

## Decision
Brendan ruled: **"The infirmary should be its own place and that's where residents go to rest and heal."** The demo
now builds the GDD's own Infirmary building and sends the hurt there. The "designate a dug burrow home as the sickbay"
path from the Tunnels panel (0622 P5) is **retired**: its code is removed (the night's kept-beds filter, the room-box
section, the desk's sickbay rules), and nothing in a home's beds is reserved any more.

1. **The figures are read from the settlement's own tables, never restated** (`demo/infirmary/infirmary_rules.gd`).
   Re-verified on GDD §5.9 (line 635), `gameplay_balance.md` §4.1 (line 201) and §4.2 (line 236), and the compiled
   `scripts/core/building_definitions.gd` / `construction.gd BUILD_MATERIALS`: footprint 8 × 8 tiles; wood 40, stone 30,
   cloth 12; 1000 WU; operational slots 2 ("Healer 2"); unlock M1; at most 4 builders. The **8 patient beds** are §5.9's
   capacity column ("Interior 6×6;8 patient beds"), which no compiled table carries. `test_demo_infirmary_building.gd`
   asserts each one.
2. **Available from the start**, as Brendan ruled for the cellar building (decision 0612 P1): the GDD's M1 needs 12
   residents, which the nine-resident demo never reaches.
3. **Placing it** (`infirmary_place.gd`): the cellar building's placing tool, for one building. The Tunnels panel gains
   an **Infirmary** section under its housing line (`tunnel_panel.gd add_section`; `infirmary_section.gd`) with
   **Build the infirmary…**, which arms the tool: a ghost follows the pointer, brass where it may stand and clay with the
   reason where not (off the village, on an obstacle, a work spot, a building, the crop beds, the water, over a tunnel or
   a dug room; its door and material site must be standable); a left click places it, Esc or a right click puts the tool
   away. **No key is added.** Once placed the button is **Cancel the infirmary** (its tooltip says what it returns);
   built, it is disabled.
4. **Building it** follows REQ-SET-124/125/126 exactly as the cellar building does (`infirmary_project.gd`,
   `infirmary_builders.gd`): placing deducts nothing; its 4 places are on the work board's new **"Infirmary"** source
   (`work/care_work.gd`, `WorkIds.SOURCE_CARE` = 8); a builder reserves a material as it sets off, lifts it at its source
   (only then is it taken), carries its §5.2 carry over the §5.5 mass (wood and stone 5000 g a U, cloth 250 g) and sets
   it down at the site; reserved, in transit and delivered all count against what is still needed, so nothing is
   fetched twice; once everything is delivered the builders' summed work (a WU 0.15 s of one builder's time) builds it;
   a builder called away puts its load back whole; Cancel lets the builders go and returns 100% of what was delivered
   before work began, 80% floored after. **Wood and stone come from the village stores at the open stockpile; cloth
   comes from the care shelf at the hall's steps** — the demo's only cloth (§5.1's 24 U).
5. **Where the hurt go** (`care_desk.gd` PATIENTS, `care_tasks.gd` BedRest): built and with a free bed, a hurt resident
   walks to its door and goes in (inside, not drawn), is admitted to one of its 8 beds, is treated there, recovers at
   REQ-SET-017's infirmary rate (+4 an hour), and leaves its bed when it gets up. At most 2 healers treat inside at once
   ("Healer 2"). Before it is built, or when it is full, the fallback is PROPOSAL P2 below.
6. **The look uses existing library models only** (`infirmary_view.gd`): the library's `residence` building (a timbered
   cottage on a stone plinth) drawn at the INFIRMARY's lookdev envelope height (5.5 m, `lookdev_dimensions.gd`), with
   `hanging_stores_strung` herb strings and a `pantry_shelf` of remedies at its door; a plank stack, tunnel rubble and a
   sack pile at its site grow with the wood, stone and cloth delivered; placed it lies flat as its marked footprint,
   being built it rises with the work, built it stands whole. Nothing new staged, nothing paid. **ART GAP:** the library
   has no infirmary model of its own; it borrows the residence's.
7. **Drawn and stood at the cellar's reduced scale.** §5.9's 8 × 8 tiles (16 × 16 m) are read and tested but not
   drawn: as the cellar building and the covered store are (decision 0612 P4, decision 0082), it is drawn at its lookdev
   envelope (about 5 × 4.5 m) and stands as a 2.9 m obstacle disk. It keeps clear of the care desk's own places -- the
   care shelf, the herb patch, the field-care spots and the stockpile -- or their work could never be reached.
8. **One cloth ledger.** The building's fetch keeps back the cloth the healers already sent will take, and a healer is
   sent only while the shelf, less the cloth the building has reserved or in hand, covers it: whichever claimed first
   keeps it; neither ever finds the other has taken it.
9. **Its footprint is an obstacle** from the moment it is placed (`cast_space.gd set_structure`, the last of the 4
   structure slots; the cellar buildings take the first). The `cast_space.gd` and `tunnel_control.gd` hunks are copied
   **verbatim** from the cellar branch so a merge of both is clean; the stand-spot helper is copied too
   (`demo/infirmary/stand_spot.gd`, to be merged with `demo/stores/stand_spot.gd`).

## PROPOSALS for Brendan
- **P1 (0623) — cloth for the building comes from the care shelf.** The demo has no other cloth (0622 P8). Building the
  infirmary takes 12 of the shelf's 24 U, leaving 12 U — 24 treatments. *Options:* (a) as built (**recommended**: it is
  the GDD's cost, and the trade-off is honest); (b) a demo cloth allowance for the building only; (c) a flax→cloth chain
  (a later feature).
- **P2 (0623) — before it is built, or when its 8 beds are full,** a hurt resident rests in its own bed, else lying at
  the field-care spot by the hall's steps (REQ-SET-173: "a field landing point or a bed"), and is treated there at
  REQ-SET-017's ordinary +2 an hour. *Options:* (a) as built (**recommended**: a hurt resident needs somewhere before the
  building exists); (b) the hall's floor; (c) where it stands.
- **P3 (0623) — the 8 beds come with the building.** §5.9 says the residence's furniture is "purchased separately" but
  gives the infirmary "8 patient beds" as its capacity; the compiled `patient_bed` furniture row exists but no demo
  furniture flow for it. *Recommend* beds included until furniture is built.
- **P4 (0623) — where its button lives.** The HUD's Build is locked (its key opens the Dig tool); the cellar building's
  button is in the Pantry. The infirmary's is a section of the Tunnels panel, under the housing line. *Options:* (a) as
  built; (b) a Buildings panel shared with the cellar when both land (**recommended** for the merge).

## Brendan's rulings on 0622 (recorded there too)
P1 (health floor 16), P3 (the herbalist), P4 (up at 70), P6 (herb restocking), P7 (forage cuts) and P8 (cloth not
restocked) are approved as built. P2 and P5 changed as above.

## Consequences — shared files (additive)
- `work/work_ids.gd`: `SOURCE_CARE` = 8, `SOURCE_COUNT` 9, `SOURCE_WALK` 9. **The number may collide** with the cellar
  branch's `SOURCE_STORES` = 8: whoever merges second renumbers its own source to the next free number, keeps the
  sequence unbroken, moves `SOURCE_COUNT` and `SOURCE_WALK` up and appends its name to `SOURCE_NAMES`.
- `work/demo_work.gd`: `add_care`.
- `cast/cast_space.gd`, `tunnel/tunnel_control.gd`: the cellar branch's structure hunks, verbatim.
- `tunnel/tunnel_panel.gd`: `add_section` (replaces 0622's `add_room_section`).
- `burrow/night_routine.gd`: the kept-beds filter removed; `bed_task_at` kept.
- `demo_village.gd`: `_build_care` wires the building, its input hook and task text; `_build_work` adds its source.

## Verification
- `test_demo_infirmary_building.gd` (24 tests) and `test_demo_care_desk.gd`'s infirmary cases; the live harness places
  it from the Tunnels panel, watches the work board's residents fetch for it, and a patient rest inside, at 1280x720 and
  1920x1080.
- Mutation testing: 39 mutants over the building's rules, books, builders, placing, drawing, board adapter, node and the
  desk's infirmary paths; 35 killed. The 4 survivors are equivalent: `_take`'s cloth check (a lift already caps at what
  the shelf holds), `percent`'s cap of 99 (the sum cannot reach 100 before it is built), the put-down's refused
  delivery (in transit counts toward the cost, so nothing is in hand once delivery is complete), and the footprint
  sync's guard (re-setting the same circle changes nothing).
- An independent review found one CRITICAL (an unparented placing tool in a test path) and one HIGH (it could be placed
  over the care shelf or a field-care spot), both fixed and tested; its MEDIUMs fixed: the cloth ledger, a lost trip to
  an unreachable door looping, untested placing refusals, the footprint's scale stated, and the Dig tool taking the
  placing click. LOW follow-ups: a patient held back by "Healer 2" says "a healer is coming"; the tunnel extension's own
  copies of the buildings a nook may not reach under do not include placed structures (inherited from the cellar).

## Source
Brendan's ruling, 2026-10-01; GDD §5.1, §5.2, §5.5, §5.9 (line 635), REQ-SET-017, REQ-SET-124/125/126, REQ-SET-173;
`gameplay_balance.md` §4.1, §4.2; `scripts/core/building_definitions.gd`, `construction.gd`;
`assets/lookdev/lookdev_dimensions.gd`; decisions 0210, 0612 (the cellar building's pattern), 0621, 0622.
