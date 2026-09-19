# Independent persistence review — SAVE-SEQ-R01 v2 (section 12 schema 3)

Date: 2026-09-19 · Independent review only · No code or test edits made, nothing executed.

## Acknowledgement

SAVE-SEQ-R01 **version 2** (`docs/rulings/2026-09-19_economic_sequence_format.md`, sha256
`7547cc81…a91b9`) is acknowledged, including its "Version2 source-review refinements (2026-09-19)"
section: pre-write validation of the complete allocator tuple in
`encode_section_prefix_into()`, the split of the economic high word out of the u32 range loop,
schema recognition before the full 28-byte prefix, use of the existing `read_u64_at`, the retained
registry namespace `RWL-CANONICAL-REGISTRY-2026-09-15-3` with only `registry_version` advancing,
`restore_pending_window()` as the exclusive section-12 install route with
`commands.restore_sequence()` left as a u32-only hook that must refuse the terminal tuple, and the
explicit non-resolution of the full-file header field at 216.

## Method and scope

I reviewed the exact implementation supplied in context: `godot/scripts/core/scheduler_events.gd`,
`godot/scripts/core/save_section_pending_commands.gd`, `godot/scripts/core/commands.gd`,
`godot/scripts/core/save_codec.gd`, `godot/scripts/core/canonical_state_hash.gd` (including the
full generated declaration table), `docs/planning/canonical_state_registry.json` (full),
`godot/test/test_economic_sequence_format.gd`, `godot/test/test_save_section_pending_commands.gd`,
`godot/test/test_scheduler_events.gd`, `godot/test/test_canonical_state_hash.gd`,
`godot/test/save_sequence_focus.gd`, the integration notes and the focused run log.

Everything below is derived by reading those bytes. I ran nothing, applied nothing and computed no
hashes. Where a claim depends on an artifact I was not given, I say so under **Limits**.

## Verdict

**No blocking findings.** The active implementation matches SAVE-SEQ-R01 v2 on every point I could
check against the supplied sources. Five non-blocking findings follow, prioritized, each with an
exact location and a bounded repair.

## What I verified, and how

### Framing arithmetic, re-derived rather than read back

`scheduler_events.gd`:

```gdscript
const SECTION_PREFIX_BYTES: int = 28
const OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_LOW: int = 16
const OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_HIGH: int = 20
const PREFIX_NEXT_SEQUENCE_HIGH_BYTES: int = 8
```

`5 * 4 + 8 = 28`. `section_twelve_length()` returns
`28 + 64*E + P + 48 + 32*S`, i.e. `76 + 64E + P + 32S`. Empty = 76. Maximum
`76 + 64*4096 + 1048576 + 32*256 = 262220 + 1048576 + 8192 = 1318988`, which matches both
`PendingCommands.MAX_SECTION_BYTES` and the ruling. The documentation table in
`save_section_pending_commands.gd` was shifted correctly with the widening: tag at `28+64E+P`,
control at `44+64E+P` (tag+16), scheduler records at `76+64E+P` (tag+48), consistent with
`EXTENSION_HEADER_BYTES = 16` / `EXTENSION_FIXED_BYTES = 48`. Record widths are untouched
(`RECORD_BYTES` 64 economic, 32 scheduler), and the four scheduler control words plus the economic
low word remain u32 on the wire.

### Pure, atomic prefix writer

`scheduler_events.gd::encode_section_prefix_into()` performs, in order and **before any**
`encode_*` call:

```gdscript
if byte_offset < 0 or out.size() < SECTION_PREFIX_BYTES \
		or byte_offset > out.size() - SECTION_PREFIX_BYTES:
	return false
if section_twelve_refusal(economic_count, economic_payload_used, scheduler_count) != REFUSE_NONE:
	return false
if economic_allocator_refusal(economic_next_high, economic_next_low) != REFUSE_NONE:
	return false
```

The room check is a subtraction, so a very large offset cannot wrap into apparent room; the test
exercises `Codec.INT64_MAX` directly. The schema word is written only after all three gates, so no
invalid tuple can leave a half-written prefix naming schema 3. `economic_allocator_refusal()` is
total and pure: it admits any u32 low, exactly `ECONOMIC_TERMINAL_SEQUENCE_HIGH` (`U32_MODULUS` =
4294967296) beside low 0, and any high in `0..U32_MAX`; it refuses negatives, 4294967297,
0x0000000200000000 and a terminal high carrying a nonzero low. Nothing clamps or wraps.

