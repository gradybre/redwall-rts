# Independent source review — SAVE-REPLAY-R01 v2 header format 2

Date: 2026-09-19 · Reviewer role: independent source review, not author.
Scope reviewed: `godot/scripts/core/save_header.gd`, `godot/scripts/core/save_codec.gd`,
`godot/test/test_save_header.gd`, `godot/test/test_save_replay_checkpoint.gd`,
`godot/test/test_save_section_01.gd`, `godot/test/save_replay_focus.gd`,
`docs/validation/evidence/replay-checkpoint-2026-09-19/integration-diff.json`,
`integration-notes.md`, `focus-first.log`, and the offset-census disposition.

## Acknowledgement of the contract

SAVE-REPLAY-R01 version 2 and decision 0156 are acknowledged as read, including the final
encode clarification: encoding keeps its existing insufficient-destination gate first, then
`_version_refusal` metadata, digest widths, generic numeric widths, and finally the checkpoint
tuple/padding gates before any staging or output copy, so no public path emits outer format 1.
The checkpoint is the next economic admission frontier of the frozen snapshot, redundant with
section 12, never an allocator owner.

## Verdict

**No blocking findings.** Five limited advisories below; none blocks the bounded task as scoped.

## What was independently confirmed in source

**Header format 2 / 264.** `FORMAT_VERSION = 2`, `HEADER_BYTES = 264`,
`SECTION_TABLE_OFFSET = 264`, `PREAMBLE_BYTES = 16`. Bytes 0..215 retain their prior field
meanings and widths; `header_bytes` at 12 and `section_table_offset` at 200 both carry 264 and
are gated by `_version_refusal`. `body_offset()` returns `264 + 64*15 = 1224`.

**Offsets, pair and padding.** `OFFSET_ECONOMIC_NEXT_SEQUENCE_LOW = 216` (u32),
`OFFSET_CHECKPOINT_RESERVED_ZERO = 220` (u32), `OFFSET_ECONOMIC_NEXT_SEQUENCE_HIGH = 224` (u64),
`OFFSET_BODY_DIGEST = 232` (32 bytes). 232 + 32 = 264 exactly, with no slack and no overlap with
the 208 chronicle u64 (208 + 8 = 216). The scalar `replay_sequence` and its old offset alias are
absent from `Header` and from the constant block, so no caller can retain the old interpretation.
`is_sequence_pair_valid(high, low)` is the single pure tuple predicate: negatives refuse; the
terminal high `4294967296` admits only low `0`; otherwise both words must satisfy
`SaveCodec.fits_u32`. It is reached from encode, decode, `header_refusal` and
`checkpoint_binding_refusal`, so the rule cannot drift into three copies.
`checkpoint_refusal` judges nonzero reserved padding as `REFUSE_RESERVED_NONZERO` before the
tuple, and the reserved word is carried verbatim from the file rather than normalised.

**16-byte preamble precedence.** `preamble_refusal` enforces, in order: 16-byte requirement
(`REFUSE_HEADER_TRUNCATED`), magic (`REFUSE_MAGIC` via `magic_refusal`), version > 2
(`REFUSE_FUTURE_FORMAT_VERSION`), version != 2 (`REFUSE_FORMAT_VERSION`). It reads only bytes
0..15, allocates no `Header`, and mutates neither input nor output. `decode_header_into` invokes
it before the 264-byte size requirement, so a valid 16- or 256-byte legacy format 1 preamble is
named an unsupported version rather than truncation, and a valid format 2 preamble in a 263-byte
file is truncation. A wrong magic in a 16-byte preamble yields magic even with a wrong version
word. The module docstring states plainly that raw decode now gains magic/version dispatch and
that zero-filled buffers are no longer valid structural fixtures.

**Transactional encode/decode.** Encode: destination room, then `_version_refusal`, then
`digest_lengths_refusal`, then `_encodable_ranges_refusal`, then `checkpoint_refusal`; only then
is a 264-byte staging buffer written and copied out via `SaveCodec.write_bytes_into`. A refused
encode therefore leaves `out` byte-identical. Decode: preamble gate, size gate, integer words
through a bounded sticky `Reader`, then `_read_checkpoint_words` staging low/reserved/high into a
local `parsed`, then `checkpoint_refusal` on that local, then digests, then `_copy_header`. No
field reaches the caller's `Header` unless every gate passed.

