# 0451 — The seasonal planner: one table of the beds, a calendar that says how it knows, three soil plans and a record of what happened
Date: 2026-10-01 · Status: Accepted

Review group O: finding F45, UX-008 (compare the beds), the presentation half of ECO-005 (soil recovery), P1's
"Seasonal forecast" row and P4's "Farm overview work detail" (`/Users/brendan/Developer/redwall-review/REVIEW.md`
601–607, 806, 904–923; the review digest's UX-008 and ECO-005 entries). **Numbered 0451**: no record numbered 0422 or
above existed on any branch or worktree, and the brief reserved 0451–0459 for this group.

Branch `feat/review-o-planner`, from `feat/demo-day-length` c228d90 (master with every review group A–N, Q and R, the
tunnel revamp, the meals and the ten-minute day of decision 0421).

## The problem

F45: a bed tells the player many facts, but the village cannot answer "what threatens tonight's meal or next season?"
-- a player inspecting six beds and several job queues aggregates urgency, labour and supply in their head. P4 asks for
an exception-first overview and a seasonal calendar, derived from real state, keeping "uncertain estimates distinct
from guaranteed events", with "an accessible table alongside timeline", and a date that agrees with the HUD. UX-008
asks for a sortable "Compare similar" table with a map highlight. ECO-005 asks for compost, legume or fallow as a
comparable one-season plan "with the expected next harvest and staff-days", using the existing GDD:469 rules, and P4's
work package 4 for "a compact after-action record based on committed outcomes".

## Decision

### 1. One planner screen, opened by T and the Farm panel

`demo/farm/farm_planner.gd`: a modal of the input gate (decision 0261) in the HUD's modal rectangle, as the Work screen
and the Pantry are -- T, Esc and its "×" close it, Tab stays inside it, focus goes back where it was -- at the
interface scale (`DemoUiScale`, decision 0391), laid out for 1280x720. Four tabs: **Farm overview**, **Season
calendar**, **Soil plans**, **Record**. The bed panel's head carries **Planner (T)** (the "Farm tab" opener).

**The key is T** -- since the batch 5 integration, decision 0492. As this branch shipped it, the key was G, for this
reason, kept for the record: UI §5 binds the seasonal calendar to T (`open_calendar`), but in the demo T was the Dig tool's alias for
B (`tunnel_control.gd`, tested in `test_demo_tunnel.gd`). G is free in the input map and in every demo handler (checked:
the input map's 80 actions; the demo's hard-coded keys B, T, H, C, L, U, V, K, R, F7, F8, F11; J is the Work screen's,
decision 0411; Ctrl+G and other modified G are left alone). Reclaiming T for the calendar would move the Dig tool's key;
that is a separate decision. The HUD's date trigger (UI-SET-101) still opens the shell's own calendar panel; routing it
to the planner is left open (below).

### 2. The farm overview: seven cells, exceptions first, never the bed panel's detail

`farm_plan_rows.gd`, one row a bed: **Bed, Crop, Stage** (with the verb when it needs attention: "Needs: Drain"),
**Harvest: when · how much**, **Soil moisture** in the bed panel's own words and rounding ("Good · 66%", decision
0251), **Work** (each job on the bed and who has it, or queued, paused, blocked), **Next sowing**. Filters **All**,
**Needs attention** (a warning Needs line -- clear, a harvest past its grace, drain, water, cover -- a harvest waiting
for store room, or a job nobody can reach) and **Harvest soon** (ripe, or ripening within 24 game hours at this hour's
rate; a demo presentation value). The counts sit on the filter buttons; an empty filter says so. A row is one whole
button: a click (or Enter on it) closes the planner, opens that bed's panel and eases the camera over it -- the village
news' own "Go to" (`demo_news_jump.gd`). Attention rows are clay AND carry the word.

