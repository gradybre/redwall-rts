# 0146 — Section 8 binds 8192 and section 9 pins what a primary count means
Date: 2026-09-14 · Status: Accepted

## Decision

Implement SAVE-C3-R01 from
[the 2026-09-14 cycle-03 counts and capacities ruling](../rulings/2026-09-14_cycle03_save_counts_and_capacities.md).

1. **Section 8's `primary_count` is 8192**, bound as
   `save_section_job_indexes.gd::PRIMARY_COUNT`, defined as
   `JobPlannerScript.SERVICE_ROW_COUNT` — the **designated pending-service row
   table**, not the literal. BLOCKER J1 is closed.
2. **The writer and the decoder validate against that compiled constant, not
   against a caller.** `encode_section(record, out)` and
   `decode_section_into(bytes, offset, out)` lost their count parameters;
   `primary_count_refusal()` accepts 8192 and refuses everything else, naming
   7, 4096, 5248 and 14080 and the reading that produces each.
   `descriptor_row_count()` takes no argument and returns 8192.
3. **`SAVE_JOB_PRIMARY_COUNT_UNRULED` is retired**, because an unruled-count
   refusal can no longer be raised. `production_write_refusal()` survives and now
   stands on **BLOCKER J2 alone**, returning `SAVE_JOB_STORE_NO_COLUMN_API`.
4. **Section 9 keeps 512 / 8192 and descriptor 8192, and zero §9 production bytes
   change.** `save_section_navigation.gd` is byte-untouched. What was missing was
   not a value but a *pinned* one: `test_save_section_navigation.gd` gains the
   descriptor assertion the ruling says the suite lacked, plus the two wrapper
   words read at absolute wire offsets 20 and 18558.

Section and owner schema versions all stay where they were: §8 section 1 / owner
1, §9 section 2 / movement 1 / navigation 2. §8's payload stays 363112 bytes, its
section stays 363151, and all 29 field ordinals, types and extents are unchanged.

**This binds counts and nothing else.** It claims no section-8 or section-9
capture/restore adapter, and **no release-save completeness follows from it.**
`release_save_ready` stays false.

## Why

### A multi-table section has no obvious row count, and that is the whole problem

Two shipped sections answered the same question incompatibly.
[Decision 0120](0120-section-8-freezes-its-payload-and-refuses-to-invent-a-primary-count.md)
refused to pick a §8 value and carried the number as a parameter;
[decision 0121](0121-section-9-navigation-persists-used-prefixes-and-declares-its-own-primary-count.md)
declared §9's rather than block the section. Both were defensible. Neither could
be right, because the two files disagreed about **what the field means**, and a
value chosen under one reading decodes cleanly under the other.

SAVE-C3-R01 settles the meaning first: `primary_count` is *a declared primary
physical row extent for that owner block, not a total of every field's extents
and not an occupancy count*, and a multi-table owner must **name its primary
table in its section contract**. The number follows from the designation.

So the reason is written beside each number, in the module headers and in the
constants, rather than the digits alone:

* **§8 = 8192 because the pending-service ledger is what section 8 *is*.** Rows
  0..8191 carry the status, the Job binding, the service day and the sowing gate.
  The other four extents describe that ledger's inputs and edges — 4096 rows of
  per-plot cycle history, 128 designation flags, 640 forage demand rows, 1024
  hive service rows.
* **14080 is refused** — the sum of all five extents is not any table's row
  extent, so no decode could ever check a column against it. A sum makes the word
  describe nothing.
* **5248 is refused** — the sum of the three independent owner capacities, with
  the extra defect of summing an arbitrary subset.
* **4096 is refused** — the per-plot cycle history is a secondary table keyed by
  farm plot.
* **7 is refused** — it was the old suite fixture, chosen *because* it was not a
  real extent, back when the count was carried rather than chosen. It is evidence
  of the gap, never a compatibility precedent.

### 8192 is also column zero's extent, and that coincidence is a trap

`FIELD_EXTENTS[0]` is 8192 too, so a codec that derived the count from the first
column — precisely what REG-R01 forbids — would emit the same byte for the wrong
reason and pass every equality test. The constant is therefore written as
`SERVICE_ROWS`, not as `8192`: the designation follows the *table*, so a future
planner that resized its ledger moves this word and its owner schema version with
it. The suite asserts `PRIMARY_COUNT == JobPlannerScript.SERVICE_ROW_COUNT`
against the planner's own constant, and separately asserts it is none of the
other four extents nor either sum.

