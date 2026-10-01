# 0481 — A guided first village, and the village guide: help, field guide, practice stories, projects
Date: 2026-10-01 · Status: Accepted. The objective texts were approved by Brendan on 2026-10-01, with one change:
residents are "they", not "it" (see "For Brendan"). The independent review's findings are fixed (see "Review").

Numbered 0481: the highest records on any branch or worktree were 0471 and 0491; 0481 was free, inside the 0481-0489
band the brief gave.

Review group U: F49 ("The demo has many verbs but no integrated first-session objective path"), P7 ("A guided first
village and a reason to continue"), UX-017 (learning through chosen accomplishments) and UX-019 (optional practice
stories); and the approved half of group AI: UX-018 (a connected field guide) and UX-020 (player-named projects). The
GDD's progressive disclosure, REQ-SET-165 to 168, sets the rules. Code: `godot/demo/guide/`.

## Decision

The demo gets a **first-village guide**: one objective card at a time (UI-SET-072), four objectives, each completed
**only by its real outcome in the village's own models**, never by a button press or a timer; a brass marker in the world
on the objective's target; a **village guide** window behind the HUD's Objectives command (O) holding the objectives,
up to three **player-named projects**, a **field guide** built from the demo's own tables, the **searchable help** (which
also replaces the game menu's Controls page) and three **practice stories** kept apart from the village.

## The four objectives and what completes each

The guide's owner reads the village through `guide_world.gd` (read-only: no method there writes a model) and latches
facts in `guide_facts.gd` every frame from the first, shown or hidden. An objective is done exactly when its fact is
latched:

| # | Objective | Completes on (the real outcome) | Does NOT complete it |
|---|---|---|---|
| 1 | Meet a villager | a resident selected (the party panel then inspects it) | Show me (it only centres the camera) |
| 2 | Bring in a harvest | a delivery shelving food in a store: `farm_pantry.gd delivered_milli` grows (`store_upto_into`, called only by the farm crew's drop) | the order on the board, the crop cut, a load in hand, food stocked by `add_into` |
| 3 | Serve the first supper | a resident FINISHING a cooked supper portion: their own record (`nourishment.gd ate_meal`, written as the kitchen consumes the portion) | the plan, the cooking, the call, the pot on the table, a portion still held, raw food, breakfast, a supper nobody ate |
| 4 | Ready the village for the frost | the FIRST of: someone over the middle of an OPEN bridge's deck on its crossing leg, out of the water; someone going below and coming up `WALKED_THROUGH_M` (6 m) away without working the tunnels on the way; a bed with a crop standing covered, raised, banked, ditched or drained by a tunnel | a bridge planned or half built, a swimmer under it, the digger, a dig crew's member or a tunnel job's worker (wherever they come up), an empty bed covered |

Why these: they are P7's journey (inspect a resident, bring a ripe harvest into store, serve the first supper, then one
improvement of three -- "safe bridge, useful dry route, or better field preparation" -- before a foreseeable seasonal
event), and each is something the village's own model already records. The 6 m threshold is a demo value: a tunnel is
at least 8 m mouth to mouth (`tunnel_rules.gd`), while a dig crew, a hauler or a home's own door comes up within a few
metres of where it went down. The **foreseeable threat** is the farm's own frost calendar (`farm_weather.gd`: the night
into Spring 11, announced at noon on Spring 10); once it passes, the card names the next frost night. The wet spell
before it is named in the field way's line ("The carrot bed is wet: click it and press Drain").

