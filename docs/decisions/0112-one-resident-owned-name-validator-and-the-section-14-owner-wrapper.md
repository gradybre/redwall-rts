# 0112 — One resident-owned name validator, and section 14's owner wrapper

Date: 2026-09-12 · Status: **Accepted**

Implements **NAME-R02** and the **§14 NAME_POOL wrapper** paragraph of
[the 2026-09-12 save-registry answers](../rulings/2026-09-12_save_registry_answers.md),
closing the four blockers
[decision 0099](0099-the-first-variable-length-save-section-frames-its-own-row-count.md)
left open. It touches `godot/scripts/core/residents.gd`,
`godot/scripts/core/save_section_name_pool.gd` and their two suites, and nothing else.

**It claims no release-save completeness.** Section 4 has no codec, so nothing restores
`_named`, `_present` or any other resident column; the cross-check below reads the
incoming flags out of whatever the caller has already built. §15, the load orchestrator
and cross-process parity are all still absent.

## Context

SAVE-R09-002 said "a live resident cannot load an empty name". Read literally that
sentence refused the GDD §5.1 starter settlement outright: REQ-SET-040 makes naming
trigger-based and eleven of the twelve founders are anonymous, so eleven live residents
hold the empty name on tick 0. Decision 0099 recorded the tension as **BLOCKER N2** and
implemented a reading — the sentence governs a row the schema has *flagged* as named —
without authority to confirm it. NAME-R02 confirms that reading and publishes the table.

Three further blockers came with it. **N1**: section 14 had no registered owner-block
framing, so the wrapper was deliberately not applied. **N3**: `set_name()` validated
*nothing* — it stored any `StringName` and derived `_named` from emptiness, so a live
store could hold a 40-scalar name with control characters that the codec then had to
refuse; the rule held at the wire and not at the setter. **N4**: section 14 had to be
applied after section 4, with no orchestrator to hold the order.

## Decision

### 1. One validator, owned by `residents.gd`, with no second copy anywhere

`Residents.name_refusal(name_value: StringName) -> StringName` is the only place the
personal-name rules are written down. `set_name()`, the new `restore_name()`, automatic
name assignment in `_write_initial_resident()`, `capture_into()`, `record_refusal()` and
`apply()` all reach it; `save_section_name_pool.gd` adds no rule of its own and only maps
the returned code onto its `SAVE_NAMES_*` vocabulary so a load report keeps its own
words.

A nonempty name must be strict-UTF-8 encodable, at most **128 bytes**, **2–32 Unicode
scalar values**, and free of Unicode category Cc. Empty stays legal, because it is the
anonymous row.

Three judgements inside that:

- **Scalars are counted as scalars.** Godot's `String` is UTF-32, so `length()` is
  already the scalar count, and `scalar_length_of()` names that fact rather than leaving
  it to be rediscovered. The suite pins the trap with `"A" + U+0301` repeated 17 times:
  34 scalars, 51 UTF-8 bytes, 17 grapheme clusters. The scalar rule refuses it; a
  byte-counting validator sees 51 against a 128-byte cap and a cluster-counting one sees
  17 against a 32-cluster cap, and **both admit it**. One fixture discriminates against
  both wrong units.
- **The control-code test is three explicit integer bounds** — `<= 0x1F`, `== 0x7F`,
  `<= 0x9F` — and not a call into whatever Unicode category tables the engine build
  carries. NAME-R02 requires this explicitly. It also means an engine upgrade cannot
  silently change which names this store admits.
- **`utf8_byte_length_of()` is arithmetic over the 0x7F / 0x7FF / 0xFFFF width
  boundaries**, not `to_utf8_buffer().size()`. That keeps `residents.gd` from preloading
  the codec — the dependency runs the other way — and the suite asserts the two agree on
  six fixtures rather than trusting that they do.

Nothing is normalized, truncated or replaced. A refusal writes neither column; the suite
asserts that by byte-comparing an image of all 512 rows built from `residents.gd`'s own
public readers, per ADR 0059.

