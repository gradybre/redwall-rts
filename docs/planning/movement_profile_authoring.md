# Movement profile authoring — the Q2 register, with Cycle 3's adopted policy applied

Status: **CYCLE 3 POLICY APPLIED. Q2 IS MATERIALLY ADVANCED AND STILL NOT CLOSED.**
Prepared 2026-09-14 as proposal and evidence only · lane `MOVE-PROFILE-AUTHORING` · code base
`origin/master` at `26f1f8f`.
Revised 2026-09-15 · lane `MOVE-POLICY-REGISTER` · base `origin/master` at `50e78ce` · under
[MOVE-C3-R01](../rulings/2026-09-14_cycle03_movement_policy.md).

**What changed and what did not.** MOVE-C3-R01 adopted named policy rulings, and this document and
its JSON companion now record them. It closed no movement gate, supplied no measurement, and
enabled no row. **MOVE-G01/Q2 remains OPEN** for complete mode and species cost rows, ADULT and
ELDER water and unprotected-climb permissions, real source-bound measured envelopes, support and
contact producers, and the associated G02 contracts. Zero rows are `ENABLED`; zero rows are
`admission_qualified`. Section 9 lists exactly what the ruling corrected in the original package,
which is retained verbatim as a Cycle 3 review input at
`docs/planning/astra_cycles/cycle_03_inputs/`.

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
   must not be described as biological inability." The 32 rows that are now `explicitly_disabled`
   became so by an **authored life-stage and action policy** carrying its own source and its own
   conditions, not by inference from an absent profile — and those same rows still name the
   admission contract they independently fail, precisely so the two cannot be confused.
3. **Proposes no route recentring.** The production root offset stays `(+256,+256)`. A different
   offset needs a separate reviewed position/anchor/save contract.
4. **Marks nothing ready that depends on an unmeasured body dimension.** No row in §4 or in the
   readiness JSON carries `admission_qualified: true`.

Completing this lane does not answer Q2, does not close MOVE-G01–G05 or 05.1b, and does not
change `astra_answered` on the combined `MOVE-ENVELOPES` inbox item. **Applying MOVE-C3-R01 does
not change that either.** The combined OPEN item is preserved; the ruling itself says "Do not mark
the original Q2 question fully answered, enable modes, modify UI contracts or allocate competing
ADR numbers as a consequence of this sidecar."

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

**There is still no fourth state**, and MOVE-C3-R01 §5 forbids adding one meaning "policy-approved
therefore ready". A positive policy permission is recorded on the row as `ordinary_access_policy`
and a Q2 slot's disposition is recorded as `cycle3_disposition`; both are planning fields, neither
is a runtime enum, and neither promotes a row. A row can carry a policy permission and still be
`unresolved_q2` because its profile is unpublished — 144 of them do.

### 2.1 Adult matrix

`adopted` appears only where `movement.gd` actually publishes a profile row. Everything else is
`unresolved_q2`. **No cell in the adult table is `explicitly_disabled`.** The four species
carrying starter profiles are mole, mouse, otter and squirrel, ground and ford only; the other
twelve species and all four connected modes are unresolved. The complete 288-row matrix is in
[movement_profile_readiness.json](movement_profile_readiness.json).

Counts, adults: **adopted 8** · **explicitly_disabled 0** · **unresolved_q2 88**. Unchanged by
Cycle 3: the ruling adds no adult prohibition and no adult enablement.
Of those, the 64 connected rows (16 species × `SWIM_SURFACE`/`DIVE`/`CLIMB`/`TUNNEL_WALK`) match
MOVE-C2-R01's "all 64 adult species/mode combinations" exactly. This is not permission to enable
all 64 later without authoring.