**Checked high-u64 with a distinct code.** `_read_checkpoint_words` maps an unreadable high u64 —
including the sign-bit case that `SaveCodec.read_u64_at` refuses with
`REFUSE_UNREPRESENTABLE_U64` — to `REFUSE_SEQUENCE_RANGE`, while the low and reserved u32 reads
and every other u64 header word keep their existing codec refusals unchanged. Confirmed by
contrast in `test_save_header.gd::test_an_unrepresentable_u64_header_field_is_refused_not_read_as_negative`,
which pins `total_file_bytes` at `SaveCodec.REFUSE_UNREPRESENTABLE_U64`. No width failure
substitutes a zero into a published header.

**Pure binding, no preload cycle, no store mutation.** `checkpoint_binding_refusal(header,
section12_next_high, section12_next_low, section1_completed_tick)` lives in `save_header.gd` and
imports nothing beyond the existing `save_codec`, `catalog_ids` and `int_math` preloads — no
section, scheduler, commands or world-runtime module, so no preload cycle is introduced. Its
precedence matches the contract: null header → `REFUSE_VALUE_RANGE`; version/size/table offset →
the existing `_version_refusal`; reserved nonzero and malformed header pair → `checkpoint_refusal`;
malformed section 12 pair → `REFUSE_SEQUENCE_RANGE` via the same shared predicate; either negative
tick → `REFUSE_NEGATIVE_TICK`; only then well-formed inequality → `REFUSE_CHECKPOINT_MISMATCH`.
It takes plain integers, calls no restore or admission API, allocates no sequence and touches no
store or clock. Its docstring explicitly disclaims being a whole-header/body/world validator.

**Relocation limited to file offsets + 8.** The integration diff changes exactly two constants in
`save_section_01.gd`: `FIRST_SECTION_OFFSET` 1216 → 1224 (with `SECTION_2_OFFSET` derived, hence
3753992). `SECTION_BYTES` stays 3752768; no wrapper, payload, count-prefix or canonical ordinal
is touched. `test_save_section_01.gd` transcribes `RULING_FIRST_SECTION_OFFSET = 1224` and
`RULING_SECTION_2_OFFSET = 3753992` as independent literals with a provenance comment naming the
+8 amendment, while `RULING_SECTION_BYTES`, `RULING_DESCRIPTOR_ROW_COUNT = 344067`,
`RULING_BLOCK_OFFSETS`, `RULING_PAYLOAD_OFFSETS` and `RULING_END_OFFSETS` are unchanged. The
`commands.gd` diff is comment-only and now states the header pair is redundant with section 12 and
never an installation path. The `canonical_state_hash.gd` diff is a comment-only `[256, EOF)` →
`[264, EOF)` correction; no canonical declaration or CRC/digest input changes. CRC-256 table size
and the ISO-HDLC constants are untouched.

**Test coverage against the required evidence list.** `test_save_replay_checkpoint.gd` pins a full
independent 264-byte hex vector (`PINNED_HEADER_HEX`, per the intake notes generated with Python
struct from literal offsets, not from the module under test), decodes those independent bytes and
re-encodes to the same buffer. Valid boundaries covered: `(0,0)`, `(0,4294967295)`,
`(2147483647,2147483648)`, `(2147483648,4294967295)`, `(4294967295,4294967295)` and terminal
`(4294967296,0)`, with the terminal 16-byte checkpoint slice pinned. Hostile cases: negative
words, `low = 4294967296`, terminal-with-nonzero-low, `high` 4294967297 / 8589934592 /
`INT64_MAX`, an explicit sign-bit byte at 231, and nonzero reserved padding from both an
in-memory caller and mutated bytes. Old/future/truncated magic-version recognition is swept over
sizes {0,7,8,11,12,15,16,256,263} and versions {0,1,3,4294967295} at sizes {16,256,264}, plus a
wrong-magic 16-byte preamble. Output and input immutability is asserted by `_decode_refuses`
(caller header re-encodes identically; input buffer byte-identical) and by pre-dirtied 165-filled
destination buffers in the encode-refusal tests. The body-digest-unchanged case is pinned: header
bytes at 32/216/224 are flipped, `compute_body_digest` is unchanged, the header still decodes, and
only `checkpoint_binding_refusal` catches it with `REFUSE_CHECKPOINT_MISMATCH`. The terminal
capture test drives a real `Commands` queue to the last ordinary pair, submits, and binds in both
the pending and the drained state via an actual section 12 capture/encode/decode round trip —
not inferred from the queue's emptiness.

