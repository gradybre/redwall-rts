# 0161 — Encode event schedules without inventing event kinds

Date:2026-09-19 · Status:Implemented candidate; independent review, focused/full tests and static gates passed; CI/merge pending

[SAVE-S11-R01v2](../planning/event_schedule_codec_contract.md) implements the
already ruled section11 form: next_sequence:i64 then0..64sorted32-byte records,
with row count in the descriptor. Empty schedules still encode8bytes; an
exhausted allocator0 remains exhausted even after all rows are consumed.

Use existing owner getters for capture and its atomic restore_rows under the
supplied clock's load barrier for apply. Shared record validation delegates to
a cold temporary owner, avoiding a second interpretation of allocator/order
rules. Four i32 values remain storage domains only; no event kind, catalog,
producer, expiry or consumer is invented. PLAN-COMMUNITY-EVENTS retains actual
semantic activation. The codec is independently testable before those consumers
exist, but does not close world save coordination or gameplay acceptance.
