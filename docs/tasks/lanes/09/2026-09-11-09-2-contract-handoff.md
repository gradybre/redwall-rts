# 09.2 contract handoff — 2026-09-11

Task: 09_persistence_replay_reliability.md
Date: 2026-09-11


Read [SAVE-R09-001–005](../rulings/2026-09-11_save_codec_contract.md) before codec
work. It resolves the five requested storage decisions; task09.2 is still open.
Implement the version vector, u32 UTF-8 strings, canonical identity artifacts,
map provenance binding, gapless sections and assigned11/13/15 payloads. Update
registry/memory as owners land; missing event/Chronicle content and expanded
MOVE-G02 schemas still block their complete release saves. Follow the ruling's
independent corruption and continuation evidence; do not label empty fixtures
complete systems. STATE-COHORT-R01 excludes `_cohort_slots` rollback scratch.
The earlier09.1 note about three unresolved rows is historical: decision0063
resolved result/reachability classification; scheduler writer wiring remains work.
