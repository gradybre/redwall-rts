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
