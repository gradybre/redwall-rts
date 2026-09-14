# 0132 — `needs.gd`, `residents.gd` and `jobs.gd` publish their columns and rebuild the rest

Date: 2026-09-12 · Status: **Accepted**

Extends [decision 0105](0105-the-directory-publishes-its-columns-and-rebuilds-the-rest-on-restore.md)
from `entity_directory.gd` to the three largest §4 COMPONENT_COLUMNS owners. Those stores
could be encoded but not captured from or applied to: every reader they publish answers
for a **live** row, so a released row's retained bytes — which the persistence registry
requires to survive verbatim — were unreachable without reading another module's
underscore columns. No module in this repository does that, and none of the blocked lanes
was willing to be the first.

This record does **not** certify a release save, does not close 09.2, and does not add a
§4 or §5 codec. It publishes the store-side halves those codecs need.

## Decision

1. **The 0105 shape, three times: `copy_columns_into()`, `restore_columns()`,
   `last_column_refusal()`, `state_bytes()`.** Caller-owned buffers refilled in place;
   the copies are snapshots, never aliases. Packed arrays are passed by reference in
   Godot 4 — re-verified on 4.7.2 for a class member as well as a local before any of
   this was written.

2. **The buffers travel in a `Columns` inner class rather than as positional
   parameters, and that is the one deliberate departure from 0105.** The directory has
   six columns; `needs.gd` has twenty, `residents.gd` nineteen and `jobs.gd`
   forty-two across two sections. A forty-two-parameter function is not reviewable and
   its call sites cannot be checked by eye. `Columns` is allocated once to the declared
   extents, holds one named public field per category-1 column in ordinal order, and
   carries `clear()` and `equals()`. It is one object per save or per load, sized by
   capacity and not by population, so ARCH-MEM-001's ban on per-entity objects is not
   engaged; `save_section_directory.gd`'s inner `Record` is the same pattern.

3. **The column list and its ORDER are transcribed from the registry, never chosen
   here.** Each store publishes `COLUMN_KEYS`, `COLUMN_TYPE_CODES`, `COLUMN_EXTENTS`
   and `COLUMN_COUNT` (`jobs.gd` publishes `SECTION4_*` and `SECTION5_*`, because two
   sections mean two ordinal spaces numbered from zero each). The suites re-read
   `docs/planning/canonical_state_registry.json` and compare ordinal by ordinal, so a
   reordering fails rather than ships. `docs/persistence_state_registry.md` and the
   JSON artifact **agree** for all three modules; nothing had to be adjudicated.

4. **Every category-2 member is rebuilt from the installed columns, and the rebuild is
   the validator wherever one exists.**
   - `needs.gd`: `_present_count` and `_living_count`. ARCH-SAVE-005's 256-living cap is
     checked against the **recomputed** number before a byte is installed.
   - `residents.gd`: `_live_slots` refilled ascending, `_live_count`. The validator is
     the **directory resolution**: each present row's `(_ref_slot, _ref_generation)`
     must name a live `KIND_RESIDENT` slot whose typed row is that row. A directory slot
     owns exactly one typed row, so two resident rows claiming one slot cannot both
     satisfy it — the same property 0105's owner map has, reached from the other side.
   - `jobs.gd`: `_job_persistent_id` and `_agent_persistent_id` refilled from §3 and the
     resident store, `_live_slots` and `_bucket_begin` rebuilt as declared-urgency runs
     ordered by ascending persistent ID, `_live_count`, `_agent_count` and
     `_deepest_continuation_bucket` recounted. Same resolution rule for jobs, plus the
     worker binding checked in both directions and the §5 member chains walked.

5. **Restore ORDER across stores is a real dependency and is enforced, not assumed.**
   §3 before `residents.gd`; §3 and `residents.gd` before `jobs.gd`. A reference the
   directory does not honour refuses; an agent row on an absent resident refuses.

