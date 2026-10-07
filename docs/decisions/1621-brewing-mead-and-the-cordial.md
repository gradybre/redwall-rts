# 1621 — Brewing in the demo: mead in the brewery's vats, the cordial at its bench, drinks poured at the feast
Date: 2026-10-07 · Status: Accepted (engineering); **PROPOSALS P1–P7 approved as built by Brendan on 2026-10-07**

**Numbering.** BACKLOG.md's BREW packet assigns 1251–1260; that range collides with a parallel digging branch (0991–1217
and growing), so the lead remapped the food packets to 1601–1629 and BREW takes **1621–1629** (1621 here). Checked free
on every local and remote ref; `docs/validation/decision_numbers.py` passes.

## Approval

Feature #19, brewing (Brendan, 2026-10-01; tracker only, first recorded in `docs/handoff/RULINGS.md`), and group W's
ECO-031, a modest drink culture (decision 0493). Art pass 3's brewing props (decision 0971). The cordial is Brendan's
own DEC-045 row ("Approve all", decision 0603). Scope beyond the GDD is a PROPOSAL.

## Decision

The demo brews **§5.7's `mead`** in **four vats at a brewery** east of the kitchen and makes **the DEC-045 raspberry
cordial** at the brewery's bench, both as further rows of the stations' recipe table (`preserve_rules.gd`, decision
1611): the vats are four more passive slots after the rack's in the fishery's one slot table (`SLOT_COUNT` 8), each
slot's station decided by its index. **Mead** (item 34, `CAT_MEAD` 16) and **cordial** (item 35, `CAT_CORDIAL` 17) are
appended to the pantry as drinks -- never eaten raw, never a meal. **The regatta's feast pours them**, beside the Hearth
row's warm infusion, without making them part of what earns Shared Warmth. Nothing models what drink does.

### The rules used, as written

- **GDD §5.7** `mead`: honey 3, water 3 → mead 4, 20 WU + 72 h passive, Brewery/COOK, 1440 h; the item table's "Mead |
  0 | No | 1440 | Feast ingredient only; no intoxication subsystem".
- **§5.9 Brewery**: "Cook 1 | 4 passive batch slots" -- the vats.
- **DEC-045 / decision 0603** `cordial`: berries 2 + honey 0.5 + water 2 → 4 portions, 10 WU, 72 h -- the recipe book's
  row (`dish_book.gd`), whose numbers the brewery row carries exactly (`test_demo_brew.gd` compares them).
- **§5.7's feast rows** for the drinks' quantity: the Harvest and Orchard feasts pour mead ceil(E/4) U; the warm
  infusion's "consumed proportionally to attended/E with milli-unit rounding at the last attendee" for the pouring.
- **ECO-031**: water service, a herb infusion, one seasonal fruit drink (the cordial); mead optional; "no dehydration
  system or alcohol dependence"; new drink recipes approved explicitly (none is added here).
- **REQ-SET-093/094/112/118** as decisions 0434 and 1611 apply them to every station row.

### Shared files touched

| File | Hook |
|---|---|
| `godot/demo/farm/farm_catalog.gd` | items 34–35 and categories 16–17 **appended**; `PANTRY_ITEM_COUNT` 36 |
| `godot/demo/kitchen/meal_rules.gd` | two `CATEGORY_WORDS` (no raw-food rows: drinks are not eaten) |
| `godot/demo/fishery/fishery.gd`, `demo_fishery.gd`, `fishery_view.gd` | the vats (`free_slot`, `VATS_FULL`), the brewery's spot, `brewing()`; the cards and Brewing line; the vat, the cask and the vat's steam |
| `godot/demo/waterplay/water_panel.gd` | a **Brewing** heading, line and row (Brew mead, Make cordial) |
| `godot/demo/regatta/regatta_menu.gd` | THE FEAST'S DRINKS: reserved at confirmation, poured at the supper's end, a preview line |
| `godot/demo/props/demo_props.gd` | `brew_vat` 0.95 m and `ale_cask` 0.8 m (DEC-048) |
| `godot/demo/guide/field_guide.gd` | the drinks' entries (through `preserve_text.gd`) |
| `tools/make_demo_pantry_index.py`, `godot/demo/farm/pantry_index.json` | the two keys (no library leaf) |

No work-board source and no key is added; nothing is renumbered. Nothing under `scripts/core/`, `demo/burrow/`,
`demo/tunnel/`, `demo/cast/` or the settlement UI is edited.

## PROPOSALS (for Brendan)

1. **The brewery stands from the start** east of the kitchen (Q-D4 (a)), so the GDD's Brewery cost (wood 24 + stone 12
   + iron 2, 480 WU, M2) is not charged and Q-D3's iron does not bite. *Options:* (a) as built; (b) the player builds
   it once Q-D3 settles iron. *Recommendation: (a), with (b) after Q-D3.*
2. **Drinks at the feast** ("the infusion and cordial served where the ruling says" -- there is no ruling yet): the
   regatta's supper pours mead and the cordial, ceil(E/4) U each, when the brewery has made enough, beside the Hearth
   row's infusion, and neither is required for Shared Warmth. *Options:* (a) as built; (b) only the GDD's infusion at the
   Hearth feast, mead kept for the Harvest and Orchard feasts (FEAST); (c) the cordial also at ordinary suppers.
   *Recommendation: (a) until FEAST builds the other feasts, then mead moves to them.*
