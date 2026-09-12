# Task 08 — Community, care, scenarios and progression

2026-09-09 · PLANNED milestone card. **Begin authoring contracts now** while
runtime integration follows 05–07.
Owners: setting_decisions DEC-001–035 within their recorded scopes; GDD §5.2,
§5.8, §5.11; SET-AMEND-001 admission/feasts; UI community/roster/feast/chronicle/
scenario/progression requirements; ARCH-SYS-007/017/018/019/020 and corresponding
task-08 requirement CSV rows. Lower GDD adult-only/single-scenario coverage is
incomplete for adopted policies, not authority to remove them.

## Required contracts and sequence

- [ ] 08.1 **PC-03 scenario package:** define a finite roster covering original
  communities, Abbey and novel/era settings, and founding/restoration/established
  premises with explicitly valid combinations. Each row supplies scenario ID,
  era/cast, player role, admission profile, protected and flexible source facts,
  map/init/catalog hashes, exact residents/inventory/building condition/ecology,
  objectives/loss/continuation, onboarding and title/selection text. Unknown
  quantities are authoring blockers. Do not duplicate Refuge values as defaults.
- [ ] 08.2 **PC-04 family amendment:** fixed life stages and dependents, household/
  caregiver references, schedules, service/care work, quantities and needs,
  injury/illness/exposure/rescue/death, early warning and non-graphic presentation.
  All living stages share the 256/512 limits. No hazardous child work; births,
  aging or automatic adult coefficients are not adopted. Include schema/bytes,
  command/save changes and fixtures before enabling dependent profiles.
- [ ] 08.3 Implement real relationships, care, mood memories, grief/remembrance,
  recovery and departure intent; commit deaths/departures with correct reference,
  inventory and history handling. Use exact existing effect values; do not attach
  arbitrary buffs to humor, dialect, stories or spiritual experiences.
- [ ] 08.4 Implement scenario admission and exceptions, petition expiry,
  bed/population constraints, manual acceptance and deterministic arrivals.
  Integrate ACCEPT_CANDIDATES/ASSIGN_BED/APPOINT_WARDEN and relevant care commands.
  Keep reserved hunter skill inactive and check each candidate atomically.
- [ ] 08.5 Implement feasts and CONFIRM_FEAST, chronicle, meaningful named events,
  contextual voices and civic Charter. Preserve uncertain supernatural truth
  and era-specific identity. Finite event definitions specify trigger, effect,
  repeat prevention, recipients and saved state. Open DEC content boundaries
  block only affected authoring; source torture is not an enabled mechanic.
- [ ] 08.6 **PC-06 progression:** resolve ARCH-CONFLICT-004's continuous winter
  requirement/award instant and budget saved interval state, then implement
  milestones, completion screen, continuation, collapse and autosave protection.
  Add every approved scenario through task-04 initializer and shared simulation.

## Creative retrieval and ownership

The source lead reads library README/authoring/continuity/location/material
handoffs and queries individual book-qualified records. All twelve available
books were inspected; Eulalia full text and the Salamandastron gap remain absent.
Six-book emphasis does not restrict access to the full library. A planning-time
bounded example, `mossflower::MF_place_log_a_log_s_cave`, locates an inhabited
working dwelling; it supplies no canonical dimensions or building recipe.

Source facts, interpretation and AI-authored completions stay separate. Reconcile
recipe candidates through task 07's quantities/work/unlocks before activation.
Use original ImageReference files with the art guide for relevant briefs,
recognizable anatomy and varied domestic forms. Do not conflate reused offices
or characters in different eras. Preserve warm humor and light dialect.

Parser/source lead owns scenario/family drafts; lead resolves owning-spec
changes; game coder owns community/care stores; UI owner roster/story; independent
QA checks policy, family warnings and player experience as well as state math.

## Acceptance and completion boundary

Require fixture tables for every scenario (including rejected incompatible
roster/save), capped mixed-stage allocation, stale caregiver/bed references,
refuge exception expiry, interrupted feast, deaths/grief, rescue warnings,
reachable care, deliberate capacity failures and no lost history. Test exact
progression interval edges, collapse not overwriting prior autosave, victory and
continuation. Supply actual Mac player-flow captures with non-color warnings.