Supper completes when the first resident FINISHES a cooked supper portion -- their own record, which the kitchen writes
as it consumes the portion. It was first the meal's tally (19:00), but the tally counts residents still holding a
portion as served, and the kitchen corrects that row later if one gives the food back; and the tally log keeps only its
latest 64 rows (see Review). A supper of porridge (the kitchen cooks the other dish when soup's roots are short) is
still the supper; raw food eaten when a meal is missed is not. Missed suppers are still read from the tally log, by
meal key.

## The card: one at a time, teach / try / confirm

- **Teach**: the objective's title and its economic reason. **Try**: the current cause or blocker and the next legal
  action, read live (`guide_status.gd`). **Confirm**: once done, the real figures ("5.1 U of carrot came into store"),
  for 10 s of UNPAUSED time or until Next; an objective done before its card came up is confirmed "Already done:" for
  5 s. A pause never counts a confirmation down (P7: "Pause does not complete steps or lose guidance").
- **Never a softlock (REQ-SET-167)**: every state resolves to a target and a next action. The harvest card goes, in
  order: a load on its way, a ripe bed (or "No store has room ... make room"), the bed that ripens soonest and its
  hours, a stalled bed and why, an empty bed to plant, a lost crop to clear. A target lost (harvested by someone
  else, withered, blighted) is replaced by another of the same action. The supper card shows the kitchen's own
  refusal and fix (`kitchen.gd decide_meal`, the same decision as its Cook order), or, after a missed supper, when
  the next is. Objective 4 offers its three ways side by side, each with where it stands -- a blocked bridge shows the
  Water panel's own refusal ("Can't build: it needs 4.7 U planks ...") and leaves the other two.
- **Verbs**: Show me (the camera eased over the marker -- centred 22 % of its distance beyond the target, so the
  target stands below the card; a bed, tunnel or bridge is also selected and its panel brought, as Go to does; a
  resident is only centred, because selecting it is objective 1), Help (the village guide's Help on this objective's
  topic), Hide guide; Next while confirming; Close at the end.
- **The marker** (`guide_beacon.gd`): a brass ring on the ground round the target and a brass point bobbing over it,
  on the surface marks layer, following a walking resident each frame, on real time so it is findable paused.
- **Where**: UI-SET-072, top centre under the alert zone, in the incident card's span (between the side columns), at
  most 420 wide. It **yields to a critical incident's card** (one card at the top centre: the most urgent), to the
  stall banner and to the open news history. It **never reaches the Map layer picker** below it: where the whole card
  would, it drops its teaching and objective 4's three lines (COMPACT), then its next action (MINIMAL); where even that
  cannot fit (125 % on 1280x720 with a layer's legend unfolded) it waits for room -- the village guide (O) still lists
  every objective. Its buttons are the input gate's last F7 region (world -> right column -> left column -> map
  layers -> guide card -> world).
- **Completion** acknowledges the community: "The first village stands" (text below), and a chronicle entry in the
  village news history under a new source, **Village** (`demo_notices.gd SOURCE_VILLAGE`, group Village), written once.
  Free play continues; the card can be closed.

## Skip and reopen (REQ-SET-168)

Hide guide on the card, Skip guide / Reopen guide in the **game menu's guide row** (under its buttons: where the guide
stands, Skip or Reopen, Village guide (O), Practice stories) and Show / Hide the guide card in the window's Objectives
tab only show or hide the card. None writes a fact, a resource or an unlock; tests compare the stores and the pantry
before and after. Hidden, the guide keeps up silently (done objectives are passed without confirmations), so reopening
lands on the first objective not done. A hidden guide that completes is still chronicled.

## The village guide window (O)

The HUD's Objectives command (UI-SET-033, O) is drawn locked by the game's shell (its Charter panel is not built); the
guide unlocks it as the work board unlocks Jobs: enabled, the painted goals icon, a tooltip in the command strip's form,
and O (which the shell presses on an enabled command) toggles the window. A modal (scrim, focus trapped, Esc / O / ×
close it; O types in its text fields, so its × says Esc). **While open it holds the clock's MENU pause reason**, as the game menu does, so the village waits while the
player reads, and a practice story's run cannot race it; closing releases only that reason. Five tabs: Objectives (each
done ✓ with what happened, current ▸ with its cause, ahead ·; Show/Hide the card; the Charter's line), Projects, Field
guide, Help, Practice. The Charter remains the long-term, community-authored goal; the window says this demo does not
reach it, and nothing here claims it.

## Help replaces the wall of controls

