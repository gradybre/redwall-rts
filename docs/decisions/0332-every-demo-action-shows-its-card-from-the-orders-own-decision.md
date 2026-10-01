# 0332 — Every demo action shows its card, filled by the order's own decision
Date: 2026-09-30 · Status: Accepted

> **Superseded in part by [0421](0421-a-game-day-lasts-ten-minutes.md) (2026-10-01):** a game hour is now 25 s, so a
> card's work under an hour reads in whole game minutes ("about 29 game minutes"); from an hour, tenths as before.

Review group H, "action previews": findings F33 (action buttons omit costs, consequences and useful disabled
reasons) and F44 (selection changes assignment semantics without a common preview) of the live-demo review
(`/Users/brendan/Developer/redwall-review/REVIEW.md`, written against 157a3a4; P1's bridge planner and bed rows with
the bridge wireframe, and P2's assignment preview). Both were confirmed on this branch (e4628c9, decision 0251) before
the change: the farm's disabled verbs said their refusal code in lower case ("not too wet", "nothing growing") and its
enabled ones only some effects; the woods' `_enable()` disabled a button with no reason at all; the tunnels enabled
Widen/Brace/Lanterns/Repair by geometry alone, a short store or a missing worker only answered after the click; the
Water panel enabled "Build footbridge" with 0.0 U of planks; no button said who would go, for how long, or what that
resident would stop.

**Numbering.** The highest record on this branch is 0251 (group E's). Parallel review groups work in other worktrees,
so this took 0251 **plus 80** (0331), as the group-H brief asked; the gap is deliberate.

**Renumbered 0331 -> 0332 at integration (review batch 2).** Group I's village news record took 0331 too
(`0331-village-news-history-incidents-and-re-alerts.md`); I's merged first, so this record moved to 0332, the next
number free on every branch and worktree. Every reference to this record -- the README's "Action cards" section, the
code comments and the tests -- was changed with it; a "decision 0331" in the news, incident and alert code is I's.

New files: `godot/demo/ui/action_card.gd`, `godot/demo/control/work_interrupt.gd`, `godot/demo/farm/farm_card.gd`,
`godot/demo/forestry/forest_card.gd`, `godot/demo/burrow/fixture_card.gd`; `godot/test/test_demo_action_cards.gd`.

## Decision

### 1. One card, one shape (F33)

`action_card.gd` is a reusable record every action's tooltip is written from, in this order -- the review's
formatting rule, warning and way out first: the verb and its object; refused, **"Can't now:"** the exact refusal and
**"To fix:"** the way to put it right (a panel ▸ button where one does it: "Woods ▸ Saw planks (2.0 U wood makes 2.0 U
planks)"); the **result**; each **cost as have / need** ("Planks: have 0.0 U · need 4.7 U"); the **work** in game
hours; **who**; what that resident **interrupts**; **needs**. Enabled buttons carry the card too.

- **Costs read the stores the HUD reads** (decision 0251's owners: the village stores' wood, stone and planks), the
  farm's compost store and the fullest spoil heap -- the very figures each refusal compares. Units are the stores'
  formatter (`tunnel_stores.gd units_text`), called in one place (the card), so group B's unit work merges at one site.
- **Work in game hours**: every system's work runs on demo microseconds, the same microseconds the one calendar turns
  into hours (`demo_calendar.gd HOUR_USEC`, 2.5 s), so a work time is exactly that many hours of the HUD's clock --
  rounded up to the tenth so a sliver of work never reads 0.0. The walk is not counted (it depends on the route) and
  the card says so; a mole job's card says a crew is quicker (its rate depends on who joins).
- **The look**: the demo panels sit outside the HUD's skinned theme, so their tooltips drew in the engine's grey over
  the panel. `dress` gives a card's button a theme holding only the HUD skin's tooltip items (the map piece, ink,
  15 px): the button keeps its own look. Lines break at 46 characters to stay inside UI-SET-073's 360 × 240.
- A tooltip is written only when its text changed, and a button's enabled state is set once a refresh from the card
  (the panels' own `show_*` now take the card's answer): a refresh that flipped `disabled` off and on again closed a
  showing tooltip (seen at 1280x720 on the Build buttons). Likewise `tunnel_panel.gd show_room` now sets each palette
  row to its final visibility once; it used to hide every row and show the palette's again on every refresh, which
  dropped the pointer's hover and closed a "+"/"−" tooltip within a fifth of a second (decision 0210's rows; nothing
  could read those buttons' tips before).
- **Quantities come from their constants**: the farm's dose ("2.0 U") from `COMPOST_MILLI_PER_TILE` and
  `SPOIL_PER_JOB_MILLI`, the saw's batch from `SAW_BATCH_MILLI`. A requirement is stated exactly (`need_text`:
  hundredths when it has them -- planting's 0.25 U of compost, a 5-quantum brace's 1.25 U), where the HUD's floored
  tenth would understate it; what the stores hold stays in the HUD's own words.

### 2. The card is the order's own decision

**One function decides both.** Where an action computed its eligibility and cost inside the order, it was refactored
into a pure decision the order then executes and the card reads:

| Family | The shared decision | Executes |
|---|---|---|
| Farm verbs, Plant…, crop rows | `farm_crew.gd decide` (refusal, the job on the board, the nearest free selected) | `order` |
| Woods verbs | `forest_crew.gd decide` (joined job, refusal, board, lead, haulers) | `order`, `order_haul` |
| Tunnel jobs | `tunnel_actions.gd refusal` (tunnel, worker into `_pick`, stores) | `order` |
| Fixtures | `room_fixtures.gd order_refusal`, `suggest_refusal`, `take_refusal`, `place_for` | `order`, `suggest`, `take_out` |
| Bridges | `demo_waterplay.gd build_refusal` (survey, `_material_refusal`'s source, a free row; `build_refused_by`) | `build` → `_pay` |
| Dive | `dive_spot` + `dive_refusal` per selected resident | `order_dive` |
| Dig tool, room tools | `tunnel_control.gd choose_digger`, `crew_size` | `confirm` |

Work shares its timing the same way: the farm's `farm_jobs.gd plan_work_usec` sums `work_usec_of` (the step timer's
own), the woods' `forest_crew.gd step_usec` is now what `_begin_work` sets a step's length from, the bridges'
`bridge_crew.gd build_usec` multiplies `_usec_per_wu` (the credit rate) by the stages' WU.

- **A refusal's words are the order's.** The farm's refusal codes now read in the player's words for the order's
  answer and the card alike (`farm_card.gd WORDS`: "Can't drain: the bed is not too wet", not "not too wet"); every
  other family's card quotes its order's own string (a fixture's from `room_text.gd answer`, a bridge's from the
  build's refusal without its "-- <fix>" tail, which the card puts on its fix line).
- **The panels enable by the card.** Build footbridge with no planks, Brace with the stores short or nobody free who
  fits, a fixture the stores cannot pay for: disabled before the click, with the reason. Rejected: keeping
  geometry-only enabling and refusing on the click (the finding).
- `forest_text.gd tree_actions`, which enabled the tree verbs by `refusal_for` alone, is removed: the cards' answer
  enables them (it also covers a job already queued, the board and a selected haul with everyone busy).

### 3. The assignment preview (F44)

"Who" is the system's real rule, said in one grammar in every panel (`action_card.gd`'s helpers):

- "Assign selected: Mouse keeper (nearest of 3)" -- the farm, the woods and the bridges send the nearest free
  selected resident ("nearest free of 3 selected" when some are busy with that kind of work);
- "Assign selected: Mouse fieldworker (first of 2 who fits the bore)" and "Assign Mouse keeper (the nearest free
  resident who fits the bore)" -- the tunnels' first-selected rule and their village pick; "Assign Mole digger (the
  village's most skilled free digger) + 2 on the crew" -- a mole job, its crew counted as `add_crew` will
  (`crew_joining`);
- "Lead: Squirrel forester (nearest of 3) + 2 waiting to haul" -- felling;
- "Queue for the field crew: Mouse fieldworker or Squirrel gatherer, whoever is free first", "Queue for the forestry
  crew: …", "Queue for the nearest free resident who can reach the room, by day (up to 3 at once)"; a fixture's
  selected installer is the first who can reach the room (`fixture_crew.gd first_able`), and since `give_selected`
  hands it the room's FIRST waiting fixture in place order, the card says when that is another one ("; first it puts
  in the bed already waiting");
- "Queue for the bridgewright: Beaver bridgewright (specialist)" -- with nobody selected a bridge waits for the
  routine bridgewright (DEC-041);
- "Already under way: X is on it".

**What the resident stops** (`work_interrupt.gd`, `demo_command.gd interrupt_text`): the party panel's own activity
words and the brain's RESUMING rule (decision 0205) read as the brain applies it -- a task kept to come back to when it
has something to come back to (a tunnel job, an install); a dig kept paused once a tick is dug, else its route
**dropped** (the card warns); an outside job answered by its owner through `add_resume_rule` (the farm's, the woods'
and the spoil crew's resume; a bridge builder leaves the bridge waiting for a builder); a sleeper goes back to bed
after (decision 0210's night routine); a work spot let go; anything else interrupts nothing ("Free now: wandering").

## Why

The finding was that preview and execution were computed apart, so a button could be enabled and then refuse, or say
nothing and then spend. Putting the eligibility and cost in one function and letting both read it makes disagreement
structurally impossible rather than a matter of keeping two copies in step. The assignment rules were already real
(they differ by system for good reasons -- a bore admits only who fits, a bridge has a specialist); the defect was
that the player could not see them, so the card names the rule rather than unifying it.

Rejected: a hover panel built of separate controls (a richer card), because it would need either a Button subclass in
the panel factories group G is editing or a parallel hover system; the native tooltip with the HUD's skin and a short
fixed line shape is the same information with no input-handling changes. Rejected: a clickable "fix" link -- a tooltip
cannot hold one, and the review asks not to auto-create orders from a tooltip; the fix names the panel and button.

## Verification

- Tests: `test_demo_action_cards.gd` (new, no staged assets): the card's line order, game-hour rounding, wrapping and
  grammar; the resuming rule for each case and the command layer's line; per family, the card's cost equals what the
  order spends (compost from the store; sawing's wood; bracing's wood and stone at the job's start; a bed's planks
  and the suggested layout's; a footbridge's planks) and its work equals the work steps' length; every refusal maps
  to the order's (code and words) with its fix; the assignment preview equals who is sent (selected, the crew after a
  hand-out, the bridgewright specialist, a felling's lead and haulers, a mole job's crew, the Dig tool's digger, the
  dive's divers); the panels' buttons carry their cards and are enabled by them. Updated: the farm UI, HUD truth,
  water play and spoil suites (the farm's refusal words; the footbridge disabled without planks).
- Suite: `./tools/run_tests.sh` -- "ok: 6452 tests, 549425 assertions, 0 failures." (base, e4628c9: 6401 tests).
- Mutation testing of the new logic, one mutant at a time, restored and hash-checked each time (the card, the grammar,
  the resuming rule, each family's decision, preview, work and words, the panels' enabling, the fixes below):
  **138 mutants, 136 killed, 1 equivalent, 1 retired.** First pass 119: 74 killed at once; 45 survived -- 43 killed by
  tests added for them (have equal to need, zero work, continuation indents, the farm's kept work and later steps, the
  spoil plan, a full board on each side, the trunk's hands, a selected haul's count and all-busy, the sawyer's skill,
  the haul's trips, the pile's generation, the tunnel job's work done, the crew's room and the digging member, the
  bridgewright's level and load, the able count, the full set of bridge rows, short pier wood, the first diver, the
  fixture crew's reach and resident 0, ...), 1 equivalent (below), 1 retired with the Cancel line it mutated (rewritten by the review fixes,
  its replacement killed). The review fixes' own 17 + 2 (the room rows): all killed. Equivalent: the dive card's
  spread spot (`dive_spot(spot, n)` against `spot`): the pond is as deep there for every height a diver may have
  (searched 1200-2100 u, about 1.2-2.0 m), so no outcome differs.
- Frames at 1280x720 and 1920x1080 (each hovered, the tooltip open): a farm verb (Compost) and a refused one (Harvest,
  not ripe); a woods verb (Fell, lead + haulers) and a refused one (Saw planks, short of wood); a tunnel job (Brace);
  a fixture refused (a bed, every place taken); a bridge refused (no planks, the saw as its fix) and allowed (queued
  for the bridgewright): `scratchpad/rv_h_check/` (`a720_*`, `a1080_*`).
- Review: the independent `code-reviewer` agent, no CRITICAL. Fixed: **HIGH** untyped loop and test variables; MEDIUM
  the log card's trunk note overwritten, a full set of bridge rows called a material shortage (now `NO_FREE_ROW`, no
  fix), the fixture card naming its installer for the wrong fixture (now says what it puts in first), a picker row a
  full board refuses left enabled, untested branches (now tested), the Dig tool's test not running `confirm` (now
  does), per-refresh allocations (the dig ticks' scratch, the fit-out keys made once, the crews' names cached,
  `sow_refusal` instead of formatting a reason), hard-coded quantities (from their constants), a 31-line `configure`;
  LOW a freed owner's resume rule skipped, the farm's Cancel tooltip written only on change, `clear_refusal`, a
  haul's work said to be shared by its haulers. Not changed: a task-held resident's card asks the task's
  `unfinished()` (it builds a small object for the answer) -- a handful a refresh, at most 5 Hz, and the task classes
  belong to the tunnels' work in flight elsewhere.

## Integration with B, C, I, J, Q, R and phase 6 (review batch 2)

H was written on E alone. Merged after the harvest conservation (decision 0222), the village news (0331), the map
layers (0292) and the second level (0212):

- **A harvest with no store room waits; its card says so.** 0222 never cuts a harvest without reserved room: the
  order queues it (or finds it queued) and it waits on the board, nobody sent, the shortage said and the full-store
  incident raised. `farm_crew.gd decide` now asks the same room test (`_room_for`: `_can_store` for the job on the
  board, else the pantry's `location_for_item_into` for a new harvest's expected yield) and answers `waits_room`;
  `order` executes it (`_wait_for_room`, 0222's two answers word for word) and the card's Who line reads "Waits on
  the board: no store has room for 5.1 U of carrot — make room in the Pantry (K)" (`room_words`, the order's own
  shortage words). The button stays pressable, as the order is not refused.
- **A planting's compost is paid once (0222).** Joining a planting already on the board takes no compost, so its
  card's compost row needs 0 and says it is paid already (`forest_card.gd compost_paid`).
- **Units.** The card keeps one site for quantities (`amount_text`, the stores' and HUD's `tunnel_stores.gd
  units_text`) and `need_text` for hundredths; 0222's farm formatter (`farm_text.gd units_text`, with "<0.1 U") stays
  the farm panels' and the order's. No formatter was added or duplicated by the merge.
- **Woods deliveries.** `point_of` also places 0222's log and plank deliveries (the log and plank stacks).
- Tunnels, fit-out and bridges merged without conflict over phase 6's levels: the cards read the same
  `refusal`, `choose_digger` and fixture refusals the orders do.

## Consequences

- A new demo action gets its card from its system's decision function; an order that decides inline is the defect
  this record removes.
- **Open**: the woods' and water panels' disabled buttons look much like enabled ones (the woodland disabled wood is
  faint; the farm dims its own); the card says "Can't now" either way. The longest cards (a felling's, a refused
  bridge's) run to ten 25 px lines, a little over UI-SET-073's 240 px at 1280x720. Refusal words elsewhere still say
  "the demo stores" (0251's open item). Work times exclude walking; a haul's is the total of its trips, shared by
  however many haul.

## Source

REVIEW.md F33 (461–471), F44 (593–599), P1's bridge planner, bed rows and wireframe (795–861), P2's assignment preview
(865–884); decisions 0205 (resuming), 0210 (the night, fit-out), 0251 (the HUD read model); UI-SET-073.