`command_dispatch.gd` is **not** on this task's allowlist and is unchanged. Its
`_alias_refusal()` still runs its own copy of the rules before calling `set_name()`, so
the two now compose: the command's codes are reported where they fire, and a C1 control
character (which the command's `< 0x20` test misses) is caught by the store and surfaces
as `RESULT_STORE_REFUSED`. That is a *reporting* gap, not a state gap — no invalid name
reaches a column either way. Folding `_alias_refusal()` into the shared validator is
reported to the dispatcher's owner, not done here.

### 2. Section 14 gains SAVE-LAYOUT-R01's owner wrapper; the payload is unchanged

`store_count:u32 = 1`, then the standard wrapper, then the **existing** payload:

| Offset | Type | Field | Bytes |
|-------:|------|-------|------:|
| 0 | u32 | `store_count` = 1 | 4 |
| 4 | u32 | owner-key byte length = 9 | 4 |
| 8 | utf8 | `owner_key` = `residents` | 9 |
| 17 | u32 | `owner_schema_version` = 1 | 4 |
| 21 | u64 | `primary_count` = 512 | 8 |
| 29 | u64 | `payload_byte_length` | 8 |
| 37 | u32 | `row_count` = 512 (retained) | 4 |
| 41 | row ×512 | `utf8_byte_count:u32 LE` + that many bytes | variable |

Wrapper 33 bytes, framing 37 with `store_count`. Payload is
`4 + sum(4 + utf8_byte_length(name[slot]))`, floor 2052, cap 67588; section floor 2089,
cap **67625**. Every one of those numbers is NAME-R02's own arithmetic, restated in the
suite as literals rather than derived from the module under test.

**Both counts are validated, against each other.** `payload_byte_length` is checked
against `length - FRAMING_BYTES` from the descriptor — not merely against the bounds —
and the retained inner `row_count` is checked against the compiled capacity. Two
authorities state the payload size and a disagreement between them has no repair.

**Section 14's schema version becomes 2.** `SCHEMA_VERSION` is published as a constant
here because `save_header.gd` carries the descriptor field opaquely; the two would
otherwise drift.

**The canonical record does not change shape.** REG-R01 fixes it as
`(14, "residents", "_name_key", type 5, count 512, values)` and rules that neither
framing count nor the wrapper becomes an extra canonical record, so
`canonical_bytes_of()` still emits only the 512 values. Measured on the real starter
settlement: section 2101 bytes, canonical 2060, **delta exactly 41** — 4 `store_count`
+ 33 wrapper + 4 `row_count`. A test asserts the owner key does not reappear inside the
hashed bytes.

`docs/planning/canonical_state_registry.json` **already declares** owner `residents`,
owner schema 1, `primary_count` 512, `max_payload_bytes` 67588, `max_section_bytes`
67625 and section-14 schema version 2. No change to that file is required by this work.

### 3. The ordering rule is a precondition, not a sequence

NAME-R02: *"Name/occupancy agreement is validated before any setter can rewrite the
incoming `_named` flag; 'apply names last' must not conceal corruption."*

Sequencing §4 before §14 is not sufficient on its own, and that is the substance of N4.
`set_name()` recomputes `_named` from emptiness, so **a derived flag can only ever
produce agreement, and therefore can only ever conceal a disagreement.** Two concrete
shapes were silently repaired before this change: a row §4 flagged named for which §14
supplies nothing (demoted to anonymous, no report), and a row §4 left anonymous for
which §14 supplies a name (promoted to named, no report).

So:

- `Residents.name_occupancy_refusal(present, named, name)` evaluates the whole ruled
  table as a **pair**, and `row_name_refusal(slot)` applies it to a live row's physical
  columns — not through `name_key_of()`, which masks an absent row's stored key and
  would report a stale key as clean.
- `save_section_name_pool.occupancy_refusal(record, store)` runs that check over all 512
  rows **before `apply()` issues its first write**, and is public so a load orchestrator
  can take the verdict without committing to the write.
- The writes then go through `Residents.restore_name(slot, named, name)`, which takes the
  flag explicitly and derives nothing. §14 restores names; §4 owns the flag. `apply()`
  snapshots the incoming flag column once before the first write so the rollback puts the
  exact prior pair back rather than a recomputed one.
- A free row and a present anonymous row share the same shape — flag 0, empty name — so
  occupancy alone never decides whether a name is legal. `present` is still passed
  separately so a caller hanging a name on a free row gets its own code.
- **Liveness is never consulted.** A retained dead row keeps its name and its flag; the
  suite kills a real resident through `needs.apply_health_event(slot, -100)` and asserts
  the identity survives.

## What this changed that was previously tested, and why

Two tests in `test_save_section_name_pool.gd` asserted behaviour NAME-R02 reverses, and
were rewritten rather than deleted:

- `test_encode_store_refuses_a_live_name_that_breaks_the_alias_rule` asserted that
  `set_name()` **accepts** a 40-scalar name and only the codec refuses it — the N3
  asymmetry stated as a fact. It is now
  `test_the_live_store_can_no_longer_hold_a_name_the_codec_would_refuse`, and a second
  test keeps the wire's own gate on the hook for a `Record` the setter never built.
- `test_apply_sets_the_named_flag_from_the_key_for_every_row` asserted that `apply()`
  **derives** `_named` from the key, which is exactly the concealment N4 names. It is
  replaced by three tests: the two mismatch directions and one that proves the verdict is
  available before any write.

No other test was weakened, and no test was deleted.

## Consequences

- A name that fails any rule cannot reach a resident column, so the section 14 encoder's
  content refusals become unreachable from a live store and reachable only from a
  hand-built `Record`. Both paths are still tested.
- `spawn_initial_settlement()` can now refuse on the Warden's name and rolls the whole
  cohort back if it ever did. `_write_initial_resident()` returns a refusal code instead
  of `void` for that reason.
- `apply()` refuses a save whose §4 and §14 disagree instead of repairing it. When §4's
  codec lands, a save produced by `capture_into()` can never disagree, because capture
  refuses an inconsistent store first.

## Evidence

Full suite on this branch: `3790 test(s), 133623 assertion(s), 0 failure(s)`
(`godot --headless --path godot --script test/run_tests.gd`). Ten single-mutation runs,
one Godot invocation each, restored and `shasum -a 256` byte-compared against a pristine
copy; results in the task checklist. `ready07_arithmetic.py`,
`state_registry_coverage.py`, `decision_numbers.py` and
`validate_underground_economy_hazards.py` all pass.

`docs/validation/validate_save_registry_handoff.py`, which the ruling names, **does not
exist on this branch** and was not run.

## Still open

- **Section 4 has no codec.** Nothing restores `_named`. The cross-check is only as
  meaningful as the flags the caller installed.
- `docs/systems_architecture.md` and `docs/persistence_state_registry.md` need updated
  §14 framing rows; neither is on this task's allowlist. The exact rows and their byte
  arithmetic are reported to the integration owner.
- `command_dispatch.gd::_alias_refusal()` remains a second copy of the name rules,
  differing from the shared validator on C1 controls. It is now belt-and-braces rather
  than the authority, but it should be folded in by that file's owner.
