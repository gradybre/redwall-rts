# Movement profile authoring — proposal and evidence package for the unresolved Q2

Status: **PROPOSAL AND EVIDENCE ONLY. Q2 IS NOT ANSWERED BY THIS DOCUMENT.**
Prepared 2026-09-14 · lane `MOVE-PROFILE-AUTHORING` · code base `origin/master` at `26f1f8f`.

Authority read and not reopened:
[MOVE-C2-R01](../rulings/2026-09-14_cycle02_movement_envelopes.md),
[Cycle 2 report](astra_cycles/cycle_02.md) "Exact change boundaries",
[SET-MOVE-001](../movement_direction_amendment.md),
[MOVE-DEP-R01–R05](../rulings/2026-09-12_movement_dependency_rulings.md),
[MOVE-G01 review](../rulings/2026-09-12_move_g01_review.md),
[movement contracts](movement_contracts.md),
[starter ground profile](movement_starter_ground_profile.md),
[species rig identity](species_rig_identity.json),
[DEC-039/DEC-040](../setting_decisions.md),
[SET-MOVE-ECON-001](../underground_economy_hazard_amendment.md).

Machine-readable companion: [movement_profile_readiness.json](movement_profile_readiness.json).

---

## 0. What this package is, and the four things it must never do

Astra's Cycle 2 handoff is the binding scope sentence:

> MOVE-PROFILE-AUTHORING is proposal and evidence work only: missing policy/cost values stay
> explicitly unresolved until the Q2 ruling. Production movement remains blocked on approved
> profiles and measured fit evidence.

Accordingly this document:

1. **Invents no dimension, cost, speed, air budget, depth or clearance value.** Every unknown
   below is a named empty slot with its units and its owner. There is no placeholder, no
   "example", no "reasonable default". A slot with a number in it in this document is an
   *inherited* value with a cited source, never a new one.
2. **Infers no biological inability from a missing profile.** A species with no authored row for
   a mode is `unresolved_q2`, never `explicitly_disabled`. MOVE-C2-R01: "Missing production data
   must not be described as biological inability."
3. **Proposes no route recentring.** The production root offset stays `(+256,+256)`. A different
   offset needs a separate reviewed position/anchor/save contract.
4. **Marks nothing ready that depends on an unmeasured body dimension.** No row in §4 or in the
   readiness JSON carries `admission_qualified: true`.

Completing this lane does not answer Q2, does not close MOVE-G01–G05 or 05.1b, and does not
change `astra_answered` on the combined `MOVE-ENVELOPES` inbox item.

---

## 1. The six modes

The mode enum is compiled in `godot/scripts/core/movement.gd` and is the whole traversal domain.
There is no seventh mode and no `FLIGHT` mode; free flight is outside settlement scope
(SET-MOVE-001 §1), and MOVE-DEP-R03 keeps sparrow and kestrel grounded **with their own
anatomical rigs** — that is a scope exclusion, not a species prohibition on any of the six.

| Mode id | Mode | System-level adoption | Profiled in code today |
|---:|---|---|---|
| 0 | `GROUND_WALK` | Adopted (baseline settlement travel) | **Yes** — bit set for 4 adult starter profiles |
| 1 | `FORD_WALK` | Adopted (GDD §5.1 natural ford) | **Yes** — bit set for the same 4 profiles |
| 2 | `SWIM_SURFACE` | **Adopted as required** — SET-MOVE-001 §1 | No — refuses `MODE_NOT_PROFILED` |
| 3 | `DIVE` | **Adopted as required** — SET-MOVE-001 §1 | No — refuses `MODE_NOT_PROFILED` |
| 4 | `CLIMB` | **Adopted as required** — SET-MOVE-001 §1, DEC-035 | No — refuses `MODE_NOT_PROFILED` |
| 5 | `TUNNEL_WALK` | **Adopted as required** — SET-MOVE-001 §1, DEC-029/031/035 | No — refuses `MODE_NOT_PROFILED` |

