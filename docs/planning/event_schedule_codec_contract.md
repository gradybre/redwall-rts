# Event schedule section11 codec

SAVE-S11-R01 · version2 accepted for bounded implementation · 2026-09-19 · Astra

Implement the existing SAVE-R09-005 wire contract over event_schedule.gd. This
closes the missing section11 byte adapter, not event gameplay or world saving.
The canonical registry already declares its8fields. No new event kind, semantic
argument domain, production rule, expiry or consumer is introduced. Real event
activation remains blocked on the community/scenario packages.

## Existing authority and exact bytes

Read docs/rulings/2026-09-11_save_codec_contract.md SAVE-R09-005, the later
2026-09-12_save_registry_answers.md distinct-form ruling, EventSchedule and its
tests, save_codec.gd primitives and save_header.gd Refusal/descriptor.

Section ID11; section schema1 names this first implementation of the already
ruled bytes. Descriptor row_count=N in0..64. The empty section always has8bytes, never zero. No owner wrapper or inline count
is added: payload is next_sequence:i64 followed by N32-byte records in exact
order kind:i32, source_id:i32, arg0:i32, arg1:i32, due_tick:i64, sequence:i64.
Little-endian, length8+32*N (empty8, full2056). Count is carried by the descriptor
and canonical registry, not duplicated in this distinct wire form. `_count` stays
a canonical registry field emitted by the logical-state hash walker. Outer CRC,
body SHA, section placement and canonical logical-state hashing remain their
existing owners. No generic column framing is applied here.

Four i32 values are storage domains only. All signed int32 values are permitted
until the future catalog establishes semantic domains; this codec does not
claim to validate a real event. Due ticks are nonnegative i64, including overdue
rows retained for a consumer. Live sequences1..I64_MAX unique across all rows,
strictly ascending by (due_tick,sequence), and below next_sequence unless
next_sequence=0(exhausted). next_sequence otherwise1..I64_MAX and never inferred
from remaining rows. Empty exhausted schedules remain exhausted. No sorting or
expiry during capture, decode or apply.

## API and validation

New save_section_event_schedule.gd extends RefCounted. Preload EventSchedule,
SaveCodec, SaveHeader, SimClock and IntMath only as needed. Nested Record has
next_sequence:int=1 and six initially empty packed arrays named kind/source_id/
arg0/arg1 (i32), due_tick/sequence(i64). Count is kind.size(), no redundant scalar.
Arrays all have the same length0..64. Int32 typing enforces storage width: a caller
assigning0x80000000 has already narrowed it toINT32_MIN before validation. Test
signed extrema, never promise detection of the original out-of-range assignment. Record.copy_from duplicates every field
buffer. Output has no pre-required lengths because a successful decode replaces
all six variable-length arrays. Null Record always refuses.

Public static methods:
- record_refusal(record:Record)->SaveHeader.Refusal
- capture_into(store:EventSchedule,out:Record)->SaveHeader.Refusal
- encode_section(record:Record,out:EncodeResult)->bool
- decode_section_into(bytes:PackedByteArray,offset:int,length:int,row_count:int,
  schema_version:int,out:Record)->SaveHeader.Refusal
- apply(record:Record,store:EventSchedule,clock:SimClock=null)->SaveHeader.Refusal
- descriptor_row_count_into(record:Record,out:IntMath.IntResult)->bool validates
  through record_refusal, then out.succeed(kind.size()); failures use
  out.refuse(String(refusal.code)). Caller supplies a nonnull IntResult.

EncodeResult mirrors existing section modules: ok,bytes,refusal,detail; refused
encode clears bytes/ok and supplies code/detail. All other refused public methods
leave caller Record and live canonical owner state unchanged. No callbacks or
await inside these calls. Record copy_from is a low-level valid-input helper.

record_refusal order: null; count>64; ragged arrays; allocator<0; row scan in
index order(nonnegative due tick, positive sequence, upper allocator relation);
strict pair order; uniqueness across unequal due ticks. To avoid divergent
owner validation, validate on one temporary EventSchedule via restore_rows(),
then convert its last_refusal into SaveHeader.Refusal. Null/shape checks precede
allocation; record validation never invokes a method on the real owner.
The temporary store is2048B packed capacity and no external authorities.

