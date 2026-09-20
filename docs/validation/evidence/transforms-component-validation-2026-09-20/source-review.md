# Independent source review — Transform component validation

Date: 2026-09-20. Scope: accepted TRANSFORMS-S4-VALIDATE-R01 v1 / ADR 0173, as
implemented by `transforms.gd::columns_refusal`, `_has_duplicate_positive_binding`
and `save_owner_transforms.gd`. Reviewed as source, against the compiled schema,
the parent suite and the recorded evidence. **No blocker.** Nothing below was run
by this review; every figure is re-derived arithmetic or a reading of the source.

## Canonical shape, order and byte arithmetic

The nine accessors are read in owner-local ordinal order 0..8 and passed straight
into the predicate's argument list. `FIELD_KEYS[271..279]` of the compiled schema
are `_bound_persistent_id`, `_x`, `_y`, `_z`, `_yaw`, `_prev_x`, `_prev_y`,
`_prev_z`, `_prev_yaw` — stamp FIRST, matching both the contract and the parameter
names. Every owner-15 field is I32, so `storage_index()` equals the ordinal and
`i32_column(field)` cannot silently address a neighbouring bucket; gate 4 pins each
ordinal's key, type and 87552 extent with scalar constants regardless.

Values 9 × 87552 × 4 = 3151872. Payload adds the 4-byte child header and nine
8-byte element counts: 3151872 + 76 = 3151948, matching `OWNER_PAYLOAD_BYTES[15]`.
Block adds 24 wrapper bytes and the 10-byte key: 3151982, matching
`OWNER_BLOCK_BYTES[15]`. `child_extent_count` is 0 and `primary_count` 87552, both
cross-checked against `Transforms.TRANSFORM_CAPACITY` and `ROW_ELEMENT_COUNT`.
Schema and registry versions are untouched.

## Gates, order and domain

Each gate completes over all 87552 rows before the next begins, so a first refusal
is global rather than first-row: shape, then binding non-negativity, then positive
uniqueness, then the eight-zero rule for zero-bound rows, then `REFUSE_NONE`.
Negative stamps are eliminated before the duplicate scan, so `value > 0` in the
adjacent-pair test is sufficient and repeated zeros are legal by construction. The
loop runs `index` over `TRANSFORM_CAPACITY - 1` and reads `index + 1`, covering
every adjacent pair with no out-of-range access.

All eight pose fields keep the full signed int32 domain at a positively bound row:
no map bound, no yaw normalisation, no speed rule, no current/previous equality
rule. Arbitrary yaw outside one turn, differing current and previous, and both
signed extrema are accepted. A positive stamp naming a destroyed entity stays
canonical; no Directory instance, live store, callback, I/O or reflection is
reached from either file, and `save_owner_transforms.gd` preloads only Transforms,
Schema, Section and SaveHeader. An all-zero frame is accepted as a valid empty
image. No ordinary gameplay method, `state_bytes()` ordering, reset/unbind
semantics or existing public refusal field is changed; the new codes are constants
and the predicate writes no diagnostic.

## Scratch, non-mutation and memory

The only scratch is one `duplicate()` of the binding column, 87552 × 4 = 350208
bytes, sorted privately and discarded; the caller's array is never reordered and
the copy is never retained. It is allocated only after the shape gate, so a hostile
frame cannot drive an unbounded allocation. Framed image 3151872 + scratch 350208 +
three 65536 stream windows = 3698688 logical packed bytes, inside the existing
6417408 one-owner allowance — and only under the existing streaming release
protocol, where the caller frees the previous owner record before the next wrapper.
That is arithmetic, not a measured resident set; native and wrapper overhead remain
unmeasured and no new resident allocation row is claimed.

## Bridge gate order and details

Null → SAVE_COMPONENT_SHAPE; owner ≠ 15 → SAVE_COMPONENT_OWNER; `schema_refusal()`
forwarded unchanged in both code and detail; metadata → SAVE_COMPONENT_METADATA
with a detail beginning exactly `Transforms owner15 metadata:`; `owner_shape_refusal`
forwarded unchanged; then the raw column code with a detail containing
`Transforms owner 15 ` and the code text, carrying no row identity. Gates 3 and 4
share a code, so the prefix is the only discriminator — the forwarding case is
exercised separately and asserts detail equality with the isolated schema refusal,
which is the right way round: it proves forwarding rather than assuming it.

