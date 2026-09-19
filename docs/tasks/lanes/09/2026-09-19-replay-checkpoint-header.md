# Versioned header checkpoint binding — 2026-09-19

Task: 09_persistence_replay_reliability.md
Date: 2026-09-19

SAVE-REPLAY-R01 version2 / decision0156 closes the header's previously undefined
checkpoint meaning and insufficient scalar representation. Outer format2 carries
an exact economic next-admission pair at216/224 with reserved-zero padding at220.
The body digest moves232; header/table begin/end264 and first body1224. Section1
length and every section-relative owner position remain unchanged.

The pure header-local binding validator compares the header pair and completed tick
against decoded section12/section1 scalars, without importing section modules or
restoring owners. The full coordinator owns that same-file association and must call
this gate before mutation. Old formats refuse explicitly, preserving caller buffers.

Implementation acceptance is recorded under
`docs/validation/evidence/replay-checkpoint-2026-09-19/`; the exact source/offset
census and independent contract review are in the adjacent contract evidence folder.
No disk coordinator, release-save readiness, replay recorder, native play or Windows
qualification follows from the header codec. Task09.4's log framing, admission/append
transaction, checkpoint/log identity and branch recovery remain a named planning task.
