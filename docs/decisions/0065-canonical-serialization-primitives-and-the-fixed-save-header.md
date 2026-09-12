# 0065 — Canonical serialization primitives and the fixed save header

Date: 2026-09-11 · Status: **Accepted** (executor; task 09.2, partial)

## What was built

Two new modules, and nothing else:

- [`godot/scripts/core/save_codec.gd`](../../godot/scripts/core/save_codec.gd) —
  ARCH-SAVE-001's encoding primitives: explicit little-endian integers,
  two's-complement reinterpretation, length-prefixed UTF-8 with strict
  validation, a bounded `Reader` and an appending `Writer`.
- [`godot/scripts/core/save_header.gd`](../../godot/scripts/core/save_header.gd) —
  ARCH-SAVE-002's fixed 256-byte header, its 64-byte section descriptors,
  CRC-32/ISO-HDLC, the offset-224 body digest and ARCH-SAVE-004's structural
  section-table validation.

Suites: [`test_save_codec.gd`](../../godot/test/test_save_codec.gd) and
[`test_save_header.gd`](../../godot/test/test_save_header.gd).

## Why only this much of 09.2

`docs/tasks/09_persistence_replay_reliability.md:17` blocks release saves on an
explicit schema version policy — "do not silently repurpose v1 bytes" — and
[the READY_07 addendum](../rulings/2026-09-11_ready07_save_ui_addendum.md)
authorises 09.2's per-store codec registry without settling that policy.
ARCH-SAVE-007 restates the boundary in terms: it "assigns section ownership;
task 09.2 still owns its explicit field byte offsets/schema."

Everything in these two modules is version-independent. The *file-level* format
version is stated as 1 (`systems_architecture.md:718`) and ARCH-SAVE-005 requires
rejecting future versions, so that one is checked. The *per-section*
`schema_version` is carried as an opaque u32 and nothing validates its value,
because validating it would be inventing the policy.

Nothing here writes or parses a section body. The per-store codec registry is
deliberately left to a later pass: three of the fifteen sections (§11
EVENT_SCHEDULE, §13 CHRONICLE, §15 STATE_DIGEST) still have no owning module at
all, and the stores that do exist are being edited concurrently.

## Four contract gaps, named rather than filled

**S1 — the string length-prefix width is not specified.** ARCH-SAVE-001 says
"length-prefixed UTF-8" and stops. ARCH-SAVE-005 requires rejecting "illegal
negative lengths", which is meaningful only for a *signed* prefix. Searched:
`systems_architecture.md` §8 entire, `game_gdd.md`, `gameplay_balance.md`,
`ui_ux_controls.md`, `docs/rulings/`, `docs/decisions/` and the whole `docs/`
tree for "length-prefix", "length prefix", "prefixed UTF-8". The only other hits
are `persistence_state_registry.md:444` quoting ARCH-SAVE-001 back, and decision
0043, which measures a `NAME_RESIDENT` alias in *characters* behind the command
envelope's own i32 `payload_length` — a different field.

Resolution: the codec exposes `read_utf8_u32_into` / `write_utf8_u32` and
`read_utf8_i32_into` / `write_utf8_i32` as two separately named primitives.
Neither is a default. Which one a given field uses is 09.2's schema decision.

**S2 — no string byte cap is specified.** Every string read and write takes an
explicit `max_bytes` from its caller, so there is no invented maximum here to be
wrong about. The remaining-buffer bound applies on top of it regardless.

**H2 — four of the five header identity hashes have no producer.** The rules
hash (offset 40), map hash (104), integer lookup-table hash (136) and engine
build hash (168) are carried as caller-supplied 32-byte digests and checked for
length only. Decision 0034 already records this of the rules hash: "the separate
offset-40 rules hash, whose serializer does not exist yet either." The catalog
hash at offset 72 is the exception and is not recomputed here — `catalog_ids.gd`
owns it, names that offset in its own `SAVE_HEADER_CATALOG_HASH_OFFSET`, and
`catalog_hash_refusal()` asserts the two constants agree before comparing.

**H4 — whether section ranges must tile the file is not stated.** ARCH-SAVE-004
requires "nonoverlapping ranges, exact file length, overflow-safe offsets" and
does not say contiguous. `section_table_refusal()` enforces every clause that is
stated and permits a gap; a test pins that reading so tightening it later is a
visible change.

## Two decisions that are engineering, not policy

**A u64 with its high bit set is refused, not reinterpreted.** GDScript's `int`
is signed 64-bit, so Godot decodes such a pattern into a negative number. A
negative byte count or file offset reaching a caller is precisely the sentinel
class decision 0059 and `int_math.gd`'s header exist to prevent, so
`read_u64_at()` refuses with `SAVE_CODEC_UNREPRESENTABLE_U64`. The upper half of
the u64 range is therefore unwritable and unreadable, which is stated rather than
worked around.

