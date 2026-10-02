# 0622 — Herbalist and infirmary in the live demo: injuries, bed rest, treatment, the sickbay and herbs
Date: 2026-10-01 · Status: Accepted (demo feature #26, approved by Brendan 2026-10-01; proposals P1–P8 await his ruling)

## Decision
The live demo gains a non-fatal injury-and-care loop built on the adopted rules found in decision 0621
(`godot/demo/infirmary/`): hurt residents rest in a bed (or at a field-care spot), the best healer treats them with
herb and cloth at the GDD's HEAL rates, they recover at REQ-SET-017's rates (doubled in a sickbay), the herbalist
gathers herbs from a §5.5 herb patch, and a burrow home can be made the sickbay. Health and the Injury row are the
REAL core stores (`scripts/core/needs.gd`, `injury.gd`), run privately for the demo cast; the settlement simulation
is not written. No combat, no death, no illness.

## What is the GDD's (implemented as written)
- **Injury row and merge** (GDD §4.2, HAZ-004): one aggregate injury a resident, the worse severity replacing, equal
  severity keeping the lower kind, incident ordinals deduplicated — `injury.gd` itself.
- **One health rate** (GDD §5.2, HAZ-002): untreated −1/h (severity 1) and −4/h (severity 2, which also bars
  recovery), recovery +2/h (+4/h in an infirmary) when hunger and rest are ≥4000, starvation −4/h, airless −125/h,
  integrated per tick with remainders — `needs.gd` itself. The demo's hunger (kitchen) and rest (swim stamina) are
  mirrored into it before every integrated tick; cold stays NEUTRAL (the winter owner's).
- **Sources** (decision 0621): HAZ-003 exhaustion in the water (EXHAUSTION, severity 1, no loss; re-armed at rest
  4000), HAZ-002 airless below (EXPOSURE, severity 2, no loss, −125/h while airless), REQ-SET-068's forage roll on the
  core RNG's FORAGE stream (one draw per completed 60 WU; danger 1; CUT, severity 1, −10). The Demo Lab's two test
  injuries use §5.4's hazard results (net: −20, severity 1 BITE; boat/ice: −35, severity 2 EXPOSURE).
- **Treatment** (REQ-SET-173, balance HEAL row): herb 1000 + cloth 500 milli-U paid once per injury at work start
  (§5.3: inputs at WORK start), 60000 milli-WU of HEAL at §5.2's 80 milli-WU × factor/1000 a tick with the remainder
  kept, the factor §5.3's `1000 + 50 × level` times the resident's work pace, clamped 300–1800; the work is the
  patient's (HAZ-004: a helper change keeps WIP); 10 XP a WU; +10 health and the injury cleared.
- **Health factor** (§5.2): 600 below 40, 850 below 70, 1000 from 70 — the infirmary's work-pace factor.
- **Infirmary room** (§5.9): ≥1 bed, ≥1 shelf, heated — mapped onto a burrow home (P5); its rate +4/h (REQ-SET-017);
  an invalid sickbay suspends its service without losing its beds (REQ-SET-129).
- **Herb patch** (§5.5, §5.1): capacity 160 U, start 0.8 K = 128 U, the ruled regrowth
  `min(K−P, floor((K−P)·80·S/10⁶)+1000)` each midnight by season, sustainable floor 20% K, work per U
  `ceil(8·10⁶/((1000+40L)(1000+100d)))` (8 WU at level 0, danger 1); starting shelf stocks herb 12 U, cloth 24 U.

## PROPOSALS — demo choices where the documents are silent (each a question for Brendan)
- **P1 — the health floor.** Health never falls below 16: an incident's loss is capped there, and a tick that brings
  health under it is answered by restoring the difference. *Options:* (a) floor 16: never incapacitated, never dead
  (**recommended** for the demo: no carried rescue is built, and the brief forbids death); (b) floor 1: incapacitation
  and REQ-SET-171's carried rescue to a bed (needs the rescue carry built); (c) the GDD as written, death at 0
  (forbidden by the brief).
- **P2 — where a hurt resident goes.** It stops work and rests: a free sickbay bed of its size, else its own bed, else
  lying on the ground at a field-care spot before the hall's steps (REQ-SET-173's "field landing point or a bed").
  *Options:* (a) rest in bed until treated (**recommended**: it makes the loop visible and keeps the untreated off
  hazardous work, REQ-SET-172); (b) keep working (non-hazardous) and be treated where it stands.
- **P3 — the herbalist.** The squirrel gatherer (Linnet Whinberry) starts at HEAL 2 (the GDD's starting level for active
  skills); everyone else 0; anybeast learns by treating; the healer chosen is the highest HEAL level, then the nearest.
  *Options:* (a) this (**recommended**); (b) everyone at HEAL 2 as the GDD's 12-resident start has.
- **P4 — when a patient is up.** After treatment it rests on until health 70 (the full work band), recovering at +2/h,
  or +4/h in a sickbay bed. It is never kept in bed for good (review H2/H3): hurt, it gets up while it needs a meal
  (hunger ≤3500, REQ-SET-012: the kitchen takes nobody from bed rest) and, with a minor injury, while the shelf cannot
  pay for its treatment (REQ-SET-172 allows non-hazardous work); treated, it also gets up while it cannot recover
  (hunger or rest under 4000). A serious injury rests until treated. *Options:* (a) 70 (**recommended**); (b) up at
  once when treated; (c) up at 100.
- **P5 — the sickbay.** The infirmary is a burrow home the player designates from the Tunnels panel's room box, valid
  with a bed, a hearth (heated) and hanging stores (its shelf); its beds are kept from the night's allocation. The
  GDD's 8×8 Infirmary building (M1) is not built: the demo builds no surface buildings. The ≥3 tiles a bed rule is not
  checked (the demo's homes already ignore it for dormitories). *Options:* (a) a designated home (**recommended**);
  (b) a new room template; (c) the surface building, with new art.
- **P6 — herb gathering.** One herb patch by the south road (natural danger 1); the idle herbalist gathers a 4 U trip
  by day while the shelf holds under 12 U (the GDD's starting stock as the target) and carries it to the shelf at the
  hall's steps, where the patch is debited. No FORAGE skill is tracked (level 0). *Options:* (a) automatic restock
  (**recommended**); (b) a "Gather herbs" order only.
- **P7 — the forage injury's kind.** REQ-SET-068 names no kind; the demo uses CUT.
- **P8 — cloth.** The shelf's 24 U of cloth (48 treatments) is not replenished: the demo has no flax→cloth chain.
  Once it is gone no injury can be treated: minor ones carry on at work (−1/h until the floor), serious ones rest at the
  floor for good. *Recommendation:* leave until a crafting feature lands; if a long demo session should not run dry,
  restock cloth with herbs (a demo value) instead.

## Not done, and why
- **The fishing hazard roll** (§5.4/REQ-SET-053) is adopted but needs a hook inside the fishery owner's cycle
  completion (`demo/fishery/fishery.gd` `_fishing_done`, `_boat_catch`); decision 0431 left it unrolled. The care
  desk's `hurt(i, kind, severity, loss, source)` is the call it would make (§5.4: −20 severity 1 BITE; boat/ice −35
  severity 2 EXPOSURE). Left for the fishery owner.
- **Mood memory** `untreated_injury` (−800): the demo has no mood.
- **Illness:** no adopted model (CHILL is draft).
- **The work pace's readers:** only HEAL work reads it. The other job owners' credit sites (farm `farm_crew.gd`, woods,
  tunnels `tunnel_crew.gd credit_ticks`, fishery `_credit_work`, bridges `bridge_crew.gd`, the fit-out) can multiply by
  `services.work_pace.permille(who)` (or `scale`); with no factor below 1000 that is the identity. Since P2/P4 keep a
  patient in bed until 70, the health factor bites only for a starving resident.

## Engineering notes
- **A jump.** The Lab's *Next weather* runs the calendar up to 48 hours in one frame. Integrating every tick of that
  while someone mends (~130 µs a moving tick under load) stalled the clock into its CRITICAL pause and broke the input
  harness at 1080p. So quiet ticks are skipped whole, and of a moving span all but the last 30 ticks are taken in closed
  form: the frame's hunger and rest are one figure, so each resident's health rate is constant across it and its health
  moves by that rate in whole points (the fraction dropped), clamped to the floor and 100 (`care_state.gd` A JUMP).
  Nothing is owed to a later frame, so an event never lands on old time. The span does not advance the injury row's
  untreated-hours counter (a readout; the core store has no bulk setter).
- **Supplies are reserved by the healers sent** (review H1): a healer is sent only while the shelf covers every healer
  already on the way, and a healer beside a patient whose shelf has since run short is sent back to its work — so the
  herbalist cannot be stuck waiting to pay, and it can gather again.
- **A healer is chosen only if it can reach the patient's bed** (the night's own reach test).
- **Allocation.** The core stores return an `OpResult` from every call (`needs.tick_all`, `injury.tick_all`,
  `apply_need_event`): a moving tick allocates a few short-lived objects, freed at once (the suite checks no object is
  retained). Quiet ticks allocate nothing; the care progress and the herb work per U are cached.
- **Mutation testing:** 68 mutants over the rules, state, desk, tasks and work pace (after the review's fixes); 65
  killed. The three survivors are equivalent here: the desk's `not resting(i)` before sending a patient to rest (a
  resting patient's BedRest is urgent, so `may_take` already refuses it), its `not night` before the gatherer's
  dispatch (the night routine sets the brain's `resting` all night, which that dispatch already refuses), and the
  healer's `reaches` (every test village's home is reachable by every body; the live village's homes are dug by the
  cast's own diggers through bores the cast fits).
- **Review** (independent code-reviewer): no CRITICAL beyond the core API's per-call result objects (above); HIGHs H1
  (supplies), H2 (an unfed patient stuck in bed), H3 (an untreatable injury meaning bed rest for good) fixed; MEDIUMs
  fixed: events on old time after a jump, the healer's reach, the gatherer's retry every frame, the Tunnels panel
  re-placed when the section changes, a patient's bed given to a sleeper when the sickbay changes, and the tests'
  gaps. Left as follow-ups: the water owner's rescue and swim admission do not yet consult health (HAZ-001's ≥70 and
  REQ-SET-172 — a patient at its field-care spot can still be drafted as a rescuer); a few LOWs (duplicated health
  factor and button code, the field-care spots' spacing).

## Consequences — the shared hooks (narrow and additive)
- `demo/demo_services.gd`: `work_pace` (`demo/work/work_pace.gd`), the one composable per-resident work factor
  registry: `add_factor(name, (who) -> permille)`, `permille(who)` the product. The winter owner's Chilled factor adds
  itself here; nothing else changes.
- `demo/burrow/night_routine.gd`: KEPT BEDS — `set_bed_filter(keep)` drops kept beds from the allocation, `bed_task_at(i,
  bed, task)` (the old private `_bed_task` now calls it), and a home whose beds are all kept says "the sick only".
- `demo/tunnel/tunnel_panel.gd`: `add_room_section(control)` appends another owner's section to the room box.
- `demo/demo_village.gd`: `_build_care()` after the fishery, the two Lab triggers, `care()`.
- `demo/ui/demo_menu.gd`: the Lab's description names the test injury.
- `test/live/demo_input_live.gd`: the Lab's expected trigger list gains Injury and Serious injury.
- No key is bound. The resident card's lines come through `demo_command.gd add_skill_text` (no change there).

## Source
Decision 0621 (the findings); docs/game_gdd.md §4.2, §4.3, §5.1, §5.2, §5.3, §5.4, §5.5, §5.9, §7 REQ-SET-171..173;
docs/underground_economy_hazard_amendment.md HAZ-001..004; docs/gameplay_balance.md HEAL row; decisions 0036, 0109,
0196, 0210, 0231, 0431; Brendan's approval of feature #26 (2026-10-01).
