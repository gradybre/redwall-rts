# Independent contract review: NEEDS-S4-VALIDATE-R01 draft1

Read-only. No production or test file was edited; nothing was run. Scope is the owner-9 `needs`
validation primitive and its framed bridge. Sources: the draft contract, `needs.gd`,
`save_component_columns_schema.gd`, `save_section_component_columns.gd`, `test_needs_columns.gd`,
and the two prior evidence notes in this directory.

## Verdict

**Implementable as written; dispatch after four one-line clarifications.** The core direction is
sound and previously accepted. I found no contradiction that blocks authoring, no missing input,
and no unsafe gate. The items below are wording gaps that would otherwise be settled by the
production author or the test author unilaterally, which is exactly what an exact-code contract
exists to prevent.

## Findings

**F1 (must fix before dispatch). The bridge's refusal code is stated twice, differently.**
Gate 7 says "Preserve its StringName code" and then "detail identifies Needs owner 9 and the
returned column code". Those admit two implementations: `Refusal.code == &"COLUMN_HEALTH_STATUS"`,
or a `SAVE_COMPONENT_*` code carrying the column code only in prose. Every one of the 20 mapping
mutants and every enum/range boundary test asserts an exact code, so the choice is load-bearing
and cannot be left to the author. Recommended reading, consistent with "preserve": the bridge
returns the unwrapped `COLUMN_*` StringName as `Refusal.code`, and `detail` names owner 9 plus the
same code for humans. State it in one sentence.

**F2. `SAVE_COMPONENT_METADATA` is reachable from two gates.** Gate 3 forwards
`Schema.schema_refusal()`, which itself returns `SAVE_COMPONENT_SCHEMA` or `SAVE_COMPONENT_METADATA`;
gate 4 returns `SAVE_COMPONENT_METADATA` for key/type/count disagreement. Gate identity is therefore
not observable from the code alone. Either give gate 4 a distinct detail prefix, or state that the
metadata tests assert the code only and prove ordering by fixture construction. Not unsafe, but a
test asserting "gate 4 fired" from the code would be asserting nothing.

**F3. The status-omission mutant is killed by the new rule, not the enum rule.** `Columns.clear()`
fills `status` with `STATUS_DEAD`, so omitting ordinal 9 on a present, health-100 row now refuses
with `COLUMN_HEALTH_STATUS`, not `COLUMN_ENUM_BYTE`. The mutant still dies, and dies by assertion,
but only if the fixture keeps at least one present row at positive health. Record that requirement
with the fixture list so it is not accidentally built from an all-dead image.

**F4. The COW claim is conditional on the helper set.** "Packed assignments share COW buffers;
validation only reads them" is true for `_byte_column_below` (uses `count()`), but
`_int32_column_within`/`_int64_column_within` call `duplicate()` and sort. That is the charged
sort-copy and is fine; the contract should say the bridge itself must call no `duplicate()` and
must not reach `_install_columns`, which is the only other copying path in the file.

## Checks that passed

- **Metadata parity is satisfiable.** Compiled owner 9 gives key `needs`, version 2, primary 512,
  zero child extents, 20 fields beginning at index 187; those keys, type codes and element counts
  match `COLUMN_KEYS`, `COLUMN_TYPE_CODES` and `COLUMN_EXTENTS` ordinal for ordinal. Gate 4 can be
  implemented as a literal comparison, not an interpretation.
- **Helper count.** The nine named argument-only helpers are exactly the nine in the file; plus
  `_column_health_status_refusal` gives ten, plus the public predicate. The earlier "eight" was the
  miscount already corrected in the observation note.
- **Null guard placement.** Putting it in `_columns_are_capacity_sized` covers both
  `restore_columns(null)` and `copy_columns_into(null)` with the existing `COLUMN_SHAPE` code and no
  dereference. `Section.owner_shape_refusal` already refuses a null record, so gate 1 is a needed
  duplicate ahead of `record.owner`.
- **First-refusal order.** Free rows read only `present == 0`, death equivalence only `present == 1`;
  disjoint, so neither can mask the other, and running before the cap is both correct and cheaper.
- **Memory arithmetic.** 2 x 57344 + 20480 = 135168, and the i32 copy (10240) does not coexist with
  the i64 copy across returning calls. Conditional allocation arithmetic, not a measured RSS.

## All 20 omission mutants have distinct invalid per-field witnesses

Yes. For each ordinal there is an invalid value whose exact code differs from the outcome when the
assignment is dropped and the `Columns.clear()` default stands. Witness on a present, non-DEAD row
unless noted; default in parentheses.

| ordinals | invalid witness | code | default (accepted, or other code) |
|---|---|---|---|
| 0 present | 2 | COLUMN_PRESENT_BYTE | 0 |
| 1 need_value | 10001 | COLUMN_NEED_RANGE | 0 |
| 2, 4, 6 remainders | denominator exactly | COLUMN_REMAINDER | 0 |
| 3 health | 101 | COLUMN_HEALTH_RANGE | 0 -> COLUMN_HEALTH_STATUS |
| 5, 7, 8 counters | -1 | COLUMN_NEGATIVE_COUNTER | 0 |
| 9 status | 7 | COLUMN_ENUM_BYTE | DEAD -> COLUMN_HEALTH_STATUS (F3) |
| 10,11,12,14,15,18 enums | own `*_COUNT` | COLUMN_ENUM_BYTE | declared default |
| 13,17,19 flags | 2 | COLUMN_FLAG_BYTE | 0 |
| 16 clothing_tier | 0 | COLUMN_CLOTHING_TIER | 1 |

Ordinals 3 and 9 are killed by a *different* code rather than by acceptance; that is a stronger kill
and is why the assertion must be on the exact code, never merely on "refused". Shape checks cannot
substitute: an omitted assignment still leaves a correctly sized default column.

## Scope this review does not extend

Unchanged and still owed elsewhere: `NEEDS-STATUS-PRECEDENCE`, `NEEDS-DEPARTURE-DOMAIN`,
`NEEDS-LIVING-COUNT-TICK-R01`, `NEEDS-DOMAIN-SCAN-R01`, cross-owner saved consistency, and owner
capture/apply. A positive bridge result certifies the owner-9 column-image predicate only.