3. **The cordial is made at the brewery's bench and kept in the pantry** as a drink (4 U from a batch), rather than
   cooked by the kitchen as a portion; the recipe book still lists it as a drink. *Recommendation: confirm.*
4. **Drinks are not eaten raw**: mead is §5.7's "No"; the cordial's 500 NP a portion is not given to a hungry resident
   either -- it is poured at feasts only. *Options:* (a) as built; (b) the cordial counts as raw food at 500 NP.
   *Recommendation: (a).*
5. **A drink is reserved when the feast is held** (as the infusion's herb is) and poured on the day; the cordial keeps
   only 72 h, so a cordial held days ahead may have spoiled in part, and only what is left is poured.
   *Options:* (a) as built; (b) reserve the drinks on the feast's day. *Recommendation: (b) if the cordial matters.*
6. **Ordered by the player** from the Water panel's Brewing, as the rack and the mill are; no routine brews on its own.
   *Recommendation: confirm.*
7. **Not built**: ale and cider (icons exist; no GDD row): they wait on Q-D5 (b) and (c) -- how drink is depicted
   (DEC-007) and their recipes. *Recommendation: ask them together with the preserves' recipes.*

## Brendan's rulings (2026-10-07)

Relayed by the coordinator: **BREW P1–P7 approved as built.**
- **The Hearth regatta feast pours mead and the cordial** (P2 (a), as built): confirmed explicitly.
- **Q-D5 (b) and (c)**, on the drinks not built here (P7): "Approve and build Q-d5 and dec-007" -- new recipes for
  the waiting icons (jam, pickles, a plant-milk cheese, ale, cider) and the drink-depiction point of DEC-007 are to be
  built; that work is decision 1625 on `feat/demo-new-recipes`.

## Gates (the branch's three packets together, 2026-10-07)

- **CI-style full suite** (a clean checkout of `329c8519` with no `godot/demo/assets`, `.godot` deleted and re-imported,
  `./tools/run_tests.sh`):
  `9194 test(s), 613347 assertion(s), 0 failure(s)` ·
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 355 tolerated; leaked at exit: 0 object(s), 0 resource(s)` ·
  `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
  The last commit (`21f928c2`) only adds tests and drops a redundant check; its suites were rerun focused (0 failures).
- **Staged full suite** (the branch's head `21f928c2`, every demo asset staged): `9194 test(s), 613425 assertion(s),
  0 failure(s)` · `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 292 tolerated; leaked at
  exit: 0 object(s), 0 resource(s)` · `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s),
  0 resource(s).`
- **Analyzer**: `python3 tools/gdscript_warnings.py --max 0` → `0 GDScript warning(s) in 0 of 1038 file(s)`.
- **Contracts**: decision_numbers, merge_gate, ready07_arithmetic, ready07_addendum_checks, state_registry_coverage,
  ui_refinement_contract, validate_save_registry_handoff, setting_contract, astra_inbox, dispatch_plan,
  generate_canonical_state_table, lane_notes -- all PASS; `tools/test_stage_art_passes.py` 17/17,
  `tools/test_make_demo_pantry_index.py` OK.
- **Live harness** `test/live/demo_food_live.gd` (staged art): `LIVE-SUMMARY 27 0` at 1280x720 and at 1920x1080.
  Frames looked at, at both sizes: `apiary`, `apiary_panel`, `bees`, `preserving_table`, `preserves_panel`, `brewery`,
  `brewing_panel` (session scratchpad `food_check/`). They moved the skep off a stump and the brewery's cask out of a
  rock cluster; tests now keep every station's props clear of the world's obstacles.
- **Mutation testing** (one mutant a run, the focused suites): HIVES 25 + 15 review mutants, PRESERVE 23, BREW 16.
  Every survivor got a test and was rerun killed, except two shown EQUIVALENT and removed from the code (the
  ration batch's own program, identical to the mill's; a check `consume_into` already makes). SURVIVED_MUTANTS: none.
- **Independent review** (`code-reviewer`, one per packet, waited for): no CRITICAL. HIGH: HIVES -- honey could be
  half-withdrawn for a refused recolonisation (fixed: all-or-none take); the village wiring untested (fixed: unit and
  live checks). PRESERVE -- a batch could start short of an input (fixed: the take trimmed, every withdrawal checked,
  given up whole). Every MEDIUM fixed in `329c8519`/`21f928c2` or answered here: the drinks' Hearth pouring is
  proposal P2 of decision 1621, kept on as built until Brendan rules; a batch's fetch to its first input's store only
  is proposal P6 of decision 1611.

## Source

GDD §5.7 (mead, the item table, the feast rows), §5.9 (Brewery); DEC-007, DEC-045; review ECO-031 (decision 0493);
decisions 0434, 0603, 0682, 0971, 1601, 1611; `docs/handoff/BACKLOG.md` BREW; open questions Q-D3, Q-D4, Q-D5.
