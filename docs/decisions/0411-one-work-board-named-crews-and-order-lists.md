# 0411 — One work board, named crews and order lists
Date: 2026-10-01 · Status: Accepted

Review group M of the live-demo review (`redwall-review/REVIEW.md`, written against 157a3a4): **F22** (automatic labor
split into hidden fixed crews), **F32** (no usable common work queue or job assignment interface), **F44**'s remainder
(one assignment grammar for the Work screen and group orders), **SOC-004** (crew commitments and capacity), **UX-001**
(commands at three management scales, mixed groups previewing eligibility), **UX-002** (an editable order sequence) and
**UX-007** (batch work policies: presets), with P2's acceptance; and the farm's and the woods' cases of **F05** that
decision 0361 left open. Built on `integrate/review-batch-3` 6515825 (A's explicit arrival and routing desk, 0361; H's
action cards and `work_interrupt`, 0332; I's incidents, 0331; B's conservation, 0222). Everything here is the demo's
presentation layer; nothing the simulation owns. MOVE-G01–G05 stay open.

Number: the next free above 0410 after checking every branch and worktree (the highest in use was 0391).

## Decision

### 1. The farm's and the woods' crews credit only an arrived worker (F05)

`farm_crew.gd` and `forest_crew.gd` no longer take holding near the spot for arrival. A walk advances only when the
brain's trip ARRIVED and it stands within ARRIVE_M of its spot (`arrived_near`; a carry down into a root cellar
arrives below at the cellar's middle, `_arrived` with the crew's own `_below` column); a walk given up there is a failed
try, the walk issued afresh. Every frame of work rechecks it: a worker no longer at its spot credits nothing and goes
back to its walk -- the farm keeping the work done (`rewind_to_walk`, GDD §5.3 "changing workers retains progress"),
the woods putting the tool away (its board clears a step's progress when it rewinds, as it always has when a worker is
called away).

### 2. One common owner: the work board

`demo/work/work_board.gd` owns no job. Each job owner keeps its own board; the work board reads it through one adapter
(`work_source.gd`: `farm_work`, `woods_work`, `bridge_work`, `tunnel_work`, `fit_out_work`, `spoil_work`), fills one
record a task for the screen (`work_task.gd`: target, action, worker, state, reason in the owner's own words, work left,
percent, Go to target) and carries each command to the owner's own function. So B's conservation holds by
construction: **a load in hand is never paused or reassigned** (refused in words: "X is carrying the load — it
finishes the delivery first"), **Cancel this task with a load in hand makes it its delivery** (0222), and a bridge's
builder let go puts its material back at its source.

What each source supports, and what it says when it does not:

| Source | Claimed by the board | Pause | Cancel this task | Reassign |
|---|---|---|---|---|
| Farm, woods | yes | yes (not with a load) | yes (a load becomes its delivery; a delivery goes on) | yes (not with a load) |
| Bridges | yes | yes | no: "a bridge's material is paid when it is planned" | yes (material back to its source) |
| Tunnel jobs | yes, a paused job no one means to come back to | yes: `tunnel_jobs.gd` THE PLAYER'S HOLD (its worker's task ends; nobody, not even that worker, takes it back until released) | only before its materials are paid | yes (progress and paid inputs kept; releases a hold) |
| Fit-out | no: keeps its own hand-out (KEPT places, anyone who can reach) | no: the room's palette | no: "take it out" gives its cost back | a waiting fixture |
| Spoil heaps | no: cleared by order only | no | no | no |

### 3. The claim -- GDD §5.3, and its demo simplifications

