# READY_07 scheduler-event contract proposal

2026-09-11 · **PROPOSED engineering amendment R07-SCHED-001.** This is the complete
candidate requested by task04.1, not an already shipped format or a user-approved
change to simulation rules. Parent [READY_07 answers](../rulings/2026-09-11_ready07_open_item_answers.md).
Owners: ARCH-CMD-002, ARCH-CLOCK-001/002, GDD REQ-SET-002–008, UI pause reasons,
architecture §8. Preserve economic CommandKind IDs and their 64-byte records.

## Record and bounded storage

One scheduler event has this 32-byte little-endian wire layout. Store fields as
packed columns; U32 values use PackedInt32Array bit patterns and unsigned compare,
as the existing economic queue does. No Variant/object-per-event allocation.

| Offset | Field | Type | Meaning |
|---:|---|---|---|
| 0 | boundary_tick | I64 | Nonnegative effective completed boundary; see admission timing below |
| 8 | sequence_low | U32 | Low word of world-local scheduler sequence |
| 12 | sequence_high | U32 | High word; sort unsigned high then low |
| 16 | kind | I32 | 0 SET_REQUESTED_SPEED, 1 SET_PAUSE_REASON |
| 20 | reason | I32 | 0 for speed; one existing pause bit for pause |
| 24 | value | I32 | Speed1/2/4 or pause0/1 |
| 28 | reserved | U32 | Must be zero |

Capacity256 records =8192 bytes. Queue control is 32 bytes: head:I32, count:I32,
next_sequence_low:U32, next_sequence_high:U32, last_drained_boundary:I64,
last_applied_sequence_low:U32, last_applied_sequence_high:U32. Total **8224 bytes**.
Initial head/count=0, next sequence=(high0,low1), last applied=(0,0), last drained
boundary=-1 (no prior drain). This field is diagnostic and never suppresses a
second drain at the same boundary; paused frames can admit more events at tick 0
or any later tick. Tail derives from head/count; no order-index allocation. Admission
stamps monotonically ordered records, so ring order is canonical. Record state
must be fully initialized before incrementing count.

The last usable U64 sequence is all ones; next=(0,0) is the exhausted sentinel,
never a valid event. Once exhausted refuse creation and provide save/restart
recovery, never wrap/reuse sequence1. This is independent of economic sequences.
A user repeat receives a new sequence after successful admission; duplicate
pause holds from an internal producer may be treated as already-held/pending
before admission and must not consume a sequence. Imported replay records with
non-increasing sequence, past/future barrier or invalid fields refuse.

## Valid operations and admission refusal

SET_REQUESTED_SPEED accepts reason0/value1,2,4 only. Zero is effective pause,
not a selectable speed. SET_PAUSE_REASON accepts exactly PLAYER1, MENU2,
CRITICAL4, VICTORY8 or LOAD16, with value0(clear) or1(hold). Reject composites,
unknown bits, speed3, reserved data, negative boundary and overflow. Each producer
is allowed only its own pause reason; ordinary Resume clears PLAYER only.
Clearing CRITICAL/LOAD requires that reason owner's recovery/load completion,
not a generic UI toggle. Failed admission changes no queue/state/sequence.

Normal submissions are refused when count≥250, leaving six slots for internal
control events. After the last normal admission, at most five additional unmatched
pause holds (one per reason) and one overload downgrade can be needed before the
next frame's mandatory pump. Internal identical holds coalesce before admission;
scan pending operations so a hold after a pending clear is not incorrectly dropped.
The overload producer issues at most one downgrade per frame and the next frame
pumps before producing another. These bounds are part of the contract, not merely
expected UI usage. No accepted record is overwritten or reordered. Normal
clear/recovery operations may refuse temporarily; the pump drains while paused,
so capacity cannot create a permanent unpause deadlock. Capacity refusal is
visible and retryable. Queue256/normal250 are proposed plumbing values.

## Boundary pump and clock debt

Before each fixed-tick decision, atomically drain the admitted prefix for the
current completed boundary in sequence order. Do not run a simulation tick
between events in that prefix. This pump also runs on paused host frames.
If admitted between ticks, stamp the current completed tick. If an internal
callback requests an event while tick k is executing, stamp its first effective
boundary k, retain it in the same bounded ring, and drain only after k commits;
never stamp k-1 and later reinterpret it. Such admission changes no speed/pause
state midway through k. No save can expose a half-executed tick; failure to commit
k is a simulation failure, not permission to apply its future event at k-1.
Marshal requests on the same simulation thread. Input accumulated between frames belongs to the next safe boundary,
not to a past interval inferred from a screen timestamp.