This task establishes the authored community/scenario/progression scope only
after numerical amendments and runtime acceptance. A roster document alone does
not implement dependents or scenarios. Feed all new state into task 09 parity
and all scenarios into task 10 qualification; do not claim three-year survival
from arithmetic or three point samples.

## Astra follow-up — 2026-09-12

MOVE-DEP-R02 supplies the fixed authoritative life-stage column/domain. PC-04 still owns dependent needs/care/work profiles; do not enable children/elders with adult defaults.
Read [the current executor handoff](../rulings/2026-09-12_executor_followup.md) before dispatch.

### Life-stage identity status — 2026-09-12

Implemented in `godot/scripts/core/residents.gd` under
[decision 0095](../decisions/0095-the-resident-stage-column-and-the-logical-rig-binding.md):

- [x] `Resident.life_stage:B8[512]`, ADULT 0 / CHILD 1 / ELDER 2, COUNT 3 as a bound only
- [x] Explicit validated stage on the generic spawn; refusal, never a clamp, for an
      out-of-domain value (including 256, which truncates to ADULT in a byte column)
- [x] Explicit initialization on free-slot reuse; canonical unused 0 on retirement
- [x] Generation-checked reader that rejects a stale reference rather than answering
      from whichever resident later took the slot
- [x] The twelve starters pass ADULT at the starter site
- [x] The sixteen MOVE-DEP-R03 logical rig identities, compiled in ASCII order and bound
      through each species' own key; CHILD/ELDER variants refuse instead of inheriting
      the adult rig, and that refusal does not deny a spawn

Still open and **not** claimed by that work:

- [ ] PC-04's dependent needs, care, schedule, work and hazard rules. Nothing derives a
      child or elder coefficient from an adult one, and no non-adult may run through
      adult coefficients at runtime.
- [x] Movement admission reads the resident's actual stage rather than an
      `Admission.life_stage` caller value, in `godot/scripts/core/movement.gd` under
      [decision 0101](../decisions/0101-travel-admission-reads-the-stored-life-stage.md).
      A caller that disagrees with the store refuses on its own code
      (`LIFE_STAGE_DISAGREES_WITH_RESIDENT`), distinct from a resident whose own stage
      has no profile (`LIFE_STAGE_NOT_PROFILED`, unchanged). CHILD and ELDER residents
      refuse; this enables no non-adult travel and claims nothing of PC-04.
- [ ] `_profile_life_stage:B8[4]` as a **packed column** on the starter profile catalog.
      The per-profile ADULT binding exists as `movement.gd`'s `PROFILE_LIFE_STAGE` const
      table and admission matches against it, so the behaviour is in place; the four
      bytes are not allocated. Blocked on a `docs/persistence_state_registry.md` row —
      `state_registry_coverage.py` `C3` fails without one, and `C5` forbids folding it
      into the width-4 `StarterGroundProfile catalog` row — plus the §2.3 ledger row
      decision 0083 already owes. Exact rows and byte arithmetic in decision 0101.
- [ ] Save section §4 persistence and hashing of the stage column with its owner/schema
      increment, plus the migration provenance rule for schemas that predate it. No save
      module exists yet.
- [ ] The +512-byte memory-ledger row in `docs/systems_architecture.md` §2.2 and the
      `_life_stage` row in `docs/persistence_state_registry.md`.
      `docs/validation/state_registry_coverage.py` fails `C3` until they land.
- [ ] The `StarterGroundProfile` §2.3 ledger row decision 0083 owes, at 96 bytes today and
      **100** once `_profile_life_stage` lands (6 x 4 x 4 + 1 x 1 x 4). `movement.gd`'s
      running owed total is 12384 bytes now and 12388 then.

## EH injury and rescue contracts

[HAZ-001–006 and EH-04/05](../planning/underground_economy_hazard_handoff.md) bind the existing InjuryKind domain to exact air/exhaustion/fall/rescue rules and one health-rate owner. PC-04 remains responsible for dependent-resident coefficients/profiles; this package grants no child hazardous work or adult fallback.