**The distinction that matters most in this table.** "Adopted as required" is a *system scope*
statement: the settlement must support these modes at first release, and that adoption is not
reopened here. It is **not** a per-species capability grant. SET-MOVE-001 §1's own boundary column
says the approval does not settle "a blanket innate ability table inferred from species or slide
lists", and MOVE-C2-R01 repeats it: "No table entry grants an innate ability."

So the per-species question and the per-mode question have different answers, and conflating them
is the failure this package exists to prevent:

- **Mode-level, settled:** all six modes are in release scope. Nothing here narrows that.
- **Species-level, unresolved:** which `(species, life stage, mode)` rows become ENABLED or
  DISABLED is exactly what Q2 asks and this document does not answer.

---

## 2. Per-species disposition

Vocabulary, mapped one-to-one onto MOVE-C2-R01's three catalog meanings so a later reader cannot
find a fourth:

| This document | MOVE-C2-R01 | Meaning |
|---|---|---|
| `adopted` | the ruling's `S/N` cell | An authored profile row exists and binds this mode, **and production qualification is still N**. Never an admission grant. |
| `unresolved_q2` | the ruling's `N` / `AUTHORED_PROFILE_NOT_READY` | The required authored profile is missing or incomplete. **Not** a prohibition. |
| `explicitly_disabled` | the ruling's `DISABLED` | An identified **authored** prohibition applies, with its reason and the conditions that can change it preserved. |

### 2.1 Adult matrix

`adopted` appears only where `movement.gd` actually publishes a profile row. Everything else is
`unresolved_q2`. **No cell in the adult table is `explicitly_disabled`.** The four species
carrying starter profiles are mole, mouse, otter and squirrel, ground and ford only; the other
twelve species and all four connected modes are unresolved. The complete 288-row matrix is in
[movement_profile_readiness.json](movement_profile_readiness.json).

Counts, adults: **adopted 8** · **explicitly_disabled 0** · **unresolved_q2 88**.
Of those, the 64 connected rows (16 species × `SWIM_SURFACE`/`DIVE`/`CLIMB`/`TUNNEL_WALK`) match
MOVE-C2-R01's "all 64 adult species/mode combinations" exactly. This is not permission to enable
all 64 later without authoring.

### 2.2 What `adopted` binds, and what it still refuses

The four adopted profiles are `starter.ground.adult.{mouse,mole,otter,squirrel}`, ids 0–3,
revision 1, built in `movement.gd` `_build_starter_profiles()`. Each binds, by **reading** the
value out of `residents.gd` rather than copying a literal: life stage `ADULT`; size class from
`residents.species_size_class()`; ground speed cap from `SIZE_MOVEMENT_U_PER_S` (small 3277,
medium 4096, large 3072 u/s); carry capacity from `SIZE_CARRY_G` (12000 / 16000 / 24000 g); and
the mask `PROFILED_MODE_MASK = (1<<GROUND_WALK) | (1<<FORD_WALK)`.

It binds **no clearance class**. `movement.gd`'s own header states the boundary, quoted rather
than paraphrased:

> WHAT A PROFILE DOES NOT CARRY, NAMED RATHER THAN GUESSED:
>
>   * NO CLEARANCE CLASS. Body, posture and gear envelopes are unstated everywhere […]
>     `profile_clearance_class_into()` therefore REFUSES rather than returning a number, and
>     travel admission does not silently choose one.

and `spatial_world.gd`'s header states the other half:

> A route asks `cell_passes_clearance(cell, clearance_class)` with a clearance class the CALLER
> supplies. **This module publishes no body, posture or gear clearance number** […]

So `adopted` means *the mode binding is authored*, and nothing more. Every one of those eight
cells is `admission_qualified: false`, blocked on `Q2-05`, which is blocked on `Q2-01`–`Q2-04`.

### 2.3 CHILD and ELDER

`CHILD` and `ELDER` are real, stored, fixed stages (`residents.gd` `_life_stage`, B8[512],
ADULT 0 / CHILD 1 / ELDER 2; MOVE-DEP-R02). **No profile row exists for either stage, for any
species, for any mode.** All 96 CHILD rows and all 96 ELDER rows are `unresolved_q2`, blocked on
PC-04 plus their own profiles.