`test_economic_sequence_format.gd::test_prefix_writer_refuses_invalid_tuple_without_any_write`
pre-dirties a 44-byte buffer with `0xA5`, writes at offset 8, and asserts full byte equality after
each of the six invalid tuples. That is the pre-dirtied byte-exact refusal the ruling asks for.

### Schema recognition before the full prefix; checked u64 decode

`save_section_pending_commands.gd::extent_refusal()` orders the gates as:
negative offset → `_schema_word_refusal()` → 28-byte prefix requirement → count/extension shape →
total length. `_schema_word_refusal()` uses `SaveCodec.read_u32_at()` and reports
`SAVE_PC_TRUNCATED` when fewer than four bytes are readable, otherwise
`SAVE_PC_SECTION_SCHEMA` naming both the declared and the supported version:

```gdscript
"section 12 declares schema %d, not the supported %d" % [scalar.value, SECTION_SCHEMA_VERSION]
```

A 24-byte buffer declaring schema 2 therefore reports the unsupported version, not truncation —
pinned by `test_schema_is_recognized_before_full_prefix_is_required`, which also covers sizes
0,1,2,3,4,27 for the truncation side. No migration, no default, no rewrite of input bytes; the
hostile-input immutability assertion (`assert_equal(bytes, input_before, …)`) is present in the
shared `_decode_refusal()` helper.

`_read_prefix()` uses the existing checked primitive and tests its result:

```gdscript
if not SaveCodec.read_u64_at(bytes, offset + OFFSET_PREFIX_NEXT_SEQUENCE_HIGH, scalar):
	return SaveHeader.Refusal.new(REFUSE_SEQUENCE_RANGE, …)
```

No duplicate primitive was added. A set high bit (`bytes[27] = 128`) is refused rather than
surfacing as zero or as a negative int64 — pinned in
`test_invalid_u64_and_terminal_tuples_refuse_atomically`.

### Validate-then-commit

`decode_into()` parses into a local `Record`, runs `record_refusal()` against that local, and only
then calls `out.copy_from(parsed)`. `_scalar_refusal → _sequence_range_refusal` checks the five
remaining u32 allocator words and delegates the economic high word to `_economic_high_refusal()`,
which reuses `SchedulerEventsScript.economic_allocator_refusal()` so the pre-write gate and the
decoder cannot disagree about the legal domain. The test helper proves caller immutability by
re-encoding the caller's `Record` before and after and comparing bytes, not by inspecting a flag.

### Actual final issue, pending and drained terminal round trips

`_round_trip_exhaustion()` stages `(4294967295, 4294967295)` through the public hook, then issues a
real ordinary command via `submit_into()` and asserts the runtime transition to `(4294967296, 0)`.
I confirmed that transition against `commands.gd::_advance_sequence()` and that
`_sequence_room()` refuses from there (`if _next_sequence_high > U32_MAX: return false`). Record
halves keep their signed-i32 storage (`sequence_high == -1`, `sequence_low == -1`). The test pins
the terminal bytes `00 00 00 00 01 00 00 00` at offset 20 and the section sizes 142 (pending) and
76 (drained), proving the four added bytes and nothing else. Both the pending and the fully drained
variants are exercised, which is what the ruling requires since pending records cannot stand in for
an exhaustion marker.

After restore, the next ordinary submission refuses with `COMMAND_SEQUENCE_EXHAUSTED` and the test
re-captures and compares full section bytes, which simultaneously proves no wrap, no lost pending
work, no arena change and no consumed sequence (the allocator words are part of those bytes).
`accepted_count() == 0` separately proves restoration is not admission.

### Restoration route and the legacy hook

`save_section_pending_commands.gd` installs the economic side exclusively through
`commands_store.restore_pending_window(records, arena, high, low)`, including the empty-window
case, and the rollback path reinstalls `PackedByteArray(), PackedByteArray(), prior_high,
prior_low` through the same API with its bool checked. `commands.gd::_window_sequence_is_legal()`
admits the terminal pair, so a previously exhausted owner can be put back. `restore_sequence()`
remains u32-only (`if high < 0 or high > U32_MAX …`) and its refusal of `(4294967296, 0)` is pinned
in `test_economic_sequence_format.gd`. Its previously stale comment about the header at 216 has
been corrected and now points at `restore_pending_window()`.

