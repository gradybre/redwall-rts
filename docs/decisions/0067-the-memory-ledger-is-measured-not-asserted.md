# 0067 — ARCH-MEM-010 is measured against the code, and divergences are reported, not fixed

Date: 2026-09-11 · Status: Accepted.

Scope: a measurement harness for `docs/systems_architecture.md` §2.3's allocation ledger,
and the first evidence document produced by it. **No budget, capacity or allocation
constant is changed by this record**, and no gate is closed by it.

Evidence: [memory ledger measurement](../validation/memory_ledger_measurement.md).

## Context

§2.3 states a planned allocated payload of **60821078** bytes over 24 rows, plus an
8388608-byte reserve, giving **69209686** for one live world against REQ-SET-163's 100 MB
budget. ARCH-MEM-010 says in its own closing sentence that this "remains a
baseline/incomplete planning ledger, not measured RAM". `docs/validation/ready07_arithmetic.py`
checks that the rows sum to the printed totals; nothing checked that the rows describe the
code. Roughly thirty stores now allocate their packed columns in `_init()`, so that check
became possible and had never been run.

## Decision

**1. Measure, do not model.** A column's bytes come from the array's own `size()` after
construction, never from a constant the harness carries. The element widths the ledger's
arithmetic assumes are themselves measured, by allocating 2097152 elements of each packed
type and dividing the process's own `OS.get_static_memory_usage()` delta. All eight packed
widths are confirmed at 1/4/8/4/8/8/12/16 bytes per element. `Array[StringName]` is not:
it measures **24** bytes per element where §2.3 budgets 8.

**2. One wired world, walked and deduped — never a list of `new()` calls.** Most stores
build a private collaborator when passed `null`. `memory_ledger_probe.build_world()` wires
one composition explicitly; `collect_instances()` then walks the object graph and dedupes
by `Object.get_instance_id()`, so a store that quietly built a second `EntityDirectory`
would be reported as a duplicate instead of inflating a row by 10572756 bytes. None was
found.

**3. Report per row, and never only a total.** Five merges in this repository's own
reconciliation trail have dropped or conflated a row while leaving every total correct. A
harness that printed one number would reproduce that failure. Every one of the 24 rows is
compared individually, and the transcription's own sum is asserted against §2.3's printed
60821078 by a test, so a transcription that drifts fails rather than quietly reporting
against a different ledger.

**4. Distinguish allocated from resident, in the report's own words.** What is measured is
allocated payload. The process-level figure is reported as a labelled delta around world
construction — 44976308 static-memory bytes for 44254212 bytes of payload, an overhead of
722096 (1.63%) — and is never folded into a row. What `OS.get_static_memory_usage()` does
and does not include is stated in the evidence document rather than assumed.

**5. Refuse rather than substitute a figure.** A row with no implementing code reports
`UNATTRIBUTED`, not `0`. "No store allocates this" and "this store allocates nothing" are
different findings, and four rows totalling 2752512 bytes are in the first category while
`item_definitions.gd` is in the second. The element calibration likewise reports
`UNMEASURED` if the allocator gives no observable delta, rather than dividing by an element
count and returning a zero that would read as "this type is free".

**6. `docs/systems_architecture.md` is not touched.** It is contended and reconciled by
hand. Divergences are reported with row, declared figure, measured figure and cause.

## What was found

Sixteen of the twenty-two measurable rows are **exact to the byte**, including 65540 and
244. Six diverge:

| Row | Declared | Measured | Cause |
|---|---:|---:|---|
| Spatial heads | 65536 | 0 | Separation is deliberately unbuilt; MOVE-G01 owes the parameters |
| Command result store codes | 32768 | **98304** | A GDScript `Array` element is a 24-byte `Variant`, not an 8-byte reference |
| Timing samples | 55200 | 168 | 7 stages instrumented with one sample each, not 23 × 300 |
| Scheduler event queue | 8224 | 8192 | The 32-byte control header is scalar members, not a packed buffer |
| Tick event ring, catalog arenas, I/O buffers, UI snapshots | 2752512 | UNATTRIBUTED | No implementing code exists |
| Fixed registry + auxiliary payload | 42261694 | 28600708 | §2.2/§3 schema roughly two-thirds built |

Total measured allocated payload is **44254212**, 16566866 below the declared 60821078.