What Cycle 3 **did** add to the adult rows is a positive policy permission with no state change:
under MOVE-C3-R01 §3 supported ground, the authored ford and completed dry supported tunnel
walking are **ordinary settlement access for all sixteen species**, requiring no species-specific
innate permission and **no excavation skill** — walking a finished tunnel is ordinary access, not a
digging specialist's privilege. Qualified protected climbing infrastructure may likewise serve
ordinary access with no species-exclusive veto. Body, stage, posture, grip, cargo, health and
connection qualifications remain conjunctive requirements. **ADULT and ELDER permissions for
`SWIM_SURFACE`, voluntary `DIVE` and unprotected `CLIMB` are expressly still owed** and stay inside
Q2-31.

Register-wide counts after the revision, every one of them a recount over `rows` rather than an
edited figure: **288 rows · adopted 8 · explicitly_disabled 32 · unresolved_q2 248 ·
admission_qualified 0**, with 144 rows carrying the ordinary-access policy permission and 16 CHILD
`CLIMB` rows reported separately as conditional. `tools/test_movement_profile_policy.py` recomputes
all of it and refuses a `totals` block that disagrees.

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

DEC-032 and HAZ-001 forbid **CHILD hazardous work and excavation**, a work/job class recorded as
`PROHIB-CHILD-HAZARDOUS-WORK` and deliberately **not** a mode row. MOVE-C3-R01 §2 restores the
clause the original package omitted: DEC-032 says "No ordinary productive labor assignments,
**hazardous expeditions** or excavation jobs." Child excavation remains prohibited even though
properly supported dry excavation adds no HAZ danger flag, and a helping animation may not secretly
produce inventory or production XP.

### 2.3.1 Q2-32, answered: entry is prohibited, recovery is not entry

**MOVE-C3-R01 §2 settles the slot this package opened.** New deliberate CHILD travel through a
HAZ-001 dangerous connection is prohibited, irrespective of whether the intention is work, needs,
play or learning, a direct move, an expedition or accompanying an adult. It is recorded as
`PROHIB-CHILD-HAZARDOUS-ENTRY`.

| CHILD action | Disposition | Rows |
|---|---|---|
| Voluntary `SWIM_SURFACE`, voluntary `DIVE` | **`explicitly_disabled`.** Consent, a direct order, an escort's presence and a skill value cannot override it. | 32 — `RC_CHILD_WATER_PROHIBITED` |
| **Unprotected** `CLIMB` | Prohibited **as a variant of the row**, not as the whole mode | recorded under `RC_CHILD_CLIMB_CONDITIONAL.climb_action_variants.unprotected` |
| **Protected** `CLIMB` on a qualified HAZ-003 connection | Eligible for **nonproductive ordinary access** with a compatible child profile | same row, `…variants.protected` |
| Ground, the authored ford, completed supported tunnel | Permitted nonproductive access; not prohibited by child stage alone | 48 — `RC_CHILD_NONHAZ` |

Four boundaries the ruling draws that the register must not blur:

- **A child being rescued from water is not a child entering water.** The prohibition is a
  **new-entry** restriction — not immunity, not disappearance, and not a ban on recovering a child
  already in danger. Occupancy, retained air, cargo and injury are preserved for an existing
  distressed occupant, and only its validated committed return/recovery or an eligible rescue
  executes. A carried child is a patient in HAZ-004's checked relationship, not a self-swimming
  actor. The register records this as `recovery_is_not_entry`, and it is **not a row**: no leaf in
  `rows` describes recovery. Rescue grants no child voluntary mode, cannot schedule hazardous
  leisure travel under a rescue label, and children do not become productive rescue workers.
- **No escort grants a forbidden mode.** An adult accompanying a child confers no permission, and a
  rope icon, a nearby adult or a caller boolean cannot turn an unprotected connection into a
  protected one.
- **Protected access is not work.** Protected access to a platform does not authorize an orchard-work
  job at its landing. A child cannot be assigned an ordinary productive job even when its travel
  path is safe.