MOVE-C2-R01 is explicit that this is not a mobility ban: their "release immobility is **not
adopted**. […] Do not infer an elder penalty or replace either stage with adult coefficients."

The single authored prohibition here is **not a mode row** and must not be recorded as one:
DEC-032 and HAZ-001 forbid **CHILD hazardous work and excavation** — a work/job class, with no
stated conditions that change it, and PC-04 owning CHILD/ELDER activation.

**A slot this creates rather than closes:** HAZ-001 derives `dangerous` from the action, and
`DIVE`, `SWIM_SURFACE` and unprotected `CLIMB` are dangerous. Whether the CHILD prohibition
extends to CHILD **non-work travel** in those three modes is not stated anywhere. This document
does not decide it; it is slot **Q2-32**.

### 2.4 Situational prohibitions that already apply to every species

These are authored, already `explicitly_disabled`, and **not** per-species mode rows —
through travel in an incomplete or water-intersecting excavation; dangerous entry without consent
or below the HAZ-001 health/hunger/rest thresholds or with an active untreated injury; a dive
without a protected breathable endpoint, a complete finite round trip, or
`available_air >= T + 300`; a surface swim without a declared float/return posture and
submergence recovery; a climb without its protected support or its declared fall landing;
removal of an occupied passage or only safe exit; and free flight, branch-gap jumps, underwater
attacks, moving vessels and unsupported collapse/flood shortcuts.

Every one is **action- or state-conditioned**. MOVE-C2-R01 records "Species-wide DISABLED rows
for the four requested modes: zero established by current policy."

---

## 3. Two refusals that must never stand in for one another

> **A missing rig is a presentation/export gap. A missing clearance, profile or contact contract
> is a movement ADMISSION blocker. They must refuse differently, and neither may be substituted
> for the other.**

MOVE-DEP-R03: "Missing art MUST NOT refuse otherwise legal resident spawn or authoritative
movement: simulation legality comes from approved movement profiles, not render availability."

| | Presentation / export gap | Movement admission blocker |
|---|---|---|
| Examples | rig hierarchy, bone order, bind transforms, sockets, clips, palette, LOD | measured swept envelope, margin, clearance class, mode cost row, posture/grip, gear contract, contact producer, domain geometry |
| Owner | asset / crowd (MOVE-G04), MOVE-DEP-R03 | movement + GDD/balance + spatial + contact owners |
| Refuses | asset export, or that crowd-render representation | `begin_travel()` admission, and any route entering the affected edge |
| Must NOT refuse | resident spawn, stored stage, authoritative movement, save state | — |
| Codes in source | `RIG_STAGE_VARIANT_UNBOUND`, `RIG_CATALOG_INVALID`, `UNKNOWN_RIG` | `PROFILE_CLEARANCE_UNSPECIFIED`, `PROFILE_NOT_PUBLISHED`, `MODE_NOT_PROFILED`, `LIFE_STAGE_NOT_PROFILED`, `CONTACT_NOT_BOUND`, `DOMAIN_NOT_CONTRACTED`, `LAYER_NOT_CONTRACTED` |

**Consequences this package binds itself to.** All sixteen `SpeciesDefinition.rig_id` values exist
and are compiled — **this closes nothing here**: a logical rig identity is not a capability, is
not a measured envelope, and is evidence for no row in §2. Conversely, the absence of a mesh, clip
or palette **must not** appear anywhere as a reason a species cannot use a mode; it appears only
in the readiness JSON's `presentation_gaps`, which no admission validator reads. A future
validator must fail if any row's `blocking_contract` is `BC-RIG`, which is declared
`"kind": "presentation"` for exactly that purpose.

---

## 4. Inherited inputs — settled, NOT reopened

Cycle 2: "DEC-039 height approval and DEC-040/ECON/HAZ parameters remain **inherited inputs, not
questions reopened by this cycle**."

### 4.1 DEC-039 — approved anatomical heights

| Species | u (1/1024 m) | m |
|---|---:|---:|
| mouse | **1024** | 1.00 |
| mole | **922** | 0.90 |
| squirrel | **1178** | 1.15 |
| otter | **1526** | 1.49 |
| badger | **2611** | 2.55 |

