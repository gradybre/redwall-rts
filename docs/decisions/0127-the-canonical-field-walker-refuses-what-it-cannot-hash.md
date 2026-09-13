# 0127 — The §15 canonical field walker compiles its order and refuses what it cannot hash
Date: 2026-09-12 · Status: Accepted

## Decision

Implement **SAVE-R09's section 15 STATE_DIGEST** and its RWL-STATE-1 stream in the new
`godot/scripts/core/canonical_state_hash.gd`, the owner
[REG-R01 names](../rulings/2026-09-12_save_registry_answers.md) when it says
"canonical_state_hash owns §15 and never includes itself".

1. **Record order comes from a compiled constant table, not from a runtime read and not
   from anything derived at runtime.** The table is generated from
   [`planning/canonical_state_registry.json`](../planning/canonical_state_registry.json)
   (registry `RWL-CANONICAL-REGISTRY-2026-09-12-1`: 50 owners, 590 declared fields, 582
   canonical records, 530 persisted packed fields) and sits between the
   `BEGIN/END GENERATED DECLARATION TABLE` markers at the bottom of the module.
   `test_canonical_state_hash.gd` re-reads that JSON and compares every owner and every
   field against the table, so the table cannot drift from the registry and survive.
2. **There is no subset mode.** `Walker.digest_into()` refuses with `CANONICAL_NO_ADAPTER`
   before hashing a single byte if any declared owner has no value adapter.
   `Walker.missing_adapter_owners()` names them. **As of this record not one adapter
   exists**, so the production walker refuses and lists all 50 owners. That refusal is the
   deliverable; REG-R01's "Missing producers cannot be waved through by feeding a digest of
   a subset or arbitrary empty bytes" is implemented literally.
3. **The release/fixture distinction is in the API, not only in prose.**
   `DigestResult.covers_release_state` is true only when the canonical declaration was
   walked AND every owner supplied an adapter. The pinned fixture below digests
   successfully and reports `covers_release_state == false`.
4. **Section 15 is structurally excluded.** `Declaration.validate()` refuses any owner
   declaring section 15 with `CANONICAL_SELF_INCLUSION`; records exist for sections 1–14
   only. This is separate from the header's body SHA-256 over bytes `[256, EOF)`, which
   `save_header.gd` owns and which this module neither reads nor produces.
5. **Ordering is checked, never re-derived.** Owners must arrive in section-then-ASCII-
   `owner_key` order and fields in their declared ordinal order. Nothing in the module
   sorts anything; `ascii_compare()` is an explicit byte-wise comparison so no locale or
   case rule can creep in.

`release_save_ready` stays **false**. This record certifies no save, closes no MOVE gate and
adds no simulation-owned packed column.

## The pinned fixture, reproducible by hand

Three owners, seven declared fields, six records. Section 1 holds `"Zed"` and `"alpha"` —
ASCII order, because `'Z'` is `0x5A` and `'a'` is `0x61`, which disagrees with both
case-insensitive and length order. `"Zed"`'s declared ordinals are `_zulu` then `_alpha`,
which disagrees with alphabetical order. `alpha._excluded_tick` is declared with
`hash=false` and emits nothing. `"Móle"` is 4 characters and 5 UTF-8 bytes.

Prefix inputs: rules/catalog/map/lookup identities are 32 bytes of `0x11`, `0x22`, `0x33`,
`0x44`; the engine identity line is `4.7.2.stable.official.ed1daf0bf\n` (32 bytes,
including the LF); `completed_tick` is 54000.

| Stream element | Hex |
|---|---|
| `RWL-STATE-1`, 11 ASCII bytes, no terminator | `52574c2d53544154452d31` |
| rules, catalog, map, lookup identities | `11`×32 `22`×32 `33`×32 `44`×32 |
| engine identity line, u32 byte length then the line | `20000000` + `342e372e322e737461626c652e6f6666696369616c2e6564316461663062660a` |
| `completed_tick:i64 LE` then `record_count:u32 LE` | `f0d2000000000000` `06000000` |
| `(1, "Zed", "_zulu")` type 2, 3 values `INT32_MIN, -1, INT32_MAX` | `01000000030000005a6564050000005f7a756c7502030000000000000000000080ffffffffffffff7f` |
| `(1, "Zed", "_alpha")` type 0, 2 values `0, 255` | `01000000030000005a6564060000005f616c70686100020000000000000000ff` |
| `(1, "alpha", "_cursor")` type 1, 1 value `0x80000000` | `0100000005000000616c706861070000005f637572736f7201010000000000000000000080` |
| `(1, "alpha", "_name")` type 5, values `""` and `"Móle"` | `0100000005000000616c706861050000005f6e616d6505020000000000000000000000050000004dc3b36c65` |
| `(14, "residents", "_big")` type 3, 1 value `INT64_MAX` | `0e000000090000007265736964656e7473040000005f626967030100000000000000ffffffffffffff7f` |
| `(14, "residents", "_debt")` type 4, 1 value `-1` | `0e000000090000007265736964656e7473050000005f64656274040100000000000000ffffffffffffffff` |