## Metadata fault arithmetic

The disposable-clone faults are balanced so that `schema_refusal()` still passes and
gate 4 is genuinely reached. `field_count` moves Work's leading i32[512] into
Transforms: 512 × 4 + 8 = 2056 added to owner 15 and removed from owner 16, field
begin 280 → 281, section total unchanged. `field_type` turns ordinal 271 from I32 to
U8: 87552 × (1 − 4) = −262656, propagated to owner payload, block, later offsets and
both section totals. `field_extent` 87552 → 87553 gives +4, propagated identically.
`children` moves one 8-byte extent from orchard_hive, shifting owners 11..15 down by
8 with a net-zero section. `primary` uses 87553 against 511 so the 193184 descriptor
row sum holds. All five are recomputable from the tables as written. Production
format is untouched; the harness restores and re-verifies source SHA-256 in a
`finally` block.

## Mutation oracles

The nine all-zero accessor substitutions are each killed by an exact code change.
Binding substitution has both required witnesses: `-1` with all poses zero turns
COLUMN_BINDING_ID into success, and a positive stamp with a non-zero pose turns
success into COLUMN_FREE_ROW. Omitting the binding domain, the duplicate check or
the free-row check each collapses a distinct expected code to success. Both order
mutants use paired, non-equivalent faults: negative stamp plus repeated positive 17
separates binding-before-duplicate, and repeated 17 plus a separate zero-bound row
with pose residue separates duplicate-before-free. Pose-field swaps ARE equivalent
under these symmetric rules and are correctly excluded rather than counted; the
ordinal-to-argument mapping is therefore established by source review plus the
schema key pinning in gate 4, not by an assertion, and this review re-derived it
directly. Test failures are assertions against an expected suite count, with parse
errors and script errors treated as invalid runs.

## Fixture remapping and public history

`_from_owner` maps canonical field 0 to diagnostic slice 8 and field f to f−1,
which is the exact inverse of `state_bytes()`'s pose-first/stamp-last append order,
and it pins the 3151872-byte extent first. The replayed history — place(11,22,33,44),
advance(55,66,77), set_yaw(88) — correctly expects `[pid,55,66,77,88,11,22,33,44]`
at row 82944 + typed_row. Predicate calls are shown to leave `last_refusal()`,
`bound_count()`, `authoritative_digest()` and `state_bytes()` unchanged, including
across destruction, successor creation, replacement and unbind.

## Documentation and patch intake

The registry's previous-pose note now states that both canonical current and
previous fields survive load, digest verification and publication, with first-frame
previous = current as a presentation-only override — consistent with ARCH-HASH-001
and ARCH-SAVE-004 and with ADR 0173. The new owner row records the memory
arithmetic and the deferred bulk/identity work. The patch-format repair is recorded
as removing one surplus unchanged blank context line only, with added and deleted
lines byte-identical; the disposition is internally consistent and retains both
patches and the original failure, and claims no raw-patch success.

## Non-blocking observations

1. COLUMN_SHAPE is unreachable through the bridge, because `owner_shape_refusal`
   already guarantees the extents. It remains correct defence for direct static
   callers, and the suite tests the static and framed codes separately rather than
   conflating them.
2. Pose-to-pose accessor swaps are undetectable by any behavioural oracle here.
   This is inherent to the rule, is declared, and is covered by review.
3. Endianness is not a concern on this path: typed columns are read, not bytes.

## Not established by this review

The required mutation run is still in progress and the full suite, import/static
gates and exact-head CI are pending; this review asserts no result for them.
Local acceptance does not establish TRANSFORMS-SAVED-IDENTITY (saved cursor upper
bound, same-file Directory association and provenance), coordinator invocation,
bulk capture/apply, the `bound_count` rebuild, cross-section identity or full save
publication. Section 4 remains incomplete.
