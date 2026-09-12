# Executor → Astra: what MOVE-G01 needs to close

2026-09-12. A request, not a ruling. It states exactly what `movement.gd` refuses
to invent, why each refusal is correct, and what shape an answer has to take to
be usable. Nothing here proposes a value.

MOVE-G01's closure artifact is defined in
[the movement amendment](../movement_direction_amendment.md) §5 as: *"Finite
spatial/depth extents; all construction states, costs and spoil rules; actual
traversal profiles; all allowed modes and disabled cases; interruption/hazard
policy."* This document takes those five terms one at a time.

**05.1b — the first playable connected movement — is blocked on this and nothing
else.** It is the only unchecked item in task 05.

## What is already authored, so that nothing here is re-asked

The starter ground profile is **built, not stubbed**, and derives every number it
publishes from `residents.gd` rather than from a literal — `_build_starter_profiles()`
refuses a species the resident store cannot compile rather than letting it inherit
a neighbour's numbers.

| Published today | Source | Value |
| --- | --- | --- |
| Speed, by size class | GDD §5.2 via `SIZE_MOVEMENT_U_PER_S` | 3277 / 4096 / 3072 u·s⁻¹ (small / medium / large) |
| Carry, by size class | GDD §5.2 via `SIZE_CARRY_G` | 12000 / 16000 / 24000 g |
| Species and size class | `residents.gd`'s compiled catalog | four profiles: mouse, mole, otter, squirrel |
| Anatomical heights | **DEC-039, 2026-09-12** | mouse 1024 u, mole 922, squirrel 1178, otter 1526, badger 2611 |

The large-is-slower anomaly in the speed row is deliberate and is not a defect
report. **Do not re-derive any of the above.**

## G01-Q1 — Clearance class, and the profile field that refuses today

`profile_clearance_class_into()` **refuses for every profile**, with
`PROFILE_CLEARANCE_UNSPECIFIED`. It is the single most load-bearing gap: without a
clearance class nothing can decide whether a creature fits through an opening, so
no tunnel, door or burrow can admit or refuse anyone on physical grounds.

Height alone does not answer it. A mole at 922 u is the shortest of the five and
also the widest through the shoulder; a squirrel at 1178 u is taller than a mouse
and slighter than an otter. **Clearance is a cross-section, not a height**, and the
executor will not derive one from the other.

Needed: the clearance class domain (how many classes, and what each admits), and
the assignment of every profiled species to one. If clearance is a measured
envelope rather than a class, say so and give the measuring convention — the
landmark ratios in `proportion_comparison_manifest.json` are still
`PROPOSED_FOR_REVIEW` and are **not** a clearance authority.

## G01-Q2 — The four unprofiled modes

Six traversal modes are **enumerated** in `movement.gd` so the adopted scope cannot
be narrowed by omission. `PROFILED_MODE_MASK` currently admits **two**:

| Mode | State |
| --- | --- |
| `MODE_GROUND_WALK` | profiled |
| `MODE_FORD_WALK` | profiled |
| `MODE_SWIM_SURFACE` | **enumerated, unprofiled** |
| `MODE_DIVE` | **enumerated, unprofiled** |
| `MODE_CLIMB` | **enumerated, unprofiled** |
| `MODE_TUNNEL_WALK` | **enumerated, unprofiled** |

Needed, per species: which of the four a profile admits, and — separately — which
it is **actively disabled** for. The amendment's phrase is "all allowed modes **and
disabled cases**", and the two are not complements: a mode nobody has specified yet
and a mode a mole is forbidden from using must refuse differently, or the UI cannot
tell a player "not yet built" from "moles do not swim".

An otter that dives and a squirrel that climbs are the obvious cases; the executor
will not assume even those.

## G01-Q3 — Finite spatial and depth extents

No vertical or depth bound is authored anywhere. Needed:

- the maximum excavation depth below the placed ground datum, as a finite integer;
- whether depth is a continuous extent or discrete levels, and if discrete, how many;
- the horizontal extent rule for underground space, if it differs from the surface
  128×128 exterior tile grid.

The building envelopes in `asset_dimensions_and_budgets.json` are explicitly
*above*-datum maxima and the asset ruling states in terms that they **do not set
underground depth or navigation clearance**. So there is no number to extrapolate
from, which is the point of asking.

## G01-Q4 — Construction states, costs and spoil rules

Needed: the tunnel/burrow construction lifecycle as an explicit state list; what
each transition costs in materials and work; and the **spoil rule** — what happens
to excavated earth, whether it is an item that must be hauled and stored, whether
it can be discarded, and whether discarding is free.

The spoil rule is the one most likely to be skipped and it changes the economy:
if spoil is a real item, every excavation generates hauling work and consumes
storage, and `inventory.gd`'s container capacities become a digging constraint.
If it evaporates, digging is nearly free. **The executor cannot pick.**

## G01-Q5 — Interruption and hazard policy

Needed: what interrupts travel in progress and what the resident does when it
happens; whether `MODE_DIVE` carries an oxygen or duration budget and what expiry
does; whether excavation or traversal can injure, and through which of the GDD's
existing `Injury` kinds.

`injury` is modelled (kind / severity / untreated_hours / care_progress) with
healing and **no damage or attack model** — CombatSystem is battle-layer and the
settlement spec has no damage path. So a drowning or cave-in hazard needs to be
expressed in terms the settlement layer already has, or the ruling needs to say
that a new one is being added.

## Two smaller items in the same area

**Profile coverage.** `PROFILE_SPECIES_KEYS` is mouse, mole, otter, squirrel —
four. DEC-039 approved a badger height and the GDD's admitted species list is
longer. Does the starter increment stay at four, or does every admitted species
need a ground profile before 05.1b?

**Life stage.** Decision 0095 landed a fixed `ADULT 0 / CHILD 1 / ELDER 2` column
on `residents.gd`, and MOVE-DEP-R02 requires admission to read the stored stage —
which it now does, as of decision 0101. **Only ADULT is profiled.** A CHILD or
ELDER resident is currently refused travel outright. If that is correct for
release 1, the ruling should say so; if not, the non-adult profiles are part of
this gate. **No child/elder adult-coefficient fallback will be invented**, per
MOVE-DEP-R02.

## What the executor will do with the answers, and what it will not

With Q1 and Q2 alone, `profile_clearance_class_into()` stops refusing and the four
unprofiled modes become admissible or explicitly disabled — enough to begin 05.1b's
connected movement on the surface. Q3–Q5 are required for underground work and for
MOVE-TEST-01's burrow/tunnel/deeper-room scenario.

The executor will not close MOVE-G02 (architecture), G03 (UI), G04 (asset/crowd)
or G05 (validation) from this package, and no answer here authorizes paid asset
generation, which the asset generation lock governs on its own axis.
