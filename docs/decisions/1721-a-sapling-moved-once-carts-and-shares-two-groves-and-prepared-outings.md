# 1721 — A sapling moved once, carts and shares, two groves, and prepared gathering outings
Date: 2026-10-07 · Status: Accepted; Q-D7 ruled by Brendan on 2026-10-07; **PROPOSALS 1–12 approved by Brendan on
2026-10-07, each as option (a), provisional, as built** (see "Brendan's rulings")

**Numbering.** BACKLOG.md's RG-Y packet assigns 1411–1420, but a parallel digging branch uses 0991–1217 and its range
grows (docs/handoff/README.md §3.6), so the coordinator gave this lane **1721–1729**. 1721 is free on every local and
remote branch (`git for-each-ref` over `refs/heads` and `refs/remotes`, 574 refs, `git ls-tree` of each one's
`docs/decisions/`: no 1720–1729), and `docs/validation/decision_numbers.py` passes.

## Approval and Brendan's ruling (2026-10-07)

Review group Y (decision 0493, 2026-09-30: ECO-008–012, ECO-014, ECO-015 approved); the packet RG-Y, selected by Brendan
on 2026-10-07. Open question **Q-D7** (moving a sapling, 0673's "needs its own ruling"; carts, 0674's "not built"):

> **"Both, agent proposes numbers"** -- a sapling can be moved once, with a delay of some days; carts are a haul tool
> for harvest groups.

(Relayed by the coordinator; recorded in `docs/handoff/RULINGS.md`; Q-D7 is marked CLOSED in `OPEN_QUESTIONS.md`.)
Everything else here is the packet's remaining scope (ECO-009's move, ECO-010's carts and shares, ECO-014's prepared
outing, ECO-015's reserve and more groves), built as the smallest sensible behaviour where the documents are silent.

## Decision

### 1. A sapling moved once (ECO-009, Q-D7)

- **Which trees**: a PLANTED tree still a sapling -- under `HALF_YEAR_DAYS` (24 days), the stage it is drawn as a sapling
  -- never an inherited one, and never one moved before (`orchard_model.gd moved`).
- **Where to**: the first free site -- empty, not promised to a nursery plan, not another move's destination. It is
  spoken for from the order (`move_dest`; `plant_refusal` and `add_plan` refuse it, `SITE_MOVE_DEST`).