Two columns fall outside the ledger's model entirely. `residents.gd` holds `_species_key`
and `_name_key` as `PackedStringArray`, which has no fixed element width and therefore no
row shape §2.3 can express; both are reported by slot count and UTF-8 content and excluded
from every total. `_name_key` is also not the shape §2.2 and §3 budget for — they describe
an `i32` index into a `NamePoolUtf8`/`NamePoolIndex` arena (180224 bytes) and the code
stores the `String`. That is a schema question for §2.2/§3, not an arithmetic error in
§2.3, and it is reported rather than resolved here.

**Row 14 is the only case where the ledger under-budgets real memory**, and it under-budgets
by 3×. It is small in absolute terms (65536 bytes) but the reasoning that produced it —
"assigning an interned name is a reference copy, not an allocation" — is correct about the
name and wrong about the slot, and will repeat wherever a future row budgets an `Array` of
interned names at 8 bytes per element.

## What was deliberately not done

- **The §2.2 / §3 split was not guessed.** No column in the codebase is marked with the
  section that budgets it; `jobs.gd` holds both in one flat set of 48 members. The two
  aggregate rows are therefore measured together and the split is reported as NOT
  MEASURABLE. Making it measurable would mean annotating columns with their owning table,
  which is a schema decision this record does not take.
- **No production file under `godot/scripts/` was modified.** Reading every store needed
  only reflection, so no accessor had to be added. This is worth recording because it is
  the reason the harness works at all: GDScript exposes script members through
  `get_property_list()` and `Object.get()` regardless of the leading underscore.
- **`ready07_arithmetic.py` was not touched.** It still passes and still checks a different
  thing: internal consistency of the document, not correspondence to code.

## Cross-check against decision 0062's state registry

`docs/persistence_state_registry.md` declares a width and a count per column group, and
`state_registry_coverage.py` enforces that the count quotes the module's own `resize()`
expression. That is a claim about **source text**. This harness's claim is about the array's
`size()` after `_init()` returned. A `resize()` that never runs, runs twice, or runs with a
different argument would satisfy the first and fail the second.

Comparing the registry's `width x count x members` against the measured bytes of the same
members: **214 of 214** resolvable rows agree exactly, **0** disagree. The three rows whose
count is not a resolvable number (`commands._no_refs` "never allocated";
`item_definitions.gd`'s two "`count` runtime" rows) are the same two stores this harness
independently measured at zero bytes. Two instruments built for different purposes, reading
source text and live objects, agree on every checkable row.

This is worth recording because it narrows where the §2.3 shortfall lives: the columns that
exist are the right size. What is missing is columns, not bytes.

## Consequences

- `godot/tools/memory_ledger_probe.gd`, `memory_ledger_rows.gd` and
  `measure_memory_ledger.gd` are new. `godot/test/test_memory_ledger_probe.gd` tests the
  instrument — reflection, the byte derivation, the name filter, dedupe, and that the
  transcription still sums to 60821078.
- `memory_ledger_rows.gd` is a **transcription** of §2.3 and will go stale when §2.3
  advances. The test that pins its sum to 60821078 is what makes that visible: it fails
  loudly rather than silently comparing against a superseded ledger. Whoever next edits
  §2.3's allocation table should expect to update that file and that constant.
- Eighteen rows now have a named owning script recorded in one machine-readable place, which
  did not previously exist anywhere.
- Nothing found puts the one-world gate at risk. Every unimplemented item moves the
  measured figure *up* toward the declared one, and the measured 1.63% allocator overhead
  leaves the 8388608-byte reserve generous at that destination. ARCH-CONFLICT-011's
  two-world peak is untouched by this work.

## Source

- `docs/systems_architecture.md` §2.1, §2.2, §2.3, ARCH-MEM-009, ARCH-MEM-010 and
  ARCH-CONFLICT-011 — the ledger under test. Read, not modified.
- `docs/game_gdd.md` REQ-SET-163 — the 100 MB simulation-owned memory budget.
- The measurement itself: `godot --headless --path godot --script tools/measure_memory_ledger.gd`
  on Godot 4.7.2.stable.official.ed1daf0bf, macOS arm64, 2026-09-11. Two consecutive runs
  were byte-identical.
- `docs/validation/ready07_arithmetic.py` — still PASS, unmodified. It checks the document's
  internal arithmetic, which is a different claim from the one measured here.
