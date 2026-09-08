# 0016 — Needs integration costs 60% of the tick budget at the population cap
Date: 2026-09-06 · Status: Open, measured · Owner: unassigned

## The measurement
`needs.tick_all()` on this Mac (Godot 4.7.2, development build):

| Population | Cost |
|---|---:|
| 12 residents (starting settlement) | 65 µs |
| **256 residents (the cap)** | **1.19 ms** |

ARCH-PERF-001 / REQ-SET-163 budget the **whole** simulation tick at p99 ≤2 ms at
1x. Needs alone would consume roughly **60%** of that at the living cap, before
jobs, pathfinding, ecology, crops, weather, buildings, recipes or production
exist — all of which must fit in the remainder.

This is already after an optimisation pass that cut it from 2.61 ms: compound
multipliers hoisted to season boundaries, the five per-resident rates
precomputed into a reused column, and four per-operation checked calls replaced
by three hoisted precondition refusals plus one checked add.

**The residual cost is GDScript call overhead** — roughly 4.5 µs per resident
across ~11 calls — **not arithmetic.** That is the important part: there is no
obvious algorithmic win left, so the remaining levers change structure.

## Why it is recorded rather than fixed
The next step down is collapsing the single-integrator design — one
`_integrate_step()` through which every need, health and cold value passes. That
property is what makes the remainder rule verifiable in one place, and it is
mutation-proven: discarding the remainder fails 23 tests, mishandling the bound
remainder fails 7, floor-instead-of-truncate fails 4. Trading it away to save
call overhead is a real architectural decision, not a refactor, and it should not
be made silently by whoever happens to be writing needs code.

## What this is evidence of, and what it is not
It is **not** a measurement against the qualification hardware. Development is on
macOS; Windows testing is deferred by user instruction, and the available Windows
machine (64 GB, RTX 5090) is far above the specified minimum floor, so it cannot
establish the budget either way.

It **is** an early data point on the risk
`docs/crowd_rendering_architecture.md` §10.1 already names: it expects the
bottleneck to move to "GDScript movement/neighbor loops" and explicitly rejects
"1,600 independent … pathfinding in GDScript" as the wrong baseline, while
maintaining that there is no demonstrated Godot capability wall — the cost is
custom engineering. A per-resident GDScript loop hitting 60% of budget at 256 is
the settlement-layer version of that same expectation, arriving earlier than §10
anticipated.

## Options, none yet chosen
1. Accept it and hold every other system to the remaining ~0.8 ms. Plausible only
   if the later systems are far cheaper per resident, which is unlikely for jobs
   and pathfinding.
2. Reduce call overhead by inlining the integrator per need column, losing the
   single-integrator property and the one-place verifiability that goes with it.
3. Stagger needs across ticks — §5.2 permits rates per game hour, and REQ-SET-011
   requires only that results be independent of visibility and game speed, not
   that every resident updates every tick. This looks the most promising and the
   least destructive, but it must not perturb the remainder rule.
4. Escalate to native code (GDExtension) for the hot integrators, per crowd
   document §10's stated position that the cost is custom engineering.

## What must happen before choosing
Measure a second per-resident system — jobs is the natural candidate — so the
decision is made against two data points rather than extrapolating from one.
Re-measure on a release build; these numbers are from a development build.

## Source
Task 2.9 implementation measurement, 2026-09-06, escalated rather than resolved
unilaterally by the implementing agent.


## Correction and measurement plan (Brendan, 2026-09-06)

**The causation claim in this record overreaches.** Stating that call overhead
is the cause requires profiling evidence separating calls, allocations, checks
and arithmetic. The measurements so far establish **pressure**; they do not
prove the cause. Treat the per-call inference as a hypothesis to test.

Collect all of the following before choosing between the four options:

| Measurement | Purpose |
|---|---|
| Needs alone, WU alone, and the combined tick | Separate individual cost from interaction |
| At 12 and at 256 residents | Check how it scales |
| **Release build**, with machine and build documented | Make comparisons reproducible |
| 1x tick **p99** and 4x aggregate simulation **p95** | Match what REQ-SET-163 actually specifies |
| Deterministic state comparison | Verify any optimisation preserves behaviour |