Settled and closed — and equally binding in the other direction: these heights "do NOT set
navigation clearance, service reach, step height or movement capability", landmark ratios remain
`PROPOSED_FOR_REVIEW`, and torso-width proxies are not clearance measurements. **No clearance
class in this package is derived from a height.**

### 4.2 DEC-040 and SET-MOVE-ECON-001

Reused, never re-authored: ECON-001's axis-aligned 1024u cut cube (which MOVE-C2-R01 states is
**not** a navigation voxel or body envelope); ECON-002–006 spoil identity, mass, lifecycle and
conservation; HAZ-001's hazard policy, `dangerous` classification and entry thresholds;
HAZ-002's `air_standard_v1` (1200 capacity, 1/submerged tick, 4/breathable tick, +300
contingency, advisory ≤ 450, 125 health/game-hour airless drain, admission `available_air >= T +
300`); HAZ-003's exhaustion/fall/recovery rules including the protected-climb build cost and the
unprotected-climb consequence formulas; HAZ-004 rescue and treatment; HAZ-005's interruption
matrix; HAZ-006's fixtures. All of it "assigns no species capability."

### 4.3 Adopted scope that stays adopted

Persistent constructed tunnels, inhabited underground space, interoperable placed-burrow /
planned-tunnel / free multi-level excavation, surface swimming, diving, connected climbing and
canopy access all remain first-release requirements. Nothing here narrows them, and the absence
of a profile is never evidence against them.

---

## 5. Q2 slot register — 35 named empty slots

Every value Q2 must supply, with units, owning contract, and what it blocks. **All values are
empty.** The machine-readable register is `q2_slots` in the readiness JSON; the groups are:

| Group | Count | Ids | What it is |
|---|---:|---|---|
| A | 5 | Q2-01 … Q2-05 | measured envelope inputs: swept bounds, vertical extent, margin, declared anchor-to-root offset, derived clearance class |
| B | 11 | Q2-06 … Q2-16 | the mode cost row: speed, entry/exit/turn timing, edge cost, posture, grip, load, cargo shapes, gear eligibility, need/work effects, interruption recovery |
| C | 8 | Q2-17 … Q2-24 | mode-specific safety bindings: float/return posture, airless recovery, dive air binding, breathable endpoints, climb recovery case, fall landing, rescue envelope, and the ford predicate |
| D | 6 | Q2-25 … Q2-30 | geometry and domain extents: domains/layers, underground levels, extents, connection openings, water column, canopy |
| E | 5 | Q2-31 … Q2-35 | policy rulings only Astra can make |

**Q2-04 carries a standing warning, not a proposal.** Production placement is `(+256,+256)`. If
either translated minimum is negative, **no larger `k` repairs it** — the correct outcome is an
explicit placement incompatibility, separate from an absent measurement. This package proposes no
alternative offset and no recentring.

The five policy questions: **Q2-31** the ENABLED/DISABLED terminal state for every row;
**Q2-32** whether HAZ-001's CHILD prohibition reaches non-work travel; **Q2-33** whether any
ELDER restriction exists; **Q2-34** whether any mode is a learned ability needing an acquisition
and save owner; **Q2-35** whether the inherited ground speed and carry caps extend to the other
four modes.

---

## 6. Evidence inventory

### 6.1 What exists

Four adult starter profile rows; the six-mode enum; inherited speed and carry caps; the stored
life-stage column for all 512 rows; sixteen compiled rig identities (**presentation only**);
DEC-039's approved heights; the ECON/HAZ parameter set; the anchored clearance predicate and its
1–512 class domain; the contact record schema; and `begin_travel()`'s admission ordering.

None of it qualifies a single row for admission.

### 6.2 What does not exist

Each absence names the file searched and the identifier searched for:

