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

---

# Corrections after Astra's review, 2026-09-12

[Astra's review](2026-09-12_move_g01_review.md) found four material
overstatements in the request above. **The original text is preserved unedited**,
per the review's own handoff instruction; these corrections sit below it so a
reader sees both what was claimed and what was wrong with it.

Each was checked against the code before being accepted. All four hold.

## C1 — The clearance domain already exists. Only the assignment is missing.

The request framed clearance as absent. It is not. `spatial_world.gd` declares
classes over a 512×512 grid of `CELL_SIZE_UNITS = 512` (half-metre) cells, and
`_clearance[cell]` is *"the side of the largest all-passable square whose
**north-west corner** is that cell"* — anchored, not centred, with
`CELL_CENTRE_OFFSET_UNITS = 256`.

**This was readable in that file's own header**, which states that it *"publishes
no body, posture or gear clearance number, because READY_07 §1.2 is explicit that
exact production body/gear clearances are a profile decision."* The request should
have asked the narrower question it actually meant.

What is genuinely missing: each profile's **body/gear envelope** and **proof of
correct placement within the anchored square** — integer local min/max X/Y/Z, the
root/origin, anchor-to-root offset, swept envelopes over entry/travel/turn/exit,
and an explicit margin. `ceil(max(width, depth)/512)` gives a size lower bound and
**does not prove placement**; the 256u centre offset cannot be treated as the
centre of a larger square.

The correction does not soften the refusal: `PROFILE_CLEARANCE_UNSPECIFIED` stays,
and a guessed body width must not be used to turn it into an apparent pass.

## C2 — Settlement health loss already exists. Reuse it.

The request said the settlement layer has no damage path. Wrong.
`needs.apply_health_event(slot, points)` and `needs.set_injury_state(slot, state)`
are both implemented, GDD §5.4/5.5 already assign fishing and foraging health loss
and injury severity, REQ-SET-172 sets untreated damage at ¼ health per hour for
severity 1/2, and REQ-SET-173 owns treatment.

Absence of settlement **combat** does not imply absence of health **loss** — the
request conflated the two. What remains owed is the aggregate Injury
kind/severity/care store, hazard integration, and the new hazard rules themselves.
Fishing's bite/cut/exposure descriptions are not a compiled `InjuryKind` domain
that movement may silently extend.

## C3 — Construction rules exist. Underground needs extensions, not a second system.

REQ-SET-124–128 and 137 already rule delivery before work, consumption when work
begins, 100% refund before work and 80% after (milli-U floor), evacuation before
demolition, and demolition at 25% of declared work returning 50% of materials.

Underground excavation, spoil and backfill are **extensions to that owner**, not a
parallel building or inventory system. The request implied more was missing than
is.

## C4 — Q1 and Q2 do not unblock swimming or climbing.

The request claimed Q1+Q2 would be enough to begin surface work for 05.1b. They
are not: speeds, entry/exit durations, equipment and posture, supported
exit/landing, and **interruption behaviour (Q5)** all apply on the surface too.
Q5 is a predecessor for swimming and climbing even with no underground work
involved.

And **full 05.1b needs G02's architecture bindings after G01** — the task text
never said G01 alone completes it. The request's scoping paragraph was wrong.

## Also corrected

**Mode states are three, not two.** `UNPROFILED` (data or implementation missing —
a development boundary that *may not masquerade as an animal's inherent
inability*), `DISABLED` (an authored restriction with a reason and the exact
circumstance that could change it), and `ENABLED` (a complete cost/eligibility row
exists; entry still checks body, gear, load, health, stage, endpoints, topology
and protected return access). The request asked for two.

No species-mode permission table is approved, and no universal "moles cannot swim"
or "only squirrels climb" may be inferred — the content atlas records training,
assistance, equipment and access beyond species identity.

**Species and life-stage coverage is settled, and not in our favour.** Four
adults-only profiles are a legitimate starter increment but **not** the release
catalog: all 16 admitted species need ground and applicable connected-mode
profiles, and a badger height approval does not make a badger profile.
**CHILD/ELDER immobility is explicitly not an approved release design** — DEC-032
requires visible dependent residents and active elders. `LIFE_STAGE_NOT_PROFILED`
is a temporary refusal pending PC-04, and must not be removed by substituting
adult coefficients.

## Proposals now on the table, awaiting Brendan — not constants

- **Four underground levels at 4 m spacing**, floors at −4096, −8192, −12288 and
  −16384 u from one registered immutable ground datum, surface footprint retained.
  **Unratified engineering candidates.** They imply 65536 tile-level addresses, or
  1048576 half-metre cell addresses fully expanded; neither is a store capacity,
  and full arrays at the inherited row width alone would be 14680064 bytes.
- **Real haulable, reusable spoil** with its own catalog key, mass per U, yield per
  excavation unit and deterministic disposal sinks — not stone or compost renamed.
  A ground pile holds 400000 g, not infinite space.
- **Warned, preventable hazards with rescue**, using existing injury and care
  consequences rather than surprise instant-death rolls.

None is adopted. The executor will not implement any of the three until Brendan
answers.

## DEC-039 provenance

The review could not locate DEC-039 and correctly recorded it as
*"executor-reported, source not located"* rather than disproven.

**It is on `master`, in `docs/setting_decisions.md`** as "DEC-039 — Approved
creature proportions for all five species", landed with the lookdev work.
`SPECIES_HEIGHT_U` reads `[1024, 922, 1178, 1526, 2611]` and every entry of
`SPECIES_STATUS` reads approved. The heights are not to be reverted to the 1024u
squirrel candidate.

The cause of the miss is structural, not clerical, and is fixed in the same change
as this correction: **`DEC-nnn` records live in `docs/setting_decisions.md` while
`NNNN` records live in `docs/decisions/`, and nothing said so.** An auditor looking
in the decision log for a user decision would find nothing, every time.
`docs/decisions/README.md` now states the split.