### Why the parameters were removed rather than merely validated

The ruling requires validation "against the compiled constant rather than a
caller-supplied positive number". Keeping `encode_section(record, count, out)`
and checking `count == PRIMARY_COUNT` would satisfy the letter, but it leaves an
API whose only remaining purpose is to be rejected, and it leaves the old
`test_primary_count_is_carried_not_derived()` shape alive as a suggestion that a
caller still has a say. Removing the parameters makes the two sections the same
shape: §9 has always had `encode_record(record, out)` /
`decode_into(bytes, offset, out)` and an argument-free `descriptor_row_count()`.
There were no production call sites; only the suites had to change.

A wrong count is now **only** producible by writing it into the wire, which is
where the decoder has to catch it anyway.

### The descriptor is 8192 for a stated reason, in both sections, and they differ

SAVE-LAYOUT-R01 makes a multi-block section's descriptor `row_count` the checked
sum of its blocks' primary counts. §8 holds exactly one block, so its descriptor
is that block's count by the sum rule. §9 holds **two** blocks and its descriptor
is **8192, not 8704** — SAVE-C3-R01 is explicit that the descriptor rule is
section-specific, that §4 and §5 keep their already-ruled checked sums, and that
this "does not establish a universal sum rule for all sections". Both facts are
now pinned by value, so a later reader who finds 8192 in two places does not
conclude that one rule produced both.

### No version bump, because nothing released can be reinterpreted

§8 production writing was refused while the count was unruled, so no file carries
a section 8 with a different word at byte 23. SAVE-C3-R01's version disposition
says so directly and warns against a gratuitous bump. §9 changes zero bytes. A
later change to a field's actual extent, type, order, persistence or meaning
still needs the normal SAVE-R09-001 decision.

### The production refusal survives its own justification

The ruling says to "keep production refusal until J2 is actually implemented and
tested, even after the J1-specific refusal is retired". A refusal whose stated
reason has been answered is worse than none — the next reader retires it as
stale. So `production_write_refusal()` was rewritten rather than left: it now
names BLOCKER J2, reports that the count *is* settled at 8192, and returns
`SAVE_JOB_STORE_NO_COLUMN_API`. `job_planner.gd` still publishes no
`copy_job_index_columns_into()` / `restore_job_index_columns()` pair, so no live
planner state can reach this codec in either direction.

### Two encode-time guards were deliberately not added

`primary_count_refusal(PRIMARY_COUNT)` inside `encode_section()` and
`decode_section_into()` would read as defence in depth and is in fact
unkillable: against a compiled constant it can never refuse. A guard that no
mutation can kill is a guard that hides the absence of a test. Both were removed,
with the reason written at the call site. A `PRIMARY_COUNT` outside the u64
domain fails in `writer.write_u64()` instead, which *is* reachable.

## Consequences

- `docs/planning/canonical_state_registry.json` still carries no `primary_count`
  key for `job_planner`. Adding one is REG-C3-R01's sidecar work and that file is
  another lane's; this lane did not touch it. The compiled constant, not the
  artifact, is the source until that lands.
- The §8 suite's byte vectors are now literal at literal offsets (23, 31, 39)
  rather than sliced through `Section.OFFSET_*`. The module's own offsets are
  checked against those literals in a **separate** test, so neither can drift
  without a failure, and no vector locates itself through the thing it checks.
- `SAVE_JOB_PRIMARY_COUNT_UNRULED` no longer exists. Nothing outside the §8
  module and its suite referenced it.
- BLOCKER J2 is unchanged and unclosed. So is §9's BLOCKER N1.

## Source

- [SAVE-C3-R01](../rulings/2026-09-14_cycle03_save_counts_and_capacities.md),
  `#multi-table-primary-count`, including its rejection list and its
  version/field disposition.
- SAVE-LAYOUT-R01 §4/§5 in
  [the 2026-09-12 clock/restore and layout follow-up](../rulings/2026-09-12_clock_restore_and_layout_followup.md).
- REG-R01 in
  [the 2026-09-12 save-registry answers](../rulings/2026-09-12_save_registry_answers.md),
  for "the logical registry does not authorize guessing these from the first
  column".
- Decisions [0120](0120-section-8-freezes-its-payload-and-refuses-to-invent-a-primary-count.md)
  and [0121](0121-section-9-navigation-persists-used-prefixes-and-declares-its-own-primary-count.md),
  the two records this one reconciles.
