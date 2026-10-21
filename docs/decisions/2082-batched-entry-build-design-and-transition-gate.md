# 2082 — The batched entry build: the design, and the transition gate measured (the gate fails; stopped for rulings)

Date: 2026-10-20 · Status: **Proposed.** Phase 0 of the batched entry build lane: a design record and the measurement
gate decision 2081 ruled must come first. **The gate fails on real time** (§4), so the lane stops here, as the ruling
says, before any runtime change. Proposals P-2082-1 to P-2082-7 wait for Brendan.

Number: **2082**, from the range 2082–2089 the coordinator gave this lane, checked free on every local and remote ref
(`git for-each-ref refs/heads refs/remotes`, then `git ls-tree` of each ref's `docs/decisions/`).
`python3 docs/validation/decision_numbers.py` passes. Branch `feat/entry-batched-build`, cut from M5's committed head
`46a20449` (`feat/slice-d-m5-full`, decision 2045), worktree `scratchpad/wt-batch`. Decision 2081 is on master
(`2dbebddc`) but not yet in this branch, which was cut from M5's head; it was read from master and is cited from there.
The branch merges master when it next has runtime work.

## The ruling being built

Decision 2081, P-2081-1 to P-2081-9, all (a), Brendan, 2026-10-20 (relayed by the coordinator):

- the whole full-level stair, Confirm to level 1 open, takes **30–60 real seconds at 1x** (900–1,800 ticks);
- it is a **batched build** with **one entry time scale k**: about one dig episode and one fitting episode per module,
  committed in tens of cold transitions instead of M5's roughly 760;
- M5's geometry, bill and final state stay; village haulers stock M and the crew never hauls; deep spoil goes to a
  foot pile; a started build runs through rest hours; one crew; no fast-forward and no second clock; the entry only;
- M5 lands first as the exact reference, and its chain stays the reference suite;
- **the gate: measure the batched transitions first, and stop if any single transition exceeds `Space.MAX_CHECKS`
  (1,048,576) or their real-time sum exceeds about 15 s.**

## In short

- **The bound holds.** A scratch prototype committed each stage's cubes in one cold transition (module 0's 48
  top-metre cubes in one, each landing's deep layer in one) and ran the whole flight to level 1
  (`ENTRY_KITCHEN_UNBUILT`, tick 31,560) with no refusal. The largest single spend was **WorldRoutes 1,029,837
  (98.2 %)**, at landing 1's 40-cube commit. Ten-cube blocks take that to 689,568 (65.8 %).
- **Real time fails by about ten times.** The prototype's 184 cold transitions took **154.9 s**, against about 15 s.
  On top of that, 2,070 ordinary Work ticks each took longer than a 1x tick's 33.3 ms (55–210 ms each), adding
  **173.1 s** more.
- **For comparison, M5's per-cube flight, measured the same way:** 756 transitions taking **1,001 s**, plus 249 s of
  slow Work ticks (§3.1). So batching cuts the transitions' time by about 85 %, but not to 15 s.
- **Batching the cubes is not where the time goes.** Staging 47 extra cubes in one candidate cost 75 ms. A transition
  costs 0.3–4.5 s whatever it carries, because each one re-proves the whole entry, and that cost grows with every
  installed part: about 0.5 s on the surface, 2–4.5 s at landing 4.
- **The 36 installations are now the biggest share:** two cold transitions each (the paid start and the completion),
  72 in all, about 86 s. The dig needs 14 transitions in the full design; the fitting needs 72 unless several parts
  are committed together, which nobody has measured and which the sill alone (92.7 % of its bound) makes doubtful.
- **Where the checks go:** Contacts (`underground_connector_contacts.gd`) is **57 %** of every check charged in the
  transitions and **85 %** in the slow Work ticks. Routes is 19 % and 15 %. Locations and WorldRoutes are 8 % each,
  in the transitions only.
- **Phase-spreading stage 2 alone cannot close the gap.** It moves a transition's work out of one tick, but the work
  still has to be done. About 113 s of transition work, in the full batched design (§3.5), does not fit in a
  45-second build at 1x on top of the tick budget. The cost per transition has to come down several times as well.
- **Recommendation (P-2082-1): stop the batched build here.** Next, a lane on the per-transition and per-Work-tick
  cost, Contacts first (Slice D's own file), with Slice C's stage 2 reopened on these numbers. Then re-measure with
  this record's harness. The design (§1) is ready to build once the cost fits.

## 1. The design

### 1.1 What stays, and what is replaced

Everything M5 built stays, as 2081 (g) said: the geometry and the `qualified-stairs-m5-v2` bundle, the bindings,
Locations and WorldRoutes fixes, the stair path with its landings and R′, the Frontier and its byte bound, the
progress record (save v4), the row index and the memos. M5's per-cube chain stays the qualified reference suite.

**Replaced:** the foreman's per-cube plan (`_append_episodes`: three phase tasks per cube, each a START, a hand-over
and a settlement, about four cold transitions a cube). In its place come block tasks, a Frontier successor that names
one work spot per block instead of a station per cube, and a block commit in the Space authority.

### 1.2 A batched dig episode

**One episode per dig stage.** The stages are those M5 already plans by installed prefix: L0's 4 cubes, T0's 2,
module 0's top metre (48), and each landing's deep layer (40, 30, 20, 10). That makes 7 dig episodes for the flight.

**One episode, one or a few commits.** A block is a run of a stage's episodes in M5's dig order. Its commit is one
cold Space transaction that takes every cube in it from solid to finished void:

1. **START (one transition):** one block Project. Its inputs are the block's cubes' brace inputs, drawn from M's free
   stock; if M is short, the build waits and says so (P-2081-3). The crew's one claw entry follows, at the block's work
   spot.
2. **Work:** the block's whole Work, N × 4,230 mWU (DEC-059's brace, cut and finish amounts per cube, unchanged), at
   the crew's rate times k (§1.5).