The game menu's third button was Controls (21 keys); it is now **Help**: one searchable page (`help_page.gd` over
`help_topics.gd`) of 18 how-to topics in plain words ("Why is a job waiting?", "Build a bridge", "Protect beds from
frost and wet", "Saving") and the 25 keys, each a topic. Search drops stop words, widens everyday words to the demo's
("eat" -> supper, kitchen; "cross" -> bridge, ford), requires every word to match before falling back to any word, and
ranks title over keywords over text. A topic a command answers carries it as a button (open the Pantry, the Kitchen
tab, Work, Village news, Residents, the Water panel, the Dig tool, a guide tab). The menu keeps its page index
(`PAGE_CONTROLS`), so Esc's way back and focus return are unchanged; Help's first focus is its search field.

**Typing inside a modal (`demo_input_gate.gd`)**: a modal swallowed every letter. Now, while an editable text field
inside the top modal has the focus, every press but Esc, Tab and Enter goes to it -- letters, Space, Backspace, their
repeats, and the modal's own letter close keys (which then type rather than close). **Enter is swallowed**: no field
submits, and a passed Enter reached the Dig tool's `_input` (which runs before the GUI) and dug the piece laid behind
the modal (review, HIGH). Text fields are Tab stops.

## The field guide (UX-018): only what the demo has

`field_guide.gd` BUILDS its 41 entries from the demo's tables rather than writing them beside them: 16 crops from
`farm_catalog.gd` (titles, the dish each feeds by `meal_rules.gd is_input`, raw value, shelf life at the covered store
and the cellar from the catalog's §5.7 rows and `stock_age.gd`, row-mates), the 2 dishes (inputs, water, wood, work,
portions), 6 materials, 8 buildings and stations, 5 skills and 4 water-safety entries with figures from
`room_fixtures.gd`, `swim_rules.gd`, `forest_rules.gd`, `tunnel_stores.gd`, `demo_kitchen.gd`, `farm_storage.gd`.
Each has Uses, Requires, Alternatives and Available here, and links; a crop reads the pantry live ("In the pantry now:
5.1 U"). Tests check every crop and dish against its table, every link resolves, and no entry names what the demo
lacks (mead, hunting, mills, boats, feasts, the Charter). "Not yet learned" and spoiler controls (UX-018's longer list)
are not built: everything here is playable now.

## Practice stories (UX-019): kept apart by construction

Three stories (`practice_stories.gd`), each a situation, three choices, what happened, a debrief comparing all three
and its lesson, and Restart:

- **A loaded crew at the stream** -- 24 U of logs across the stream, a crew of three carrying 6 U a trip: swim them over
  (refused: a loaded resident never swims), carry them round by the ford (the authored map's ford, wading at 55 %,
  carrying at 65 %), or build a plank footbridge at the neck first (the bridges' own survey, cost and stage work at the
  bridgewright's level). Fixture values: walking 1.0 m/s, 10 U of planks in store.
- **A delivery with nowhere to go** -- a fresh farm's carrot bed ripened on its own calendar, a covered store full of
  oats: leave it standing (the real ripe-expiry rule: 5.1 U falls to 4.5 U in three days), cook 10 U of oats into
  porridge to make room, or rack a 30 U root cellar; the harvest goes in by a real reservation and delivery.
- **A winter pantry** -- a household of four, 150 U of roots and 100 U of oats laid in on Autumn 1, 24 days to spring:
  all in the covered store (17 of 24 days fed, 90 U spoiled), a root cellar (24 of 24, none spoiled) or half and half
  (23 of 24, 15 U spoiled), by the pantry's hourly ageing at each season's factor and the dishes' inputs, the lot that
  would spoil soonest eaten first.

**Why pure models, not a second village.** A practice story needs to "reset to a known state" with "nothing touching
the main village". The village is one scene over shared autoloads (GameManager, UIManager) and module statics; a second
instance, a reload or a detached copy would share or destroy the main village's state, and a second process would double
a 6 GB texture footprint. So each story builds its fixture from the same model scripts the village runs -- a fresh pantry
and stores, a fresh farm with its own calendar, a fresh bridge surveyor -- and is handed nothing of the village except,
optionally, the **water map** (the stream's finalised shape, which nothing writes and the survey only reads; building it
costs over a second). Restart rebuilds from nothing; the same choice tells the same story word for word. While a story
is open the window holds the MENU pause, so the village waits. Tests run every story and choice with restarts and
compare the village's stores, calendar, notices, pantry and farm before and after; the live harness does the same on the
real scene. Launched from the window's Practice tab, the game menu's guide row, or the Demo Lab ("Practice stories").

## Player-named projects (UX-020)

Up to three, pinned for the session (no save; the demo cannot save): a name (1-32 characters), the places selected when
pinned (the selected bed, the selected tunnel, then selected residents -- three at most; each with Go to), and one
measure with a target, stepped with − / +: wood, planks or stone in store, ready food (days), harvested into store from
now, suppers eaten from now, bridges open, tunnel stretches open. Measures read the village's own figures; "from now"
measures count from the pin. Reached, a project is done once, ticked, and its **chronicle entry** goes into the village
news history under the Village source with its before and after and a Go to its first place:
`Project complete: "Wood for winter" -- wood in store, 40.0 U -> 60.0 U (target 60.0 U).` A done project stays pinned
until removed. UX-020's "before/after image" is the before/after figures; an image is not built.

## For Brendan: the exact texts to review

From `godot/demo/guide/guide_text.gd`; `%s` / `%d` are filled from the village.

**Approved by Brendan, 2026-10-01, with one change: residents are "they", not "it"** -- applied below, in
`guide_text.gd`, the help topics and the field guide.

1. **Meet a villager** -- "Every resident has a trade, needs and work of their own. Selecting one shows what they are
   doing, what they can do and how well fed they are." Try: "Nobody is selected yet." / "Next: Click the resident under the brass
   marker, or open Residents (L) and click a row." (Nobody up: "Everyone is indoors or below ground just now." / "Open
   Residents (L) and click a row to select a resident.") Confirm: "%s is selected. The Demo party panel (left) shows
   what they are doing, their skills and what you can order them to do."
2. **Bring in a harvest** -- "Food only counts once it is in store. A ripe bed is cut, carried and shelved; nothing is
   credited from afar." Try lines: "The %s is ripe." / "Select a resident and right-click the bed, or click the bed and
   press Harvest."; "Under way: %s is harvesting the %s." / "Under way: %s is carrying %s of %s to store." / "It counts
   once it is shelved. Speed time up (2x, 4x) to see it sooner."; "No store has room for the harvest: the crop stands
   uncut." / "Open the Pantry (K): compost spoiled food, or rack a root cellar (Dig tool, C)."; "Nothing is ripe yet:
   the %s ripens in about %d h." / "Speed time up (2x, 4x), or plant an empty bed meanwhile."; "The %s has stopped
   growing: %s." / "Click the bed: its Needs line says what to do (Drain a waterlogged bed, Water a dry one)."; "No crop
   is growing in any bed." / "Click %s and press Plant…; radish ripens soonest."; "Every crop is withered or blighted."
   / "Click %s and press Clear, then plant it again." Confirm: "%s of %s came into store. The Pantry (K) shows every lot
   and when it spoils."
3. **Serve the first supper** -- "The cook makes supper from 15:00 and calls everyone at 17:00. It needs roots or grain,
   water in the butt and a little wood." Try: "Supper is on the table until 19:00: the residents are eating."; "Supper
   is planned: %s for the village. It is cooked from 15:00 and called at 17:00 (now %02d:00)." / "Watch it in the
   Pantry's Kitchen tab (K). Speed time up (2x, 4x) to reach the evening sooner."; "Can't now: %s." / "To fix: %s."
   (the kitchen's own words); "Supper, day %d: nobody ate. The next supper is tomorrow at 17:00." Confirm: "%s. The
   village ate what it grew." (e.g. "Supper, day 2 was eaten (Mouse keeper first). The village ate what it grew.").
4. **Ready the village for the frost** -- "A frost is coming. Choose one way to be ready -- a bridge over the stream, a
   dry tunnel route, or fields made safe." Try: "Frost comes on the night into %s (in about %d h)." / "Frost is due
   tonight, 02:00 to 05:59." / "No frost is forecast this year: any of the three still readies the village." and "Do
   any one of the three; each line says where it stands." The ways: **A bridge** -- "No bridge yet: the Water panel's
   site has the costs and Build." / "No bridge yet: a %s can be built at %s now." / "No bridge yet: %s" / "%s: being
   built, %d%%." / "%s is open: waiting for someone to walk across it." **A dry tunnel route** -- "No tunnel yet: press B
   with a mouse, mole or squirrel selected and drag at least 8 m." / "A tunnel is being dug: %d%%." / "%d tunnel(s)
   open: waiting for someone to walk through one." **Fields made safe** -- "No bed is readied yet: a bed with a crop can
   be raised or banked now (tunnel earth)." / "Cover is open now: click a bed with a crop and press Cover." / "The %s
   is wet: click it and press Drain." Confirms: "%s walked across the new bridge: the stream no longer splits the
   village." / "%s walked through the tunnel dry-shod: the village has a way that weather does not slow." / "The %s is
   ready for the frost (%s): its crop keeps its health."

**Completion** -- "The first village stands" / "You met a villager, brought in a harvest, fed the village its supper and
readied it for the frost. The village is yours now: carry on as you like. (The Hearth Charter, the village's long-term
goal, is beyond this demo.)" Chronicle: "The first village stands: a harvest brought in, a supper served, and the
village readied for the frost (with a bridge)."

## Rejected

- **Completing on orders or on time spent** (P7 forbids it, and a bridge order that never gets built would teach the
  wrong thing).
- **A forced tutorial blocking play**: REQ-SET-165 says "without blocking unrelated play"; nothing is locked by the
  guide, and every verb stays usable.
- **The card under the incident card**: stacked, the two covered the Map layer picker at 1280x720 (measured by the
  layout harness); one card at a time at the top centre, the critical first.
- **Practice stories in a second scene, a reloaded scene or a second process**: see "Why pure models".
- **Saving projects or guide progress**: the demo has no save (decision 0261's "The demo can't save yet").

## Verified

`test/test_demo_guide.gd` (26: each objective only on its real outcome, a real kitchen's supper over real brains, a
held or raw portion not a supper, meals seen past the log's 64 rows, dig crews and tunnel jobs not walkers, a partial
delivery counted as what fitted, pre-completion, no softlock, skip and reopen, the owner's pause and its one
chronicle, hiding the finished card), `test/test_demo_guide_pages.gd` (20: help search,
the menu's Help, the field guide against its tables, story isolation and restart, projects into the chronicle, typing
in a modal), `test/test_demo_guide_live.gd` (the real scene at 1280x720 and 1920x1080: objective 1 done by a real click
on the marked resident, Show me, Hide and the menu's Reopen granting nothing, help typed into, a field-guide entry, a
practice story leaving the village alone, a project typed and pinned, the card above the picker at 125 %, Enter in
a search never reaching the Dig tool, the Lab's Practice stories on top, the card's Help focusing the search), and the
layout harness's guide-card checks at every scale. Mutation testing: 38 mutants killed before the review; after it, 49
of 49 against the unit suites (the facts, steps, status, projects, search, stories, field guide, the owner's pause and
chronicle, the gate's typing and the pantry's counter) and 3 of 3 live-only ones against the live harness (the Lab, the
Help focus, Enter).

After the review fixes: `./tools/run_tests.sh` -- first run `7130 test(s), 563057 assertion(s), 1 failure(s)`, the one
the wall-clock `test_twenty_workers_at_four_x_cost_little_per_frame` (sound cost, p99 979 us under 500 us, load
average 22 on the machine); rerun `7130 test(s), 563061 assertion(s), 0 failure(s)`. Live, headless: guide 50/0 and
50/0, input 183/0 and 191/0, layout 153/0 and 226/0 (checks/failures at 1280x720 and 1920x1080).

## Review (2026-10-01)

Two independent `code-reviewer` runs over `git diff c228d90..HEAD`. Every CRITICAL and HIGH finding is fixed with a
test; so are the cheap MEDIUM and LOW ones.

| Severity | Finding | Fix | Test |
|---|---|---|---|
| HIGH | Enter typed in a modal's text field passed the gate and the Dig tool's `_input` dug the piece laid behind the modal | the gate swallows Enter (and keypad Enter) in a text field | gate unit test; live: Dig tool open, guide open, Enter in the search, the tool's notice untouched |
| HIGH | The guide read the kitchen's meal log by position; the log keeps its latest 64 rows, so after 32 days no meal was seen again (objective 3 and "Suppers eaten" projects stuck) | suppers eaten read from each resident's own record; missed suppers from the log by meal key | 40 days of tallies through the kitchen's own `_record_meal` |
| HIGH | The tunnel way counted dig-crew members: a crew member is ORDER_TASK, which `activity()` reports before DIG, so "not while digging" never fired for them | `working_below`: the digger (State.DIG, ORDER_DIG), a dig crew's task, a tunnel job's task; a farm or woods task walked through a tunnel still counts | crew and tunnel-job cases |
| HIGH | The Demo Lab's Practice stories opened the guide underneath the still-open Lab (same layer; the Lab later in the tree) | the trigger closes the Lab first | live |
| CRITICAL (rubric) | per-frame allocations: the selection array every frame until someone was selected; an `Array[bool]` per bed per frame; the Projects tab refreshed every render frame | `first_selected()` (no array); an if-chain; the Projects tab refreshed at the guide's 0.25 s cadence | (behaviour unchanged; covered by the existing tests) |
| MEDIUM | the tally counted a held portion as eaten | see objective 3 (the resident's own record) | held / raw / breakfast cases |
| MEDIUM | the finished card could not be hidden | toggling follows `hidden` alone | unit |
| MEDIUM | "× Close (O)" typed an "o" on the tabs with a field | the × says Esc | -- |
| MEDIUM | the card's Help opened the guide with focus on a tab, not the search | focus goes to the tab's first control after the window shows | live |
| MEDIUM | each 0.25 s redraw re-set every label's colour override | set only when it differs; the marker re-aimed only when its target changes | -- |
| LOW | the window hid itself even if the clock refused to release its pause; the menu row opened the window without checking the menu closed | the window stays open on a refusal, as the menu does; the row and Help links open only after the menu closed | -- |
| LOW | the isolation test never handed the stories the one shared object | the test hands them the water map and checks it unchanged | unit |
| LOW | a constant live check; `_button_of` fell back to the first entry; deferred focus captured a node that a test could free | real check; null and skipped; the focus target held weakly | -- |

Not changed: the completion chronicle has no protection from the news feed's 128-entry overflow (it is a note, and it
is also the card's last state); "Supper is planned" always names soup, though the kitchen may cook porridge when roots
are short (LOW); a practice story's first click costs about 83 ms while the window holds the pause.

## Open

- The practice stories' fixture conditions are as described above; only the objective texts were reviewed.
- P7's evaluation data (task success, time spent searching, mistaken clicks) is not recorded; P7 says thresholds should
  follow baseline sessions.
- UX-017's "a mild setback shows two remedies" is met only as the blocked lines and the three ways; no setback is staged.
- UX-018's "not-yet-learned" entries and spoiler controls, and UX-020's before/after image, are not built.

## At the batch 5 integration (2026-10-01)

- **Help carries S's controls** (0471: Space as the one Resume, G for Run until, F6 for the object list) and O's planner
  on T (0492), with "B" alone for the Dig tool. New topics cover the object list, the presets, planning the season and
  going fishing.
- **The window's pause goes through S's ledger** (`hold_pause` -> `hold_guide`), not straight to the clock.
- **One card at the top centre**: the incident card, then this guide card, then T's offer card (0491), which waits
  behind it. Both the guide card and the offer card also stand aside while the Residents list (L) is open: at
  1280x720 the guide card covered the list's rows, which the people harness caught. The pause card steps below the
  guide card.
- **Water part B** (0431–0436): the field guide gains the fish stew, the six fish, dried fish, flour, fishing gear,
  fishing and the boats, and the drying rack and mill (53 entries). Only a CROP shelved counts as the "harvest came
  into store" a guide objective confirms; a catch, dried fish or flour never does.