6. **A refused restore leaves the store byte-identical (decision 0059).** Everything is
   checked before the first write; unlike §3 there is no scan that must mutate to find
   its answer, so there is no rollback path at all. `state_bytes()` proves it by
   comparison in every refusal test.

7. **A separate refusal namespace per store, every code prefixed `COLUMN_`.** These
   stores answer operations through an `OpResult` the caller holds; a load writing into
   that channel would make one operation report another's problem. As in 0105 the
   spellings are a **proposal** — no ruling publishes a registry for column operations.

8. **`_name_key` is not in `residents.gd`'s API, and the §4/§14 seam is made visible
   rather than papered over.** §4 owns the `_named` flag; §14 owns the string through
   decision 0112's `restore_name()`, which validates the pair. `restore_columns()`
   installs the flag and **empties every name**, because a string surviving from the
   previous world is exactly the concealed corruption NAME-R02 forbids. Between the two
   sections a named row holds a flag with no string, and `unresolved_name_row_count()`
   counts precisely those rows — a count, never a sentinel — so a load that skipped §14
   is observable. No second name path was added.

9. **`needs.gd` gains one constant, `STATUS_COUNT = 7`.** ARCH-SAVE-005 bounds each
   byte "against its `*_COUNT`" and this store had numbered its seven statuses without
   publishing a bound. It is arithmetic over an enumeration the module already declares,
   not a new policy value.

10. **The five reserved JobAgent columns must be zero.** `_agent_path_id`,
    `_agent_path_cursor`, `_agent_lease_expiry`, `_agent_blocked_tick` and
    `_agent_manual_until` have no writer; the registry says §4 "must write them as
    zeros and MUST NOT repurpose these v1 bytes". `restore_columns()` enforces that,
    which is the rule transcribed rather than a new one — and the refusal is where the
    rule will move when those owners land.

## What mutation testing changed about the code

Thirty-two mutation runs over twenty-six distinct sites, one mutation per Godot
invocation, each production file restored and `shasum -a 256` byte-compared against a
pristine copy afterwards. Every site ends killed. **Five runs survived on first
attempt.** Three of them were real findings — checks no input could reach — and were
removed rather than papered over with a test that could not fail:

- The worker-binding **count comparison** (`named != bound_jobs`). Each per-row walk
  already proves its own row's opposite half resolves back to it, so the two maps are
  inverse wherever they are defined and the totals can never disagree.
- An **`agent_present != 1` guard** in the job→agent walk. `_column_agent_refusal()` runs
  first and has already proved every released agent row carries the null job pair, and a
  live Job's own reference is never null, so the following comparison refuses that case
  on its own. Removing the guard changed no behaviour, and the case it was guarding now
  has a test that **is** reachable: a cleanly released agent row whose job still names it.
- The **generation half** of the job→agent reference comparison. The agent→job walk has
  already resolved that agent's full pair through the directory, and a directory slot
  carries exactly one live generation, so an equal slot with a different generation is a
  state the earlier walk refuses.

The other two survivals were missing coverage, and the tests were strengthened:

- Deleting the **slot half** of the job→agent comparison survived, because the remaining
  generation check covered every input the suite offered. It is killed now by a case only
  that half can catch: **two live jobs claiming one worker**, deliberately on the same
  directory generation so nothing else can separate them.
- Widening the **negative** need-remainder bound by one survived a positive-only
  boundary test. Decay leaves a negative retained remainder and is the common case, so
  the side that matters most in practice was the side not covered. Both edges are pinned
  now.

One fixture was strengthened pre-emptively rather than in response to a survivor, and it
is worth recording because the weakness is invisible: the jobs fixture **destroys its
first job and lets the last one reuse that low slot with a high persistent ID**, so
ascending-slot order and ascending-ID order disagree inside one urgency run. In a store
built strictly by creation order the two sequences are identical and an index sorted by
the wrong key passes every ordering assertion. With the reuse in place, swapping the sort
key kills it.