**Focus log.** `focus-first.log` reports 159 tests, 11265 assertions, 0 failures across
`test_save_header`, `test_save_replay_checkpoint`, `test_save_section_01`,
`test_economic_sequence_format` and `test_save_section_pending_commands`. Recorded as parent-
supplied evidence only; see limits below.

## Advisories (non-blocking)

**A1 — stale docstring in `test_save_header.gd`,
`test_a_future_format_version_is_refused_separately_from_a_wrong_one`.** After setting
`header.format_version = 2` the assertion message reads `"version 1 is accepted"`. The assertion
itself is correct; only the human-facing string is stale and could mislead a future reader into
thinking format 1 is accepted. Bounded repair: change that one message string to
`"version 2 is accepted"`. Documentation-only; no behaviour change.

**A2 — `test_save_header.gd` header docstring still says "fixed 256-byte header"?** Checked: the
file header now reads "fixed 264-byte header", and
`test_the_header_and_descriptor_sizes_are_exactly_consumed` pins 232+32=264, `HEADER_BYTES` 264,
`SECTION_TABLE_OFFSET` 264 and `body_offset()` 1224 as literals. No repair needed; recorded so the
absence of a stale figure here is explicit rather than assumed.

**A3 — `test_the_body_digest_refuses_a_file_with_no_body` docstring says "A 255-byte file".** The
code correctly builds `HEADER_BYTES - 1` = 263 bytes. Prose-only drift from the 256-era wording.
Bounded repair: reword to 263. No behaviour change.

**A4 — independent-vector provenance is asserted in prose, not in-repo.** `PINNED_HEADER_HEX` is
an opaque literal; its independence rests on `integration-notes.md` stating it was generated with
Python `struct` from literal offsets. That claim cannot be re-derived from the repository as
reviewed. Bounded advisory: retain the generator snippet (or its output hash) under this evidence
directory so a later reviewer can regenerate the vector without trusting the note. Not blocking,
because the vector is additionally cross-checked by field-level offset literals in
`test_save_header.gd` that were transcribed from the architecture table.

**A5 — `validate_cycle01_handoff.py` now asserts both the historical 3753984 and the current
3753992 arithmetic.** This is correct under the contract's instruction not to rewrite historical
evidence, and the added comment names the distinction. Advisory only: the two adjacent asserts
could be read by a newcomer as a contradiction. Bounded repair, if desired, is a one-line comment
naming which is the live runtime offset. No change to what is validated.

## Explicitly out of scope and not claimed complete

There is no full-file writer, save coordinator, capture/orchestrator path, disk publication,
replay recorder, merged replay-file record grammar, crash-safe append protocol, or native
acceptance in this packet, and none is implied by anything reviewed. Full-file exhaustion
acceptance — actual capture, disk reload, canonical section 15 check and next-ordinary-submit
refusal for both pending and drained queues — remains outstanding and cannot be inferred from this
isolated codec/helper. The rules identity producer (SAVE-R09-003 registration of outer format 2)
remains a separate prerequisite. The WorldRuntime `next_command_sequence` architecture row is
marked historical reserved allowance in the diff, with no live duplicate and no claimed memory
reduction, which matches the contract.

## Evidence limits

This review is a reading of source, diffs, tests and a supplied log. Nothing was executed,
built, applied or measured by this reviewer, and no such claim is made. The 159 tests / 11265
assertions / 0 failures figure is reproduced from `focus-first.log` as parent-supplied evidence
and is not independently reproduced here. The full suite is reported by the parent as underway;
its outcome is not evidence available to this review. Patch-intake reconstruction (exact context
hunk metadata only, every old context matched once, no semantic repair) is likewise taken from
`integration-notes.md` and was not re-performed. Byte-level claims above are derived from the
constants and control flow visible in the reviewed sources, not from executing the codec.