- **Not all 48 dangerous-mode CHILD rows are disabled.** 32 are; the 16 `CLIMB` rows are conditional
  on the connection's declared HAZ-003 case and are reported separately as
  `totals.child_climb_conditional`. Protection is a **connection property, not a seventh mode**.

The 16 CHILD `CLIMB` rows and the 48 CHILD ordinary rows all remain `unresolved_q2`: the policy that
would permit them is now settled, and the CHILD profiles and PC-04 rules they need are not.

### 2.3.2 Q2-33, answered: no blanket elder veto

MOVE-C3-R01 §3: **no ELDER-only mode veto, age penalty or stricter danger threshold** is added in
release 1. DEC-032 requires active individual elder roles and says age alone is neither helplessness
nor a universal productivity penalty. The authored action policies and HAZ thresholds apply to an
elder's actual state with their explicitly authored stage profile and PC-04 rules. All 96 ELDER rows
stay `unresolved_q2`, blocked on those profiles and never on age: a missing elder profile returns
not-ready and is **never** replaced by adult coefficients.

### 2.4 Situational prohibitions, and the line MOVE-C3-R01 §5 draws through them

These are authored, already `explicitly_disabled`, and **not** per-species mode rows —
through travel in an incomplete or water-intersecting excavation; dangerous entry without consent
or below the HAZ-001 health/hunger/rest thresholds or with an active untreated injury; a dive
whose declared round trip is not finite and complete or whose `available_air` is below `T + 300`;
a surface swim or climb executed without the float/return, submergence-recovery, protected-support
or fall-landing condition **its connection declares**; removal of an occupied passage or only safe
exit; and free flight, branch-gap jumps, underwater attacks, moving vessels and unsupported
collapse/flood shortcuts.

Every one is **action- or state-conditioned**, and each is lifted by its own stated condition being
satisfied at admission time — never by authoring alone. MOVE-C2-R01 records "Species-wide DISABLED
rows for the four requested modes: zero established by current policy", and that is still zero:
`PROHIB-CHILD-HAZARDOUS-ENTRY` applies to every species, which is exactly why it is **not** a
species restriction. No species is singled out or exempted.

**The correction.** MOVE-C3-R01 §5 finds that the original §2.4 and `PROHIB-SITUATIONAL` put
**missing** float/recovery/support definitions into the same "already explicitly disabled" bucket as
known prohibited actions. They are different, and MOVE-C2-R01's three meanings must survive:

| | Recorded as | Example |
|---|---|---|
| A known prohibited action | **`explicitly_disabled`**, with its action context and source | deliberate child unprotected climbing |
| A required missing profile, measured envelope, recovery definition or actual contact | **`unresolved_q2`** (`AUTHORED_PROFILE_NOT_READY`) | the declared float/return posture that no surface-swim profile yet states |
| A complete permitted profile | **`adopted` → `ENABLED`** only under that meaning's own completeness requirements | none today |

Runtime entry refuses in the first two cases alike, and that shared refusal is what makes the
conflation easy — **but lack of authoring is not an authored inability**. The register now lists the
second bucket separately as `missing_definitions_not_prohibitions`, keyed to Q2-17–Q2-24 and Q2-31,
and `tools/test_movement_profile_policy.py` refuses any row that is marked `explicitly_disabled`
without naming a real authored prohibition that records its own escape conditions.

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
in the readiness JSON's `presentation_gaps`, which no admission validator reads.

`tools/test_movement_profile_policy.py` rule **R06** now fails if any row's `blocking_contract` or
`additional_blocking_contracts` names `BC-RIG`, which is declared `"kind": "presentation"` for
exactly that purpose — and it also fails if `BC-RIG` is relabelled `admission` to get around the
first check. Rule **R07** fails if a `presentation_gaps` id leaks into `evidence_absent`. Both have
negative tests: each is proven to refuse a register that violates it, rather than merely to pass the
one that does not.

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

## 5. Q2 slot register — 35 slots, all still empty, 13 now carrying a Cycle 3 disposition