A cycle in a member chain kills its mutant by **non-termination**, not by an assertion:
removing the `JOB_CAPACITY` step cap made the run exceed the harness alarm with no
summary line at all. That is the failure mode
`test_a_cyclic_member_chain_refuses_instead_of_hanging` is named for, and the verdict is
recorded as a hang rather than as a failure count.

The continuation bound is checked **behaviourally** and could not be checked any other
way: `_deepest_continuation_bucket` has no public reader, and `_admit_into()` skips its
agent walk entirely when the admitted bucket is deeper than the bound. A restore that
left the bound at "nobody is scanning" therefore leaves a restored continuation alive
through an admission that must clear it — silently, and only in a world loaded from
disk. The test creates a job after the restore and requires the continuation to be gone.

## Consequences

- **The five blocked codecs can capture and apply against these three stores.** What
  they can do is exactly this: read every category-1 column of `needs.gd`,
  `residents.gd` and `jobs.gd` including free rows, and install a validated set back.
  **No claim of release-save completeness is made**: there is still no §4 or §5 codec,
  and §14 must run after §4 for names.
- `restore_columns()` discards the previous world wholesale. A slot index taken before
  the call belongs to a different world; every docstring says so.
- `residents.gd`'s header no longer claims "there is consequently no restore writer
  here". That sentence was written when none existed. The migration half — refusing a
  pre-`_life_stage` schema — remains the codec's through `owner_schema_version`, because
  a store handed a column set cannot see which schema produced it.
- `_rebuild_live_index()` allocates one `PackedInt64Array` of sort keys on the load
  path. It is cold-path local scratch, freed on return, and is not a column; the
  alternative was an O(n²) insertion sort over up to 8192 live jobs.

## Rows owed to files outside this work's allowlist, reported and NOT applied

No new **packed column** was added to any of the three stores, so **no ledger byte is
owed**. Everything published is a reader, a validator, or a refusal code.

- `docs/persistence_state_registry.md`, one category-3 member row per store for
  `_last_column_refusal` (`needs.gd`, `residents.gd`, `jobs.gd`), alongside the existing
  category-3 rows. **A refusal-code `StringName` is a scalar: it is not a packed column,
  it is not persisted, it is excluded from `state_bytes()`, and it owes no ledger byte.**
  Stated explicitly because that is the question the ledger will be asked.
- `docs/persistence_state_registry.md`, `needs.gd` section: `STATUS_COUNT` is a new
  public constant, not state; it owes no row, and is listed here only so the next reader
  of that section is not surprised by it.
- If the registry is taken to record *how* each category-2 member is restored, three
  notes are owed: `needs.gd`'s counters, `residents.gd`'s active list and `jobs.gd`'s
  §8 index rows are now rebuilt by `restore_columns()` and not only by their own
  spawn/despawn paths.

`state_registry_coverage.py`, `ready07_arithmetic.py`, `decision_numbers.py` and
`validate_save_registry_handoff.py` all pass without those rows, because they check
packed columns and declared ordinals.

## Source

- [Decision 0105](0105-the-directory-publishes-its-columns-and-rebuilds-the-rest-on-restore.md)
  — the API shape, the separate refusal namespace, `state_bytes()`, and the rule that
  the rebuild is the validator.
- [Decision 0103](0103-section-3-writes-six-columns-and-rebuilds-the-rest.md) — why a
  derived index is rebuilt rather than persisted.
- [Decision 0059](0059-allocate-before-consume-is-a-repository-wide-rule.md) — allocate
  before consume.
- [Decision 0112](0112-one-resident-owned-name-validator-and-the-section-14-owner-wrapper.md)
  — `restore_name()` and the one shared name validator, reused and not duplicated.
- [Decision 0017](0017-party-work-versus-single-job-worker.md) — the coordinator/member
  chain whose order is observable and therefore written.
- `docs/persistence_state_registry.md` and `docs/planning/canonical_state_registry.json`
  — the category-1 lists and the declared ordinals, transcribed.
- `AGENTS.md` — integer authoritative state, the 256 living cap, `EntityRef` shape.
