# 1131 — Account for the additional Entry World composer

Date: 2026-10-04 · Status: accepted source accounting; runtime qualification open

Decision 1119 adds a concrete subclass of WorldBindings. Charge its distinct
2048-byte control/helper reservation once per World, outside the already fully
assigned 524288-byte binding reserve. Its inherited WorldBindings storage and
the existing Contacts packet are already counted. The subclass borrows that
same Contacts through a weak reference; it cannot own a second packet.

The source-derived checker verifies 130 numeric control bytes and three fixed
six-I32 arrays totaling 72 bytes. The existing 1024-byte logical helper allowance
brings that census to 1226 within 2048. It checks the complete member types, exact
allocation/array-use statements and sole borrowed getter. New constructors,
additional packed scratch, changed initializers, aliases, dimensions or member
types fail until their accounting is reviewed. Twenty mutation cases exercise
these changes. Independent review found and corrected two earlier weaknesses:
dimension-only checks missed additional growth, and member-only checks missed
local packed scratch.

The joint mutable/reserved pack becomes 4968921 bytes. The architecture ledger
adds one allocation row and preserves every historical reconciliation step:
payload 91573078; one World plus the existing 8388608 reserve 99961686; decimal
100 MB headroom 38314. The rejected two-World peak becomes 185285071, exceeding
the same gate by 85285071. Neither reserve nor memory gate increases.

Contacts' additional eight numeric bytes and decision 1124's route controls
remain inside their existing reservations; neither is charged a second time.
Native object headers, Variant storage, actual helper frames and the composed
runtime peak remain unqualified. This arithmetic grants no playable, movement,
profile or save permission.

Evidence lives in
`docs/validation/evidence/underground-entry-world-memory-2026-10-04/`.
The initial 146 passing tests used explicitly injected, frozen 1119/Contacts
source records because that module was not yet committed in the checker
worktree. That run is retained as developmental evidence. After integration,
the normal current-source invocation also passed all 146 tests, artifact
generation and exact checking, plus READY07's 49 allocation rows. No source was
injected in that run. Independent Geometry review checked the final wiring,
all 57 historical trail rows and exact arithmetic; the normal generated pack
has identical non-hash data to the reviewed prospective pack. Current source
hashes additionally include the accepted route and entry changes.