### Canonical declaration

Registry JSON `(12, "commands")`: `owner_schema_version: 2`; field `_next_sequence_high` with
`type: "u64"`, `type_code: 3`, `ordinal: 2`, `hash: true`, `shape: {count: 1}`; twenty fields, all
other keys and ordinals byte-for-byte as before. `registry_id` retained, `registry_version: 4`,
`record_count: 596`, `packed_source_field_count: 550`. `section_schema_versions[11] == 3`.

Generated table: `DECLARATION_ID` unchanged, `DECLARATION_VERSION = 4`, counts 52/604/596. I
re-derived the commands owner's global field span from `OWNER_FIELD_COUNTS` (cumulative 567) and
confirmed it against `FIELD_COUNT_INDEXES`, which lists exactly `567, 568, 569, 570` for the four
commands scalars — so index 569 is `_next_sequence_high` with declared count 1. I also re-derived
the owner-version index (48) and confirmed `OWNER_VERSIONS[48] == 2`.

Test pins: `test_economic_high_declaration_and_value_preserve_exhaustion` asserts owner schema 2,
ordinal 2 key, `field_type == 3`, `field_is_hashed`, declared count 1, an actual eight-byte
little-endian emission (`ffffffff00000000` vs `0000000001000000`) through the real `_emit_wide()`
STORAGE_INT64 path, and a hash difference between the final-available and terminal tuples.
`test_generated_fields_match_the_registry_json` keeps the compiled table and the JSON in agreement.
No new per-field storage member was introduced.

### Pinned wire fixtures

I decoded both hex vectors in `test_save_section_pending_commands.gd` field by field rather than
trusting them. `_empty_section_hex()` is 76 bytes: schema `03000000`, E=0, P=0, X=`30000000` (48),
low=0, **u64 high = `0000000000000000` at bytes 20..27**, `SCHQ` at 28, version 1 at 36, payload
length 32 at 40, control head/count 0, next low 1, `last_drained = -1` as `ffffffffffffffff` at 60.
`_one_each_section_hex()` is 177 bytes: E=1, P=5, X=`50000000` (80), record at 28 with
`execute_tick = 1`, `kind = 8` at 48, `target_slot = -1` at 52, `arg0 = 5` at 68,
`payload_length = 5` at 80, payload `0102030405` at 92, `SCHQ0001` at 97 (= 28 + 64 + 5), scheduler
record at 145 with `value = 2` at 169. Both are internally consistent with the 28-byte schema-3
prefix, and the integration notes' account of how they were transformed (schema word 2→3, four zero
bytes inserted at offset 24, lengths asserted independently) is consistent with what the bytes now
say. Nothing in either fixture is derived from the new writer.

### Unsigned boundary cases

`test_ordinary_high_words_keep_unsigned_values_and_zero_is_ordinary` round-trips high words 0,
0x7fffffff, 0x80000000, 0xffffffff and 0x100000000, asserting `decode_u64(20)` equals the unsigned
value in each case — so the old u32 high bit is never read as the sign of the new u64, and zero
remains an ordinary initial value rather than a sentinel. The pre-existing record-half sign-bit
tests (`test_economic_sequence_at_the_u32_sign_bit_round_trips`,
`test_economic_key_order_is_unsigned_across_the_sign_bit`,
`test_reversed_sign_bit_keys_are_refused`) still guard the i32 record storage, which this change
deliberately does not touch.

### Parent's intake corrections

The three corrections described in the integration notes are visible and correct in the reviewed
sources: the restored success-return is the `economic_allocator_refusal()` gate sequence in
`encode_section_prefix_into()` (the function returns `true` only after all six field writes);
`OWNER_SCHEMA_VERSION_COMMANDS` now reads 2 and is asserted as such; the two stale comments
(`restore_sequence()`'s header-216 claim, and `scheduler_events.gd`'s schema-2 retention note) now
describe the active behaviour.

## Prioritized non-blocking findings

### F1 — `section_schema_versions[11]` is unpinned, so registry/codec drift on §12 passes green

