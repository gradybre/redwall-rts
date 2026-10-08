# 1701 — Called feasts: the GDD's Hearth, Harvest and Orchard feasts, called by the player, at the 17:00 supper

Date: 2026-10-07 · Status: Accepted (engineering); **PROPOSALS P1–P9 approved by Brendan on 2026-10-07, all as recommended**

Handoff packet FEAST (`docs/handoff/BACKLOG.md`, "## FEAST — Feasts (#9)"). Branch `feat/demo-feasts`.

**Numbering.** BACKLOG.md assigns FEAST 1261–1270; that range collides with the parallel digging branch (0991–1217 on
its `codex/underground-*` and some `claude/*` branches), so the lead allocated **1701–1709** to this packet, superseding
the BACKLOG range (README §3.6's note of 2026-10-07). 1701 was checked free on every local and remote ref
(`git ls-tree` over `git for-each-ref refs/heads refs/remotes`); `docs/validation/decision_numbers.py` passes.

## Approval and Brendan's ruling (2026-10-07)

Feature #9, feasts (Brendan, 2026-10-01, "NEW 2"; tracker only, first recorded in `RULINGS.md`), with group AE's
SOC-023, feasts with occasion and memory (decision 0493).

**Q-D11, the hour of a feast. Brendan, 2026-10-07: "All at 17:00 supper".** Every feast, called or the regatta's, is
served at the kitchen's 17:00 supper. It was first built as a deviation from REQ-SET-103's 18:00; on his approval of P9
(a) the same day, **REQ-SET-103 is amended by DEC-058** to 17:00, so the demo now follows the GDD. The rest of
REQ-SET-103 (waves, consumption on attendance) stands. Q-D11 is CLOSED in
`docs/handoff/OPEN_QUESTIONS.md` and indexed in `RULINGS.md`. The regatta was already served at that supper (decision
0438; the 2026-10-01 tracker ruling), so it is unchanged.

## Decision

The HUD's **Feast** command (UI-SET-032) now opens a **Feasts panel** (`demo/feast/`), where the player calls one of
GDD §5.7's three feasts for one of the next suppers, with a keeper (the host). The feast is cooked as the kitchen's
existing **occasion** (decision 0438's API, both courses), served at 17:00, tallied at the kitchen's MEAL FINALIZED event
(decision 0997's reading), and its buff granted and **applied** where the demo models the thing it changes.

### The rules used, as written

- **§5.7's feast table** (and SET-AMEND-001 §4.2 for the Orchard main course): Hearth ceil(E/3) bean_hotpot + ceil(E/3)
  nut_loaf + the warm infusion (water ceil(E/4) U, herb 0.25 x ceil(E/12) U, "prepared during service"); Harvest
  ceil(E/6) feast_fish + ceil(E/3) berry_tart + mead ceil(E/4) U; Orchard ceil(E/4) nut_roast + ceil(E/3)
  orchard_crumble + mead ceil(E/4) U. Each attendee one portion of each course; the beverage "consumed proportionally to
  attended/E with milli-unit rounding at the last attendee"; staffing 2 cooks + 1 keeper; seats >= ceil(E/3); service
  wood ceil(E/12) U reserved at confirmation; at most one feast may start in any 72 game hours.
- **§3's Feast row**: "At most 1 scheduled/active feast" -- a called feast and a held regatta never coexist.
- **REQ-SET-099/100**: the plan shows E, every course's food and portions, the seatings, staffing and the reserves after
  it; a refusal names the specific input and the missing quantity ("needs mead: 2.0 U (0.0 U free) — the brewery's mead").
- **REQ-SET-101**: refused under 3 food-days or 3 fuel-days after the feast unless the player overrides it for this
  feast. Ready food after it leaves the feast's reservation out ("locked feast reservations" are not food-days, §5.8):
  `kitchen.gd days_of_meals_after_milli`, an additive hook. Fuel-days after it are **§5.8's** -- the wood left after the
  service and the batches over the hearths' heating demand plus the cooking mean (`winter/hearth_fuel.gd`), as the
  packet's pitfall asked, not the kitchen's wood alone; the regatta now reads both figures through the same hooks.
- **REQ-SET-102**: held, everything is reserved; cancelled, everything goes back untouched. A feast may be cancelled
  until the kitchen starts cooking its supper (15:00 on its day): after that its batches are under way, the kitchen never
  undoes cooking, and an uncooked remainder would stay with that supper (the review's H1, below).
- **REQ-SET-104/105**: the theme's buff when at least 80% of E ate every course and the beverage was poured; once, 48 h,
  never stacked or extended. The regatta's Shared Warmth is the same Hearth buff (a called Hearth feast does not stack on
  it), and the readers count either.
- **The new courses are §5.7's rows exactly** (SET-AMEND-001 §4.1 for `nut_roast`), appended to the recipe book as
  OCCASION dishes (`dish_book.gd` rows 20–23, never renumbering; added to `ADOPTED_ROWS`): `feast_fish` (fish 4, roots 2,
  herb 0.5, water 2 → 6 x 2500, 48 WU, 36 h; the GDD's own dish), `berry_tart` (flour 2, berries 2, honey 0.5, water 1 →
  3 x 2200, 28 WU, 48 h; the library's `triss::TRI_recipe_feast_tarts`), `nut_roast` (beans 3, roots 2, nuts 1, herb
  0.25 → 4 x 2400, 30 WU, 36 h, no water; the GDD's own), `orchard_crumble` (fruit 3, flour 2, honey 0.5 → 3 x 2300,
  28 WU, 48 h, no water; the library's `rakkety_tam::RAK_recipe_banquet_crumbles`). No pantry item or work-board source
  is added.
- **Buffs applied**: Shared Warmth's cold exposure −25% is **wired** into `winter/cold_exposure.gd` (`gain_permille`,
  scaling exposure gained, never clearing; §5.2's 2000 → 1500 and 1000 → 750 exact; clamped at §5.7's 40% cap) -- the
  packet's pitfall: the regatta published it but nothing read it. Abundant Tables' work +5% is a factor ("feast", 1050)
  on the village's work pace (`work_pace.gd add_factor`). Mood +400, purpose +20%, social decay −20% and the two extra
  newcomers are shown, not applied: the demo models no mood, purpose or social need and no arrivals.
- **Cider beside the mead** (Brendan's ruling of 2026-10-07, relayed by the coordinator: balance proposal 1731 P3,
  option (a), "the Harvest and Orchard feasts pour mead and cider under the mead rule (no intoxication, no Shared
  Warmth effect)"; the balance rerun had found mead brewed at 52–60 U a year and never poured, the regatta being its
  only sink). The Harvest and Orchard feasts pour their required mead ceil(E/4) U and also the brewery's **cider**,
  ceil(E/4) U, reserved at confirmation when all of it is free, poured proportionally to attended/E, the rest given back
  -- the regatta's own handling of its drinks (decision 1621) under **the mead rule** (Brendan's ruling on DEC-007,
  decision 1625: a feast or table drink only, no intoxication, no effect on a buff). Cider is never required; its
  quantity is decision 1625's PROVISIONAL ceil(E/4). Ale and the cordial are not poured at called feasts (the ruling
  names mead and cider).
