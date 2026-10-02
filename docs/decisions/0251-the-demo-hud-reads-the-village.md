# 0251 — The demo HUD reads the village: one read model, the cast's roster, a drawn map, farm figures in player terms
Date: 2026-09-30 · Status: Accepted · Fuel's slot holding Planks superseded by 0571 (the hearths burn wood: the slot is
UI-SET-003's Heating fuel again, the planks on the ledger's Wood line and in Wood's tooltip)

Review group E, "numbers and roster that tell the truth": findings F10, F14 and F34 of the live-demo review
(`/Users/brendan/Developer/redwall-review/REVIEW.md`, written against 157a3a4; P1's HUD and bed rows and its
before/after copy table). All three were confirmed on this branch (43d9654) before the change, at 1920x1080: the
top bar read Wood 180 U / Stone 100 U against the stores' 40.0 U / 20.0 U, Residents "--" and "Sim beds:
Unavailable"; the ledger printed the settlement's Food-days, Ready NP and Fuel-days; Residents listed "Warden
Rowan" and eleven "Unnamed resident" rows, a click selected nobody in the Demo party panel; the minimap said "No
world generated"; the bed panel said "Moisture 6000 — good (2500–7000)" and "Sand · fertility 70% (yield ×0.85) ·
health 100%".

**Numbering.** The highest record on this branch is 0211. Parallel review groups work in other worktrees, so this
takes 0211 **plus 40** (0251) to avoid a collision, as the group-E brief asked; the gap is deliberate.