`docs/planning/canonical_state_registry.json` carries the section-schema vector and index 11 is
correctly `3`. No test asserts it. `test_canonical_state_hash.gd` pins only index 0
(`assert_equal(int((data["section_schema_versions"] as Array)[0]), 3, …)`) and index 6
(`assert_equal(int((data["section_schema_versions"] as Array)[6]), SECTION_SEVEN_SCHEMA_VERSION, …)`),
and the latter is explicitly cross-checked against the §7 codec constant. §12 has no equivalent:
`test_save_section_pending_commands.gd` asserts `PendingCommands.SECTION_SCHEMA_VERSION == 3`
against a literal only. A future edit that left the registry vector at 2 while the codec wrote 3
would therefore keep the whole suite green.

Bounded repair (one test, no production change): in `test_canonical_state_hash.gd`, beside the
existing index-6 assertion, add a `SECTION_TWELVE_SCHEMA_VERSION: int = 3` literal and assert both
`int((data["section_schema_versions"] as Array)[11])` and
`PendingCommands.SECTION_SCHEMA_VERSION` against it, mirroring the §7 pattern exactly. This
reproduces the §7 four-source discipline (literal, registry, codec, table) for the section this
ruling changes.

### F2 — `source_module_sha256` for `commands` and `scheduler_events` no longer matches the shipped files

The registry records:

```json
"commands": "f174bb300044e78db875d46620d6c8a28ab7f31f0795d752251bcf3d4e280c13",
"scheduler_events": "5981c3c05c454f46968a252bd544da084b9a530b3bbcf26d8041c583e09063bc",
"save_codec": "afd7b7f51b8ddc2cd282baecf19ff8a582695346a7005108cb4de3958e3af508"
```

The dispatch bundle declares, for the same paths, `commands.gd` =
`024f5725f8a23e634a85ce3916b769781c06b4da8fe8abffdf6d5039ad5070bc` and `scheduler_events.gd` =
`b8d7389b6a679f98ff5c0fd1beb6836561c6aa132f7f70dd56800229d908f9ee` — both differ from the recorded
values, while `save_codec.gd` (untouched by this packet) matches the registry exactly. Both
mismatching modules are the two this packet edited.

This is genuinely ambiguous and I am not asserting a defect. Either (a) `source_module_sha256`
tracks current module content, in which case these two entries are now stale and should be
regenerated through the existing tool alongside the declaration table, or (b) it deliberately pins
the historical snapshot named by `"source_commit": "reconciled_to_integration_head_from_197472b9d7f2"`,
in which case no action is correct. The exact match on `save_codec` is weak evidence for (a). No
test reads this map, so neither reading is enforced.

Bounded repair: one line of owner adjudication. If (a), regenerate those two entries with the
existing tool; if (b), add one sentence to the registry's `policy` string stating that
`source_module_sha256` pins the reconciliation snapshot and is not expected to track HEAD. I could
not compute SHA-256 here, so I am comparing two declared values, not a file against itself.

### F3 — decision 0155 and the ruling preamble still describe this contract as inactive

`docs/decisions/0155-widen-saved-economic-sequence-high-word.md` states
`Status: Accepted follow-up contract; implementation pending` and closes
"This contract is separate from P2's schema2 arena repair and is not yet active code." The ruling's
second line similarly reads "This is a follow-up format contract, not an active schema change in
the P2 repair." Both are now false of the tree under review: the format is live, schema 2 is refused
by name, and the registry is at version 4.

Bounded repair: change 0155's status line to record the implementation landing and replace its
closing sentence with one naming the active schema; leave the ruling's body untouched apart from
the single preamble clause if the ruling's owner agrees, since rulings are normally immutable
history. Preferred minimal action: amend 0155 only.

### F4 — stale narrative beside a pin that this ruling moved

`godot/test/test_canonical_state_hash.gd` declares the independent pins:

```gdscript
const REGISTRY_DECLARATION_ID: String = "RWL-CANONICAL-REGISTRY-2026-09-15-3"
const REGISTRY_DECLARATION_VERSION: int = 4
```

Both values are correct. The comment immediately above them still narrates only INV-CANON-R01 and
says "INV-CANON-R01 moves the identity 2026-09-14-2 -> 2026-09-15-3 and the version 2 -> 3", which
no longer explains why the literal reads 4. The comment block is the mechanism that makes these
literals load-bearing, so leaving it describing a superseded transition weakens exactly the
independent anchor it exists to justify. Note also that SAVE-SEQ-R01 retains the identity string
and moves only the version, which is the first time these two pins move independently.

