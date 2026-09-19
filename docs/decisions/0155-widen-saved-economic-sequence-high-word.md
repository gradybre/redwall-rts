# 0155 — Widen the saved economic allocator high word

Date: 2026-09-19 · Status: Accepted; implemented in merged PR145

The economic allocator has 2^64 ordinary sequence values plus one exhausted state.
Two u32 words cannot encode all of them. Zero is an ordinary initial value, so the
scheduler's zero sentinel cannot be copied without losing a valid economic state.

[SAVE-SEQ-R01](../rulings/2026-09-19_economic_sequence_format.md) chooses section12
schema3 with a28-byte prefix and a u64 high allocator word. The live allocator and
64-byte command records stay unchanged. Canonical commands owner schema2 declares
the same scalar at width8; no new packed allocation is added. Old section schemas
refuse explicitly without rewriting input files; automatic migration is not claimed.
This contract is separate from P2's schema2 arena repair. The active implementation advances section12 to schema3; full-file header binding and the coordinator remain separately gated.
