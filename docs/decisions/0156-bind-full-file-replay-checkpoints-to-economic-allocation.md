# 0156 — Bind full-file replay checkpoints to economic allocation

Date: 2026-09-19 · Status: Implemented and locally accepted; integration CI pending

Section12 schema3 can represent the economic allocator's ordinary u64 range plus
its exhausted state, while the outer header's scalar checkpoint cannot. The old
header also had no decided relationship to the live owner.

[SAVE-REPLAY-R01 version2](../planning/replay_checkpoint_contract.md) defines the
checkpoint as the next economic admission frontier of the frozen snapshot. The
commands owner remains its sole authority. A redundant header declaration must
match section12 exactly, and the header tick must match section1 before loading.
It does not identify the last executed command or a replay-file byte offset.

Outer format2 extends the header to264bytes: low-u32 at216, reserved-zero-u32 at220,
high-u64 at224, body digest at232. The descriptor table begins264 and first section
1224. Existing section bodies and their schema versions remain unchanged. Old outer
formats refuse explicitly; no implicit migration or file rewriting is introduced.

The contract explicitly supersedes the older fixed outer1/header256 ruling without
reviving its rejected scheduler-only version2 proposal. Independent review's five
contract gaps are resolved in version2. The bounded implementation includes format
dispatch, atomic codec refusals, a pure scalar binding validator, relocated file
positions and tests. Full disk orchestration, canonical owner adapters and replay
recording remain separate prerequisites, not implied completed work.