### Two corrections to the options
- **Staggering is not behaviour-neutral.** Spreading needs across ticks can move
  when hunger, collapse and interruption thresholds fire. Preserving hourly
  totals alone is **not** sufficient evidence that it is safe.
- **Inlining need not destroy verifiability.** An optimised implementation can be
  compared against the retained reference integrator. That keeps inlining on the
  table as an option to evaluate, not one ruled out.

Status stays **open**. The WU model supplies the next data point.


## Measurement (2026-09-06) — the second data point, taken

**Build and machine, stated because both matter.** Godot
`4.7.2.stable.official.ed1daf0bf`, the **editor/development binary** — `assert()`
live, debugger compiled in. **No release build was possible**: the export
templates directory is empty and `godot/export_presets.cfg` does not exist, both
verified. Machine: Apple M5 Pro, 18 cores, 48 GB, macOS 26.6.2. **This is not the
qualification floor** (Ryzen 5 3600 / GTX 1660 Super / 16 GB), so nothing here
settles REQ-SET-163 either way.

Method: 300 warm-up ticks discarded, 3000 sampled, p99 by nearest rank; 4x
aggregate is consecutive tick pairs, p95 over 1500 windows. Every configuration
run twice in independent processes.

Budgets: 1x tick p99 ≤ 2000 µs; 4x aggregate p95 ≤ 6000 µs.

| Configuration | Pop | p50 µs | **p99 @1x** | **p95 4x-agg** |
|---|---:|---:|---:|---:|
| Needs alone | 12 | 60 | 74 | 134 |
| WU alone | 12 | 169 | 211 | 377 |
| Combined | 12 | 236 | 284 | 518 |
| Needs alone | 256 | 1152 | 1225 | 2377 |
| WU alone | 256 | 3651 | **4370** | **7970** |
| Combined | 256 | 4880 | **5622** | **10446** |

### What this settles

1. **WU alone breaks the 1x budget on its own** — 4370 µs against 2000, ~2.2x
   over, and roughly **3x the cost of needs**. Combined is 2.8x the budget; the
   4x aggregate is 1.7x over. The pressure is worse than this record assumed.
2. **The two systems are additive, not interacting.** At 256, needs p50 + WU p50
   = 4803 vs 4880 combined (+1.6%). So this is per-system per-resident cost, not
   an interaction — which is what the "separate individual cost from
   interaction" row was for.
3. **Scaling is linear-plus, nothing superlinear.** 12→256 is 21.3x population;
   needs costs 19.2x, WU 21.6x.
4. **The needs figures reproduce this record's originals** — 60 µs at 12 and
   1152 µs at 256 against the recorded 65 µs / 1.19 ms. The harness agrees with
   the earlier measurement.

### The causation hypothesis is now measured, not inferred

This record previously claimed call overhead was the cause, and that claim was
correctly called out as an overreach. It was then **decomposed by measurement**,
same method, 256 residents, p50:

| Component | µs | Share |
|---|---:|---:|
| Whole WU tick | 3651 | 100% |
| `work_factor_of()` reader chain (5 allocated `IntResult`s per worker) | 1651 | **45%** |
| `jobs.resident_may_work()` (status + need reads, 2 `OpResult`s) | 693 | **19%** |
| Everything else — job state, acceptance, consumption, XP, result | ~1307 | ~36% |

**~64% of the WU tick is reader-call plumbing across module boundaries.** The
hypothesis holds, and now on evidence rather than inference. `work.gd`'s own
party walk, acceptance, split and carries allocate nothing; `jobs.gd` already
publishes `_into` forms. The modules without them are `needs.gd` and
`residents.gd`.

### Determinism evidence, which was missing

Every configuration emitted an FNV-1a hash over all authoritative columns — work
carries, XP remainders, skill XP, job `remaining_mwu`, health, all five needs and
their remainders. **All six produced byte-identical hashes across independent
processes under identical commands.** Identical test counts prove only repeatable
suite results; these hashes are the determinism evidence.

### Next, per the ruling of 2026-09-06
Add allocation-free `_into` readers to the owning modules, retain the existing
convenience readers, and **measure again**. That does not require choosing
between this record's four options, and does not change needs timing. Status
stays open until a release-build measurement on documented hardware exists.


## Reader optimization follow-up (2026-09-07)