- **M4's "12 completed feasts"** is bound (`goal_book.gd bind_measure`; 0901 left it unbound): the called feasts
  completed plus the regatta's `feasts_served`.

### Numbers chosen that the GDD does not give (PROVISIONAL)

| Number | Value | Source |
|---|---|---|
| Suppers offered | the next 3 (`DAY_CHOICES`) | this decision; three suppers fit inside one 72-h interval |
| The day's cut | today's supper only before 15:00 | `meal_rules.gd COOK_FROM_HOUR` (the supper's cooking starts then, decision 0421) |
| Seatings | ceil(E / seats), at most 3, inside the supper's 17:00–18:59 | REQ-SET-103's "up to three one-hour waves", at Brendan's 17:00 |
| "Completed" | at least one resident ate the main course | Brendan's 2026-10-07 reading of "Regatta day" (decision 1651), applied to every feast |
| Work-pace factor name | "feast" | display only |

### Shared files touched (all additive hooks)

| File | Hook |
|---|---|
| `godot/demo/demo_village.gd` | `_build_feasts()` after the weather effects (the feasts node, its people hook, the Feast command, the cards, guide and people card give way while its panel is open, M4's `feasts` bound); `feasts()`; one `add_planning("the feasts", ...)` line |
| `godot/demo/kitchen/kitchen.gd` | `days_of_meals_after_milli(set_aside)` and its `_set_aside` pool deduction (empty: no change); `held_for_meal_milli(key, selector)` (P6 (b), a read); a **fix**: a batch of a dish with no water no longer calls `take_water(0)`, which refused and raised "a batch's water or wood was gone" |
| `godot/demo/kitchen/dish_book.gd` | four OCCASION rows appended; three category constants; `ADOPTED_ROWS` |
| `godot/demo/regatta/regatta.gd` | three optional Callables (`feast_clash`, `food_days_after`, `fuel_days_after`); unbound, the regatta's own figures as before; FEAST_CLASH refusal first in `_feast_refusal` |
| `godot/demo/regatta/regatta.gd` (P6 (b)) | `count_supper(day)` (called from `refusal` and `preview_lines`, cleared by `hold`), `free_beans`/`free_cabbage` through `_free_with_supper` |
| `godot/demo/regatta/regatta_menu.gd` (P6 (b), after #234 merged) | `supper_key` and `_course_free`: the nut loaf's flour and nuts count the supper's held food; `_free` (the infusion's herb, the drinks) stays free food alone |
| `godot/demo/regatta/demo_regatta.gd` | header words (the Feast command is the feasts' now); `hold_card` names its supper first (`count_supper`) |
| `godot/demo/winter/cold_exposure.gd` | `gain_permille` (1000 by default: no change) and `gained_rate` |
| `godot/demo/README.md` | "Called feasts" section; Layout row; the regatta's line |

Not touched: `godot/scripts/core/`, `demo/burrow/`, `demo/tunnel/`, `demo/cast/`, the settlement UI, and the files
#234 changed (`kitchen/meal_rules.gd`, `preserve/*`, `fishery.gd`; `regatta_menu.gd` only after #234 merged, for P6 (b)). **No key added**: the panel is
behind the existing Feast command.

## PROPOSALS for Brendan

- **P1. Which suppers a feast may be called for.** Built: the next three (today's before 15:00). (a) as built; (b) any
  day of the season, as the regatta; (c) tomorrow's only. Recommendation: (a).
- **P2. A called feast needs every course.** Built: the plan is refused naming what is short (REQ-SET-100: "complete
  ingredient/portion requirements"); the regatta keeps your 2026-10-01 ruling to hold with a missing course. (a) as
  built; (b) called feasts follow the regatta's rule (held, no buff). Recommendation: (a).
- **P3. Drinks at a called Hearth feast.** Built: the Harvest and Orchard feasts pour mead and cider (your ruling, above);
  a called Hearth feast pours only its row's infusion, while the regatta's Hearth feast pours mead, the cordial, ale and
  cider (decisions 1621, 1625). (a) as built; (b) a called Hearth feast pours mead and cider too. Recommendation: (a),
  keeping the Hearth row as the GDD writes it; (b) is a one-line change.
- **P4. What "completed" means** for M4 and the 72-h interval. Built: at least one resident ate the main course (your
  "Regatta day" reading). (a) as built; (b) only feasts that earned their buff. Recommendation: (a).
- **P5. REQ-SET-106 (a critical emergency pauses serving).** Not built: the demo's threats do not interrupt meals.
  (a) leave it; (b) build it with the incidents (pause serving, keep the unserved portions, cancel after 24 h).
  Recommendation: (a) for now.
- **P6. Food today's supper already holds.** Built as the regatta: only food nobody holds is "free", so a feast called
  for today's supper cannot count the food the kitchen has set aside for that very supper, though the feast replaces it.
  (a) as built; (b) count it (a small kitchen hook, shared with the regatta). Recommendation: (b), as a follow-up.
- **P7. Abundant Tables' +5% work** applied to every resident's work pace for 48 h. (a) as built; (b) a readout only.
  Recommendation: (a).
- **P8. Dish art for the four new courses** (they show the fallback swatch). (a) leave them; (b) add the four dish
  icons to the next costed art list. Recommendation: (b), with the cost itemised then; nothing is spent now.
- **P9. Recording Q-D11 in the specification.** (a) a `DEC-nnn` in `setting_decisions.md` and REQ-SET-103 amended to
  "17:00" at the next integration; (b) leave the GDD's 18:00 and keep the deviation recorded here and in `RULINGS.md`.
  Recommendation: (a).

## Brendan's rulings (2026-10-07)

Relayed by the coordinator: **"all nine of 1701's proposals approved as recommended"** -- P1 (a), P2 (a), P3 (a),
P4 (a), P5 (a), P6 (b), P7 (a), P8 (b), P9 (a). What they required:

- **P6 (b), built on this branch.** A feast counts the food its own supper's ordinary meal already holds, which the
  feast replaces: `kitchen.gd held_for_meal_milli(key, selector)` (additive) -- what the planned meal `key` holds of a
  selector, 0 when the meal is not planned, is already an occasion's, or has a batch cooked or at the cauldron
  (nothing cooked is undone). `feast_menu.gd available_of` adds it to the free food for the feast's own supper; the
  plan, the "needs X" words and the preview's "free" figures use it. The reservation is unchanged: what the free food
  lacks at confirmation, the kitchen's own top-up takes once it adopts the occasion (it lets the meal's food go and
  holds each course's from it). **The regatta counts it too** (the ruling's "shared with the regatta"; the second
  review found its planned day's supper already planned four meals ahead): `regatta.gd count_supper(day)` names the
  supper while planning, `free_beans`/`free_cabbage` and `regatta_menu.gd _course_free` (the nut loaf's flour and nuts) add
  what it holds, and the hold clears it. Only courses count it: the kitchen never tops a beverage or drink up, and no
  ordinary meal takes herbs or mead, so the called feasts' beverage check uses the free food alone.
- **P9 (a), done.** `DEC-058` in `docs/setting_decisions.md` ("Every feast is served at the 17:00 supper", Brendan's
  words "All at 17:00 supper"; DEC-050–057 are taken on the digging branch, so 058 is the next free one); REQ-SET-103
  in `docs/game_gdd.md` amended to "the 17:00 supper" with a dated amendment note; `docs/gameplay_balance.md`
  BAL-RUN-004 and `docs/ui_ux_controls.md`'s "Hold a feast" flow amended to match.
- **P8 (b), queued.** The four courses' icons are on the next costed art list (`docs/handoff/BACKLOG.md`, ART-NEXT:
  one icon sheet, about 6 credits). Nothing was spent.
- P1–P5 and P7 approve what was built.

## After #238 (the balance tuning, decisions 1732–1737)

Merged 2026-10-08; the README's two new sections (this lane's and the tuning's) kept side by side.

- **The hotpot's greens or roots (decision 1735's seam, fixed here).** The regatta's main course now checks and reserves
  the recipe book's own selectors (`regatta.gd main_beans`/`main_greens`, `input_selector(DISH_BEAN_HOTPOT, 0/1)`),
  never the cabbage row: `free_cabbage` became `free_greens`, its refusal `NO_GREENS` ("the main course needs 6.0 U of
  greens or roots"), and the card and preview use the book's words. The called feasts already read every input through
  `input_selector` (feast_menu.gd), so they needed no change; tests now show beans and carrots alone holding and
  cooking a Hearth feast and holding a regatta. **REQ-SET-101 with a cross-category input** (the quick review's
  HIGH): the post-feast ready food set the hotpot's greens-or-roots input aside under greens alone, so with no greens
  in store a feast of roots left its roots counted as food-days after it and could pass the reserves gate a greens
  feast failed (3.000 days against 2.888 on the same food). Fixed: `feast_menu.gd add_course_drawn` sets such an input
  aside as the kitchen's estimate draws it (`_draw_pool`: its categories in order, each up to what the pantry holds
  beyond what is already set aside); the called feasts and the regatta's `food_days_after` hook both use it, and a
  test holds the greens and roots figures equal and both refused.
- **The table drink (decision 1733) skips a called feast's supper**: it skips any occasion's supper by the kitchen's
  `occasion_key`, which a called feast sets; a test runs a Hearth feast with cordial in store and finds none poured at
  it. The Harvest and Orchard feasts pour mead and cider, never the cordial, so nothing is poured twice. (Noted for 1733's
  owner: a feast cancelled before its supper leaves its key in the drink's memory, so that ordinary supper pours no
  cordial.)
- **A portion and a half (1732)** changes the kitchen's daily portions; the fuel-days fallback reads
  `daily_portions()`, and its tests now compute from it.

## Tests and gates

- **Suites**: `test_demo_feasts.gd` (31 tests, after P6 (b): its supper's own food counted, for another dish's meal,
  not once a batch is cooked or at the cauldron, and the regatta menu's nut loaf; the numbers, SET-AMEND-001's E = 12/13, Q-D11's hour and the interval,
  every refusal in order with REQ-SET-101's food and fuel halves and the override, holding, cancelling before and during
  cooking, a feast the kitchen had not planned yet, every theme cooked and eaten on real brains, the lapse, the tally's
  courses, the beverage's partial pour, cider, the buffs and the cold, the regatta's hooks, the words and the panel);
  `test_demo_regatta.gd` gains the regatta counting its day's supper (its preview, its free beans, the hold topped up);
  `test_demo_feast_live.gd` (the live harness at both sizes); `test_demo_dishes.gd` (24 rows, 20 distinct, the four new
  §5.7 rows exact, GDD_OWN); `test_demo_crop_roles.gd` (peas now feed the nut roast too).
- **The full suite, CI-style** (assets moved aside, `godot/.godot` deleted, re-imported, `./tools/run_tests.sh`), on
  the final tree (P6 (b) built; `origin/master` merged with #236, #237 and #238; the hotpot seam and its reserves
  fix, at ed698299):
  `ok: 9456 tests, 653580 assertions, 0 failures.` ·
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 373 tolerated; leaked at exit: 0 object(s), 0 resource(s)` ·
  `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- **Analyzer**: `python3 tools/gdscript_warnings.py --max 0`: `0 GDScript warning(s) in 0 of 1076 file(s)` (its own `--port 6117`), on ed698299.
- **Contracts**: every check in CI's contracts group passes (decision_numbers 338 records, ready07_arithmetic,
  merge_gate, setting_contract, dispatch_plan, astra_inbox, the save registry handoff, the canonical state table, the
  cycle 1–3 handoffs, the registry capacity audit, the component columns schema, lane_notes, the movement checks,
  state_registry_coverage, ui_refinement_contract).
- **Live harness** `test/live/demo_feast_live.gd`, assets staged: `LIVE-SUMMARY 18 0` at 1280x720 and 1920x1080, headless
  and windowed. Frames looked at: `scratchpad/feast_check/{feasts_panel_open,feasts_panel_ready,feasts_panel_called,
  feast_at_supper,feasts_panel_after}_{1280x720,1920x1080}.png` -- the panel in the window clear of the side panels,
  the plan and its refusal, Call held, the hall's tables at supper, and the tally ("9 of 9 shared it ... Shared Warmth
  for 48 h"; the cold's gain at 750).
- **Mutation**: 110 mutants, **110 killed** -- 107 on the rules, menu, buffs, cold, plan, tally, kitchen hooks, regatta
  hooks, dish rows, P6 (b)'s kitchen read and its feast and regatta callers against `test_demo_feasts.gd` +
  `test_demo_dishes.gd` + `test_demo_regatta.gd` (a mutant also dies on any unexpected
  diagnostic or leak), and 3 on the village wiring (the cold's gain, the Feast command, M4's binding) against the live
  harness. **SURVIVED_MUTANTS: none.**
- **Independent review** (the `code-reviewer` agent, waited for): no CRITICAL. **H1** (a feast cancelled during the
  15:00–17:00 cooking window gave back nothing while the kitchen kept cooking) -- fixed: a feast may be cancelled only
  until the kitchen starts cooking it, with a test. **H2** (five gates a mutant could break silently) -- fixed with
  tests: the unplanned feast's cancel, the INTERVAL refusal through `refusal`/`hold`, REQ-SET-101's fuel half, the lapse
  path, the occasion and takes let go after the tally. MEDIUMs: **M1** the live harness now asserts the buff before the
  cold (fixed); **M2** a held feast's preview no longer takes its service wood twice (fixed); the HUD's Ready food still
  counts a held feast's reserved food, as it counted the regatta's -- declared here, left to the HUD's owner; **M3** the
  tally and settle mirror the regatta's rather than sharing a helper, to keep `regatta.gd` and `regatta_menu.gd` out of
  #234's way -- a refactor for a later lane. LOWs: the override resets on a new theme or day (fixed); `_exit_tree`
  leaves the cold at full rate (fixed); `fuel_days_milli`'s docstring (fixed); the cold's factor lags its setter by one
  frame (accepted: presentation, a frame of 48 h); the panel's 4 Hz refresh recomputes the plan (accepted: only while
  open); the regatta's Shared Warmth ignores a called Hearth feast's (safe: the 72-h interval outlasts the 48-h buff).

- **Second and third reviews** (P6 (b) and P9 (a), `code-reviewer`, waited for): no CRITICAL or HIGH. Fixed: the
  regatta half of P6 (b) built (MEDIUM 1); REQ-SET-103 reads "begins at 17:00", with its waves and the WORK-hour
  overlap noted and the latter left to Q-D14 (MEDIUM 2); every "deviation" now reads "amended by DEC-058" (MEDIUM 3);
  the beverage, the regatta's herb and its drinks count free food alone; DEC-058 placed after the DEC-040
  follow-through and credited as relayed; the ART-NEXT anchor and sheet; the regatta's hold card names its supper; the
  tests the reviews asked for. Answered: the feast's beverage check and the hold card's ordering are equivalent today
  (no ordinary meal takes herbs or mead; the panel builds the preview first) and are pinned in code and words; the
  plan's "free" figures include the supper's held food for that supper's own feast (kept as "free": it is free to
  that feast, which replaces the meal); when `feat/demo-balance-tuning` lets the
  hotpot take roots, the regatta's cabbage check may under-count (refuse more often), never over-commit -- re-check at
  that merge.

- **Fourth and fifth reviews** (after #238; `code-reviewer`, waited for). The fourth found one HIGH, the roots
  reserves figure above -- fixed in ed698299 with a regression test -- and MEDIUM wording ("cabbage" in the guide's
  regatta entry and the README), fixed. The fifth, on that fix: no CRITICAL or HIGH; its MEDIUM, the static
  `add_course` now used only by the Orchard numbers test, is answered: it stays as the plain one-category primitive
  that test pins (SET-AMEND-001's E = 12 roast); the courses go through `add_course_drawn`, whose one-category branch
  the feasts' full-day tests cover. Its LOWs are recorded: the projection draws greens before roots as the kitchen's
  estimate does, while the hold reserves whichever lot spoils first (usually greens, at 144 h against 240 h), so the
  preview's figure can differ a little from the hold's; and a later single-category greens or roots course would not
  move the hotpot's draw (no theme has one).

## Source

GDD §3 (Feast row), §5.7 (feast table and rules; REQ-SET-099–106), §5.8 (food-days and fuel-days), §5.11 (M4);
SET-AMEND-001 §4; decisions 0438, 0682, 0997, 1601, 1611, 1621, 1625 (on `feat/demo-new-recipes`), 1651; DEC-007;
Brendan's ruling on Q-D11 (2026-10-07).