Every value Q2 must supply, with units, owning contract, and what it blocks. **All 35 values are
still empty**, and MOVE-C3-R01 supplied none: it settled *policy*, which a slot records as a
`cycle3_disposition` with its `decision_source`, its `settled` text and its `still_open` text. The
validator refuses a disposition that carries any number at all. The machine-readable register is
`q2_slots` in the readiness JSON; the groups are:

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
alternative offset and no recentring. MOVE-C3-R01 §7 adds that `(+256,+256)` was never an
unanswered placement preference in the first place; each record still declares its own offset and
measurement verification is still owed.

### 5.1 What Cycle 3 closed, and what each closure still owes

| Slot | Status | Settled | Still open |
|---|---|---|---|
| **Q2-32** | **ANSWERED** | Child hazardous **entry** prohibited for voluntary swim/dive and unprotected climb, all 16 species, no consent/order/escort/skill override; protected climb eligible for nonproductive access; **recovery and rescue preserved** | PC-04 and movement must enforce the action context with no adult fallback; CHILD profiles unpublished |
| **Q2-33** | **ANSWERED** | No elder-only veto, age penalty or stricter danger threshold | The actual ELDER stage profiles; never adult substitution |
| **Q2-34** | **ANSWERED** | Eligibility is **declared in versioned profiles** and explicit connection/equipment/access conditions, not acquired by movement XP or an unrelated work skill; no hidden "trained swimmer" bit, so no new save owner | Authored scenario/resident differences need a real owned input and provenance; a later training progression needs its own acquisition/state/save contract |
| **Q2-35** | **ANSWERED** | GDD §5.2's caps are retained **resident ceilings**, not an auto-copied per-mode row; connected-mode authoring states its own binding; changing mode never expands the satchel, and an absent row is not unlimited capacity | Q2-06 and Q2-12: the actual connected speed, turn, bank-transition and cargo rows |
| **Q2-24** | **ANSWERED IN PART** | Ford semantics — see §6.4 below | Generalized wading depth, new wading sites, bank/step/shore geometry and timing; the per-segment field/API/version change is Movement/G02's |
| **Q2-31** | **ANSWERED IN PART** | The ordinary-access policy for all 16 species; the CHILD prohibitions | **ADULT and ELDER permissions for swim, voluntary dive and unprotected climb**; a complete release profile for every supported case |
| **Q2-15** | **ANSWERED IN PART** | Ordinary walking uses existing awake needs/activity rules, no terrain exertion multiplier, **no travel WU, job output or production XP**; rescue and underwater work are separate phases | The swimming/climbing exertion decision, marked separately and **never given an invented zero** |
| **Q2-04** | Baseline retained | `(+256,+256)` was already the production baseline | Per-record measurement verification |
| **Q2-16/18/19/21/23** | Binding bound, artifact open | The exact HAZ-005 / HAZ-002 / HAZ-003 / HAZ-004 rule each must use, stated as a reference rather than a requested number | State/edge/recovery identities, measured posture and retained air, the permitted profile set and full cost `T`, real attachments or fall geometry, the combined rescue envelope and contacts |

**The other 22 slots are untouched** — Q2-01–03, Q2-05–14, Q2-17, Q2-20, Q2-22 and Q2-25–30. They
are real measurement, geometry and cost authoring work, not choices a policy paragraph fills, and
they keep their units, owners and emptiness.

**Q2-15's units were wrong and are corrected.** The original slot put every `need_and_work_effect`
on "the existing signed denominator-750 remainder in the single health owner". MOVE-C3-R01 §4 and
`godot/scripts/core/needs.gd` distinguish the needs' scaled-rate denominator
`NEED_DENOMINATOR = TICKS_PER_HOUR 750 × MILLI_PER_POINT 1000` from health's signed
`HEALTH_DENOMINATOR = 750`, and work retains its own arithmetic. A shared health integration rule
does not transfer needs and work into the health owner. Both denominators are read out of the
committed GDScript; neither is authored here.