3. **COMMIT (one transition):** one Space candidate. In it, for every cube in M5's order, the authority:
   - proves the cube is dry solid;
   - retires the cube's floor strips (P-2044-12's hook, at the block's start);
   - stages the cube's natural bands (what each BRACE commit stages in M5);
   - replaces the cube with Room-owned supported void in its section, keeping the outside slabs.

   The block's spoil goes to the output: R's pile on the surface, the foot pile for deep cubes (P-2081-4). Then one
   companion preparation requalifies the world (§1.4). Then the crew makes its one recovery.

**Two transitions per block, not four.** M5's hand-overs (settle, then START, in one tick: DEC-059 P2) disappear,
because a block has no per-phase boundary. Each operation's history is still recorded per Site, so the ledger matches
M5's (§1.6).

**Block size is set by the bound, not the cubes.** The prototype's numbers (§3.2, §3.3):

- staging the cubes is nearly free (75 ms for 47 cubes);
- each transition costs the same re-proof whatever its size;
- so fewer, larger blocks are better, up to `Space.MAX_CHECKS`.

Module 0's 48 cubes fit in one commit with half the bound to spare (WorldRoutes 538,448). Landing 1's 40-cube commit
fits with only 1.8 % to spare, so P-2082-3 proposes two 20-cube commits there.

**The work spot.** A block needs one place for the crew to stand, not a station per cube:

- the top metre's blocks: a land station at the trench side;
- each deep block: the landing floor beside F′, the spot M5's last deep cube is already struck from.

The deep floor graphs (P-2045-5's two-row blocks), the per-cube surface batches and most deep-station Locations
then never publish. The Frontier successor drops the deep stations from the sills' installed contacts.

### 1.3 A batched fitting episode

**One episode per module:** the crew stands at the module's fitting spot and fits its seven parts (L0/T0 for the
prefix), with no walk between parts and nothing hauled (M is stocked).

**Today, each part is two transitions**: the paid start (FUND) and the completion. The prototype measured them at
0.3–2.1 s each, 72 for the flight, about 86 s. That is more than all the dig. Fitting a module's seven parts in one
Placements transaction would make 7 commits instead of 72. It is not designed or measured here:

- module 0's sill alone uses 92.7 % of the bindings' entry budget;
- a seven-part commit would need the bindings' operation split across parts first.

P-2082-4 asks whether to study it.

### 1.4 Requalification once per batch

