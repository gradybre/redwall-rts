# Replay checkpoint and full-file allocator binding

2026-09-19 · SAVE-REPLAY-R01 version2 · Accepted engineering contract after independent review.
Implementation and acceptance remain pending; current source still emits outer format1.

## Problem and authority

ARCH-CMD-001/002 make the economic command allocator a never-reused u64 sequence space,
represented by two words in each 64-byte command record. The runtime additionally retains
terminal high4294967296/low0 after issuing the last ordinary value. SAVE-SEQ-R01 v2 gives
section12 a representation of that 65-bit state. The 256-byte outer header currently has
one u64 `replay_sequence` at216, supported by a signed-int64 scalar API; it can represent
neither every ordinary value nor exhaustion. It has no live producer. The architecture's
WorldRuntime.next_command_sequence entry is also unimplemented, not a second authority.
SAVE-R09-001 requires an outer version change when header interpretation changes.

This ruling explicitly amends SAVE-R09-001's "Container and section versions" sentence
that fixed outer version1/header256. After this contract is implemented, outer version2
uses header264 as specified here. The earlier rejected scheduler-only outer-version2
proposal remains rejected historical evidence; this is a new header-interpretation change,
not revival of that proposal. Descriptor size and current per-section schema vector remain
unchanged. It also amends R-WORLD-S1-001 section8's absolute file positions by+8 only;
all section-relative owner positions and body bytes remain unchanged.

## Meaning and ownership

The checkpoint is the NEXT ECONOMIC ADMISSION frontier of the exact frozen snapshot,
not the highest executed command and not a physical byte offset into a replay file.
Its low/high pair is copied from the same `commands` owner captured in section12.
Initial is (high0,low0). All u32 pairs are ordinary; the sole exhausted pair is
(high4294967296,low0). Never infer it from pending records, which can be empty after
commands drain. Refused submissions do not advance it. Accepted commands that later
fail domain execution have still consumed their issued sequence.

The header is a redundant consistency declaration, never an allocator owner. Loading
it alone must never restore a queue or reserve a sequence. The approved full-window
install API restores section12. There must be no new WorldRuntime allocator field,
no coupling of the scheduler's independently specified initial1/zero-terminal space,
and no reset at a terrain publication, a save or a load.

The scheduler checkpoint remains its complete section12 SCHQ0001 control state and
pending records. Replaying the full simulation requires both lanes and the saved
completed tick. This contract does not specify a merged replay-file record grammar,
crash-safe append protocol, log identities or branch selection. Task09.4 must author
those before claiming a resumable replay recorder; the header is not a substitute
for those contracts. A standalone settlement save must remain loadable without an
external replay file. No command below the saved next frontier may be re-admitted
as new external input; pending saved commands execute from their restored queue.

## Outer format2 header

Keep magic RWLSET01 and the64-byte descriptor. Emit outer format_version2.
Header bytes and section_table_offset become264. Bytes0..215 retain their current
field meanings and widths; header_bytes at12 and section_table_offset at200 carry264.

| Offset | Field | Width |
|---|---|---|
|216|economic_next_sequence_low, u32 LE|4|
|220|reserved_zero, exactly zero|4|
|224|economic_next_sequence_high, u64 LE|8|
|232|SHA-256 body digest of descriptor table plus section bytes|32|

Header ends exactly264. The two declared words use positive GDScript int values;
no combined signed scalar or lossy shift is used. Validate the whole tuple before
any output mutation; the high u64's sign bit, high>4294967296, terminal/nonzero-low,
negative words and nonzero reserved padding refuse. Use existing checked SaveCodec
primitives. Section12 remains schema3 with its already specified compact28-byte
prefix; no section body changes merely because its containing file starts8bytes later.

The15 descriptors occupy960bytes beginning264; first section offset1224. Section1
length stays3752768; section2 begins3753992. Every compiled absolute section1/file
position and independent pinned test must shift by8 consistently; relative offsets,
owner layouts, section1schema3, row counts and canonical field ordinals do not change.
Prove that explicit relocation instead of replacing the absolute-offset validation
with trust in incoming descriptor offsets. No implied full-file writer exists yet.

## Compatibility, bytes and canonical verification

After activation, the current header writer emits only format2. No release-save readiness
is claimed; existing development saves have no implicit migration promise. The preamble
and structural/semantic validation sequence below is normative. Explicitly refuse format1 as an
unsupported development format, preserving the file and caller's record; future
versions get the existing distinct future-version refusal. There is no migration or
recovery rewrite. A truncated valid format2 header refuses; hostile offsets/counts
continue to use subtraction-based bounds. Document the planned activation in the
architecture and task09 lane record; do not rewrite historical evidence.

The body digest and section CRC do not protect header bytes. Before any live-array
write, the coordinator must require header pair == section12 pair and header tick ==
section1 clock tick, plus all existing compatibility bindings. It must verify canonical
state against section15 before publication and again after install. Commands' existing
canonical high-u64/low-u32 fields remain the sole canonical allocator values. A changed
header pair with an unchanged body digest is rejected by the explicit cross-check;
changing both without changing section15 is rejected by the canonical digest. SHA-256
is corruption/determinism evidence, not authentication against a malicious reauthor.

The rules identity must register outer format2 and every header field's meaning/width,
including this interpretation revision, through SAVE-R09-003. No new canonical owner
or duplicate allocator field is declared. The actual rules identity producer is still
a separate prerequisite. The older WorldRuntime budget entry must be marked historical
reserved allowance pending a complete ledger reconciliation; do not implement a live
8-byte duplicate, or silently claim a measured memory reduction. The8 extra transient
header bytes fit within the existing65536-byte streaming buffers. No retained world
allocation is introduced by this header change.

