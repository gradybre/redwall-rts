# 0063 — Save classification, stable naming and responsive UI
Date: 2026-09-11 · Status: Accepted engineering ruling; implementation evidence pending

## Decision

Resolve G1–G3 and I2 as specified in the
[READY_07 addendum](../rulings/2026-09-11_ready07_save_ui_addendum.md): command
outcomes are transient; source-intent identity is persisted and hashed; current
container reachability is persisted and hashed; clock debt and six counters
persist as host-continuation metadata but remain excluded from ARCH-HASH-001.
Bind generated naming to the existing `hash_pair(persistent_id, world_seed)`
under identifier RWL-NAME-1, with pinned vectors and persisted assigned names.
Implement responsive UI §1.2 rather than retaining a fixed base-canvas transform.

## Why

Persistence and hash inclusion are distinct. An allocated column need not be
saved, and a saved host field need not affect the gameplay digest. The inventory
byte is an explicit GDD field with no deterministic reconstruction owner today.
Existing integer hashing already supplies the algorithm naming needs. UI §1.2
outranks prototype stretch settings.

## Consequences

Architecture, scheduler wording and the registry are aligned. Decision 0062's
original gap report remains historical evidence. Typed reference domains and
bare-index slots must retain their distinct allocator semantics in the codec.
No generation unification, row compaction, whole-debt discard, name regeneration,
new digest wire format or gameplay constant is authorized. Validation distinguishes
isolated kernel/arithmetic checks from unimplemented save and live-UI tests.

## Source

Brendan's executor addendum; GDD §§4.2/5.3; ARCH-RNG-001, ARCH-SAVE-001–006,
ARCH-HASH-001, R07-SCHED-001 and UI §1.2. Independent read-only reviewer agrees
on G1/G2. See the linked addendum for actual source revision and evidence.