**Already-decided parameters that must not be requested again.** Air 1200, consumption 1/tick,
recovery 4/tick, contingency 300, advisory threshold 450, the protected-assistance construction
prices, the fall formulas and rescue handling all exist in ECON/HAZ-002–006. They supply no water
depth, climb arc, travel speed or rescue geometry, and they are not missing numbers.

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

### 6.4 Two findings that created slots — one of which MOVE-C3-R01 has since answered

**`FORD_WALK` has an id and a bit but no behaviour of its own.** In `movement.gd` the admitted
mode is written to `_cursor_mode` at `_attach_route()` and read back only by `admitted_mode_of()`.
No cell predicate, no cost and no eligibility rule consults it, so `FORD_WALK` and `GROUND_WALK`
are today the same traversal with different labels. That defect is real and still unfixed in code.

**Where this package was wrong, corrected by MOVE-C3-R01 §1.** It is right that Movement enforces
no distinct mode predicate; it is **wrong** to treat GDD §5.1's explicit walkability as merely
geometry with no movement policy. The ford is authored, and the register now records these
semantics:

1. **`FORD_WALK` means supported walking across the explicitly authored ford** — not swimming, and
   **not a generic "any sufficiently shallow water" predicate**. It uses the authoritative
   `world_init.gd` `is_ford()` / `is_walkable()` mask, which the water-column system is not required
   to rediscover.
2. **The mode is derived per route segment, not from the caller's route-wide label.** On the current
   adjacent-cell baseline, a segment with either endpoint on a ford cell requires `FORD_WALK`; an
   ordinary land-to-land segment requires `GROUND_WALK`; a mixed route must satisfy every required
   mode. Corner, clearance and continuous support/sweep checks are retained — endpoint
   classification alone cannot legalize a diagonal through water or an oversized body extending
   beyond supported space.
3. **Costs are inherited unchanged.** The existing ground/ford speed and carry bindings and the
   baseline 10/14 route cost model stand. A ford label introduces no swim multiplier, no oxygen
   charge, no danger surcharge and no fixed entry toll — and equally authors no new bank-transition
   duration.
4. **Ford walking is not dangerous entry.** It does not demand HAZ-001 consent or its health/rest
   entry thresholds, and root Y alone cannot trigger diving air rules. Ordinary health, needs, load
   and profile rules still apply, and the wet ford is not automatically a dry floor-sleep or
   field-care landing.
5. **Two numbers that are not capabilities.** The 128u difference between water surface and ford
   floor is **not** a universal per-species maximum water depth. The 640u land/ford-floor difference
   is **not** an approved step height, ramp or instantaneous vertical transfer. Other river, lake and
   coast water stays outside the baseline walking predicate, and unsupported water must never be
   relabelled ford to avoid a swim profile.

The per-edge state itself is **not** implemented by this register. Movement/G02 owns the explicit
field, API and version change, and old saved route-wide labels must not be silently reinterpreted as
new per-edge state.

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

## 8. What this hands back

1. **35 Q2 slots, all still empty**, each with units, owning contract and what it blocks — 13 now
   carrying a `cycle3_disposition` that records an adopted policy without supplying a value.
2. **Four policy questions answered** (Q2-32, Q2-33, Q2-34, Q2-35) and three answered in part
   (Q2-24, Q2-31, Q2-15). The one remaining policy question with real teeth is the rest of **Q2-31**:
   ADULT and ELDER species permissions for surface swimming, voluntary diving and unprotected
   climbing.
3. **A 288-row readiness matrix** — 8 `adopted`, 32 `explicitly_disabled`, 248 `unresolved_q2`,
   0 `admission_qualified` — whose counts are a recount, reconcile with MOVE-C2-R01's own, and match
   MOVE-C3-R01 §2's stated "32 CHILD species/mode rows".
