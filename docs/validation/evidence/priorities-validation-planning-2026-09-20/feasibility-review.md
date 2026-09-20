# Owner 11 `priorities` — source/domain feasibility review

Read-only. No production, tests or final contract are authored here; Astra decides. Nothing was
executed, and no figure below is measured.

## 1. Figures confirmed against source

`save_component_columns_schema.gd` puts `"priorities"` at section-local owner 11 (between
`orchard_hive` 10 and `residents` 12, ASCII order holds), version 1, 512 primaries, 4 fields,
0 child extents, field span beginning 232. The four field keys in ordinal order are `_present`,
`_job_priority`, `_auto_fallback`, `_dangerous_work`; all four types are 0 (u8); counts are 512,
6144, 512, 512 = 7680 value bytes. Payload 7716 = 4 child-count + 4 x 8 element-count + 7680;
block 7750 = 24 fixed + 10 key bytes + 7716. This matches the canonical registry entry and the
persistence-registry row. The proposal's owner metadata is correct as stated.

## 2. The argument-only shape is feasible; it differs from Needs, and that is not a flaw

`save_owner_needs.gd` projects into a `Needs.Columns` object because `needs.gd` already published
one. `priorities.gd` publishes no `Columns`, no `COLUMN_*` arrays and no bulk API. Inventing a
projection object here would allocate a type solely to be consumed one line later. A static
predicate taking the four `PackedByteArray`s in registry order and returning `StringName` is the
smaller change and is reusable verbatim by a later bulk apply. The Needs metadata boundary is
precedent for *gate layering*, not for mandatory projection allocation.

## 3. Missing domain and unsafe coupling

**3.1 `_present` must be strictly 0 or 1.** This is a real domain fact, not a tidiness rule.
`is_present()` returns true only for `_present[slot] == 1`; `_check_present_slot()` refuses only
when `_present[slot] == 0`. A stored 2 therefore reads as *absent* to `is_present()` and as
*present* to every mutator and reader gate — the live store contradicts itself. Restoring such a
byte is unsafe, so the present gate must reject anything outside {0,1} before any later gate uses
presence to classify a row.

**3.2 Both flags are strictly 0 or 1.** `set_auto_fallback`/`set_dangerous_work` only ever write
0 or 1; `auto_fallback_of()` returns the raw byte while `fallback_priority_allows()` tests `== 0`.
A stored 2 behaves as enabled but reads back as 2, so accepted images would not round-trip.

**3.3 The free-row rule already exists as an instance method.** `inactive_row_is_clear(slot)`
defines a clear row as both flags 0 and all twelve priority bytes `PRIORITY_FORBIDDEN`. The packed
free-row gate restates that. Two independent statements of the same rule can drift silently and
neither mutant kills the other. Recommend one named definition shared by both, or at minimum an
explicit note in the contract that the packed gate is the authority and the instance method must
be kept equal.

**3.4 Reserved index 3.** Zero at every physical row is supported: `_write_initial_row` writes
`INITIAL_RESERVED_PRIORITY = 0`, `set_priority` refuses `JOB_KIND_RESERVED_INDEX`, `despawn` and
`clear` fill 0, and SET-AMEND-001 fixes the column. Note the gate is only *independently*
observable on present rows: on a free row all twelve bytes are already required to be 0, so the
reserved gate is subsumed there. That subsumption is the source of §4's ambiguity.

**3.5 Spawn defaults are not invariants.** HAUL=2 / others=3 / `auto_fallback=1` is the §5.1
*initial* state; `set_priority` accepts 0–4 for any active kind and both flags are player-set.
Constraining present rows to defaults would refuse legitimate saves. The proposal is right.

## 4. Exact refusal-order ambiguity (needs a ruling)

Given `shape → present → auto → dangerous → range → reserved → free rows`, two inputs are judged
by order alone rather than by rule:

- Present row, reserved byte 7: violates both range and reserved. Range fires; the emitted code
  says nothing about the reserved column. Defensible, but must be stated.
- **Free row, reserved byte 3:** in range, so range passes; the reserved gate fires and reports a
  reserved violation even though the row is absent and the *stronger* free-row rule is what it
  breaks. A reader sees a reserved-column code where the residue is the real fault.

Settle one of: (a) reserved gate precedes free rows and its detail names the row's presence state;
or (b) the reserved gate is scoped to present rows, letting free rows fall to the residue code.
Either is source-consistent; the contract must pick, because the mutant tests bind to the code.

Also note a free row carrying `_auto_fallback = 1` passes the flag gate (1 is in domain) and is
caught only by the free-row gate — correct, but worth pinning as a named witness.

## 5. Mapping mutant witness flaw

The four parameters are all `PackedByteArray`; three of them (`_present`, `_auto_fallback`,
`_dangerous_work`) have identical length 512 and identical domain {0,1}. The proposal's all-zero
substitute kills *omission*, but a **transposed** call site — bridge passes dangerous where auto is
expected — is type-legal, extent-legal and domain-legal. The predicate cannot distinguish those
two columns by content at all.

It becomes killable only if the two flags carry **distinct refusal codes** and the witness makes
them differ: auto = one byte 2, dangerous = all 0 yields the auto code correct and the dangerous
code mutated. A single shared `COLUMN_FLAG_DOMAIN` code would make the swap permanently
unobservable. Present-vs-flag transposition is separately killable via a nonzero flag on an absent
row. This argues for per-column codes, not per-gate codes.

## 6. Memory

No gap found, with one condition. The predicate allocates only its returned `StringName`; the
bridge assigns rather than duplicates, and `priorities.gd` has no range helper that duplicates or
sorts (unlike Needs), so the no-copy claim holds *while that remains true*. The 7680 caller bytes
are the framed owner block the section already charges; they are not a new resident row and must
not be presented as one. Wrapper and native overhead remain unmeasured.

## 7. Metadata parity is weaker here than for Needs — name it

Gate 4 for Needs compared `Schema` against `Needs.COLUMN_KEYS/TYPE_CODES/EXTENTS`. `priorities.gd`
publishes none of these, so a `priorities` bridge can only compare the schema against pinned local
literals. That still catches schema drift, but it cannot catch the store and the schema drifting
*together*. Acceptable for this slice; it should be written down rather than implied. Avoid reusing
the existing `REFUSE_RESERVED_JOB_KIND` / `REFUSE_INVALID_PRIORITY` spellings for column codes —
those are mutator-level slot refusals and a shared name would blur which layer refused. Distinct
`COLUMN_`-prefixed names, one per column plus one for shape, keep the layers separable.

## 8. What an accepted image would and would not certify

Would: the four owner columns are internally self-consistent and restorable by this owner's own
rules. Would not: agreement with the entity Directory's RESIDENT rows, with `residents.gd`, or with
`needs.gd` presence (the `PRIORITY_CAPACITY == RESIDENT_CAPACITY` assert is a capacity equality,
not a per-row cross-owner rule); common-file provenance; permission to install. Bulk capture and
apply remain explicit prerequisites — including recomputing the derived, unsaved `_present_count`
from `_present` on apply.

The 256 living-population cap does not bound this owner: all 512 rows are addressable through the
current public `spawn`, and this owner stores no health or status. No owner-local cap rule.

The stale HarvestZone remark in the module header is out of scope for this slice; leave it.