The farm's, the woods' and the bridgewright's routine hand-outs stand down (`set_claimer`; a suite's crew alone keeps
its old hand-out). Every **CLAIM_PERIOD_USEC = 0.5 s** of cast time (the crews' old pick-up interval) each resident is
reconsidered, the residents staggered evenly over the period. An IDLE resident -- `ORDER_NONE`, on the surface, not
resting (the night routine, 0210), not lying or indoors, not in the water, not held by the rescue, not crossing, not on a
queued walk, and not kept for its needs (`set_needs_gate`: N's meals plug in here) -- takes the best task it is
eligible for. **Safety and needs therefore always come first**: rescue, evacuation and the night take residents by
task or order, which makes them not idle.

- **Eligibility** is each source's (skills and physical fit, never a species lock -- LORE-P12): anybeast farms and
  works the woods; a bridge needs one on land; a tunnel job worked in the bore needs one who fits it, and widening or
  clearing a fall one who can dig (whose body fits a standard bore, 0208); one job a board a resident. The resident's
  crew priority for the task's activity must not be 0 (forbidden).
- **The candidate index** of waiting tasks is rebuilt once a period, never a scan of every board per frame; a resident
  looks at **at most 32** per pass, going on from its saved cursor (GDD: "evaluates at most 32 indexed candidate jobs
  per pass").
- **The sort** is the GDD's `(bucket, player_priority, job_priority, −skill, path cells, created, id)` with these
  **demo simplifications**: buckets 0–1 never reach the board (they are emergencies that take the resident off its
  work); the player's **URGENT** mark stands for bucket 2 (the GDD's bucket 2 is food/fuel below two days' reserve,
  which the demo does not forecast), everything else is bucket 3; player_priority is the resident's **crew**
  priority for the activity (the crews stand in for the job matrix); the skill term is left out (the demo's skills
  change only how long felling, sawing and bridging take); path cells are the straight-line distance in centimetres;
  created is the job's serial.
- **Fallback.** REQ-SET-028 lets HAUL, KEEP and low-risk FORAGE be taken at priority 4 when nothing permitted waits.
  The demo instead gives every activity a crew does not prefer priority 4 by default, so an idle resident takes any
  eligible work (the review's "nobody wanders while eligible work waits"); a 0 still forbids it.
- **A promised task is left to its resident**: a task on someone's order list -- queued by Shift+right-click, or kept
  from an interruption (farm, woods and tunnel entries now name their task: `unfinished_job.gd` `source`, `key`) -- is
  not claimed by anyone else. That is what makes "interrupt hauling with a rescue, resume exactly once" hold.
- **Reservations** stay the owners' (a harvest's store room, 0222); REQ-SET-032's lease renewal is not modelled.
- A claim issues the job's first walk at once (`claim` → the owner's `_step(row, 0)`), so the resident is under an
  order before anything else can hand it work; and an idle resident with entries on its own list takes those up
  before the board's best for it.
- A task's identity is its owner's serial: the farm's and the woods' job serials, a bridge's generation, and for tunnel
  jobs a new per-posting `serial` column in `tunnel_jobs.gd` (a resume keeps it; a cancel and a fresh post of the same
  kind is a new job -- the record's per-task priority, pause and promises never carry over to it).

### 4. Named, editable crews (F22, SOC-004)

`work_crews.gd`: **Field** (prefers Farm; then Hauling, Woods), **Woods** (Woods; Hauling, Building), **Diggers**
(Digging; Building, Hauling), **Haulers** (Hauling; Farm, Woods), **Builders** (Building; Hauling, Woods) -- priorities
1, 2, 3, anything else 4. One crew a resident, starting on its trade's (the fieldworker and gatherer Field, the forester
Woods, the mole and badger Diggers, the keeper and fisher Haulers, the bridgewright and boatwright Builders); the
player moves members between crews. A member is **available, occupied, resting or absent** (in the water or held).
**Presets (UX-007)** are whole tables: Normal; Harvest week (farm work and hauling at least HIGH for every crew);
Winter stores (woods and hauling at least HIGH; farm work LOW but for the Field crew). Each is previewed as the changes
it would make before it is applied; an edit afterwards reads CUSTOM. SOC-004's minimum staffing and safety policy per
crew, and saving crews, are not built (the demo saves nothing; P2 leaves a saved preset to Brendan).

### 5. The order list is the resume queue (UX-002)

No second queue: `resident_brain.gd`'s unfinished-job list (0205) is the order list. **Shift+right-click** appends to
its END (`append_queued`: taken after everything on it); a job kept from an interruption still goes to its FRONT,
taken next. So the list in take order reads Now → Next … → then its routine: at most **QUEUE_MAX = 8 queued orders**
(UI §3's eight manual tasks) and, apart from them, at most RESUME_MAX = 3 jobs kept from interruptions (the oldest of
those goes first) -- a full queue never pushes out an interrupted job's promise, nor an interruption the player's
queue. Entries can be removed and moved (`remove_queued`, `move_queued`); R still forgets them all (UI §3's "Cancel
preferred work"). Every entry is taken up by the one completion path (`take_up_unfinished`, A's `work_done`), and a
resident handed a task some other way -- a claim of a task it had queued, a Reassign -- forgets every entry naming it
(`forget_task`), so a stale one never pulls it back. **When the queue starts**: at once for a resident with nothing to
do, or working at a spot (a work-spot order has no end of its own); after a plain move, when the move arrives (the
board watches it as it watches a queued walk); after a job or a task, when that is done.
A queued board task is a `QueuedTask` (taken only while it is still the same task and waits), a queued walk a
`QueuedWalk` (ended by the board on arrival, or when given up) -- both holding the board by weak reference, since the
board holds every brain. A group's queued job goes to the **nearest** selected member (one worker a job, as a plain
order sends the nearest); a walk to every member. The party panel and the Residents roster now print the list as
"Next: back to Brace, tunnel 2 → Harvest, the carrot bed" (was "Then back to: ..."). A Shift order says what it did in
a typed answer (`queue_answer.gd`): queued (and for whom), taken up at once, or refused in words ("Can't queue: ...":
the list full -- checked before anything is put on a board --, the task under way already, or not takeable now).

### 6. The Work screen (F32) and the Jobs command

`work_screen.gd`, in the HUD's modal rectangle at the HUD's scale (DemoUiScale), a modal of the input gate (decision
0261: Esc, J and × close it; Tab and Enter work inside it; its scroll follows the keyboard focus): **Tasks**,
**Residents and crews**, **Projects** -- as described in the demo README's Work section. **Rows follow their task**:
the screen repaints its pooled rows four times a second and re-sorts them, so each task keeps the row that showed it
(by source, row and key) -- an open Reassign picker and the keyboard's focus stay with the task, and a row given
another task closes its picker. The HUD's Jobs command
(UI-SET-029) is **unlocked by the demo** for it, exactly as the farm unlocks Food for the Pantry (`farm_hud.gd
unlock_food_command`): enabled, the locked set's own painted `cmd_work` icon, its tooltip in the command strip's form,
and J -- which the shell presses on an enabled command -- opens it. `ui_availability.gd` is unchanged: the game's own
shell still claims UI-SET-029 PANEL_NOT_BUILT, which stays true of the game.

### 7. One assignment grammar (F44's remainder, UX-001)

An order left on the board says the board's rule on its card: "Queue for the Field crew: Mouse fieldworker or Squirrel
gatherer, then anyone free who can" (`work_board.gd queue_words`, through the crews' `set_claimer`). A card with two or
more selected previews each member (`action_card.gd each_member`: "Of 3 selected: X, Y can; Z can't (why)") -- the
farm's, the woods' and the tunnels' cards -- and the Work screen's Reassign picker shows every resident with the same
eligibility words, which are the command's own refusals: ONE set of words (`work_ids.gd`: has another farm / woods job,
builds another bridge, held by the rescue, in the water, does not fit this tunnel's bore, can't dig, is digging, is
below ground), with the selection previewed under the picker.

