# 0154 — Preserve pending-command arena layout through guarded restore

Date: 2026-09-19 · Status: Accepted implementation contract

Canonical command order and payload allocation order differ. Partial drains also
leave holes and a highwater cursor whose remaining capacity affects later commands.
Re-admitting records cannot reconstruct those states without changing behavior.

[SAVE-P2-R02](../rulings/2026-09-19_pending_command_restore.md) adds one validated
owner replacement API, guards ordinary economic queue mutation under the clock load
barrier, and makes section12 install commands before the scheduler with checked
recovery on failure. Exact spans and cursor survive; unused bytes remain zero.
No wire/schema or persistent field change is made in this slice.

The separately discovered exhausted economic allocator `(4294967296,0)` cannot fit
the existing schema2 u32 prefix. Runtime owner restoration supports it, but the
codec must continue to refuse it until an explicit versioned format migration.
That migration is a new required save prerequisite, not a claimed completed case.
