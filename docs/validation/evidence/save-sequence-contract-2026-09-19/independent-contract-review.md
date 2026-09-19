# Independent persistence contract review — SAVE-SEQ-R01

Date: 2026-09-19 · Scope: contract audit only, before implementation · Base commit `d94b8d2`

Acknowledged: [SAVE-SEQ-R01](../../../rulings/2026-09-19_economic_sequence_format.md) and
[decision 0155](../../../decisions/0155-widen-saved-economic-sequence-high-word.md). Reviewed against the
numbered excerpts in `source-excerpts.json` only; no code outside those ranges is claimed reviewed, and
nothing here was built, run or tested. P2's exact-arena restore is treated as landed-and-awaiting-CI and
is not re-litigated.

## 1. What checks out

**Arithmetic.** Prefix: five u32 at 0,4,8,12,16 plus a u64 at 20..27 is exactly 28 bytes, so records
beginning at 28 is consistent. Section length `28 + 64E + P + (48 + 32S)` = `76 + 64E + P + 32S`.
Empty = 76. Maximum at E=4096, P=1048576, S=256 = `76 + 262144 + 1048576 + 8192` = **1318988**, which is
exactly the current `MAX_SECTION_BYTES` 1318984 plus the four added bytes. Both stated figures are right.

**Terminal byte pin.** 4294967296 = 2^32; little-endian u64 is `00 00 00 00 01 00 00 00`. The pin at
offset 20 is correct and is a real discriminator against a u32-only writer (which would leave 00 00 00 00).

**Runtime semantics preserved.** `_advance_sequence()` carries into the high word and never wraps;
`_sequence_room()` refuses once `_next_sequence_high > U32_MAX`. The exhausted state is therefore the
single value (2^32, 0), and widening only the *saved* high word leaves both functions untouched, as the
ruling states. Command record halves stay u32 bit patterns in i32 columns — unchanged.

**All u32 pairs ordinary, no sentinel borrowing.** `(0,0)` is the initial allocator value and stays
meaningful; nothing in the proposed format assigns it a second meaning. `scheduler_events.gd`'s
initial-1 / (0,0)-sentinel policy remains confined to the scheduler's own sequence space, and the prefix
writer continues to copy the economic words verbatim. Confirmed: no sentinel is borrowed.

**Signed-int64 domain.** The largest saved high is 2^32, five orders of magnitude below 2^63, so it is
representable in a GDScript int, in `PackedInt64Array`, and through `Emitter.put_u64()`, whose only
restriction (per `canonical_state_hash.gd::_emit_wide`) is that negatives refuse. Declining to demand a
full-u64 maximum is the correct call, not a shortcut.

**Declaration accounting.** Changing one already-declared field's *type* does not move field count 604,
record count 596 or packed source count 550. Holding those pins still while owner `commands` goes 1→2,
section-schema index 11 goes 2→3 and registry version goes 3→4 is internally consistent.

## 2. Blockers (must be resolved in the implementation packet)

**B1 — the prefix writer's tuple refusal must be atomic, and is not today.**
`scheduler_events.gd::encode_section_prefix_into()` (lines 1243–1263) validates `byte_offset`, buffer size
and `section_twelve_refusal(E,P,S)` before its first `encode_u32`, but accepts `economic_next_low` /
`economic_next_high` unchecked and hands them straight to the encoder. Required: add the allocator-tuple
predicate to that same pre-write guard block — before the schema word is written, not between field
writes. The accepted domain is `0 <= high <= 4294967295` with any `0 <= low <= 4294967295`, plus exactly
`high == 4294967296 && low == 0`; everything else returns `false` having written zero bytes. Test must pass
a *pre-dirtied* `out` buffer and assert byte-for-byte equality after the refusal, since a zero-filled
buffer cannot distinguish "refused before writing" from "wrote zeros".

**B2 — `_sequence_range_refusal()` would refuse the state the format exists to carry.**
`save_section_pending_commands.gd:1132–1152` loops all six allocator words against `0..U32_MAX`. Under
schema 3 the economic high must admit 4294967296 when the economic low is 0, and only that. Required
refinement: split the economic high out of the shared loop and give it the same predicate as B1, keeping
the other five words at `0..U32_MAX` with their existing messages. Also correct the stale docstring, which
says "All four sequence allocators" over a six-element list.

**B3 — `restore_sequence()` cannot accept the terminal pair.** `commands.gd:1053` refuses
`high > U32_MAX` with `REFUSE_SEQUENCE_RANGE`, while `_window_sequence_is_legal()` (1203–1213) deliberately
admits (2^32, 0). The ruling's claim that "the owner restore introduced by SAVE-P2-R02 already admits this
exact runtime pair" is true **only** of the pending-window path. A decoded terminal section routed through
`restore_sequence()` — the API §8.1 offset 216 restore uses — refuses. Required: either widen
`restore_sequence()` to the same predicate (preferred; it is one bounded condition and the empty-queue
guard already prevents minting a duplicate key), or state in the ruling that the terminal state is
restorable *only* via `restore_pending_window()` and add a test pinning that refusal. Do not leave the two
validators disagreeing silently.

