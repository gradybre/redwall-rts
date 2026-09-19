# SAVE-P2-R02 — exact pending arena and guarded queue restore

2026-09-19 · Astra · Version 1. RESTORE-R01 and decision 0059 govern.

P2 includes allocation-order/key-order disagreement, partial-drain holes and dead
tails. Compaction changes future admission capacity. Preserve every live command's
payload offset/length and the highwater cursor exactly, while zeroing bytes no live
span owns. Schema2, its 24-byte prefix and 64/32-byte records remain unchanged.
Full save/load and economic sequence exhaustion encoding remain separate gates.

## One economic-owner restore boundary

Add to commands.gd:

`pending_window_refusal(records:PackedByteArray, arena:PackedByteArray,
next_sequence_high:int,next_sequence_low:int)->StringName`

`restore_pending_window(records:PackedByteArray, arena:PackedByteArray,
next_sequence_high:int,next_sequence_low:int)->bool`

`records` is a compact run of the existing 64-byte command records in canonical
key order. `arena` is exactly the used prefix: its length is the saved highwater,
including zero dead prefix/interior/tail bytes. Empty command run requires empty
arena. No additional record/offset copies or object-per-row array is needed.

The pure instance validator requires the owner's actual clock barrier; validates
record byte multiple/count <=4096, arena <=1048576, every envelope/target generation,
execute_tick strictly above its clock's completed tick, strict canonical unsigned
key order, flags/reserved zeros, bounded spans, non-overlap and zero unowned bytes.
Use existing envelope/key/record decode APIs, not gameplay admission. Check spans
with subtraction bounds before addition. Zero-length spans may share offsets and
may equal arena.size; preserve their offset exactly. Use current section12 span
consistency rules, not a guessed historical reachability test. Nonzero dead bytes
refuse. Dead tails are legal. The validator writes no queue field/diagnostic.

Sequence input supports every ordinary u32 pair AND the existing runtime exhausted
pair `(4294967296,0)`. No other high-over-u32 or negative value is legal. Restoring
pending records never consumes allocator sequences and never calls _sequence_room:
replay records can remain queued after ordinary allocation exhausted. This owner
API support does not make the schema2 prefix able to encode that exhausted pair.

The mutator calls its validator before any write. On success it replaces any current
window under the held barrier, rebuilding canonical head0/order indices and writing
records into rows0..N-1, exact offsets, arena prefix/highwater and both next-sequence
scalars. Fill unused rows/arena with existing canonical null/zero values; take copies
into existing allocated owner buffers, never retain caller arrays. No admission,
allocation cursor, sequence advance, tick, callback or drain is invoked. Preserve
accepted/refused/drained diagnostic counters; success may clear last_refusal.
Refusal preserves all authoritative state and counters, setting only last_refusal.
Replacement of a nonempty window is intentional privileged restore, and enables
checked bounded recovery; normal public clear/admission remain separately guarded.

Cold scratch is one decoded Command and at most4096 packed span-sort keys (32768B)
plus the caller's encoded records (at most262144B) and used arena prefix (<=1048576B).
No new retained/persisted columns, allocation mirror, schema or field ordinal.
Document this scratch and avoid allocating a second full Commands object.

## Guard ordinary economic queue mutations

Under either the current clock's load barrier (all mutators) or the incoming clock's
barrier (rebind), refuse submit_into, submit_group_into, submit_id_group_into,
admit_stamped_into, drain_due_into, clear and rebind_clock BEFORE any authoritative
write or admission/drain/refusal counter increment. SubmitResult gets an explicit
COMMAND_LOAD_BARRIER refusal; drain returns false without touching its out record;
clear retains its current void API and sets last_refusal; rebind returns false.
Only result/last_refusal diagnostics may change. Do not clear _refused_member first.
The existing restore_sequence is an explicitly privileged restore API and remains
available subject to its old empty-queue/domain rules; the new full restore does
not call it. Queries and encoding remain usable while barred.

Constructor initialization must still work with an already-barred supplied clock.
Extract private reset code so _init may initialize its new buffers while public
clear is guarded. No privileged escape flag on ordinary public APIs.

## Section12 capture and atomic two-owner apply

Capture allocates one zero-filled full Record arena and copies each live span to
its original offset. Check every read. Remove the contiguity requirement; preserve
all existing span/zero-tail validation. Keep arena_rebuild_refusal as a compatible
validator name if useful, but do not require monotonic offsets, a zero base or sum
of lengths == highwater. Capture uses the live payload_used value, including tails.
Encoding/decoding byte layouts and canonical-field order remain unchanged.

Apply first validates nulls, both queue owners share the SAME clock object, that
clock's completed_tick equals saved_completed_tick, and its actual load barrier is
held. Preserve the existing requirement that BOTH target queues are empty. Validate
the whole Record, scheduler extension and new command-owner window before writing.
Generate the compact command bytes and used arena prefix from the validated Record.
Do not infer association from equal tick values on different clocks.

Capture the pre-call empty economic queue's two allocator scalars. Install commands
first with restore_pending_window; a refusal changes neither queue. Install scheduler
second with its existing atomic restore_extension. If it refuses, restore the prior
empty economic window and exact allocator pair through the SAME new owner method.
Check the recovery return. Successful recovery returns the original nonempty install
refusal; failed recovery returns distinct SAVE_PC_ROLLBACK_FAILED and holds the
barrier, explicitly uncertain. No fallible step follows successful scheduler install.
Do not call public clear, release a barrier, change the clock or claim whole-world
rollback. The full coordinator owns handling unrecoverable failure/publication gates.

## Required evidence and ownership

Use actual owner queues/codecs. Cover permuted mixed-tick admission without drain,
partial drain with dead prefix/interior/tail, non-monotonic offsets, shared zero-length
spans and offset==highwater. Capture/encode/decode/apply/recapture must preserve bytes,
keys, payloads and highwater. Follow restore with real admissions showing exact
remaining capacity (one byte too much refuses; exact remainder succeeds), drain order
and sequence behavior. Do not compare only a cursor to itself.

Refuse bad spans, overlap, nonzero holes, truncated records, bad count, invalid/stale
targets, duplicate/reversed keys and illegal sequence pairs before mutation; include
a malformed late row. Prove input isolation, preserved counters and exhausted runtime
allocator refusal after restore. Test same-tick different clocks, mismatched tick,
absent/released barrier, nonempty apply targets, all guarded mutators and construction
with a held clock. Use bounded public-method test subclasses to force scheduler
install failure and then economic recovery failure; verify exact restoration or
explicit uncertainty and held barrier. Test the encoded two-queue state, not flags only.

Implementation owns commands.gd, save_section_pending_commands.gd, a dedicated
commands restore test, and the affected existing pending codec tests. Existing tests
must take a real load barrier for apply, without barring construction of their source
fixtures. Replace historical expected arena-refusal tests with actual accepted exact
round trips; keep malformed arena tests. Astra owns ruling/ADR, registry scratch
notes, queue and evidence. Fresh independent Opus review and full suite are required.