Implemented caller-owned needs/residents readers and migrated factor, work eligibility,
hazard-latch and XP reads without changing integration timing or gameplay formulas.
Convenience results remain fresh; the whole WU tick still has other allocations.

The original benchmark driver was missing, so the retained new harness compares source
commit `48e92ce` with the updated code under the same explicit fixture. Measurements,
24-process before/after parity, limitations, reproduction commands and test evidence are
recorded in [the validation report](../validation/work_reader_benchmark.md). The two-tick
aggregate is a CPU proxy, not a rendered-frame qualification. This follow-up does not
choose among the four architectural options. **Status remains open.**


## Profiling and adversarial workloads (2026-09-08) — the 64% figure does not survive decomposition

Per the reader follow-up's own "exact next task," the remaining productive-WU tick cost was
profiled directly instead of estimated again, and adversarial workloads were added before any
further change to work arithmetic or needs timing. No file under `godot/scripts` was touched by
this entry; `tools/benchmark_work.gd` and `tools/run_work_benchmark.py` gained isolated-part
probes (`loop`, `pid`, `xp`, `result`, `factor`, `gate`) and two workloads beyond the original
single-job-per-resident fixture (`bands`, spreading residents across §5.2's mood/health bands so
the population is not uniform; `party`, decision 0017 coordinators of sizes 1–8). Evidence is in
[the new validation report](../validation/work_profile_2026-09-08.md) and
`validation-results/work-profile-2026-09-08/`.

**The three named suspects are not the load-bearing cost.** The reader follow-up's 45%/19%
figures were themselves decomposed further: the `work_factor_of()` reader chain (`factor` probe)
and `resident_may_work()` (`gate` probe) had already been optimized by the reader follow-up above,
and profiling the three remaining named suspects — `jobs.agent_persistent_id_of()` (`pid`), the
XP-credit write (`xp`), and the escaping `TickResult` (`result`) — puts them at roughly **16%** of
the WU tick combined at 256 residents, not the ~64% the original reader-plumbing estimate implied
for the whole reader-call category. The `factor` probe alone, at roughly **24%**, is still larger
than the three named suspects combined, and roughly half the tick is call-graph work no isolated
probe accounts for. **A probe measures the cost of running that named part alone, in the same loop
shape, with the same fixed per-iteration floor (`loop`) paid by every probe** — it does not measure
what removing that part from the full tick would recover, because probes omit interaction
(instruction-cache pressure, branch history, allocator state) that a full tick carries. The
percentages above are ratios of isolated measurements, not attributions of cause. The correction
already on record above — "the causation claim in this record overreaches" — stands and is not
reintroduced by this entry.

**Party structure is the largest measured effect found so far.** Holding resident state identical
(the `bands` workload) and changing only job plumbing — 256 solo progress rows versus 59
decision-0017 coordinators for the same 256 residents — costs about 450 microseconds less at the
median for the combined needs+WU tick at 256 residents. Against 197 fewer progress rows
(256 − 59), that implies a fixed per-progress-row overhead of at least 2.28 microseconds, against a
whole-tick cost on the order of 11.34 microseconds per contributor. This was not a change under
test; it is an incidental finding from comparing the `bands` and `party` workloads that existed
only to give the per-part probes a non-synchronized population.

**The `uniform` workload — the one this record's own earlier measurements used — has a p99
artifact.** It gives every one of the 256 residents work factor exactly 1100 (the default spawn
stats), so `80 * 1100 / 1000` releases exactly 88 milli-WU with a remainder of exactly zero on
every tick, which means all 256 XP accumulators cross the 1000-milli-WU threshold on the same
tick. Its p99 tail is a synchronized burst that no realistic settlement produces, not a genuine
worst case. `bands` desynchronizes it and should be the reference workload for any future p99
claim; a change scored against `uniform` p99 alone is partly being scored against this artifact.

**Incidental finding, nothing changed:** `needs.gd`'s `work_factor()` clamp of
`WORK_FACTOR_MIN`/`WORK_FACTOR_MAX` (300/1800) can never bind. The published band tables give a
legal range of 360–1725, so no fixture — adversarial or otherwise — can drive that branch. It is
unreachable rather than untested.