## Bounded downstream tasks and acceptance

SAVE-HEADER-REPLAY-FORMAT owns save_header, its tests, section1's compiled absolute
file positions and associated tests, architecture layout/owner annotation, registry
rows for changed stateless adapters, and a pure header/section12 binding helper.
It depends on SAVE-ECONOMIC-SEQUENCE-FORMAT. No disk publication or replay recorder
is part of this task. The helper accepts decoded values and refuses mismatch without
store mutation. It must be called by the subsequent SAVE-ORCHESTRATOR/CAPTURE path,
which depends on this task as well as their existing section prerequisites.

Required evidence: independent pinned264-byte header and both cross-section offsets;
zero, u32high sign boundary, last available and exhausted pair round trips; old format1
and future3 recognition; truncation and every invalid pair/padding refusal preserving
pre-dirtied output and input; checked-u64 sign-bit refusal; exact decoded tuple match
and mismatch tests, including mismatches whose body digest still matches; section1
fixed-position poison tests preserving section-relative offsets, descriptors overlapping/overflowing/short;
full prior suite, registry/capacity checks and independent review. Full-file exhaustion
acceptance additionally requires actual capture, disk reload, canonical check and next
ordinary submit refusal for both pending and drained queues; it cannot be inferred
from this isolated codec/helper.


## Version2 review resolutions: exact API, failures and evidence

B1/B2: the supersession and activation boundary above resolve the two conflicting version
statements. Amend the older ruling with a dated pointer rather than erase its history.

B3: add `SaveHeader.preamble_refusal(bytes: PackedByteArray) -> Refusal`. Require16bytes
first (`REFUSE_HEADER_TRUNCATED`); then check magic (`REFUSE_MAGIC`); then version>2
(`REFUSE_FUTURE_FORMAT_VERSION`) or version!=2 (`REFUSE_FORMAT_VERSION`); then return
success. It reads only the preamble and never allocates a Header or changes input.
`decode_header_into` invokes this gate before its264-byte size requirement, so a valid
16/256byte legacy-format1 preamble names the unsupported version. A valid format2
preamble in a263byte file is truncation; a wrong magic in a16byte preamble is magic,
even if its version is wrong. Header-size word and endian/tick/file-extent semantics
remain in `header_refusal`. Raw decode intentionally gains magic/version dispatch checks;
zero-filled buffers are no longer valid structural-header fixtures.

Use fields `economic_next_sequence_low:int`, `economic_next_sequence_high:int`, and
`checkpoint_reserved_zero:int` in Header; remove the unused scalar `replay_sequence`
and its old offset alias so no caller can silently retain the old interpretation. The
reserved value is read and carried, never skipped or normalized before validation.
Encoding and `header_refusal` reject invalid pairs with exactly the new
`REFUSE_SEQUENCE_RANGE = &"SAVE_HEADER_SEQUENCE_RANGE"`; reserved nonzero uses existing
`REFUSE_RESERVED_NONZERO`. Structural decode stages fields, checks the pair/padding
before copying caller output, and maps an unreadable high-u64 (including sign bit) to
REFUSE_SEQUENCE_RANGE. Existing failures for other u64 words remain unchanged. Width
validation cannot silently substitute a zero. Header output remains fully transactional.

B5: keep the cross-check in `save_header.gd`, without importing any section, scheduler,
commands or world-runtime module. Add the pure API:
`checkpoint_binding_refusal(header: Header, section12_next_high: int,
section12_next_low: int, section1_completed_tick: int) -> Refusal`.
Reject null Header with existing REFUSE_VALUE_RANGE, reject invalid header version/size/
table offset by the existing version gate, validate both allocator pairs with the same
header-owned pure tuple predicate, and reject either negative tick with REFUSE_NEGATIVE_TICK.
Reserved nonzero also refuses. A well-formed unequal high, low or tick returns the new
`REFUSE_CHECKPOINT_MISMATCH = &"SAVE_HEADER_CHECKPOINT_MISMATCH"`; only exact equality
returns success. This is a binding validator, not a whole-header/body/world validator;
full coordinator separately validates file extents, identities, each section's complete
semantics, clock maximum, pending references and state digest before mutation. It owns
the association of these scalars with the same decoded file. No restoring or admission
API is called, no allocator is allocated, and no section preload cycle is introduced.

B4 is therefore adopted with two new codes: tuple range and binding mismatch. Every
other code reuses the existing Header refusals. Pin exact precedence in tests, including
legacy version recognition ahead of header length and invalid pair ahead of mismatch.

At implementation intake, retain a repository census of old header-dependent256/1216/
3753984/216/224 references. Distinguish unrelated capacity values, historical evidence,
section-relative offsets and active header consumers; do not mechanically replace256.
Update the independent section1 file-offset literals and their provenance annotation.
The80byte world_runtime payload was inspected: its fixed seed/tick/debt/control fields and six counters contain no command
sequence allocator; record its source hash and unchanged byte layout. `commands.gd`'s
legacy hook comment must now say the header pair is redundant with section12 and never
an installation path. The concrete owned source paths are save_header.gd,
save_section_01.gd (two absolute file-position constants only), commands.gd (comment only),
and their existing/new tests; Astra owns architecture/ruling/registry/lane amendments.


Encoding retains its existing first gate for insufficient destination space, then requires
current format/header/table metadata through `_version_refusal`, digest widths, generic
numeric widths and the checkpoint tuple/padding gates before staging/output copy. Thus
there is no public format1 writer after activation. Tests for hostile headers construct
or mutate bytes explicitly rather than asking the writer to emit a forbidden version.
The decoder's format dispatch does not replace the caller's later full `header_refusal`.
The binding helper also retains its deliberately narrower role described above.