4. **The refusal-class separation**, so a validator can prove no presentation gap is ever recorded
   as an admission blocker and no admission blocker is downgraded to one — now executable as
   `tools/test_movement_profile_policy.py`, with its negative tests written first.

None of this closes MOVE-G01–G05 or 05.1b, changes the `MOVE-ENVELOPES` inbox item's status,
activates any production catalog, or authorizes paid generation.

---

## 9. What MOVE-C3-R01 corrected in the original package

The 2026-09-14 proposal is retained verbatim as a Cycle 3 review input at
`docs/planning/astra_cycles/cycle_03_inputs/`. Astra's review "corrects several of its source
interpretations", and these are they — each one a place where this document previously said
something the ruling found wrong, not merely incomplete:

| # | What the original package said | What MOVE-C3-R01 ruled |
|---|---|---|
| 1 | §6.4 / Q2-24: the ford is "inherited GDD §5.1 **geometry, not a movement policy**". | §1. Movement genuinely enforces no distinct predicate, but the GDD's **explicit walkability is a movement policy**, and `FORD_WALK` is authored supported walking enforced **per segment**. |
| 2 | §2.3: whether the CHILD prohibition reaches non-work travel "is **not stated anywhere**". | §2. It is. DEC-032's "**hazardous expeditions**" clause was omitted; the package narrowed the policy to hazardous *work* and excavation. |
| 3 | §2.3 / `RC_CHILD_HAZ`: `SWIM_SURFACE`, `DIVE` and `CLIMB` grouped as one unconditional CHILD hazard class. | §2. `CLIMB` is **conditional on the connection's protection case**. Do not mark all 48 rows disabled; replace the unconditional grouping. |
| 4 | §2.4 / `PROHIB-SITUATIONAL`: missing float, recovery and support **definitions** filed with the already-disabled actions. | §5. A **missing definition is `AUTHORED_PROFILE_NOT_READY`**, not an authored inability. Preserve all three MOVE-C2-R01 meanings. |
| 5 | `EV-LIFE-STAGE-COLUMN`: "Storing CHILD is legal; **travelling as one is not**." | §2. Unqualified and wrong. The current refusal is a **missing-profile** refusal, and ordinary child access is policy-permitted as nonproductive travel. |
| 6 | §5 / Q2-15: all `need_and_work_effects` on "the signed **denominator-750** remainder in the single health owner". | §4. Needs use the scaled-rate denominator **750000**; health uses **750**; work keeps its own arithmetic. |
| 7 | §5 / Q2-04: listed as an open slot, "anchor-to-root offset". | §7. The baseline **is already `(256,256)`** — not an unanswered placement preference. Only measurement verification is owed. |
| 8 | §0 rule 1 and the JSON's rule 5: "**every value must remain null**". | Source boundary. That constraint "belongs to its proposal lane; it cannot remain the validator rule for the subsequently adopted register." Replaced with: a supplied policy or binding value must cite an adopted ruling, and unresolved numeric/measurement fields remain explicitly empty. **In this revision nothing was supplied, so every slot is still null.** |
| 9 | §2.1 / `RC_ADULT_TUNNEL`: tunnel walking left wholly unresolved, with excavation capability nearby. | §3. **Completed ordinary access is not exclusive to a digging specialist.** Digging creates space; travelling through finished space is separate. |
| 10 | Q2-33 and Q2-34 posed as open questions about an elder restriction and a learned ability. | §3. **No blanket elder veto**, and **no learned-ability progression** on these six modes in release 1. |

Two further corrections land outside this lane's allowlist and are reported rather than applied:
the ruling's §6 tooling repair (envelope input schema 2 and its residual-error accounting) already
has its own lane and ADR on master, and the `cycle_03_inputs/` snapshot the ruling links to is not
tracked at `50e78ce` — it exists only in the working tree, so whoever owns it must commit it for the
ruling's links to resolve.