**Forecast semantics.** A growing crop's date is the bed panel's own figure, `farm_sim.gd hours_to_ripe_into` at THIS
hour's growth rate, dated on the one calendar at the crossing that completes it, and written "≈ Spring 9, 14:00 · about
5.1 U": the test runs the farm forward and the carrots ripen at exactly that tick. It is not a weather projection: a
frost night, rain or a change of season moves it, and the footnote says so. The amount is the bed panel's expected
harvest (today's health and fertility); for a ripe crop it is what a harvest brings now, and the dates are REQ-SET-075's
rules (full yield until 48 hours after the tick it ripened, withers at 120), said without "≈". An empty bed with a crop
chosen shows "If sown now", at today's rate, with the crop picker's own estimate.

### 3. Compare similar lives in the bed's inspector, with the map

UX-008 puts the table "in each repeatable inspector", so it is the bed panel's **Compare…** (`farm_compare_view.gd`): in
place of the readout and the verbs, as the crop picker is, its title in the head and Back in the foot. Every bed -- the
six are one kind of thing -- one row each ("2. Bed 3 · Carrot (this bed)" over "Ripe · 5.1 U · Good · 66% · fertility
70%"), sortable by **Harvest, Ready, Moisture** (furthest from its range first), **Fertility** (most worn first) and
**Bed**. The order is set when a sort is pressed (or the view opens) and **held** while it shows: figures change in
place, nothing moves under the pointer or the keyboard (the review's formatting rule). A row opens that bed and the
view stays. **The map highlight**: while it shows, every bed wears a cream ring just outside the selection's brass one
and its rank under its label ("#2 by harvest", `farm_view.gd set_compare`); Back clears both.

**No bulk action.** The brief asked for a preview of a bulk action "if it already exists for beds". None does: every
farm verb is ordered bed by bed (or by right-click). None is invented here.

### 4. The season calendar says how it knows each thing

`farm_season.gd` builds the season's entries; `farm_timeline.gd` draws them as lanes (the four crop rows, weather,
frost, blight, beds, meals) across twelve days with today's line; the **Table** view lists the same entries in words
(When, What, Kind, Detail) -- the accessible alternative, and the timeline's accessible description points to it. Every
entry is one of four kinds, each with its own shape, never colour alone:

| Kind | Shape | What |
|---|---|---|
| Scheduled | solid bar (upper half) | §5.6 planting windows; §5.10's season baseline; the demo's frost nights and blight outbreaks (farm_weather.gd's fixed schedule, already published in the demo README); §5.10's season event **once announced**; a ripe crop's grace end and withering; the kitchen's planned meals |
| Recorded | small square | each past day's weather as the farm's real row had it (the record) |
| Now | ringed diamond | today's weather |
| Estimate | outlined bar (lower half) | when a crop sown in its window would ripen at a full growth rate; each growing bed's ripening; until when the food in store makes meals |

**Never a future the game has not disclosed.** §5.10's event is drawn only after REQ-SET-142's disclosure, three days
before it starts; before then, and for next season, the notes say what is not known. The frost nights are the demo's
fixed schedule; showing them ahead does not change when the farm warns of one (noon the day before). The food line is
the HUD's Ready food (`kitchen.gd days_of_meals_milli`, decision 0381) from today -- consumption is now connected, so
this is not a fabricated runway. **The date is the HUD's**: the planner reads `demo_services.gd`'s one calendar; the
test drives the HUD's date trigger and the planner together through half a game day at 1x (five real minutes under
decision 0421) and a midnight.

### 5. Soil plans: GDD:469's rules, presentation only

`farm_soil_plans.gd`, for one bed over one season (12 days) from the day it is next empty -- today, or the standing
crop's harvest (its fertility cost taken and its family banked, as `farming.gd _record_rotation` does):

- **Compost, then sow**: +1500 fertility, capped, 2 U from the compost store, once a tile a season (refused when used),
  then the next crop at its first window day.
- **A legume in rotation**: peas (or the bed's legume) at their first window; the harvest gives back 800 fertility (the
  LEGUME row's −800 cost) and the 12 days after it gain +100 a day; sand refuses it.
- **Rest it fallow**: +50 a day (REQ-SET-078; +100 for 12 days after a legume), no harvest, no work.

Each says what it sows and when, this season's harvest, the fertility at the season's end (and the change), what the
bed's next crop would then yield, the staff time, and what stands in its way. Every number is `farming.gd`'s constants
and static rules, or the crop picker's own estimate (REQ-SET-074 at full health and neutral pollination); the tests
check them against the farm run for real (twelve days of rest, a real pea crop harvested, a real compost). **The next
crop compared** is the bed's chosen crop, else the standing one, else the first its soil takes. **The assumption** --
a crop ripens at a full growth rate in a plan -- is printed with the plans. **Staff time** is the demo's own work for
each job the plan orders (`farm_jobs.gd plan_work_usec`, the action cards' "Work"), and **staff-days** are game hours of
that work over GDD §5.3's default working day of 10 hours (07:00–12:00, 13:00–18:00): compost 0.05, sow and harvest
0.07. The plans change nothing; the bed's own Compost, Plant… and Rest act.

### 6. The after-action record: committed outcomes only, into the village news

`farm_record.gd` closes each calendar day (the kitchen's day: hour index / 24) from **ledgers that only a committed
change moves**:

- **The pantry's ledger (new)**: per item, cumulative milli-U stored (a delivery credited: `_lot_into`, the one place a
  lot grows), withdrawn (`withdraw_into`: the kitchen's batches and raw meals) and spoiled (`_spoil`); never reset,
  composting does not touch it. For every item, stock = stored − withdrawn − spoiled (tested).
- **The kitchen's counters**: cooked food, raw food, portions eaten, portions spoiled, a cancelled batch's spoiled food,
  and its meal log for who ate and who went without.
- **The farm's events**: a crop that withered is a crop lost, named by bed.

A day is read as the ledgers' movement between its open and its close. **Its weather** is read from the farm's real row
at each of its own farm hours (a short ring keyed by day); a day the calendar only jumped across is closed with its
weather marked not seen, and the calendar draws no Recorded square for it -- never a later day's row. **It waits for the
kitchen**: a calendar jump (the Lab's "Next weather") reaches the farm's hour before the kitchen's next frame, so a day
closes only once the kitchen has run past its midnight (`kitchen.gd hour_index`), so every meal of it is tallied; a
kitchen with nobody to feed holds nothing. The farm posts each
closed day to the village news -- the history of decision 0331, place Farm, a note with a short line for the strip
("Spring 3's record: +5.1 U harvested · 16 portions eaten · 1 went without") -- and at a season's last day the
season's totals. The Record tab shows yesterday, this season's days as a table and the season's (and the last
season's) totals. The last 48 days are kept.

## Consequences

- **Shared files touched**: `demo/farm/farm_pantry.gd` (the ledger: three columns, three increments, three readers),
  `demo/farm/demo_farm.gd` (building the planner and record, T, the record's hourly close and posts),
  `demo/farm/farm_bed_panel.gd` (Planner (T), Compare…, the compare view in place of the readout),
  `demo/farm/farm_view.gd` and `demo/farm/farm_bed_visual.gd` (the compare marks and ring), `demo/farm/farm_text.gd`
  (a public `degrees_text`), `demo/demo_village.gd` (the kitchen and the camera jump handed to the farm, the planner
  watched as a modal with T its close key).
- The bed panel's verb grid has a fourth row (Compare… after Cancel jobs).
- One farm note a day enters the 128-entry feed.
- Planner refreshes only while open, 4 times a second; the calendar and the plans rebuild only when the farm, the hour,
  the record or the kitchen changed (their inputs compared whole, not hashed); the pooled tables write a cell's text,
  a row's colour and its accessible description only when they change.
- The bed panel's Compare view closes, and the map's rings and ranks with it, when the panel is hidden or no bed is
  open. T opens and closes the planner on the same (logical) key the gate reads.

## Left open

- ~~UI §5's T for the calendar (the demo's Dig alias)~~ -- settled by decision 0492: the planner is T. Routing the HUD's
  date trigger to the planner is still a HUD decision for later.
- A weather-aware forecast (projecting growth through announced events and frost nights) would disagree with the bed
  panel's own "ripe in about N h"; both would have to move together.
- Bulk bed orders and their preview (P4's "batch identical orders") remain unbuilt.
- A kitchen correction made after a day has closed (`kitchen.gd _served_but_missed` adjusting a meal's tally) does not
  reach that day's record.
- The ripe crop's wording "full yield for 48 hours, then −10% a day" is the bed panel's (`farm_text.gd`); `farming.gd`
  applies the first daily loss at 72 hours. The planner repeats the panel's words; the gap is the panel's to close.
- The soil plans compare what each plan yields next: for compost that is this season's crop, for the legume and fallow
  plans the crop sown after the season. The lines say which; they are not one like-for-like figure.

## Verification

`test/test_demo_planner.gd` (29 tests: the ledger, the record against the kitchen's real day and every kitchen counter,
the overview's forecast
against the farm run forward, the filters, the calendar against the HUD's date and the disclosure rule, the soil plans
against the farm's rules run for real, compare and its marks, the planner's keys and tabs) and
`test/test_demo_planner_live.gd`, which runs `test/live/demo_planner_live.gd` on the real scene with real input at
1280x720 and 1920x1080 (G, Tab, a filter and a row clicked, the camera eased, the calendar's timeline and table, Enter on
a tab, the plans, a day's record, G and Esc, Compare… clicked and Back, 125 %). 45 hand-written mutants of the new logic,
all killed (the independent review's surviving mutants among them).

The independent code review found two HIGH issues, both fixed before the commit. First, a multi-midnight calendar jump
closed a day without its supper and stamped it with a later day's weather. Second, several of the record's figures had
no effective test. It also found MEDIUM issues, all fixed: a pooled table re-themed every cell four times a second,
Compare's marks stayed on the map with the panel hidden, G opened on the physical key but closed on the logical one, and
the pea was a hard-coded index. Of its LOW findings, the cache keys and the double-counted cancelled batch are fixed;
the rest are recorded under Left open.

## Source

REVIEW.md F45 (601–607), P1's "Seasonal forecast" row (806), P4 (904–923) with its farm overview work detail; the review
digest's UX-008 and ECO-005; GDD §5.6 (around GDD:469: the crop table, compost, fallow, rotation, REQ-SET-071–078),
§5.3's default schedule, §5.10 (REQ-SET-142); UI §5 (`open_calendar`); decisions 0205, 0222, 0251, 0261, 0292, 0331,
0332, 0381, 0391, 0411, 0421.