## Why

- The owners' boards differ for good reasons (a harvest reserves room, a felling turns hauler, a bridge has stages, a
  tunnel job is a task in a bore) and each carries its own conservation. One job table would have meant rewriting all
  of them; an adapter per owner gives one board, one claim and one screen while every outcome stays the owner's.
- Rejected: an instance-level availability claim on the game shell (`ui_availability.gd`). It would have made the
  game's own claim for UI-SET-029 runtime-dependent, which that file exists to prevent; the Food precedent unlocks the
  one button from the demo and leaves the game's claim true.
- Rejected: queuing a group's Shift order for every member. Only one can take a job; the others' entries would go
  stale and the promise would name the wrong resident.
- Rejected: letting a paused or reassigned job's load change hands. A released carrier's load still passes to the next
  claimant with the job (decision 0222's existing rule, which predates this record): that remote pick-up remains open
  (Consequences); the new commands do not add another.

## Measurements (local M5 Pro, uncontrolled; not qualification)

The real village (9 residents) with 30 tasks queued (10 farm, 20 woods; 222 rows over the six sources), 600 frames
each at 1x and 4x, headless, after the review's fixes: the claim's own scan -- rebuilding the candidate index and
choosing among candidates -- **3.3 µs a frame mean, 179 µs max (1x); 5.4 µs mean, 134 µs max (4x)**. One index rebuild
~48 µs (21 waiting tasks); one resident's candidate scan ~61 µs (both measured through `call()`, so upper bounds). The
whole board update **29 µs a frame mean (1x), 28 µs (4x)**; its worst frame (2.4–3.8 ms) is a claimed job's first walk
being planned at once by A's routing desk (budgeted, decision 0361), not the scan. Never a scan of every board per
frame: the index is rebuilt once a claim period (or right after a command), and each resident looks at most at 32
candidates in a pass.

## Verification

- Suites (no staged assets): `test_demo_work.gd` (27: the six queued farm, woods and bridge tasks claimed by the
  right crews with nobody selected; idle residents taking any eligible work; safety, rest and needs first; a rescue
  interrupting hauling and the haul resumed exactly once; Reassign, Pause and Cancel at every phase with no remote
  delivery or duplicate credit -- farm, woods, bridge; priority and urgency; crews and presets; the order list's add,
  remove and reorder; the same command schedule at 1x, 2x and 4x giving equal outcomes), `test_demo_work_arrival.gd`
  (7: F05 for the farm and the woods with a physical block, a worker displaced mid-work, a walk given up at its
  spot), `test_demo_work_screen.gd` (25: the screen's rows and commands, the views, Cancel all's scope, the tunnel,
  fit-out and spoil adapters, Shift's queue), `test_demo_work_edges.gd` (31: each claim rule, the review's findings).
  Updated: `test_demo_command.gd`, `test_demo_hud_truth.gd` (the "Next:" line).
- `./tools/run_tests.sh`: **"6939 test(s), 559361 assertion(s), 0 failure(s)"** (base 6515825: 6849 run before this
  work).
- Live harness (`test/live/demo_input_live.gd`, real Viewport input): the Jobs command enabled; J opens the Work
  screen as a modal with focus inside and its frame inside the window; Esc and J close it; a click on Jobs opens it;
  Tab stays inside, Enter presses a focused tab; a felling queued with nobody selected appears; Reassign… opens the
  picker and a click gives the felling to an eligible resident; Crew ▶ moves a resident and its row says so; a focused
  preset previews; Cancel all work… shows its scope and Keep working cancels nothing; Shift+right-click queues walks
  and the party panel lists them; at 1920x1080 under 125 % the screen scales and fits. **1280x720: LIVE-SUMMARY 158 0;
  1920x1080: LIVE-SUMMARY 165 0.** Frames: `scratchpad/rv_m_check/work_*_1280x720.png`, `work_*_1920x1080.png`,
  `work_scaled_1920x1080.png`.
- Mutation, one mutant at a time, the file restored and its SHA-256 checked each time: **143 mutants, 139 killed,
  4 retired, 0 surviving.** First round 115: 87 killed at once; 26 survivors each got a test that kills it (the
  claim issuing its walk, one job a board, the rescue's hold, eligibility, distance, a stale index entry, the farm's
  blocked words, the old crews standing down, a woods delivery, the cards' member lines, a reassigned bridge's
  builder, an entry naming only its task, Go to's tree, the tunnel entry's promise, the nearest member, blocked
  first); 2 retired with the redundant code they mutated (the farm's take-back pause check, covered by `_ready`; the
  bridge's eligibility words, rewritten). The review fixes' own round 28: 26 killed, 2 retired with the redundant
  forgets they mutated.
- Review: the independent `code-reviewer` agent. **HIGH, all fixed with tests**: H1 a Shift-queued task behind a
  plain move was promised to a resident that would only hold (the queue now starts when the move arrives, at once for
  a work-spot order, and an idle resident's own list comes before the board's claim); H2 Reassign could pull the old
  worker back onto the task from a stale entry and leave it holding (the new worker is assigned first, and a resident
  handed a task forgets every entry naming it); H3 a tunnel job the player paused was taken back by its old worker
  (THE PLAYER'S HOLD in `tunnel_jobs.gd`); H4 an open Reassign picker followed the list position, not its task (rows
  follow their task). **MEDIUM fixed**: tunnel task keys not unique per posting (the per-posting serial); "on it now"
  said when nobody took a queued task; success read from the words' "Can't" prefix (the typed `queue_answer.gd`); a
  full queue dropping an interrupted job's promise (queued orders and kept jobs capped apart); the cards' and the
  picker's words differing (one set, `work_ids.gd`). **LOW fixed**: typed brain arrays in the adapters, a job posted
  before the list's room was checked, walk labels to the tenth, the per-refresh relayout.
## Consequences

- A new job owner joins the board with an adapter (`work_source.gd`) and, to be claimed, a `claim` that issues its
  first walk, a `waiting` test, and order-list entries that name their task (`source`, `key`). Cooking (group N) joins
  this way; N's meals keep residents from work through `set_needs_gate`.
- **Open**: a released carrier's load passing to the next claimant from afar (0222's rule); SOC-004's minimum staffing
  and per-crew safety policy; saved crews and order lists; the GDD's skill term in the sort; a tunnel job cancelled
  after its materials are paid has no salvage model, so Cancel refuses it; the Work screen repaints its pooled rows four
  times a second while open.

## Source

REVIEW.md F05, F22 (233–239), F32 (449–459), F44 (593–599), P1's "Work / production" row (801), P2 (865–884); the review
digest's SOC-004, UX-001, UX-002, UX-007; GDD §5.3 (REQ-SET-026–034 and the eligibility order); UI §3 (`command_queue`,
`open_jobs`, the eight-task queue); decisions 0205, 0208, 0210, 0222, 0261, 0331, 0332, 0361.