| Absent | Verified how |
|---|---|
| Any clearance class for any profile | `movement.gd` `profile_clearance_class_into()` has no success path after the id guard |
| Any qualified swept envelope with source revisions and hashes | no envelope record in `docs/planning/` or `godot/scripts/core/` |
| Any authored `margin_u` | no occurrence in `docs/planning/` or `godot/scripts/core/` |
| Any air state in movement | grep `movement.gd` for `air`/`available_air`/`AIR` — **zero matches** |
| Any non-ground domain or layer | `spatial_world.gd` `DOMAIN_COUNT = 1`, `LAYER_COUNT = 1` |
| MOVE-DEP-R05's destination-identity columns | grep all of `godot/scripts/` for `_cursor_destination_slot`, `_cursor_contact_key` — **zero matches** |
| Any CHILD or ELDER profile row | `PROFILE_LIFE_STAGE` is four entries, all `ADULT` |

### 6.3 The blockout pose bounds — listed, and qualifying nothing

`godot/assets/lookdev/proportion_comparison_manifest.json` **does** contain per-pose horizontal
and vertical extents in mm for five species. This package records their existence and uses **none
of them**, disqualified on five independent grounds, any one sufficient:

1. `"origin": "Hand-authored blockout volumes built by this script."` — authored proxies, not
   reviewed production geometry with recorded source revisions and hashes.
2. `"landmark_status": "PROPOSED_FOR_REVIEW"` on all five.
3. MOVE-C2-R01: "Torso-width proxy values are not clearance measurements."
4. Four **discrete rest poses**, not the complete sweep over entry, travel, hold, turn, reversal,
   retreat and exit with interpolation coverage and a declared error bound. No equipment, cargo
   or rescue-attachment variant.
5. No `margin_u` and no declared anchor-to-root offset, so Q1 §3 forbids committing them at all.

Recorded as `EV-BLOCKOUT-POSE-BOUNDS` with `"qualifies_admission": false`. Eleven species have
not even this.

### 6.4 Two findings that create slots rather than closing them

**`FORD_WALK` has an id and a bit but no behaviour of its own.** In `movement.gd` the admitted
mode is written to `_cursor_mode` at `_attach_route()` and read back only by `admitted_mode_of()`.
No cell predicate, no cost and no eligibility rule consults it, so `FORD_WALK` and `GROUND_WALK`
are today the same traversal with different labels. The map does define a ford — `world_init.gd`
`is_ford()`, river tiles z = 48..51, `FORD_Y_UNITS = -128` against `WATER_SURFACE_Y_UNITS = 0` —
but that is inherited GDD §5.1 geometry, not a movement policy, and no per-profile water-depth
limit exists anywhere. This is slot **Q2-24**.

**A stale height in a planning doc.** `docs/planning/asset_dimensions_and_budgets.md` still lists
squirrel at 1024 u; DEC-039 approved **1178**, and the lookdev manifest already carries 1178.
Reported, not edited — another lane's file, and DEC-039 is the authority either way.

---

## 7. Premises verified against source

A previous executor request to Astra asserted four missing systems that all already existed. Each
claim here was therefore checked against the file. The three most at risk:

- **"There is no life-stage column"** — *false today.* `residents.gd` `_life_stage` B8[512] exists.
  `movement_starter_ground_profile.md` §1 still says otherwise; that line is historical.
- **"`SpeciesDefinition.rig_id` has no values"** — *false today.* All sixteen are compiled.
- **"No horizontal body envelope is stated anywhere"** — *imprecise.* True of `docs/`, false of
  the lookdev manifest. §6.3 states why they still qualify nothing.

---

## 8. What this hands back to Astra

1. **35 empty Q2 slots**, each with units, owning contract and what it blocks.
2. **Five policy questions** no measurement can answer, of which **Q2-32** is new and is the only
   thing currently preventing 48 CHILD rows from being classified.
3. **A 288-row readiness matrix** — 8 `adopted`, 0 `explicitly_disabled`, 280 `unresolved_q2` —
   whose counts reconcile with MOVE-C2-R01's own.
4. **The refusal-class separation**, so a validator can prove no presentation gap is ever recorded
   as an admission blocker and no admission blocker is downgraded to one.

None of this closes MOVE-G01–G05 or 05.1b, changes the `MOVE-ENVELOPES` inbox item's status,
activates any production catalog, or authorizes paid generation.
