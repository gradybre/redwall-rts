# SAVE-D2-R02 — joint directory/cursor restore boundary

2026-09-19 · Astra · Version1 · existing SAVE-R09 §1/D2 semantics unchanged.

`save_section_01.capture_into` already captures the cursor; `EntityDirectory`
already exposes `restore_columns_and_cursor`. The missing piece is a save-layer
consumer joining the decoded §3 record to §1's decoded cursor. Implement a small
stateless `core/save_identity_restore.gd`; do not put a seventh column in §3 or
change the frozen WORLD runtime body. The full disk coordinator remains separate.

API: `static apply(record:SaveSectionDirectory.Record, next_persistent_id:int,
store:EntityDirectory, clock:SimClock)->SaveHeader.Refusal`.

Refuse null record/store/clock explicitly. Require `clock.is_load_barrier_held()`
before any mutation; ordinary PLAYER/LOAD pause bits are not that barrier. The
coordinator must supply the clock bound to this directory's world; the helper
cannot infer that association from two independent objects. It must never acquire,
release or change the barrier, tick, debt, RNG, saves or other stores.

Validate the record through SaveSectionDirectory.record_refusal, then invoke the
one existing EntityDirectory.restore_columns_and_cursor with all six decoded
columns and the actual decoded cursor. That owner validates the cursor range and
comparison against every incoming stored identity before writing anything. Never
call clear or restore_columns separately, derive max(live IDs)+1, or assign a
private allocator field. Return the exact record refusal or the owner's exact
last_column_refusal on failure. Success returns the existing empty refusal.

The owner method is atomic for these seven values; no disk transaction or
whole-world rollback is claimed. A lowered/missing barrier, stale cursor or invalid
column set leaves directory.state_bytes() byte-identical, including the cursor.
Input record arrays remain unchanged on success and refusal; the target must not
alias them. An unsupported full-world restore remains unsupported.

Required tests use actual source and target directory objects and real decoded
§3 data. Create IDs1/2/3, destroy3, capture/encode/decode, apply with saved cursor4,
then allocate and observe persistentID4. Destroy all and repeat, still allocate4.
Stage the final signed-int32 cursor through the existing owner API, issue MAX_INT32,
round-trip its six columns and separately encoded u32 cursor, and retain EXHAUSTED;
next create refuses. Pin cursor bytes 00 00 00 80 via SaveCodec. For invalid0,
2147483649 and cursor≤storedID, assert the exact owner code and unchanged target
state. Malformed columns, null participants and absent/released barrier refuse
without publication. A held barrier stays held after success/failure; clock tick,
debt and pause mask remain unchanged. Mutating the decoded record after success
must not mutate the target. Tests are identity-section round trips, not full saves.

One implementation worker owns only the new module and dedicated test. Astra owns
ruling/ADR, stateless registry entry, updating outdated D2 prose and queue/coverage
reconciliation. No schema/packed allocation/ledger total change is allowed. A
fresh independent Opus review and the actual supervised Godot suite are required.