The block commit makes one companion preparation (Placements' phase refresh): one Locations stage refresh, one
Routes stage refresh, and one WorldRoutes requalification with ADR 1205's carry. Contacts binds the block's one
episode (its work spot), not one per cube.

Measured: the requalification does not get cheaper per cube, and it does not get dearer either. Landing 1's 40-cube
commit and a 10-cube commit each cost about 1.1–1.4 s. WorldRoutes carries fewer edges after a large change, which is
why the 40-cube commit's WorldRoutes peak is higher (98.2 % against 65.8 %).

### 1.5 The time scale k

One integer k applies to every duration of the entry crew's work and motion, on entry episodes only:

- **Work:** the crew earns k × its rate per tick. The amounts stay DEC-059's, so the earned-mWU ledger is M5's to the
  milliunit. 2081's brief scaled the amounts instead; scaling the rate keeps the ledger exact (P-2082-5). This is a
  Job-level multiplier in `work.gd`, on Slice C's hold list.
- **Clips** (claw entry and recovery, handling) and **motion edges** (the ground walks, DEC-050's 30 ticks a tread and
  45 a half-turn): each lasts `ceil(base / k)` ticks, at least 1. This is a Routes playback scale, in Slice C's
  `underground_routes.gd`, which no lane has agreed to yet (2081 "Not claimed").

2081's tick budget for the batched build was 14,059 / k, so k = 10 gives about 1,400 ticks. **That k is only
meaningful once real time fits (§4)**: at today's costs the ticks are not what decides the length of the build.

### 1.6 The bill and the ledger

At the flight's end the ledger must equal M5's:

- wood 77,500, stone 38,500;
- 912,620 mWU (651,420 cube Work + 261,200 fastening);
- earth 308,000 milli-U of spoil;
- per Site: `_installed`, `_ever_cut`, `_earned_mwu` per operation, the physical phase;
- `_completed_braces`, `_virgin_sourced_milli`, and the Placement's INSTALLED count.

**How the block keeps it:**

- its START consumes N × the brace inputs to WIP in one Inventory journal;
- its COMMIT writes each Site's history exactly as M5's three phases leave it, and commits N cubes of earth;
- only the number of Projects and Jobs changes: one per block instead of three per cube. Neither is in the census or
  checkpoint comparison of final state.

The installations' bills are unchanged.

### 1.7 What the player sees: animated, never a teleport

- **Dig.** The crew walks to the work spot on real routes at k × pace. It plays one claw entry, then the looping claw
  dig for the whole Work, then one recovery. The cubes' earth is drawn going away in the order M5 cuts them, in step
  with the earned Work (presentation only, float). The pile at R or at the foot grows the same way.
- **The authoritative state changes at the commit.** Nothing walks or stands on a cube before it is committed, and no
  way is shown open before it is (P-2081-7). The shown dig runs at most one block ahead of the true state; smaller
  blocks keep the two closer (P-2082-6).
- **Fitting.** The crew plays DEC-060's general paw working motion at the fitting spot. Each part appears when its
  installation commits.
- **Between episodes,** the crew walks down the new module on the real stair at k × pace.

### 1.8 Save and load mid-batch

- **A commit is one tick.** The save's quiescence test already refuses a save inside a cold operation.
- **What a save mid-episode holds:** the block Project, funded (inputs in WIP), with its Work earned so far, and the
  cubes still solid in Space.
- **The progress record:** the block is the foreman's task, so v4's cursor (task index, stage, ledgers) holds it.
  MAX_TASKS 160 shrinks to a few block tasks plus the installations. A v5 is needed only if the record must name the
  block's cube range, which the Frontier successor gives by row instead.
- **On load:** the block's static Work proof is re-derived once by `refresh_static_proof`, as `_reproved_tick` does
  per cube today.
- **The end state** has the same regions as M5's, so a level-1 save still needs P-2045-14 (the Space owner's load
  validation) before it can load.

### 1.9 Files: what changes, what stays