**Signedness is passed, never inferred from a width.** i32 and u32 are both four
bytes and i64 and u64 are both eight, so a dispatcher keyed on byte count alone
will happily read a u32 field as i32 and turn `0x80000000` into `-2147483648`
without complaint. The first draft of `Reader._dispatch_fixed()` had exactly that
defect. `SIGNEDNESS_UNSIGNED` / `SIGNEDNESS_SIGNED` are carried explicitly and a
test asserts the two reads of the same four bytes *disagree*.

**Strict UTF-8 is hand-written because the engine's decoder does not refuse.**
`PackedByteArray.get_string_from_utf8()` substitutes replacement characters, so
ARCH-SAVE-005's "reject malformed UTF-8" cannot be delegated to it. The validator
rejects overlong forms, UTF-16 surrogates, scalars above U+10FFFF, truncated
sequences and continuation bytes in a lead position. A decode/re-encode
comparison runs on top, which additionally refuses an embedded U+0000 — legal
UTF-8 that Godot treats as a terminator, and therefore not byte-exact here.

## The body digest is not the canonical state digest

ARCH-SAVE-007 makes persistence obligation and digest membership separate
dimensions: host debt and the six clock counters are *saved* and *excluded* from
ARCH-HASH-001, while remaining covered by the section CRC and the body SHA-256.
`save_header.gd` owns the latter pair only. Nothing in it computes, stores or
compares `RWL-STATE-1`, which belongs to §15 STATE_DIGEST and has no owning
module. A test pins the consequence the architecture states at line 745:
flipping a header byte does not change the offset-224 body digest, so a changed
completed tick is caught by state verification rather than by this CRC/SHA pair.

## Verification

`./tools/run_tests.sh` at this work's merge base: **2448 tests, 93265
assertions, 0 failures**, against a measured baseline of 2365 tests, 92629
assertions, 0 failures. After merging `origin/master` (which brought decisions
0061, 0066 and 0067 with their own suites): **2526 tests, 94070 assertions, 0
failures**. `docs/validation/state_registry_coverage.py`: PASS, 38 modules, 282
rows, 548 packed columns after the merge (278/541 before it). `docs/validation/ready07_addendum_checks.py --godot`: PASS.
`docs/validation/ready07_arithmetic.py`: PASS.

A 67-mutation sweep ran one mutation per Godot invocation, restored each file
from a pristine copy and `sha256`-compared it afterwards, with the failure count
parsed as an integer. It concentrates on the bounds checks: every off-by-one in
a read/write room check, every length-prefix bound, every UTF-8 lead-byte range,
the CRC polynomial and register, and every section-table range clause.

First pass: **60 killed, 7 survived.** Six of the seven were real test gaps and
each is now closed by a named test:

| Surviving mutant | What it showed | Test added |
| --- | --- | --- |
| `length > max_bytes` → `+ 1` | every string test used a cap far from its string | a 5-byte string read under a 4-byte cap |
| padding `offset > size - count` → `+ 1` | padding was only ever checked at offset 0 | 8 bytes of padding at offset 1 of an 8-byte buffer |
| `out.size() < HEADER_BYTES` → `- 1` | the inner copy refuses too, so the codes matched | a 255-byte buffer AND a malformed digest must still report truncation |
| `section_table_offset != 256` → `>` | the fixture only ever tried 512 | 128 and 0 as well |
| overlap check without the sort | every fixture listed sections in ascending offset order | a valid descending layout must be accepted |
| `offset < reach` → `reach - 1` | every overlap fixture overlapped by more than a byte | an overlap of exactly one byte |

The seventh, removing the explicit zero-fill in `Writer.write_zero_padding()`,
is equivalent under this implementation: the backing buffer only grows through
`resize()`, which zero-fills, and the write cursor never moves backwards, so
those bytes are already zero. That dependency is now pinned by an explicit
engine-behaviour test rather than left silent, so it becomes a visible failure
if Godot ever changes. Re-running the six fixed mutants one at a time: all six
**KILLED**, and both production files `sha256`-identical to their pristine copies
after every run.

## Buffers this allocates, for the §2 memory ledger

Neither module holds a persistent buffer. `Reader` borrows the caller's
`PackedByteArray` and adds one int cursor. `Writer` owns one growth buffer sized
by its constructor argument and doubled on demand — a once-per-save cold path
under ARCH-SAVE-003, not a per-tick column. `save_header.gd` holds one lazily
built 256-entry `PackedInt64Array` CRC table, 2048 bytes, process-wide and
immutable, derived from the reversed polynomial the architecture states. Reported
rather than added to the ledger, which is not this task's to edit.
