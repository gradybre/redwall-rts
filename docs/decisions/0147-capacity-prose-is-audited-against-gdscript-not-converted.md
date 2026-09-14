# 0147 — Capacity prose is audited against GDScript, not converted
Date: 2026-09-14 · Status: Accepted

## Decision

REG-C3-R01's numeric capacity audit is implemented as a **read-only sidecar**:
`tools/audit_registry_capacities.py` reads
`docs/planning/canonical_state_registry.json` and writes only
`docs/planning/registry_capacity_audit.json`. The active registry, its checker
(`docs/validation/validate_save_registry_handoff.py`), the persistence document
and every compiled declaration are byte-untouched. No prose capacity is
converted into the registry; the sidecar carries `"adopted": false` and says so
in its own notes.

Five supporting choices go with it.

1. **A capacity is proved by GDScript and by nothing else.** The registry's
   prose is the *claim under audit*. Agreement between the registry and any
   other document — the persistence table, the generated declaration table, a
   ruling — is never accepted as evidence. The tool reads exactly three things:
   the registry JSON, its own sidecar, and `godot/scripts/core/*.gd`. A test
   asserts that set of readers, so a later "proof" sourced from a document
   fails the suite rather than passing silently.

2. **The binding is the column's own `resize()` argument.** For each field the
   audit locates the single `resize(...)` that sizes `source_member` in
   `source_module` and requires its argument text to be *the same expression* as
   the prose backtick. All 519 rows bind this way at this revision; a row whose
   prose names a different expression than the source uses is refused as
   `unproved_binding_mismatch` rather than resolved in the registry's favour.

3. **Equality and maximum are classified from source, then compared.** A
   compile-time `const` sizes a column exactly (`eq`). A runtime `var _x: int`
   narrowed by *exactly one* `clampi(arg, lo, MAX)` sizes it at most (`lte`),
   and the proved number is the clamp maximum, never a constructed size. When
   the source relation and the prose relation disagree — in **either**
   direction — the row is a `finding_relation_mismatch`, never a pass. This is
   the distinction that made the question worth asking: a store sized *at* its
   maximum and a store sized *exactly* are different claims about what a decode
   may accept, and flattening them destroys the information.

4. **The evaluator is a restricted integer resolver with no `eval`.** Decimal
   literals, module constants, `Alias.CONST` through an explicit
   `const Alias := preload("res://scripts/core/x.gd")`, and `*` products only,
   with a depth limit of 16 and an int64 guard on every intermediate. A bare
   name resolves in the field's own module and nowhere else, so a same-named
   constant in another module cannot prove a row. A constant declared twice with
   different expressions is `ambiguous_symbol`, not a coin toss.

5. **Nothing is guessed and nothing is dropped.** Resolution returns `Proved` or
   `Unproved`; there is no `-1`, no magic zero, no `None`-as-value. An
   unprovable row keeps its key, keeps its prose, carries the reason and the
   exact line where resolution halted, and appears in
   `unproved_or_contradicted`. The 80 canonical records with no
   `declared_capacity` are listed too, so the two lists partition all 599.

## Census, and the one refusal

The observed census matches Astra's Cycle 3 numbers exactly, with no parser
tuning: **519 prose records = 473 equality + 46 upper bound**, **80** other
canonical shapes, **56** distinct expressions, over **599** canonical records,
**553** persisted packed fields and **52** owners. The **8** non-hash fields are
counted and explicitly excluded; a test fails if one is swept in.

Proof outcome: **471 proved equalities + 46 proved upper bounds = 517 proved**,
**0 contradictions**, **2 unproved**.

The two unproved rows are `(5, orchard_hive, 0, _link_hive_slot)` and
`(5, orchard_hive, 1, _link_hive_generation)`, prose `` `LINK_CAPACITY` = 30720 ``.
Resolution reaches `orchard_hive.gd:319 const LINK_CAPACITY = RECIPIENT_CAPACITY *
LINKS_PER_RECIPIENT` and halts at `orchard_hive.gd:316 const RECIPIENT_CAPACITY =
FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`, because REG-C3-R01 allowlists
"**products** and qualified constants" and `+` is not on that list.

This is a deliberate refusal, not a parser gap. Widening the allowlist to `+` is
a one-line change and would prove both rows, but the allowlist is the ruling's,
not the executor's, and quietly extending it is exactly the "mechanical
conversion without a decision" that REG-C3-R01 was asked about. **Open blocker
for the reviewer of this sidecar: may the resolver's allowlist include `+` for
nested constant definitions? Two rows, and only those two, depend on it.** Until
that is answered the rows stay quarantined with their halting definition named.

## Why the numbers are not pinned as constants

`cycle_03.md` calls its capacity census "source snapshot counts, not future
immutable totals", and REG-R01 requires the declaration to grow when concurrent
state lands. Astra's four numbers are therefore embedded as a *comparison*, not
an assertion: `ASTRA_CYCLE_03_CENSUS` is printed beside the observed counts and
any difference is emitted as an explicit `DISAGREEMENT` line and stored in
`census.disagreements`. A legitimate later change moves the observed numbers and
makes the disagreement visible; it does not license editing the parser until
they match.

## What this deliberately does not do

- It does not re-assert the registry's `source_registry_sha256`. The sidecar
  records only digests it computed itself: the registry file's content hash and
  a per-module hash of each `godot/scripts/core/*.gd` it read.
- It does not choose a registry version number, add numeric metadata to the
  registry, or touch the rules identity under SAVE-R09-003.
- It does not validate any field's **wire** extent or count rule. REG-C3-R01
  keeps that separate, and a proved `lte` in particular still leaves the actual
  element count to the owning store's persisted framing.
- It says nothing about UI, movement gates or Tier-2 economics.

## Verification

`python3 tools/test_registry_capacity_audit.py` — 134 checks, 0 failures,
negative cases first. `python3 tools/audit_registry_capacities.py` regenerates
the sidecar byte-identically (`--check` is the determinism gate, and rows sort by
`(section_id, owner_key, ordinal, field_key)` independently of registry input
order). Twelve mutants were applied one per invocation with a `shasum -a 256`
byte-compare after each restore; all twelve were killed, including an upper bound
classified as equality, a proof accepted from a document, an unproved row
reported as proved, and broken deterministic ordering.