**Changes (claims inherited from M5, as 2081's brief lists):**

- `underground_entry_foreman.gd`: the block plan beside the per-cube plan, which stays for the reference suites.
- `underground_entry_frontier.gd`: the successor's block rows.
- `underground_entry_progress.gd`: only if a v5 is needed.
- `underground_entry_stair_path.gd`, `underground_entry_work_area.gd`: work spots instead of per-cube stations.
- `underground_entry_bindings.gd`: the sills' installed contacts without deep stations.
- `underground_entry_contact_retirement_scope.gd`: the successor's table census.
- `underground_entry_site.gd`, `underground_entry_composition.gd`, `underground_route_composition.gd`: the successor
  preload.
- `underground_connector_contacts.gd`: the block's one episode.
- `data/underground/runtime_files.gd`; the M5 publisher and a new successor bundle (never an edit).
- The census, the checkpoints and the pins.

**Also changes, and touches Slice C-held code or Slice C's hold lists:**

- `excavation_sites.gd`: a block START and COMMIT beside `begin_phase_work` and `settle_phase`. On Slice C's
  phase-spreading list.
- `underground_space_authority.gd`: a multi-cube candidate. Stage 2 names its cold operation "to be agreed".
- `underground_entry_structure.gd`: the block's strips and bands. On phase-spreading's hold list; Slice C asks before
  editing.
- `work.gd`: the rate multiplier (Slice C's).
- `underground_routes.gd`: the playback scale. Not claimed; needs Slice C's agreement.
- `underground_connector_placements.gd`: only for P-2082-4's multi-part commit.

**Stays:** everything else M5 touched, including the Locations and WorldRoutes held functions (no change is needed
for batching itself), Profiles, the stair motion tables, the catalog and the Session.

## 2. How the gate was measured

- **Clones.** APFS clones of this worktree, without demo art and never committed (`scratchpad/bbase`,
  `scratchpad/bproto`; scripts in `scratchpad/bb/`).
  - **The meter.** `instrument.py` meters every check domain's charge: WorldRoutes route preparations and timber
    clearances, the entry bindings, Locations, Contacts, the Space authority's cold check, the Space owner, Routes, the
    phase structure and the world bindings. For each, it keeps the operation's peak against `Space.MAX_CHECKS` and the
    tick's summed spend.
  - **The harness.** The suites' `_begin_live_entry` with `_sustain` (needs held full, R topped up), the default
    schedule, and the cache checks **off**, as production runs. It times every `run_tick` with `Time.get_ticks_usec()`
    and logs every tick that changes the crew's stage or takes 50 ms or more. A **cold transition** here is a tick of
    50 ms or more that changes stage; a **slow Work tick** is a tick over 33.3 ms that does not.
- **The baseline.** M5's per-cube flight on this branch's code (`46a20449`), today's bound, real hauls.
- **The prototype ("carrier" blocks).** The foreman plans only each block's last episode, the carrier, and the Space
  authority's FINISH commit for it also stages the block's other cubes:
  - their matter becomes finished void, keeping the outside slabs;
  - their floor strips are retired (at the carrier's BRACE start where they meet its cube, otherwise in the commit);
  - their natural bands are added;
  - each Site's history is set as M5's three phases leave it.

  M is stocked directly, standing in for the village's haulers (P-2081-3). L0's and T0's 6 cubes stay per cube:
  L0's contact-retirement scope expects its two first stations worked. The installations are M5's, unchanged.
- **What the prototype leaves out** (each makes it cost the same or more than the full design):
  - the per-cube station Locations: M5's bundle still installs the deep stations as the sills' contacts;
  - the carrier's per-cube transitions: four per block, not §1.2's two;
  - the cubes' brace inputs and spoil, which are not charged for the extra cubes; staging and Inventory are a few ms;
  - the k scale: Work and walks run at today's pace.

  None of these changes the cost of the requalification, which is what decides the gate.
- **The machine:** the development Mac (Apple Silicon), faster than REQ-SET-163's Ryzen 5 3600 floor, so these are
  lower bounds there. The first prototype run shared the machine with the baseline run; §3.2's clean rerun confirms
  its numbers.

## 3. Measurements

### 3.1 M5 per cube (the baseline, today's bound)

The whole flight, `ENTRY_KITCHEN_UNBUILT` at tick 92,560, as decision 2045 measured. 1,603 s of computation.

| Window (stage) | Cold transitions | Their time | Longest | Slow Work ticks: excess | Largest owner peak |
|---|---:|---:|---:|---:|---|
| L0 (4 cubes) and L0 | 18 | 12.7 s | 1.03 s | 0 | phase structure 53.2 % |
| T0 (2 cubes) and T0 | 11 | 6.9 s | 1.02 s | 0 | Contacts 58.3 % |
| Module 0: top metre (48) and T1–T6 | 211 | 157.3 s | 1.77 s | 2.4 s | phase structure 95.3 % |
| Landing 1 (40) and module 1 | 188 | 207.9 s | 2.44 s | 17.5 s | phase structure 95.7 % |
| Landing 2 (30) and module 2 | 149 | 230.7 s | 3.58 s | 41.3 s | phase structure 96.1 % |
| Landing 3 (20) and module 3 | 109 | 218.1 s | 4.68 s | 79.6 s | phase structure 96.4 % |
| Landing 4 (10) and module 4 | 70 | 167.8 s | 5.86 s | 108.5 s | phase structure 96.7 % |
| **Whole flight** | **756** | **1,001.4 s (16.7 min)** | 5.86 s | **249.3 s** | phase structure 1,014,458 (96.7 %) |

**What one cube costs.** Four transitions: a START (0.44 s at the top, 2.0 s at landing 4), two hand-overs (1.0 s, then
4.7 s) and a settlement (0.6 s, then 2.3 s). Each installation is two (0.6 s at the top, then 2.0 s). The per-cube
hand-overs alone take about 598 s.

**Every owner's largest spend:** phase structure 1,014,458 (96.7 %), entry bindings 971,519 (92.7 %), Contacts
921,265 (87.9 %), Locations 870,951 (83.1 %), Routes 655,819, WorldRoutes 649,811. All are under the bound, as
decision 2045's fourth phase reported.

### 3.2 The batched prototype: one commit per stage

Whole flight, `ENTRY_KITCHEN_UNBUILT` at tick 31,560 with no refusal. 479 s of computation.

| Window (stage) | Cold transitions | Their time | Longest | Slow Work ticks: excess | Largest owner peak |
|---|---:|---:|---:|---:|---|
| L0 (4 cubes, per cube) and L0 | 18 | 12.7 s | 1.03 s | 0 | phase structure 53.2 % |
| T0 (2 cubes, per cube) and T0 | 11 | 6.8 s | 1.01 s | 0 | Contacts 58.3 % |
| Module 0: one 48-cube commit and T1–T6 | 23 | 11.0 s | 1.22 s | 2.1 s | entry bindings 91.4 % (the sill) |
| Landing 1: one 40-cube commit and module 1 | 32 | 19.1 s | 1.81 s | 15.0 s | **WorldRoutes 98.2 %** |
| Landing 2: one 30-cube commit and module 2 | 34 | 26.4 s | 2.62 s | 30.0 s | entry bindings 86.3 % |
| Landing 3: one 20-cube commit and module 3 | 33 | 34.9 s | 3.51 s | 48.7 s | Contacts 83.2 % |
| Landing 4: one 10-cube commit and module 4 | 33 | 44.1 s | 4.49 s | 77.3 s | Locations 81.0 % |
| **Whole flight** | **184** | **154.9 s** | 4.49 s | **173.1 s** | WorldRoutes 1,029,837 (98.2 %) |

Clean run on a quiet machine (load about 4). The first run, sharing the machine with the baseline, gave 157.6 s and
179.5 s.

**By kind, whole flight:**

| Kind | Count | Time |
|---|---:|---:|
| Installations: paid start | 36 | 41.6 s |
| Installations: completion | 36 | 44.7 s |
| Dig: the five carrier blocks (four transitions each, plus one carried-over commit) | 21 | 42.1 s |
| Dig: L0's and T0's six cubes, per cube | 24 | 17.8 s |
| Small transitions (installer legs, phase opens, 50–250 ms each) | 67 | 8.7 s |

**The block commits themselves** (the carrier's FINISH commit carrying the rest):

| Block | Cubes | Wall time | Largest owner peak |
|---|---:|---:|---|
| Module 0's top metre | 48 | 0.77 s | WorldRoutes 538,448 (51.4 %) |
| Landing 1's layer 2 | 40 | 1.37 s | **WorldRoutes 1,029,837 (98.2 %)** |
| Landing 2's layer 3 | 30 | 1.57 s | Contacts 822,852 (78.5 %) |
| Landing 3's layer 4 | 20 | 2.02 s | Contacts (83 %) |
| Landing 4's layer 5 | 10 | 2.54 s | Locations (81 %) |

Staging the extra cubes in the candidate took 75 ms for module 0's 47 and 0.31 s for all 144 together.

**The flight's largest spends, by owner:**

| Owner | Peak | Share of `MAX_CHECKS` |
|---|---:|---:|
| WorldRoutes | 1,029,837 | 98.2 % |
| Entry bindings | 971,683 | 92.7 % |
| Contacts | 895,854 | 85.4 % |
| Locations | 849,293 | 81.0 % |
| Routes | 653,729 | 62.3 % |
| Phase structure | 566,700 | 54.0 % |

### 3.3 Ten-cube blocks (one module's rows at one depth), to tick 14,000

Module 0 makes five blocks and landing 1 four, so there are more transitions. Landing 1's largest WorldRoutes spend
falls to **689,568 (65.8 %)**. Module 0's dig went from 4 transitions (3.4 s) to 20 (about 18 s); landing 1's from 4
(about 6 s) to 16 (about 20 s). Each block's transitions cost about what a whole-stage block's do, so **smaller
blocks multiply the real time**.

### 3.4 Where the checks go

Over the prototype's first run's 184 cold transitions (685 M checks charged, 157.6 s, about 230 ns a check):

| Owner | Share of the checks |
|---|---:|
| Contacts | 57 % |
| Routes | 19 % |
| Locations | 8 % |
| WorldRoutes | 8 % |
| Phase structure | 4 % |

In the dig transitions, the companions' preparation (Locations, Routes, WorldRoutes) took 26.4 s of 60.8 s, and the
Space survey 2.3 s. Almost all the rest is Contacts' observations.

Over the 2,080 slow Work ticks (2.85 billion checks, 248.8 s): Contacts 85 %, Routes 15 %.

- **Why a Work tick is slow.** Each one re-observes the crew's contact (`worker_refusal` →
  `phase_observe_refusal`), a Region scan whose cost grows with the stair. Installation fastening ticks grow from about
  56 ms in module 0 to 208 ms in module 4; dig Work ticks reach about 100 ms.
- **They lengthen the build.** At 1x the game does not skip ticks (REQ-SET-008), so every such tick lengthens the build
  by its excess over 33.3 ms.

### 3.5 The full design, projected from these measured parts (marked as a projection)

With §1.2's two transitions per block, one block per dig stage, and today's per-transition costs by depth (§3.2):

| Part | Transitions | Real time (projected) |
|---|---:|---:|
| The dig: 7 stages × 2 (each stage's measured START and commit) | 14 | about 18 s |
| The fitting, as today: 36 parts × 2 | 72 | about 86 s |
| The small transitions | about 67 | about 9 s |
| **Total** | **about 150** | **about 113 s** |
| Floor: seven-part fitting commits, each costing no more than one part's two (unmeasured) | about 28 + small | at least about 32 s |

The slow Work ticks scale with k: at k = 10, about 210 of today's 2,070 remain, about 17 s of excess. **Even the
floor is twice the 15 s gate.**

## 4. Verdict

**The gate fails.** No single transition exceeds `Space.MAX_CHECKS` (the largest is 98.2 %, at landing 1's 40-cube
commit). But the batched transitions' real-time sum is **154.9 s measured** in the prototype, and **about 113 s
projected** for the full design, against about 15 s. Under 2081's ruling the lane stops before any runtime change.

What decides the result is not the number of cubes a transition carries but its fixed cost. Each transition costs
0.3–4.5 s, mostly Contacts and Routes, and grows with every installed part. Even the coarsest batching keeps 14 dig
transitions and 72 installation transitions.

**Phase-spreading stage 2** (decision 1953 §7) takes a transition's stall out of one tick, but it does not remove the
work. About 113 s of transition work cannot be done inside a 45-second build at 1x as well as everything else:

- REQ-SET-163's tick budget is p99 under 2 ms at 1x;
- slicing 113 s of work over about 1,350 ticks is about 84 ms a tick.

So stage 2 is needed and is not enough. The per-transition and per-Work-tick cost must also fall, roughly five to ten
times, before any 30–60 s build can be honest in real time.

## 5. The options

- **(a) A cost lane first, then re-measure.** Contacts first: a revision-keyed memo of a contact observation's static
  Region part, with the live occupancy part kept per tick. Contacts is Slice D's own file (M5's claim 13). Routes'
  per-tick and per-transition spend next, with Slice C (their file). Then phase-spreading stage 2, reopened on these
  numbers. Then this record's harness again, gate unchanged.
- **(b) Build the batched build now, missing the target.** By §3.5 the build takes about 2–3 minutes of real time
  (at k = 10: about 1,400 ticks, 47 s, plus about 113 s of transitions and 17 s of slow ticks) instead of M5's
  about 72 minutes (3,085 s of ticks plus 1,001 s of transitions and 249 s of slow ticks, §3.1), and its tick count becomes about 1,400. The 30–60 s target waits for (a).
- **(c) Change the target** (for example 2–3 minutes), keeping (b)'s design.

## 6. Proposals

**P-2082-1 — The gate failed: what next.**
- **(a) Stop the batched build. Start a cost lane: Contacts' observation memo first, then Routes (with Slice C).
  Reopen phase-spreading stage 2 with this record's numbers as its baseline. Re-measure with this harness and the same
  gate, then build §1.**
- (b) Build §1 now (about 2–3 minutes real time), then (a).
- (c) Set a new target.

**Recommendation: (a).** The batched design cuts about 760 transitions to about 150 (about 86 heavy ones), but it
is still about 113 s as designed and at least about 32 s even with untried seven-part fitting commits, against
15 s. The cost that remains sits in code the batched build does not change (Contacts, Routes), so building it first
would not move the gate.

**P-2082-2 — Batch granularity.**
- **(a) One block per dig stage (7 dig episodes), split only where the bound is near.**
- (b) Ten-cube blocks (one module's rows at one depth): safer peaks (65.8 %), but about four times the dig
  transitions.
- (c) Two-row blocks (P-2045-5's): the most transitions.

**Recommendation: (a)**, with P-2082-3.

**P-2082-3 — Landing 1's 40-cube commit (98.2 % of the bound).**
- **(a) Two 20-cube commits at landing 1; the other stages one commit each.**
- (b) One commit, accepting 1.8 % headroom.
- (c) Ten-cube blocks everywhere.

**Recommendation: (a).** 1.8 % is within one image's growth of a refusal.

**P-2082-4 — The fitting.**
- **(a) Study a module-level fitting commit (seven parts in one Placements transaction) as part of the cost lane:
  the bindings' operation per part first, measured against the bound.**
- (b) Keep two transitions per part (72 for the flight).

**Recommendation: (a).** The fitting is 72 of the 86 heavy transitions in §3.5.

**P-2082-5 — How k applies to Work.**
- **(a) As a rate (the crew earns k × its rate), so the earned-mWU ledger is M5's to the milliunit; a Job-level
  multiplier in `work.gd` (Slice C's).**
- (b) As amounts divided by k (2081's wording): no `work.gd` change, but the ledger's Work no longer equals M5's.

**Recommendation: (a).**

**P-2082-6 — Animation honesty.**
- **(a) The crew plays the real looping work clips at k × speed at a work spot. The cubes' earth is drawn going in M5's
  order with the earned Work, as presentation only, never more than one block ahead of the committed state. Nothing
  walks a cube before it is committed.**
- (b) Draw nothing until the commit: the trench appears a block at a time.
- (c) Commit per cube for presentation: back to about 760 transitions.

**Recommendation: (a).**

**P-2082-7 — Save points.**
- **(a) Saves between ticks only, as today. A mid-episode save holds the funded block and its earned Work, and a load
  re-derives the block's static proof once. A level-1 save still waits on P-2045-14.**
- (b) Saves only between episodes.

**Recommendation: (a).**

## 7. For Slice C (as asked)

The batched transitions miss the 15 s gate, so this record is the baseline 2081 promised for **phase-spreading
stage 2**:

- per transition: 0.3–4.5 s on this Mac, growing with depth (§3.2);
- Contacts 57 %, Routes 19 %, Locations 8 %, WorldRoutes 8 % of the checks (§3.4);
- stage 2 alone does not fit the build's real time (§4).

The full design (§1.9) also needs `excavation_sites.gd`, `underground_space_authority.gd`,
`underground_entry_structure.gd`, `work.gd` and `underground_routes.gd`, all on Slice C's lists. Nothing was edited
there; the prototype lived in a scratch clone.

## Gates

Docs only: `python3 docs/validation/decision_numbers.py` PASS. No runtime, data or test file changed on this branch.
The scratch clones and their scripts are not committed (`scratchpad/bbase`, `scratchpad/bproto`, `scratchpad/bb/`;
logs `base_full.log`, `proto3.log`, `proto4.log`, `proto_k10.log`).

## Source

- Decision 2081 (master `2dbebddc`): rulings P-2081-1 to -9 and the batched build lane's brief.
- Decision 2045: M5's phases, measurements, tick breakdown, row index and the P-2045-7 memo key.
- Decisions 2044 (claims), 2043 §3 (M5's dig order), 1953 §6–§7 (stages 1 and 2) and 1244.
- DEC-050, DEC-059, DEC-060 and DEC-061 (`docs/setting_decisions.md`); REQ-SET-002, -003, -008 and -163
  (`docs/game_gdd.md`).
- This lane's measurements (scratch, §2).