The concatenation is **426 bytes**, and

```
SHA-256 = 7711d6b5dcd94db94f82bb4d61fb976506ffb57aec60eb62d94d4051aad61da0
```

The suite pins both, split by stream element, as constants computed independently in Python
rather than read back out of the module.

## Why

### Why a compiled table and not a runtime JSON read

REG-R01 permits either: "runtime uses the checked-in declaration". The cost is real in both
directions and the choice was made on two facts, not on taste.

Against the runtime read:

* **The registry lives outside `res://`.** `docs/planning/canonical_state_registry.json` is
  at the repository root, and `res://` is `godot/`. The test can reach it through
  `res://../docs/...` exactly as `test_item_definitions.gd` already reaches
  `docs/gameplay_balance.md`, but an exported build cannot: `..` does not escape a PCK. A
  digest that only works from a source checkout is not a save format.
* **Godot's `JSON.parse_string()` returns every number as a float.** `ordinal`,
  `type_code`, `section_id` and `value_count` would all arrive as floats and be converted
  back, putting a float on the path of authoritative ordering. The suite's own comparison
  test does exactly that conversion, which is why it is in the test and not in the module —
  `test_module_has_no_float_and_no_dictionary()` greps the module's non-comment source for
  `float`, `Dictionary` and `JSON.` and fails on any of them.

Against the compiled table: it can go stale, and a hand edit to 590 rows would be invisible.
That is answered mechanically, not by discipline. The table is emitted by a generator into
marked regions, and `test_generated_table_matches_the_registry_json()` /
`test_generated_fields_match_the_registry_json()` compare all 50 owners and all 590 fields
back against the JSON. Mutating one generated field key, or swapping two generated owner
keys, both fail the suite (verified; see the mutation table below).

**Outstanding, and outside this lane's allowlist:** the generator itself belongs at
`tools/generate_canonical_state_table.py`, alongside the existing
`tools/extract_item_definitions.py`. It was written and used to produce the committed table
but could not be committed here. Until it lands, the equivalence test is the guarantee and
the generator is a convenience.

### Why the walker drives and the adapter only answers

An adapter exposes `canonical_field_values(field_key: StringName, out: FieldValues) -> bool`
and nothing else. It cannot choose the order, cannot choose which fields exist, and cannot
decline one. This is the shape that makes "missing/duplicate/unregistered fields or an order
mismatch fail verification" enforceable: the declaration is the only list, and an adapter
registered for an owner the declaration does not carry is refused at registration with
`CANONICAL_UNREGISTERED_OWNER`.

`FieldValues` takes the owner's own packed column by reference. Packed arrays are
copy-on-write, so handing over a 16384-row column costs a refcount, not 64 KiB. The walker
never materialises the stream: `Emitter` holds one 65536-byte window, allocated in its
`_init`, and folds it into `HashingContext` as it fills. Capture is opt-in, explicitly
capped, and **refuses** rather than truncating, because a truncated capture printed next to
a correct digest is precisely the plausible-but-wrong artifact this module exists to stop.

### The int32/int64 sign trap, stated once

GDScript ints are signed 64-bit. `0x80000000` is a positive GDScript int; `-2147483648` is
its int32 reading. The registry stores u32 columns in `PackedInt32Array` — `rng._state` is a
nine-element u32 column, and `entity_directory._next_persistent_id` has a declared range
running to 2147483648, which no i32 value can hold. So a type 1 (u32) field accepts **two**
declared storage forms and the adapter must say which it means:

* `STORAGE_INT32` — reinterpret the two's-complement bits through
  `SaveCodec.int32_bits_to_u32()`. The fixture's `_cursor` does this and emits `00000080`.
* `STORAGE_INT64` — a logical unsigned value, range-checked against `0..4294967295`.
  `4294967295` is accepted and emits `ffffffff`; `4294967296` refuses.