**Scope of this measurement, restated because it still applies.** This is the editor binary
(Godot 4.7.2.stable.official.ed1daf0bf) on an Apple M5 Pro; `godot/export_presets.cfg` is absent
and the local export-template directory is empty, both recorded directly in the driver's
`build_context`. This is neither a release measurement nor the REQ-SET-163 qualification-floor
measurement (Ryzen 5 3600 / GTX 1660 Super / 16 GB), and no figure in this entry may be read
against that budget. Verified: 631 tests / 19,381 assertions / 0 failures, unchanged from the
prior entry, because no game code was touched. **Status remains open.** Selecting between this
record's four architectural options still requires a release-build measurement on documented
qualification hardware; this entry only replaces an inferred 64% reader-plumbing share with a
measured, and smaller, one.


## Release-build setup and re-measurement (2026-09-08) — the ranking survives release mode

Decision 0024 orders release-build setup as step 6, after the baseline and the lazy-ID change.
This entry does that step: every prior number in this record came from the editor binary with
twenty-nine live asserts across the core modules, and a cost ranking taken on a binary that does
not ship might reorder once those asserts and the editor's own overhead are gone. No file under
`godot/scripts` was touched; `tools/benchmark_main_loop.gd`, `tools/compare_work_benchmarks.py`
and `tools/export_benchmark_build.py` are new, and `tools/run_work_benchmark.py` gained a
`--runner release` mode. Suite: 644 tests / 20,118 assertions / 0 failures, unchanged from the
prior entry. Evidence: `validation-results/work-release-2026-09-08/`.

**The command-line wrinkle was solved by testing, not assumption.** The release template binary
cannot run a project directory at all: Godot's official export templates are built with
`disable_path_overrides=true`, so `--path`, `--main-pack` and `-s/--script` are marked
editor-only and the template aborts with an explicit compiled-without-support error rather than
silently ignoring them. The benchmark driver therefore reaches an exported build through a
project-setting delta naming a `SceneTree`-derived main loop class, with the benchmark fixture
file itself left byte-identical between the editor and release runs, so both sides measure the
same code through different entry points.

**Asserts were proven stripped, not assumed.** A three-way probe places a call inside an assert
condition and reports how many times it was evaluated. In both the editor binary and a
`template_debug` export, the call is evaluated three times and execution halts at the failing
assert. In `template_release` the call is evaluated zero times and execution continues past the
same statement. Including the debug template alongside editor and release is what makes this a
real proof rather than a coincidence of `OS.is_debug_build()`: it shows the probe distinguishes
release from debug templates, not merely editor from non-editor. The driver now refuses to time
anything under `--runner release` unless the build manifest shows asserts compiled out and the
packed fixture, packed core sources and on-disk binary all hash as expected — every one of those
checks raises, it does not warn.

**The ranking did not change.** The factor chain (`work_factor_for_resident_into`'s call graph)
remains the largest named cost at roughly 30% of the work tick on the mixed-bands ordinary-play
reference, in the same relative order — factor > xp > gate > pid > result — across all three
workloads at both 12 and 256 residents. Release mode is 28-31% faster than the editor binary
across the board, well outside the 2.6-4.1% machine drift the byte-identical needs control
measured across the session (recorded in `editor-drift-recheck-summary.md`, re-run to bound
session-to-session noise rather than assumed from the earlier reader-follow-up figure). Stated
plainly because it is the number that matters most: combined at 256 residents is 2160-2700
microseconds at p99 in release mode, still above the 2000 microsecond tick budget, on an Apple
M5 Pro that is far faster than the qualification floor. All 58 determinism-digest triples present
in both the editor and release runs agree, so the release build produces bit-identical simulation
state to the editor build on this fixture. This is explicitly not a REQ-SET-163 measurement: an
Apple M5 Pro is not the Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB reference, and Windows remains
deferred.

**The blocker that was not worked around.** Exporting for arm64 macOS requires
`rendering/textures/vram_compression/import_etc2_astc`, which `project.godot` does not set. The
export helper applies that setting to a throwaway copy of the project under `--work-dir` and
records it as an explicit delta in the build manifest, rather than modifying the shipped
`godot/project.godot`. Whoever owns `project.godot` must decide whether that setting belongs
there permanently. **Status remains open.** This entry closes the release-build half of what the
prior entry named as required before choosing among the four architectural options; the
qualification-floor half — documented Ryzen 5 3600 / GTX 1660 Super hardware — is still
outstanding.