- **The work** (`orchard_jobs.gd K_MOVE`): walk to the sapling, lift it (`MOVE_LIFT_MWU`, 20 WU), carry it in arms
  (`lifted`: the view hides it on its block and its mover holds the sapling basket), replant it (`MOVE_REPLANT_MWU`,
  BAL-CAT-010's 40 WU) -- the compost (`MOVE_COMPOST_MILLI`, §5.6's planting 4 U) taken when the replanting is done
  (0671 P6). **The tree's row moves only then** (`move_tree`: the store's own `remove_orchard`, `plant_orchard` and
  `restore_orchard_state`, carrying its age, health, chill days, tended and harvested flags): a move let go, cancelled,
  refused or given up leaves the sapling where it was (`_restart_move`, `cancel_move` on the job's end). Nothing is
  duplicated or lost, and a sapling is never out of the ground over a night.
- **The delay**: it **settles** `MOVE_SETTLE_DAYS` (12 days) -- each midnight's §5.6 day leaves its age where it was
  (`_settle`); its health, tending and chill go on as §5.6 says. So its early fruit (decision 0672) and its maturity both
  come 12 days later, and `next_harvest_day` counts the settling (`_eligible_on`).

### 2. Carts and the fresh-table share (ECO-010, Q-D7)

- **A handcart a group** (`K_CART`): built at its baskets for wood `CART_WOOD_MILLI` (4 U) and `CART_BUILD_MWU` (60
  WU), the wood taken when it is done. Its group's hauls then carry `CART_LOAD_MILLI` (40 U) a trip; with no store room
  for that, a basket's 10 U. Handling stays one payload's BAL-CAT-010 2 + 2 WU. Demo-side only: nothing of the
  settlement's hauling (HAUL-H3+, `scripts/core`) is used.
- **The share** (ECO-010's "fresh table / preserve / seedling shares as desired priorities, not guaranteed allocations"):
  0674's destination choice becomes the group's **fresh-table share**, `FRESH_STEPS` 0/25/50/75/100%. Each haul goes
  where the share is furthest behind (`orchard_rules.gd to_kitchen`, on this year's tallies), and to the other place
  when that has no room. 100% is 0674's "kitchen pantry", 0% its "best keeping store" (both groups' default, as
  before). The seedling share stays 0674's unit keep (0/4/8 U), approved as built.
- **Drawn**: the world's staged `handcart` (its placeholder unstaged) by its baskets at `CART_PARK_AT` -- clear of every
  obstacle by `CART_CLEAR_M`, checked against the real layout -- and just ahead of its hauler on a haul, above ground.

### 3. Two groves and their forage reserve (ECO-015)

- **The beech hollow**: a second protected grove, a 6 m circle round the foraging trips' mushroom spot and two mature
  beeches (`GROVE_NAMES`, `GROVE_CENTRES`, `GROVE_RADII_M`, `GROVE_STONES`), protected from the start. Each grove has
  its stone, ring, toggle (the grove section shows the selected grove), seasonal observation and record; the woods'
  felling rule (`forest_crew.gd set_protected`, unchanged) asks `demo_orchard.gd grove_protects`, which now asks both.
- **The reserve** (ECO-015's "protected areas maintain identifiable seasonal forage reserves"): while a grove is
  protected, a foraging trip to a spot inside it may take only the woods' stock above §5.5's floor and
  `GROVE_RESERVE_PERMILLE` (10%) of the kind's capacity, less what seats already hold claimed
  (`forage_trips.gd harvestable_milli`). The basin's own rules (forage.gd) are untouched. Wired by one line in
  `demo_village.gd _build_forage`.

### 4. Prepared gathering outings (ECO-014)

- **Home before dark**: dusk is the night's 20:00 (`night_routine.gd DUSK_HOUR`, read in a test; `forage_rules.gd` keeps
  the copy), walks counted at the slowest resident's 18 m a game hour (`WALK_M_PER_HOUR`). A trip is refused at night
  and when a party could not walk out, gather the least worth a trip and walk home by dusk (`daylight_refusal`); a
  forager at its spot claims only what it can gather and still be home by dusk (`daylight_cap_milli`), and **turns
  back** with nothing claimed or held when that is under 0.1 U. The card says when they would be home.
- **The carry kit**: the village's one, lent to one trip at a time; its carrier (the first seat) brings two baskets
  (`KIT_BASKET_MILLI`, 8 U).
- **A named lead** (optional): the first selected resident leads (the first seat); the news and the place's note name
  them. Routine trips stay anonymous seats (ECO-014).
- **A remembered place**: each spot keeps one note, the latest trip home -- when, what it brought, how long it was out,
  who led -- shown under the trip preview. Information, never a bonus (ECO-014: "not an infinitely stacking skill
  bonus").
- **Consent**: REQ-SET-067 asks a resident's dangerous-work permission in danger 2 or 3. The demo's woods are danger 1,
  so none is asked; the card says so (`needs_permission`).

### Not built, and why

- **A rest stop on an outing, and rest at a grove as a need** (ECO-014, ECO-015): the demo has no rest need; resting
  would only cost time. Waits on review group AE's leisure model, as decision 0675 already said.
- **A cart slowing its hauler**: the walking pace is the cast's (`demo/cast/`, the digging lane's files); a cart walks at
  a resident's pace (PROPOSAL 4).

## PROPOSALS for Brendan (each built so a different ruling is a small change)

1. **The settling delay: 12 days** (one season; the same as §5.6's nursery wait). *Options:* (a) 12 days; (b) 6 days;
   (c) 24 days (half a year). *Recommendation: (a).*
2. **What "a sapling" is: a planted tree in its first 24 days** (drawn as a sapling), never an inherited tree.
   *Options:* (a) as built; (b) any planted tree not yet bearing (under a year, 48 days). *Recommendation: (a).*
3. **The move's work and cost: lift 20 WU, replant 40 WU, compost 4 U** (half a planting, then BAL-CAT-010's planting
   with §5.6's compost). *Options:* (a) as built; (b) no compost (the sapling keeps its soil). *Recommendation: (a).*
4. **A cart carries 40 U** (four baskets; 10 kg at §5.7's 250 g a unit, within a medium resident's 16 kg, BAL-WORK-003),
   handled as one payload (2 + 2 WU), at a resident's walking pace. *Options:* (a) 40 U; (b) 24 U; (c) a resident's
   own §5.2 carry by mass (64 U for a medium carrier). *Recommendation: (a).*
5. **A cart costs wood 4 U and 60 WU**, one a group, built at its baskets, no upkeep (20 kg of wood; 1.5 times §5.9's
   40 WU workbench trap; no rope while Q-D3 is open). *Options:* (a) as built; (b) add rope 1 U once Q-D3 settles.
   *Recommendation: (a), with (b) after Q-D3.*
6. **The fresh-table share replaces the destination choice**: 0/25/50/75/100%, each haul to whichever place is behind,
   overflowing to the other when it is full; this year's tallies shown. *Options:* (a) as built; (b) keep 0674's
   two-way choice as well. *Recommendation: (a).*
7. **The second grove: the beech hollow** round the mushroom spot, protected from the start. *Options:* (a) as built;
   (b) unprotected until the player marks it. *Recommendation: (a).*
8. **A protected grove's forage reserve: 10% of the kind's capacity above §5.5's floor.** *Options:* (a) 10%; (b) 20%;
   (c) none (protection only stops felling). *Recommendation: (a).*
9. **Home before dark**: 20:00 dusk, the slowest pace, turning back under 0.1 U, no trips at night. *Options:* (a) as
   built; (b) a later turn-back with the night routine sending them home. *Recommendation: (a).*
10. **The carry kit: one in the village, 8 U for its carrier, no cost.** *Options:* (a) as built; (b) kits made at a
    cost (cloth), several. *Recommendation: (a).*
11. **A named lead has no effect beyond the news and the note.** *Options:* (a) as built; (b) the lead's FORAGE level
    sets the party's work rate. *Recommendation: (a).*
12. **The place note keeps only the latest trip.** *Options:* (a) as built; (b) one note a season. *Recommendation: (a).*

## Brendan's rulings (2026-10-07)

Relayed by the coordinator: **all twelve proposals approved, each as option (a), provisional, as built** -- the 12-day
settling, a sapling as a planted tree's first 24 days, lift 20 WU + replant 40 WU + compost 4 U, a 40 U cart at walking
pace, a cart for wood 4 U and 60 WU (rope after Q-D3), the fresh-table share, the beech hollow protected from the start,
the 10% grove reserve, home before dark at 20:00, one carry kit of 8 U, a lead named in the news and the note only, and
the place note keeping the latest trip. The numbers stay PROVISIONAL (tunable after a balance run).

## Shared files touched (additive hooks)

| File | Hook |
|---|---|
| `godot/demo/demo_village.gd` | one line in `_build_forage`: `_forage.trips.reserve_permille = _orchard.grove_reserve_permille` |

Everything else is in `demo/orchard/` and `demo/forage/` (this packet's files). No work-board source and no pantry item is
added (the move and the cart are orchard job kinds on the existing board), so nothing in `work_ids.gd` or
`farm_catalog.gd` is renumbered. **No key is added.** Nothing under `scripts/core/`, `demo/burrow/`, `demo/tunnel/`,
`demo/cast/` or the settlement UI is edited (they are read and called only), nor `preserve/*` or `kitchen/meal_rules.gd`.

## The independent review and what it changed

Two `code-reviewer` runs on the diff (one long-running, one rerun when its result was late; both waited for). **No
CRITICAL.** One **HIGH**, fixed: a move opened through the generic order had no site reserved, and its replanting took
the compost before `move_tree` refused -- 4 U lost. Now only Move sapling (`order_move`) opens a move
(`_reserved_move_refusal`), and `replant_refusal` -- every check `move_tree` makes, the store's planting preview among
them -- runs before the compost is taken; tested. **MEDIUMs**, all fixed: a move could take a site a planting job was
working (`move_target` skips it); tests added for the daylight cap through a real claim, the rain and the skill in it,
the grove reserve at the claim, the chill carried by a move, the board-full rollback of `order_move`, one site for one
move, each grove's own trees, and the village's wiring of the reserve (the live harness); three functions split under
30 lines (`_complete`, `_result_of`, `_claim_share`; the two UI tests back to master's lengths). **LOWs** fixed:
`follow_carts` statically typed and writing the cart only when it moves; `is_move_dest` and the share's steps use the
packed arrays' own `has`/`find`; a cart's load sized by the lot it takes; a sapling lifted for its move is never tended;
a sapling lifted on its 23rd day is still replanted (its age is checked when ordered and lifted); `move_tree` checks the
store's planting and puts the tree back should it ever refuse; `_settle` only after a day the store applied; the Move
button only for a selected site; the turned-back count shown in the trip's line; the job's name "Move" (no doubled
article in the news). **LOWs answered, not changed:** the walk home is estimated from the village square and the note's
time out from the authorisation (planning figures, ECO-014's "likely travel"); the hives suite's "no room left held"
check now subtracts room held by jobs still live (the extra grove's observation takes a resident, so a berry picking can
be mid-way when the check runs -- room held by a finished job is still caught).

**What the review led to besides: east site 2's work spot.** A move given up with "the way there stayed blocked" (seen
once in the live harness) traced to the world: a mossy boulder from the woods' scatter stands inside east site 2's block,
and the orchard's work spot for that tree (`tree_spot`, 1.5 m toward the stand, decision 0671) lay 0.48 m inside it --
for a planting, a tending or a harvest there as much as a move. A tree's work spot is now `trunk_spot`: the first choice
when a resident may stand there (unchanged for the other three sites), else the first spot round the trunk an eighth of a
turn either way. Tested against the real woods' obstacles, with a move replanting there. The boulder itself (inside a
planting block) is the world layout's, not this lane's: noted for the coordinator.

## Gates (2026-10-07)

- **CI-style full suite** (a clean checkout of `703c1b47`, no `godot/demo/assets`, `.godot` deleted and re-imported,
  `./tools/run_tests.sh`): `9349 test(s), 650184 assertion(s), 0 failure(s)` ·
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 373 tolerated; leaked at exit: 0 object(s), 0 resource(s)` ·
  `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).` An earlier run (at
  `1623ae17`, while the mutation pass loaded the machine) failed only `test_twenty_workers_at_four_x_cost_little_per_frame`
  (the sound cues' wall-clock budget: p99 501 us against 500, not this lane's code); rerun once on the final commit, it
  passed.
- **Analyzer**: `python3 tools/gdscript_warnings.py --max 0 --port 6127` (the clean checkout of `703c1b47`) →
  `0 GDScript warning(s) in 0 of 1057 file(s)`. **Found on the way:** runs on the default `--port 6018` reported
  hundreds of spurious warnings (existing files "missing", members of other branches absent) while other lanes ran the
  analyzer at the same time -- the language server's default port is shared across worktrees on this machine. Give
  each concurrent lane its own `--port`.
- **Contracts**: decision_numbers, ready07_arithmetic, merge_gate, setting_contract, dispatch_plan, astra_inbox,
  validate_save_registry_handoff, generate_canonical_state_table, validate_cycle01/02/03_handoff, audit_registry_capacities
  and its test, generate_component_columns_schema and its test, lane_notes, test_movement_envelopes,
  test_movement_profile_policy, state_registry_coverage, ui_refinement_contract -- all PASS.
- **Live harness** `test/live/demo_orchard_remainders_live.gd` (staged art): `LIVE-SUMMARY 26 0` at 1280x720 and at
  1920x1080 (and in the CI-style suite through `test_demo_orchard_remainders_live.gd`, unstaged). Frames looked at, at both
  sizes (session scratchpad `rgy_check/`): `orchard_move_panel`, `orchard_cart`, `orchard_old_cart`, `orchard_moved`,
  `beech_hollow`, `forage_outing` -- they moved the east cart off a stump (the parks are now tested clear of the real
  layout). At 720p the Move and the Kit/Lead buttons sit below the panels' scroll, as their panels already do.
- **The orchard's existing harness** (`demo_orchard_live.gd`, unchanged from master): unstaged, as CI runs it, 6 of 6
  passes at 1920x1080 on this branch (the tending done in about 1340 frames; master's code 1362). With the demo's art
  staged the tending ends nearer 1410 frames and the 07:00 breakfast call sometimes takes the tender first: the job then
  waits on the board past the check's 2400-frame bound (about 1 run in 5 here). That race is the harness's own (its
  timed tending and the meal call), seen only staged; its budget is not changed. Putting this lane's steps in that file
  made it worse (a longer script shifted the race), so they have their own harness, run past breakfast.
- **Mutation testing** (one mutant a run, `test_demo_orchard_remainders.gd` and `test_demo_forage_outings.gd`): **61
  mutants, 61 killed** after the review's fixes. The first pass left six: five got tests (an empty site is never its own
  move's destination; one group's cart stays parked while another's hauls; a cart's hold sized by its lot; a lifted
  sapling not tended; the too-late boundary counting the least worth gathering), the sixth was equivalent and its
  redundant comparison was removed (`daylight_ticks`), and all six were rerun killed. SURVIVED_MUTANTS: none.
- **Independent review**: see "The independent review and what it changed": no CRITICAL; the one HIGH and every MEDIUM
  fixed; the LOWs fixed or answered there.

## Source

GDD §5.5 (REQ-SET-066..069), §5.6 (orchard rows, planting, the nursery's wait), §5.7 (masses), §5.9 (gear crafting);
gameplay_balance.md BAL-CAT-010, BAL-WORK-003; review ECO-009, ECO-010, ECO-014, ECO-015 (decision 0493 group Y);
decisions 0222, 0671–0677, 0681, 1601; meal_rules.gd's meal hours and night_routine.gd's dusk; Brendan's ruling on Q-D7
(2026-10-07).