Capture order: null store; null out; count range; stage native next_sequence and
exact row values through count()/next_sequence()/read_into(); validate; publish
independent copies. read_into() is the existing owner interface and clears its
last_refusal on successful reads; this existing diagnostic effect is explicitly
allowed. No canonical field, allocator, owner math scratch, row or scheduling
operation is changed. Empty capture performs no read and preserves that owner
diagnostic. An invalid row getter forwards EVENT_ROW_OUT_OF_RANGE and leaves that owner
diagnostic changed, with no partial publication. No private owner reflection.

Decode order: unsupported schema; row_count outside0..64; length!=8+32*N;
negative offset; offset>bytes.size() or length>bytes.size()-offset; null output;
parse into temporary Record; record validation; duplicate publication. This
section-level order runs before primitives: wrong length wins over negative
offset when both are invalid. Always
check subtraction bounds before adding offsets. Decode a bounded subsection of
a larger buffer and ignore bytes outside it. Length claims cannot allocate
unbounded arrays. No truncation/zero-padding/sorting repair.

Apply order: null record, null store, null clock, !clock.is_load_barrier_held(),
store.restore_rows() with all6arrays/cursor. Do not allocate a validation owner
inside apply: the real owner already validates its entire
input before clear/write and installs exact count/allocator with zero unused
tail. Clock identity/world association and completed-boundary coordination are
caller obligations. Never acquire/release the barrier or alter clock state.

New codec refusals: SAVE_EVENT_RECORD_NULL, SAVE_EVENT_NULL_STORE,
SAVE_EVENT_NULL_CLOCK, SAVE_EVENT_BARRIER_NOT_HELD, SAVE_EVENT_SECTION_SCHEMA,
SAVE_EVENT_ROW_COUNT, SAVE_EVENT_LENGTH, SAVE_EVENT_NEGATIVE_OFFSET,
SAVE_EVENT_TRUNCATED, SAVE_EVENT_ENCODE_FAILED. Forward EventSchedule's existing
EVENT_RESTORE_* and EVENT_TICK_NEGATIVE codes for validation/capture/apply as
appropriate; exact diagnostics remain distinct from the chosen wire format.
SAVE_EVENT_ROW_COUNT is decode descriptor-count only; count>64 in a Record or
capture forwards EVENT_RESTORE_COUNT. Ragged and all other owner codes forward.
EncodeResult.refusal is StringName and detail is String, as in existing
save_section_job_indexes.gd and save_section_rng.gd; preserve this convention.

## Ownership, memory and evidence

Own new codec/test/focused-runner files. Parent owns stateless registry row, ADR,
queue, source hashes and evidence. Do not edit EventSchedule gameplay. Variable
Record live packed payload32*N<=2048B; one staging Record, caller target and
validation owner may coexist, plus encoded2056B and retained caller buffers.
This is a transient accounting note, not an architecture live-owner ledger row.
Keep this cold; no production per-tick allocation or RSS qualification claim.

Independent tests must establish:
1. Literal golden empty bytes for allocator1 and exhausted0; one record with
negative signed i32 extrema, i64 values beyond32bits, hand-authored byte offsets;
64rows exact2056bytes. DescriptorN counts rows, not capacity.
2. Nonzero outer offset/prefix/suffix, every meaningful truncation boundary,
negative/huge offset/length/count/schema, null output, exact refusal precedence;
populated target preserved on failure and no input-byte mutation.
3. Malformed shapes and all owner allocator/tick/sequence/order/duplicate cases;
same sequence at unequal due ticks refuses even when sorted. Full valid ranges
and exhausted sequenceI64_MAX succeed. No accidental future-only tick rule.
4. Real owner schedule/cancel/pop changes, capture/encode/decode/apply/recapture,
next-issued sequence and due-pop order match an uninterrupted owner. No reuse of
consumed IDs, count0 with high or exhausted cursor retained. Exhausted0 with
live rows survives and refuses further insertion after load. Read diagnostics
allowed exactly as specified; canonical state and math scratch unchanged.
5. Apply under held clock; null/lowered barrier failures preserve source,target
and clock. Existing unrelated events replaced exactly, unused tail zero.
6. Mutate source/output arrays after successful copy/apply and prove independent
buffers. Aliased Record input arrays produce correct independent publication.

Require independent contract review before author dispatch, separate source
review after integration, focused/full suite/static gates/import and exact-head
CI before merge. Preserve unresolved semantic activation as a separate queue
obligation; this bounded codec may be accepted without inventing event kinds.