Neither is a default and neither is inferred. Type 3 (u64) accepts only `STORAGE_INT64` and
refuses a negative value outright rather than emitting a huge unsigned number GDScript could
never have meant, matching `save_codec.gd`'s `REFUSE_UNREPRESENTABLE_U64` on the read side.

### What the registry declares that the walker still cannot enforce

**BLOCKER (named, not invented around):** 501 of the 590 declared fields carry
`shape.declared_capacity` as prose — strings like `` "`TILE_COUNT` = 16384" `` — not as an
integer. Only the 54 fields with an integer `shape.count` can have their element count
checked, and they are. For every other field the walker checks the storage form and the
non-negative count but **cannot** verify that the owner emitted its full schema capacity.
That check belongs with each store owner's adapter, or needs the registry to publish
resolved integer capacities. No capacity constant was invented here.

Similarly, the walker enforces a per-value UTF-8 byte cap for type 5 fields and **refuses**
(`CANONICAL_STRING_CAP_UNDECLARED`) a type 5 field that declares none — S2's "u32 is not an
allocation permission" read literally. Exactly one field in the registry declares one:
`(14, "residents", "_name_key")` at 128 bytes.

### What §15 is not

Five things are deliberately absent from the input, each because a ruling says so:

* **Section 15 itself**, per REG-R01's `nonrecord_sections`: "not its own input".
* **The body SHA-256**, which is a different digest over file bytes `[256, EOF)`.
* **Section CRCs and descriptor bookkeeping.**
* **`world_runtime._completed_tick`**, which appears once in the prefix. The registry marks
  it `hash: false` with `hash_location: "RWL-STATE-1 prefix exactly once"`.
* **`_debt` and the six clock counters**, ARCH-SAVE-007's host exclusions. They are declared,
  they persist in the 80-byte §1 body, and they contribute no record. The suite asserts that
  `world_runtime` declares 12 fields and hashes exactly four: `_world_seed`, `_seeded`,
  `_requested_speed`, `_pause_mask`.

## Evidence

Full suite on this branch, one line, verbatim:

```
3834 test(s), 136601 assertion(s), 0 failure(s)
```

Ten mutations, one per Godot invocation, each restored and `shasum -a 256` byte-compared
against a pristine copy (`1caefd3ceb2f411e8726c67cc4e5af6dc86b148c5965ee9043562e9b177e2d09`)
before the next was applied. Every one died:

| Mutation | Result |
|---|---|
| M1 walk each owner's fields alphabetically by key, not by declared ordinal | 6 failure(s) |
| M2 `ascii_compare()` case-folds, so owner order is not ASCII | 26 failure(s) |
| M2b walk the declared owners in reverse | 6 failure(s) |
| M3 accept a section 15 owner, letting the digest include itself | 1 failure(s) |
| M4 stop noticing that a declared owner has no adapter | 3 failure(s) |
| M5 write a string's CHARACTER count as its u32 length prefix | 8 failure(s) |
| M6 emit no values for an i32 field, so one changed value cannot move the digest | 7 failure(s) |
| M7 emit the registry's excluded fields as records anyway | 8 failure(s) |
| M8 one generated field key drifts from the registry JSON | 1 failure(s) |
| M9 two generated owner keys swapped in the table | 3 failure(s) |

`python3 docs/validation/ready07_arithmetic.py` → `{"status": "PASS", ...}`.
`python3 docs/validation/decision_numbers.py` → `PASS -- 112 records, 0 problem(s)`.
`python3 docs/validation/validate_save_registry_handoff.py --require-release-ready` →
`REFUSED: release save not ready`, exit 2, which is the required behaviour.

`python3 docs/validation/state_registry_coverage.py` **fails on this branch** with
`FAIL C1 canonical_state_hash.gd has no registry section`, and
`validate_save_registry_handoff.py --source-root .` fails through it. The fix is one section
in `docs/persistence_state_registry.md`, which is not on this lane's allowlist; the exact
row, with its byte arithmetic, is in the handoff report and was trialled locally (both
validators pass with it, `state_registry_coverage: PASS -- 48 modules, 327 rows, 648 packed
columns checked`) before the document was restored byte-for-byte.

## What this does not do

No owner adapter is implemented, so no real digest can be produced. The 50 owners still
needing one are every owner in the registry. Load orchestration, the four identity producers
(SAVE-R09-003), the engine identity line producer and cross-process parity are all separate
and unstarted. §15 remains, in REG-R01's words, something that "cannot be passed off as a
complete release digest while a required adapter or live state owner is omitted".
