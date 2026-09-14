# Astra follow-up — 2026-09-12

Task: 08_community_scenarios_progression.md
Date: 2026-09-12


MOVE-DEP-R02 supplies the fixed authoritative life-stage column/domain. PC-04 still owns dependent needs/care/work profiles; do not enable children/elders with adult defaults.
Read [the current executor handoff](../rulings/2026-09-12_executor_followup.md) before dispatch.

## Life-stage identity status — 2026-09-12

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