Economic edits remain at `execute_tick=completed_tick+1`; scheduler events never
commit economic edits themselves. Example: at paused tick 100, economic A/B target
101. A scheduler Resume at boundary100 releases PLAYER. If no other pause remains,
tick 101 commits A/B in their economic sequence. If MENU still holds, no tick
runs. A pause then resume within the same drained prefix may leave the final
state running, with both events retained and no intervening gameplay consequence.

Host timing must be sampled/reset at the barrier so time spent paused is never
retroactively charged to the resumed speed. Existing debt remains measured in
unchanged tick units; speed change does not multiply/divide it. Scheduler input
may use host microseconds; gameplay does not. Preserve at most8 ticks/frame and
strict >0.25s overload: one downgrade4→2 or2→1 per host frame; at 1× hold CRITICAL
before the next frame's ticks. These internal choices pass through the same
recorded barrier without consuming gameplay RNG.

**Recommended U3 resolution:** retain all whole-tick debt. Permit only the existing
counted sub-tick presentation discard when PLAYER pause is entered with less than
one owed tick. Do not offer whole-debt discard recovery in production until a
higher-authority amendment explicitly reconciles it with no skipped ticks. Keep
historical counters/tests as historical or replace them with an explicit migration
entry; do not silently relabel acknowledged discarded ticks as completed work.
Resuming can trigger overload again if real work cannot drain the retained debt;
report that truthfully rather than fake catch-up.

## Save and replay contract

Propose save container version2 for this pending-state extension, retaining
`settlement_rules_v2`; no production v1 codec exists to claim has migrated.
Versioning is a storage-format change, not adoption of a new gameplay formula.
Do not silently reuse the version1 binary layout. Keep world requested speed,
pause mask and debt/counters with WorldRuntime; section12 holds pending economic
records followed by a scheduler extension:

- tag:8 ASCII bytes `SCHQ0001`;
- schema_version:U32=1, payload_byte_length:U32=32+32*count;
- the 32-byte queue control header above, canonical head=0;
- count 32-byte scheduler records in queue order (no unused rows serialized).

For container version2, section12 begins with an exact 24-byte prefix, six U32
fields in this order: section_schema=2, economic_count E, economic_payload_used P,
scheduler_extension_bytes X, economic_next_sequence_low, economic_next_sequence_high.
Follow it with E 64-byte economic records in canonical command order, then exactly
P bytes of the economic payload arena's used prefix (preserve offsets and consumed
space that still affects admission), then the scheduler extension above. Thus
X=48+32*S and section length=24+64*E+P+X=72+64*E+P+32*S. Require E≤4096,
P≤1048576, S≤256 and exact length agreement with the section directory. Economic
sequence fields preserve commands.gd's existing allocator semantics, not the new
scheduler's initial1/sentinel policy. Rebuild ring/order indexes deterministically;
do not compact payload storage in a way that changes future admission. Command
result/source-intent ledgers keep their own canonical auxiliary-state owners.

Validate all lengths,
count≤256, sequence bounds, reason ownership/rules, zero padding and pending
boundary==saved completed tick before world mutation. Restore records from row0,
all unused records zeroed. last_applied precedes every pending sequence; next
sequence is greater than every admitted sequence unless exhausted. Preserve
recorded historical clock counters. A v1 file without this extension may be
accepted only through a reviewed explicit migration proving no pending scheduler
intent; otherwise reject with the actual format reason. No fabricated parity.

Append admitted/applied scheduler events to their typed replay stream, distinct
from economic commands. At equal completed gameplay ticks, compare canonical
**gameplay state** across speed runs; scheduler requested speed/debt/log will
naturally differ. Compare scheduler round trips under identical host/event input
separately, and include all scheduler fields in same-session save continuation.
Performance diagnostics are not gameplay RNG inputs. SAVE callbacks observe a
complete barrier or serialize the exact pending queue, never a half-drained ring.

## Acceptance before U2 closure

Test byte offsets/stride/round-trip, unsigned high-word boundary, last U64 sequence,
normal capacity 250 then five unique safety holds and one overload event, repeated hold/clear/hold, refusal
with unchanged next sequence, paused draining/unpause, simultaneous pause reasons,
0/1/2/4 behavior, first midnight13500, speed change with debt, overload equality
versus strictly over threshold, no discarded whole ticks, and a pause requested
during an eight-tick catch-up frame. Test corrupt/oversized/stale sequence replay.

Local codec tests can pass before the full save system exists. U2's production
pending-save/replay acceptance remains blocked until that real integration is
executed. Emit proposed/adopted/implemented/verified statuses separately. Add8224
once to the **reconciled existing** ledger if adopted; record serialization buffers
or journal metadata beyond the existing streamed replay budget if implementation
introduces them. This document executes no tests and closes no gate.
