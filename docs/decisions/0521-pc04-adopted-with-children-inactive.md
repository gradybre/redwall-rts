# 0521 — PC-04 adopted with children inactive: hunger wired, the household store built, six gates left open
Date: 2026-10-01 · Status: Accepted

Numbered 0521 because the brief asked for 0521–0529. No `docs/decisions/052*` record existed on any
local branch or in any worktree when this was written (demolition step D1 holds 0531). The setting
decision is **DEC-044**: it was drafted as DEC-043, but the coordinator reported that branch
`feat/demolition-d1` had taken DEC-043, so it was renumbered before commit. Supersedes the
"stays unwired" conclusion of [0511](0511-warden-appointment-and-three-loose-ends-that-stay-gated.md) §4.

## Decision

Brendan adopted PC-04 on 2026-10-01 as
[DEC-044](../setting_decisions.md#dec-044--pc-04-adopted-with-children-kept-inactive): sign off the
design, build the household and care stores, wire the hunger helper into Needs, and **activate no
child anywhere**. His confirmed values are in DEC-044. This record says what was built, where each
piece stops, and why.

1. **Hunger and daily demand carry the life stage.** `needs.gd` copies its nine (stage, size)
   hunger rates from FAMILY-RULES-R01's table at each season change. `residents.gd` reads each
   resident's demand row from the same table instance (`needs.family_rules()`).
2. **The stage stays in one column.** Residents owns `_life_stage` (MOVE-DEP-R02). The production
   sweep is `residents.tick_needs_all()`, which passes that column to `needs.tick_all_staged()`.
   That call reads the column, keeps no copy, and validates every living row's stage before any
   row integrates. `settlement_system.gd` now calls it.
3. **A stage-blind tick cannot reach a composed store.** Residents calls
   `needs.require_life_stages()`. After that, `tick()` and `tick_all()` refuse
   `LIFE_STAGES_REQUIRED`, so a child can never be integrated at the adult rate by omission. A
   standalone Needs store has no stage column; its stage-blind entries integrate the ADULT row, as
   fixtures.
4. **`core/households.gd`** implements FAMILY-STATE-R01's single owner:
   - 256 household rows with an 8-wide member arena;
   - 512 dependent/provider rows bound to the directory generation;
   - 46352 bytes in total, re-derived by `payload_bytes()`.

   Its APIs:
   - binding with stage defaults;
   - household creation: 1..8 living members, persistent-ID order, mixed species, lowest free row
     whose generation can still advance, monotonic IDs that never reset;
   - preferences (0..2 ADULT/ELDER, stored ascending) and willingness (ADULT/ELDER only);
   - structural service assignment;
   - per-tick care integration from caller-stated paired participation;
   - the midnight fairness reset;
   - death/departure cleanup (`detach`/`unbind`), and `release_stale_row_into()` for a row whose
     resident was despawned while still bound;
   - pure care arithmetic (`care_after_tick`, `warning_bits_after`, `eligibility_after`,
     `child_sort_key`);
   - `copy_columns_into` / `columns_refusal` / `restore_columns_into`.

## Why

**Byte-identity is proven against the base, not asserted.** FAMILY-RULES-R01's ADULT row is
`floor(250000·1000·size·season / 10^9)`. That equals the old `floor(250000·size·season / 10^6)`
exactly, and likewise for demand.

`test_family_hunger_wiring.gd` pins two SHA-256 digests. They were captured by running the same
seeded runs on the **unmodified** base 3676652 before any code changed:
- the real settlement pipeline over 4500 ticks across a winter handover and back;
- a 9000-tick standalone run, LCG-driven, over all three sizes.

Each digest covers every persisted Needs column, every daily-demand total and every published
hunger rate. The code changed afterwards, and both digests still match.

**Why pass the column rather than copy it.** FAMILY-C4-R01 says the stage column "already exists;
do not allocate another".
- A Needs-side mirror would be a second stage column, with a restore-ordering rule to keep it true.
- A shared PackedByteArray reference would silently detach on Residents' next write, because
  packed arrays are copy-on-write.
- An argument is read once per tick and cannot drift.

**Why the store is not composed into the settlement.**
- A composed store holds live rows: every ADULT gets a willing bit.
- Those rows are future-affecting state. If they are not saved, a reload silently drops them.
- Saving them needs the §4/§5 owner registration, ordinals and declaration hashes. FAMILY-STATE-R01
  says plainly that the implementation packet allocates those together with the family rules
  fingerprint, and that is gate 3.

So the store is built, tested and validated, and it stops there. For the same reason its registry
rows are `UNRESOLVED` (§4/§5) rather than category 1. Category 1 must equal
`canonical_state_registry.json` exactly (`validate_save_registry_handoff.py`). Adding a canonical
owner is gate 3.

**Refuse-not-migrate is enforced where the store can see it.** A column image carries
`OWNER_SCHEMA_VERSION` = 1, and any other version refuses. Refusing a file with no households block
at all is the section codec's job, and it lands with the codec (gate 3).

**No rules fingerprint changes yet.** FAMILY-RULES-R01 says catalog versions change "when its
values begin affecting the authoritative world". Two facts decide this:
- The values now driving every live world are the ADULT rows, which are numerically identical to
  the constants they replace.
- A CHILD row is reachable only through `spawn_with_stage()`, and no scenario, command or
  admission path calls it with CHILD.

FAMILY-C4-R01 v2 puts CHILL, PLAY/LEARNING, `young_day`, the SET_POLICY selectors and the Injury
bits into ONE versioned family fingerprint at activation (gate 3). Moving the fingerprint now, for a
subset of those domains, would make two fingerprint changes where the package plans one. Stated
consequence: a hand-built save that already held a CHILD row would now integrate that child at
750/1000. No shipping path can produce such a save.

**The selection pass is not built.** `select_care_into()` consumes prepared eligibility and contact
facts from a service planner that does not exist (gate 6). `assign_provider_into()` checks only
structural rules:
- stage;
- the eligibility latch;
- willingness;
- one child per provider.

The instantaneous hunger/rest/health/route gates belong to the pass. The 5632-byte selection scratch
is not allocated until that pass lands.

**One mutant is equivalent.** Deleting "critical forces low" in `warning_bits_after()` survives
every test. The rule is redundant on every input, not merely untested:
- critical can stay set only at care ≤ 2000;
- that is already inside low's set band (≤ 3500), which sets low anyway.

It is kept because the rule is the specification's.

**First mutation pass (superseded by the review follow-up below): 59 mutants, 57 killed, 2 equivalent.** The mutants cover `households.gd`
(47), `needs.gd` (7) and `residents.gd` (5), and the run used the two PC-04 suites. The first pass
left five survivors:
- Three were real gaps, now killed by
  `test_images_that_only_a_strict_or_bound_rule_catches_refuse`: a member listed twice, an equal
  preference pair, and an outward remainder kept at care 10000.
- Two are equivalent:
  - "critical forces low", explained above;
  - `_paired_refusal_into()`'s explicit null-provider test. A null provider ref already resolves to
    `NULL_ROW` one line later and refuses with the same code. The explicit test is kept for
    readability.

## Independent review and its follow-up

An independent `code-reviewer` found three HIGH issues, six MEDIUM and five LOW. All three HIGH
and all six MEDIUM are fixed:
- **H1.** `test_ui_resident_snapshot.gd` ticked a Residents-composed Needs through the stage-blind
  `tick()`, which now refuses. It ticks through `residents.tick_needs_all()`, and the PC-04 focus
  runner now also lists the UI snapshot/card, injury and settlement suites.
- **H2.** The stored binding generation was written but never compared, so a resident despawned
  while still bound let the next tenant of that row inherit its household, and left an image that
  could no longer be saved. Every ref-addressed entry now refuses `HOUSEHOLD_STALE_BINDING`.
  Row readers answer only for the current tenant, and the care tick refuses while a stale row
  exists. `release_stale_row_into()` clears the previous tenant's member entry, its services and
  any preference naming a persistent ID that no present resident holds.
- **H3.** Too few validator rules had a hostile image of their own, and the first mutation figure
  above did not reproduce. There is now one image per rule, with care values chosen so that only
  the rule under test can catch each one.
- **M1.** A fresh store's `served_day` was 0, so its own capture refused. It is now 1, the clock's
  first day.
- **M2.** A resident who died before binding could never be bound, and that made the world
  unsaveable. Binding now accepts a present corpse.
- **M3.** Five non-resident directory rows are created before the fixture's residents, so no
  directory slot equals a typed row.
- **M4.** `child_sort_key()` is now `child_sort_key_into(…, out)`, which refuses rather than
  returning a -1 that would sort first.
- **M5.** `end_service_into()` has a test. `care_remainder_of()` is now exercised.
  `Columns.equals()`, which nothing called, is removed.
- **M6.** The resident panel reads the staged rate.

**Final mutation result: 119 mutants, 116 killed, 3 equivalent.** The set is the reviewer's own
mutants plus the first pass's 59 and 21 more covering the follow-up code (stale bindings, the
release path, the daily-share refusal, the first day and the panel's staged rate). It was run
against the hunger-wiring, household and UI snapshot suites. Two duplicated generation checks
each hid the other, so the members-side copy was removed and the per-row check kept.

The three equivalent mutants are:
- "critical forces low";
- the explicit null-provider test;
- `_served_day`'s field initializer, which `clear()` overwrites in `_init()` with the same
  FIRST_WORLD_DAY.

Two LOW items were also taken:
- the release-build `assert` in `_advance_child()` became an explicit refusal;
- `assign_provider_into()` refuses a provider whose daily share is full.

Three LOW items were left, deliberately:
- the empty `PackedByteArray()` in the standalone-only `tick_all()`;
- `life_stage_code_of()`'s -1 for an empty row, which every caller checks presence before reading;
- task 08.2's "command/save changes" wording. That clause is the contract the amendment specifies,
  and its activation is listed under gate 3.

## Gate state at adoption

| Gate | State | What exists | What is missing |
|---|---|---|---|
| 1 CHILL illness | open | — | Injury `chill_episode`/`chill_active` columns (schema 2), joint hazard/CareHealth ordinal review |
| 2 Departure/separation | open | `detach_resident_into()` performs the store-local cleanup | Lifecycle transaction committing chronicle history first; LAST_CAREGIVER_LEAVING; no departure owner exists (0511) |
| 3 Owner APIs and cross-owner transaction | open | Single-owner APIs, schema-1 column validation, held-barrier restore | §4/§5 registration, ordinals, hashes; atomic admission/lifecycle with Residents/beds/inventory; SET_POLICY selector activation; rules fingerprint; settlement composition |
| 4 PC-03 templates | open | `daily_demand_for_cohort()` is ADULT by name | Family-enabled scenario, household templates, stage-mixed admission forecast |
| 5 Child movement/rigs | open | — | Stage-qualified movement profile, geometry, bed/contact qualification, rig bindings (`rig_binding()` still refuses CHILD) |
| 6 Service/task graph | open | Pure sort key; per-tick care integration from stated participation | Selection pass and scratch, safe-work interruption, reservation arbitration, Relationship pair-day columns, notices |

## Consequences

- **Documents reconciled.**
  - FAMILY-STATE-R01 used to say "command wire design remains a blocker". It now points at
    FAMILY-LIFE-R01's drafted SET_POLICY selectors 2/3 and says only their activation is open.
  - FAMILY-C4-R01 asked for the queue's "Friend pairs" phrase to be corrected. The INIT-B queue entry
    already reads "six reciprocal affinity-20 pairs (not friend=true at threshold40)", so the
    paragraph now records that.
  - The 017a/017b/019a numbering is placed against ARCH-TICK-003 in `systems_architecture.md` §5.
    The midnight reputation-versus-immigration producer order is NOT a documentation change. It
    stays with task 08.4 and gate 6.
- **GDD amended.**
  - §5.2's hunger row and a new "PC-04 family amendment" section put the stage multiplier in force.
  - The section also records three changes as adopted, each marked "applies when children are
    active": the child mood formula (/12 with care), the same-day relationship-eviction protection,
    and REQ-SET-036's +8 being reserved for medical care.
- **Ledger.** +46352 in §3 and the ARCH-MEM-009 trail, stacked on decision 0531's +405533 when
  master's demolition D1 merged in. Planned payload is 70467712, the live world plus reserve is
  78856320, and headroom is 21143680. The rejected two-world peak is 143078835. The 288-byte FAMILY-RULES-R01 table, and Needs' hunger copy growing from 24 to
  72 bytes, are derived catalog values inside the existing read-only catalog arena, so they get no row.
- **The resident panel already shows the staged rate.** `ui_resident_snapshot.gd` reads the
  captured resident's stage from Residents and calls `hunger_rate_milli_per_hour_for_stage()`, so
  a CHILD row (reachable through `spawn_with_stage()` or a restored image) is never shown the adult
  250/hour while the sweep applies 187.5.
- **Before any child is activated** the store must be composed into the settlement and saved
  (gate 3), and that composition must call `unbind_resident_into()` before Residents despawns a
  bound row. The store survives a skipped unbind -- it refuses the stale binding and offers
  `release_stale_row_into()` -- but nothing ties the two calls together yet.
- **No canonical-registry number is used.** This work does not touch
  `canonical_state_registry.json`: no registry version, source contract ID or record number is
  taken, so nothing needs rebasing at integration beyond the ledger totals.

## Source

[DEC-044](../setting_decisions.md#dec-044--pc-04-adopted-with-children-kept-inactive);
[FAMILY-C4-R01](../planning/family_execution_package.md), [FAMILY-LIFE-R01](../planning/family_lifecycle_contract.md),
[FAMILY-STATE-R01](../planning/family_state_schema.md), [FAMILY-RULES-R01](../planning/family_rules_api_contract.md);
decision 0158; evidence under `docs/validation/evidence/family-contract-2026-09-19/`.
