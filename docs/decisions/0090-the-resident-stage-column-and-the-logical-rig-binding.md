# 0090 — The resident stage is a stored column; the rig is a species fact that may refuse

Date: 2026-09-12 · Status: **Accepted**

[MOVE-DEP-R02 and MOVE-DEP-R03](../rulings/2026-09-12_movement_dependency_rulings.md)
name the resident owner and the rig/catalog owner for two of the five dependencies
the earlier movement handoff omitted. This record fixes the judgements the
implementation in `godot/scripts/core/residents.gd` required, and names precisely
what it did **not** build. It does not close MOVE-G01, G02, G04 or PC-04, and it
claims none of them.

## Decision

1. **`spawn()` names ADULT; it does not default to it.** MOVE-DEP-R02 says "generic
   spawn requires an explicit validated stage". `spawn_with_stage(species, stage)`
   is that generic entry and validates the stage before allocating anything.
   `spawn(species)` is kept — twenty-odd call sites across five other owners' files
   use it — and is now a one-line delegation that passes `LIFE_STAGE_ADULT` **by
   name**. A GDScript default parameter would have been the same value with none of
   the guarantee: the point is that no non-adult can ever arrive from a call that
   did not say so. `spawn_initial_settlement()` passes `LIFE_STAGE_ADULT` at the
   starter site as well, which is GDD §5.1's "12 adults" and the ruling's "the
   twelve starters pass ADULT".
2. **An out-of-domain stage refuses; it is never clamped.** A clamp writes ADULT
   and loses the caller's error, which is the failure mode this repository has
   already been bitten by twice. Three families are refused explicitly and tested:
   negative values, `LIFE_STAGE_COUNT` and above, and **256** — which is 0 modulo a
   `PackedByteArray` element and would otherwise read back as a perfectly plausible
   ADULT. `0x80000000`, `0xFFFFFFFF` and `0x100000000` are refused for the same
   reason: GDScript ints are 64-bit, so `0x80000000` is *positive* and a naive
   `stage < 0` guard misses it.
3. **There is no stage setter, and that is the rule, not an omission.** DEC-032 via
   MOVE-DEP-R02 introduces no birth, no aging timer, no adulthood transition and no
   age-based death for release 1. A `set_life_stage()` would be public API for a
   rule that does not exist. The stage is written once, inside `_write_spawn_row()`,
   so free-slot reuse initializes it explicitly rather than inheriting the previous
   tenant's value; `despawn()` returns the byte to the canonical unused 0.
4. **The rig is a property of the species row, not of a resident.** MOVE-DEP-R03:
   "no per-resident mutable rig column is needed". The sixteen logical keys are a
   `const SPECIES_RIG_KEY` table transcribed from the ruling, compiled through
   `catalog.gd` as their own `RigDefinition` domain, and bound through each
   species' own key. **No packed column was added for the rig at all** — not even a
   `species_id -> rig_id` array, which would be a third copy of a fact the constant
   table already states and could go stale if either domain were renumbered.
   `rig_binding_by_species_id()` resolves the id back to its key and then does the
   same lookup, so the two forms cannot diverge.
5. **The rig keys are fed to the compiler in DESCENDING order on purpose.** This is
   the one place the work found a real hole in its own test. `rig_<species>_v1`
   sorts exactly the way `<species>` does, so handing the compiler the keys in
   declaration order made "the ids come from `catalog.gd`'s ASCII sort" and "the ids
   come from the order of the constant table" indistinguishable — a mutation that
   replaced the sort with a plain enumeration **survived**. Reversing the input
   makes only the sort able to produce the published ids, and the same mutation is
   then killed.
6. **A missing rig refuses the binding and nothing else.** `rig_binding()` refuses
   CHILD and ELDER with `RIG_STAGE_VARIANT_UNBOUND` rather than handing back the
   adult rig, because MOVE-DEP-R03 requires an explicit `(species, life_stage)`
   binding and none is authored anywhere in this repository. That refusal is a
   **presentation/export gap**. `spawn_with_stage()` never consults the rig tables,
   and a test pins that a CHILD otter spawns, is counted among the living and feeds
   the §5.8 demand denominator while `has_rig_binding(&"otter", CHILD)` is false.
   The 2026-09-12 executor follow-up is explicit: "a missing rig is a
   presentation/export gap, not authority to deny legal simulation."
7. **Storing CHILD is legal; travelling as one is not.** This store answers what a
   resident's stage *is*. `movement.gd` still refuses any stage but ADULT, because
   MOVE-DEP-R02's `_profile_life_stage:B8[4]` starter-catalog column belongs to the
   profile owner. Nothing here derives a child or elder coefficient from an adult
   one, and PC-04 still owns the dependent needs, care, schedule, work and hazard
   rules.
8. **`home` and `bed` must be well-formed or they are refused.** MOVE-DEP-R05 makes
   the owner reference half of a destination's identity. `set_home()`/`set_bed()`
   now refuse a pair such as `(5, 0)` or `(-1, 3)`, which is neither the null ref
   `(-1, 0)` nor anything a generation check could ever validate. `home_is_live()`
   and `bed_is_live()` ask the directory *now*, so a demolished owner's slot being
   reissued to a replacement does not silently rebind the resident.

## Which generation namespace

`slot_of_ref()`, `life_stage_of_ref()`, `home_is_live()` and `bed_is_live()` all
validate against **`entity_directory.gd`'s `_generation`, held on the directory
slot**. They are not `inventory.gd`'s `_c_generation` or `_l_generation`, and not
`navigation.gd`'s `_d_generation`. `is_well_formed_ref()` checks *shape only* and
says so in its docstring: this store holds no building, furniture or container
reference and therefore cannot check which space a non-resident pair belongs to.

## What this does not do, stated plainly

* **The stage column is not persisted or hashed.** MOVE-DEP-R02 requires it in save
  section §4 with an owner/schema increment. No save module exists (see the
  "Blocked" section of `docs/persistence_state_registry.md`), so there is no
  restore writer here either. Inventing one would mean inventing the migration
  provenance rule the ruling forbids: "do not infer an arbitrary loaded resident is
  adult just because old code lacked the column."
* **No measured envelope, clearance, air budget, path cost or depth is introduced.**
  MOVE-DEP-R01 and R04 are other owners' work and none of their values is guessed
  here.
* **`_profile_life_stage:B8[4]`** (+4 bytes, all ADULT) and the change that makes
  movement admission read the resident's actual stage instead of an
  `Admission.life_stage` caller value both live in `godot/scripts/core/movement.gd`,
  which this change does not touch.
* **The memory ledger and the state registry are not updated by this change**, and
  `docs/validation/state_registry_coverage.py` therefore fails `C3` on
  `_life_stage` until the owning documents are edited. The exact rows required are
  in the handoff that accompanies this record. MOVE-DEP-R02's +512 bytes are
  **only** `_life_stage`: `512 rows x 1 byte`, re-derived at runtime by
  `life_stage_payload_bytes()` rather than transcribed, so a column-length change
  moves the number and the test that pins it fails.