Bounded repair: append one sentence to that comment recording SAVE-SEQ-R01's `registry_version`
3 → 4 with an unchanged `registry_id`, and why the identity deliberately did not move.

### F5 — two dead constants and one verification gap adjacent to the widened word

Three small items, all optional:

* `save_section_pending_commands.gd` declares
  `const SECTION_SCHEMA_VERSION_SUPERSEDED: int = SchedulerEventsScript.SECTION_SCHEMA_VERSION_TWO`
  with the comment "named ONLY so an old file's refusal can report the actual version it declares".
  `_schema_word_refusal()` reports `scalar.value` read from the file, never this constant, so the
  comment describes a role the constant does not play and the constant (and, transitively, its
  `scheduler_events` source) is unreferenced by executable code. Either delete both, or correct the
  comment to say it is retained purely as history.
* `scheduler_events.gd::_assert_contracts()` asserts `EXTENSION_FIXED_BYTES == 48` but does not
  assert `SECTION_PREFIX_BYTES == 5 * FIELD_BYTES + PREFIX_NEXT_SEQUENCE_HIGH_BYTES`, even though
  the comment beside `PREFIX_NEXT_SEQUENCE_HIGH_BYTES` says the 28 is "arithmetic a reader can
  check". One added assert would make the widening self-checking at construction, matching how the
  32-byte record stride is already guarded.
* `agrees_with_stores()` compares counts, keys, kinds, payload lengths and the arena cursor, but
  never the allocator pair — `_store_economic_refusal()` has no comparison against
  `store.next_sequence_high()` / `next_sequence_low()`. This is pre-existing, not introduced here,
  but SAVE-SEQ-R01 makes the allocator the one field whose corruption this independent cross-check
  cannot see, and exhaustion is precisely the state the ruling cares about. Two added comparisons
  would close it; I verified this would not conflict with
  `test_agrees_with_stores_cross_checks_the_public_readers`, whose two cases are an exact self-
  capture and an empty pair that already refuses on count.

## Limits — what this review does not cover

* **Nothing was executed.** I did not run Godot, the focused suite, the full suite, static checks or
  any hashing tool, and I did not apply or verify any patch. The reported focused result (268
  tests / 33704 assertions / 0 failures) is taken from the supplied log, not reproduced.
* **Files not supplied.** `godot/test/test_commands_arena_restore.gd` is named in
  `save_sequence_focus.gd` and appears in the log (including
  `test_late_scheduler_failure_can_recover_a_terminal_prior_allocator` and
  `test_exact_record_capacity_restores_without_allocating_sequences`), but its source was outside
  context. I therefore cannot independently confirm that the P2 offset/capacity and two-store
  recovery coverage was genuinely re-run under the new format; I can only confirm that the owner
  APIs those tests exercise admit the terminal tuple and that the suite is wired into the focus
  runner. The same applies to `test_commands.gd`.
* **Prose artifacts not supplied.** `docs/persistence_state_registry.md`, the current save matrix,
  the capacity sidecar digest and its generator, and `tools/generate_canonical_state_table.py` were
  not in context. The ruling requires the prose registry, the save matrix and the capacity sidecar
  to be updated/regenerated; I can neither confirm nor deny that those were done.
* **No full-file, coordinator, header-216 or native acceptance is claimed or reviewed.** Consistent
  with the ruling, `Header.replay_sequence` at 216 and `WorldRuntime.next_command_sequence` remain
  unresolved and are correctly left untouched and unclaimed by this change; the code comments say so
  explicitly. Cross-process save/load continuation remains blocked (no save container module), which
  `test_scheduler_events.gd::test_the_codec_is_local_only_because_no_writer_exists` still asserts.
* **Registry consistency is checked, not proved.** I re-derived owner indices, field spans and the
  two declaration counts by hand from the generated table and the JSON; I did not regenerate either
  artifact and cannot attest that the generator would emit exactly these bytes.
* **Section 12 descriptor interaction.** `section_length_refusal()` and `descriptor_row_count()` are
  internally consistent with the new length, but the section directory writer itself was not in
  context, so I did not verify that any caller carries a fixed §12 length constant of its own.
