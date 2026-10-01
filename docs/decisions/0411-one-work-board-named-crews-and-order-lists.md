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
| Tunnel jobs | yes, a paused job no one means to come back to | yes (its worker's task ends) | only before its materials are paid | yes (progress and paid inputs kept) |
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
  order before anything else can hand it work.

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
taken next. So the list in take order reads Now → Next … → then its routine, at most **QUEUE_MAX = 8** entries (UI §3),
at most RESUME_MAX = 3 of them kept from interruptions (the oldest of those goes first; the player's queue is never
pushed out). Entries can be removed and moved (`remove_queued`, `move_queued`); R still forgets them all (UI §3's
"Cancel preferred work"). Every entry is taken up by the one completion path (`take_up_unfinished`, A's `work_done`).
A queued board task is a `QueuedTask` (taken only while it is still the same task and waits), a queued walk a
`QueuedWalk` (ended by the board on arrival, or when given up) -- both holding the board by weak reference, since the
board holds every brain. A group's queued job goes to the **nearest** selected member (one worker a job, as a plain
order sends the nearest); a walk to every member. The party panel and the Residents roster now print the list as
"Next: back to Brace, tunnel 2 → Harvest, the carrot bed" (was "Then back to: ...").

### 6. The Work screen (F32) and the Jobs command

`work_screen.gd`, in the HUD's modal rectangle at the HUD's scale (DemoUiScale), a modal of the input gate (decision
0261: Esc, J and × close it; Tab and Enter work inside it; its scroll follows the keyboard focus): **Tasks**,
**Residents and crews**, **Projects** -- as described in the demo README's Work section. The HUD's Jobs command
(UI-SET-029) is **unlocked by the demo** for it, exactly as the farm unlocks Food for the Pantry (`farm_hud.gd
unlock_food_command`): enabled, the locked set's own painted `cmd_work` icon, its tooltip in the command strip's form,
and J -- which the shell presses on an enabled command -- opens it. `ui_availability.gd` is unchanged: the game's own
shell still claims UI-SET-029 PANEL_NOT_BUILT, which stays true of the game.

### 7. One assignment grammar (F44's remainder, UX-001)

An order left on the board says the board's rule on its card: "Queue for the Field crew: Mouse fieldworker or Squirrel
gatherer, then anyone free who can" (`work_board.gd queue_words`, through the crews' `set_claimer`). A card with two or
more selected previews each member (`action_card.gd each_member`: "Of 3 selected: X, Y can; Z can't (why)") -- the
farm's, the woods' and the tunnels' cards -- and the Work screen's Reassign picker shows every resident with the same
eligibility words, which are the command's own refusals (one farm job, one woods job a resident; fits the bore; in
the water; held by the rescue), with the selection previewed under it.

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

The real village (9 residents) with 30 tasks queued (10 farm, 20 woods), 600 frames each at 1x and 4x, headless:
the claim's own scan -- rebuilding the candidate index and choosing among candidates -- **4.6 µs a frame mean, 270 µs
max (1x); 7.1 µs mean, 209 µs max (4x)**. One index rebuild ~62 µs (21 waiting tasks, 222 rows over six sources); one
resident's candidate scan ~78 µs (both through `call()`, so an upper bound). The whole board update **37 µs a frame
mean** at both speeds; its worst frame (3.9–4.4 ms) is a claimed job's first walk being planned at once by A's routing
desk (budgeted, 0361), not the scan.

## Verification

See the hand-back of this work for the suite and live lines, the mutation counts and the review; the record below is
filled in as they land.

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