New files: `godot/demo/ui/demo_hud_model.gd`, `demo_hud_counters.gd`, `demo_roster.gd`, `demo_minimap.gd`;
`godot/demo/farm/farm_moisture_meter.gd`; `godot/test/test_demo_hud_truth.gd`. Removed: `godot/demo/ui/
demo_beds_label.gd` (0211 §10's "Sim beds" relabel) and its test.

## Decision

### 1. One read model for the top bar (F10)

`demo_hud_model.gd` gives each of the six counter cells exactly one owner -- the object its panel already reads --
and `demo_hud_counters.gd` paints them and the ledger every frame the shell or UIManager has drawn over them:

| Cell (shell slot) | Owner | Words (the panel's own formatter) |
|---|---|---|
| Ready food (ID_FOOD) | the pantry's `total_milli()` | `farm_hud.gd food_text`, "12.0 U" (the Pantry headline's figure; see *Integration with decision 0222*) |
| **Planks** (ID_FUEL's slot) | stores `plank_milli_u` | `tunnel_stores.gd units_text`, "63.5 U" |
| Wood / Stone | stores `wood_milli_u` / `stone_milli_u` | the same |
| Residents | the cast's `actor_count()` | a count |
| Beds | the fit-out's installed beds in dug homes | a count |

- **Nothing is written into the settlement simulation.** UIManager, EconomySystem and the simulation run as
  before; the demo paints over their cells, as its date adapter already does (0196).
- **Fuel's slot holds Planks.** The village keeps no fuel, so "Fuel: Unavailable" was a genuinely unsupported
  summary, and planks -- a spent stock with no place in the top bar -- take its slot. Rejected: a seventh cell (the
  shell's grid is six, UI-C3-R01 §1) and leaving planks off the bar.
- **The two cells the game does not wire** (Fuel, Beds: no store exists in the game, and `set_counter_display`
  refuses a value by contract) are painted by the demo itself -- caption, a line glyph instead of the lock, the
  value in the shell's value role, measured by the shell's own rule (`cell_width-8`, else "See ledger"), the cell
  enabled so it opens the ledger. `ui_availability.gd`'s table is untouched: the game's claim stays true for the
  game. This **replaces decision 0211 §10's relabel-not-feed choice**: 0211 refused to feed Beds because the
  demo had no read model of its own and writing into the settlement's counter would have fabricated a reading;
  here the figure is the village's own, stated as such in the cell's tooltip and ledger line.
- **Unavailable is not zero.** An absent owner is "Unavailable" (the shell's 16 px disclosure role) in the cell,
  its tooltip and the ledger.
- **The ledger agrees.** The counters' drill-down (UI-SET-009) lists the same six figures, each saying where it is
  ("Wood: 73.5 U in the village stores", "Beds: 3 in 1 burrow home"). The settlement's Food-days / Ready NP /
  Fuel-days are no longer shown to the player; they remain UIManager's and the suites' (no separate developer view
  was built -- the brief made it optional).
- **Player-facing implementation talk removed**: the Tunnels panel's "— the HUD's Wood and Stone are the
  settlement's" and "— demo beds, not the HUD's Beds", the Woods panel's "(shared with the tunnels; the HUD's Wood
  is the settlement's)"; the stores line reads "Village stores: ..." and the housing line "(3 beds)".
- The Food cell's painter moved out of `farm_hud.gd` (its `sync` is gone; `food_text` stays, the one format the
  cell and the Pantry share).

### 2. The Residents command lists the cast (F14)

`demo_roster.gd` fills the shell's own roster rows (UI-SET-069) from the cast, in cast order (row k is cast index
k, `actor_of`), two lines a row: "Mole digger — Mole, digger · Underground, level 1" / "Digging tunnel — 43% ·
Then back to: Burrow home 1". The activity words are the party panel's (`demo_command.gd activity_text`, factored
out of `party_entries`, so the two never disagree); the level is read from the floor's depth against the tunnel
rules' level floors (halfway to level 2 is the boundary; a ramp is level 1). The workspace title reads "Residents".

A row clicked selects that resident alone (the Demo party panel shows it), centres the camera on it
(`demo_camera.gd centre_on`, new) and closes the roster so the resident is in view. **UIManager's handler is
disconnected from this shell's `resident_row_picked`**: the rows are no longer settlement rows, and resolving one
would open a settlement resident the player never saw. UIManager still refills its rows on the Residents action;
the demo's handler, connected later, writes the cast over them in the same call. The population counter is the
cast count (§1). The command's tooltip now says what the roster does in the demo.

### 3. The minimap draws the village (F14)

`demo_minimap.gd` is added inside the shell's minimap view: north up, a square of ground round the camera's
bounds (+2 m): meadow, the water map's own stream and pond capsules, the authored paths, crop beds and building
footprints (turned as they stand), water-side buildings, the trees standing now, dug tunnels and their mouths,
burrow homes, root cellars and bridges; over them the camera's view on the ground (its four corner rays) and every
resident as a dot in its party colour (hollow underground, brass-ringed when selected). A left click or drag
centres the camera there, and the map takes the event, so the shell's settlement tile picker never sees it.
**Cheap**: the base is a child canvas item redrawn only when the tunnel network's, the bridges' or the woods'
revision changes (Godot keeps its draw list); the marks redraw each frame into a reused PackedVector2Array and
cached vectors. A full map was feasible, so no placeholder was needed.

### 4. Farm figures in player terms (F34)

Following the review's copy table: "Soil moisture: Good · 66%" over a banded meter (`farm_moisture_meter.gd`:
dry, low, the crop's suitable range, wet, waterlogged, with 14 px labelled limits) and "Suitable for this crop:
25–70%"; "Soil: Sand", "Fertility: 70%", "Fertility effect on yield: −15%", "Crop health: 100%"; one "Expected
harvest: 5.1 U of carrot"; a **Details** toggle showing "Base 6.0 U × fertility 0.85 × health 1.00 × rotation 1.00
= 5.1 U" (and, past a ripe crop's grace, the daily loss to the harvest now) and the raw 0..10000 readings. Enabled
verbs' tooltips state their effect in percentage points ("Compost: +15 fertility points", "Rest ... +0.5 fertility
points a day"); rotation is a change ("same family again: harvest −15%"); the crop picker gives "matures in 6
days · this bed: about 5.9 U (base 7.0 U)".

**Rounding.** Readings are whole percent, floored -- except a moisture reading above the crop's range, which is
rounded up, so a wet bed never prints as its range's top ("Wet · 70%" beside "25–70%"). Every band edge in §5.6
and the empty-bed band is a multiple of 100, so neither side can print on the wrong side of an edge. The picker's
estimate drops REQ-SET-074's 125% cap: at neutral pollination the factors top out at 110% of base, so the cap can
never bind there (the cap stays in `farming.gd`'s formula, which the panel's expected harvest comes from).

The unit arithmetic of the pantry formatter is untouched (group B owns F28).

## Why

The review's finding was the information conflict, not a state write: two economies on one screen made a
player diagnose a shortage from the wrong inventory. A read model in presentation keeps the demo→production
boundary (nothing enters the simulation) while making every surface the player looks at name the same owner.
Rejected: labelling the split more clearly (the review names that as the defect), and feeding demo figures into
EconomySystem (forbidden: the demo never writes the simulation).

## Verification

- Tests: `test_demo_hud_truth.gd` (new, no staged assets): every cell equals its owner after bracing, a hauled log,
  sawing, a bridge's planks, a fixture paid and refunded -- and appears verbatim in the Tunnels and Woods lines;
  the Food cell follows the pantry; Unavailable is never 0; UIManager's and a relayout's repaint are painted back;
  the ledger's exact text; See ledger for a value too wide; roster rows map to cast ids, a click selects that
  actor (the party panel's entry), centres the camera and closes; the earlier row listener is disconnected;
  location and level boundaries; map transforms (square and non-square), ray hits, pointer handling and the
  camera clamp; moisture/fertility/health/points/factor formatting boundaries; the harvest breakdown equals the
  expected harvest; the meter's bands. Updated: the farm UI, rooms, forestry and warnings suites.
- Suite: `./tools/run_tests.sh` -- "ok: 6401 tests, 548874 assertions, 0 failures." (base: 6377 tests.)
- Mutation testing of the new logic, one mutant at a time, restored and hash-checked each time: **101 mutants, 99
  killed, 2 equivalent.** First set (90): 82 killed at once; 6 survived -- 5 killed by tests added for them (a roster
  overwritten with as many rows, the sown estimate's rotation, Details toggled twice, the meter in its column, a
  negative actor index); 1 was equivalent (the grazing-ray threshold, which the FAR_M clamp already covered) and the
  code was simplified to remove it, its replacement killed; plus the picker estimate's rotation through the sim,
  killed. The review's fixes (11): 10 killed; 1 equivalent (building the Details text only while it is open: a
  cost guard on hidden text).
- Frames at 1280x720 and 1920x1080 (HUD, ledger, Residents by day and night, a row clicked, the minimap, a bed
  panel with and without Details): `scratchpad/rv_e_check/` (`a720_*`, `a1080_*`).
- Review: the independent `code-reviewer` agent. Fixed: **HIGH** a per-frame warning flood (a filled dot drawn
  with a width) and a per-frame node lookup (the ledger's label is found once at `bind`); MEDIUM the roster
  renaming another workspace page's title, a relayout's accessible description not painted back, the wiring
  untested (now `bind_village`, tested), the meter's range untested, the row-pick disconnect narrowed to
  UIManager's own handler; LOW See ledger in the disclosure role, the glyphs preloaded, `pick_row` with no command,
  a ray from below ground, Details built only while open, a stronger meter test. Not changed: the shell's
  accessors (`counter_value_label` and the rest) reset its `last_refusal` (their existing contract; the replaced
  adapters did the same). The reviewer saw the Residents command not open on its first press when headless; in a
  window (1280x720) it opens on the first press, page 69, 9 rows; the base commit behaves the same headless.

## Integration with decision 0222

Group B (decision 0222, F28) removed the pantry's `total_units()` -- it summed per-item units already truncated --
and made `farm_text.gd units_text(milli)` the farm's one units form. This record was written against the old
`total_units`, so when both landed on `integrate/review-batch-1`:

- The read model binds `food` to `pantry.total_milli` and the cell is `food_text(milli)`, which is
  `units_text`: "12.0 U", "<0.1 U" for a trace, "0 U" only for nothing. The HUD cell, its ledger line and the
  Pantry's headline still print the same figure, which is the point of both decisions.
- `farm_text.gd` had gained a `units_text` on each branch; B's (with the "<0.1 U" floor) is the one kept. The
  crop picker's base yield goes through it too ("base 7.0 U"), as 0222 lists the picker's base among its figures.
- `farm_hud.gd sync` stays removed (this record's painter replaced it); B's test of it was dropped, and B's
  `food_text` assertions (`test_demo_conservation.gd`) and this record's cell tests cover the same figure.

## Consequences

- Any new demo stock the top bar should show goes through `demo_hud_model.gd`: one owner, the panel's formatter.
- A future production HUD replaces this adapter; the shell and `ui_availability.gd` are unchanged by it.
- **Open**: refusal and notice words elsewhere still say "the demo stores" (`tunnel_actions.gd`,
  `room_fixtures.gd`, `forest_crew.gd`); renaming them to "village stores" touches files other groups are changing
  and is left for after the merge. The ledger's first glyph sits under the shell's own scroll bar (pre-existing
  shell layout). The shell's roster column keeps an empty band above the rows (the shell's search label).

## Source

REVIEW.md F10 (285–297), F14 (339–349), F34 (473–483), P1 (771–863) and its copy table (812–825); decision 0211
§10 (superseded here for the Beds cell); UI §1.2/§2.1 (zones, 14 px floor); UI-C3-R01 §2 (cell measurement).