**B4 — old-schema refusal is ordered behind the widened truncation check.**
`extent_refusal()` (868–892) requires `PREFIX_BYTES` readable bytes *before* calling
`_prefix_shape_refusal()`, which is what names the actual and supported version. With `PREFIX_BYTES` 24→28,
a legacy schema-2 section whose prefix is exactly 24 bytes reports `REFUSE_TRUNCATED` rather than the
unsupported-version message the ruling's compatibility clause requires. Required: read and check the
schema word as soon as four bytes are readable at `offset`, and only then apply the 28-byte prefix extent
check. Both refusals still occur before any mutation, so atomicity is unaffected — this is purely about
emitting the diagnostic the contract promises.

**B5 — the canonical field's storage must move with its type.** `_emit_wide()` reads `_values.int64s`
unconditionally; there is no int32 path for u64 as there is in `_emit_u32()`. Changing ordinal 2
`_next_sequence_high` from `u32`/code 1 to `u64`/code 3 therefore also requires that field's storage to be
int64 and `_storage_allowed(TYPE_U64, STORAGE_INT64)` to hold. If the generated table currently supplies
int32 storage for that scalar, the change produces a storage-mismatch refusal rather than a widened hash.
Required: the packet states the storage transition explicitly and a test asserts the generated declaration
names type u64, **width 8**, storage int64, owner schema 2, ordinal 2, hash-included, scalar count 1.

## 3. Required follow-ups (bounded, not blockers)

1. `save_section_pending_commands.gd:229–231` hard-codes `EMPTY_SECTION_BYTES = 72` and
   `MAX_SECTION_BYTES = 1318984` as literals with a `72 + ...` comment. Both, and the comment, move to
   76 / 1318988. Every other layout constant in that block is read off its owner and will follow
   `SECTION_PREFIX_BYTES` automatically — these two will not.
2. `SECTION_SCHEMA_VERSION` aliases `SchedulerEventsScript.SECTION_SCHEMA_VERSION_TWO`. Introduce
   `SECTION_SCHEMA_VERSION_THREE` in `scheduler_events.gd` and repoint the alias, so the two files still
   cannot drift. Preserve the schema-2 constant if anything else names it; do not delete history.
3. `_read_prefix()` uses `SaveCodec.read_u32_at` for the high word and must use a u64 reader. The
   excerpts do not show `SaveCodec.read_u64_at`; if it does not exist, adding it is in scope as a codec
   primitive (not a new field), and it must refuse rather than truncate on a short buffer.
4. `section_twelve_length()`'s docstring quotes `72 + 64*E + P + 32*S` in prose and must be updated with
   the constant, or a reader will trust the wrong formula.
5. The declaration id string embeds its version: `RWL-CANONICAL-REGISTRY-2026-09-15-3`. "Retain the
   registry_id namespace, update its version" therefore needs the exact new string spelled out in the
   packet before any regeneration, because `test_canonical_state_hash.gd:118–119` pins it as a literal
   alongside `REGISTRY_DECLARATION_VERSION`. Recommend `RWL-CANONICAL-REGISTRY-<this ruling's date>-4`,
   stated explicitly in the packet rather than inferred by the generator.
6. `OWNER_VERSIONS` index 48 (section 12, `commands`) 1→2, and the registry JSON's
   `section_schema_versions[11]` 2→3. `OWNER_FIELD_COUNTS[48]` stays 20.

## 4. Acceptance-test gaps

The stated fixture matrix is good on the allocator domain (initial zero, 0x7fffffff, 0x80000000, final
available pair, terminal, 4294967297, terminal-with-nonzero-low, negatives, truncated prefix, old and
unknown schemas). Missing, and required:

- **B1's atomicity test**: pre-dirtied buffer, invalid tuple, assert every byte unchanged and no owner or
  caller state touched. The ruling asserts the property but names no test for it.
- **Arithmetic pins**: `section_twelve_length(0,0,0) == 76`, `(4096, 1048576, 256) == 1318988`, and
  agreement with `EMPTY_SECTION_BYTES` / `MAX_SECTION_BYTES` and with the section directory's own length,
  so the two derivations cannot diverge.
- **Upper-word garbage**: a high whose bytes 24..27 are nonzero but which is not exactly 2^32 (e.g.
  `0x0000_0002_0000_0000`) refuses. `4294967297` alone does not cover a set bit above the carry.
- **B4's ordering test**: a 24-byte schema-2 section reports the unsupported-version refusal naming 2 and
  3, not `REFUSE_TRUNCATED`, and the input buffer is not rewritten.
- **Hash-difference test**: canonical hash of a world at (2^32, 0) differs from the same world at
  (4294967295, 4294967295) — the terminal state must not hash as its predecessor.
- **Census**: assert no remaining caller derives 24 or 72 independently of the constants.

The drain-to-empty repetition, the two-store recovery repeat and the P2 offset/capacity repeat under the
new format are correctly specified as stated. "Do not claim the unimplemented full-file coordinator is
complete" is correctly carried and should stay in the umbrella's prerequisite list.

## 5. Verdict

The format is sound: the arithmetic closes, the terminal state is representable exactly once, the signed
int64 domain is comfortable, and no scheduler sentinel is borrowed. Five blockers (B1–B5) are all bounded
edits to existing validators and constants — none requires a new field, a second world, or a widening of
the allocator's runtime representation. Recommend proceeding to implementation with B1–B5 and §3–§4
folded into the packet, then a fresh independent review, the full Godot suite and static checks before
merge, as the ruling already requires.
