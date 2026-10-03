# 1068 — Resolve Gear through a bounded lot index

Date: 2026-10-03 · Status: Accepted — implemented and independently reviewed

## Decision

Decision 1056 measured repeated Gear row scans in actual 256-resident excavation
work. Add a private derived `PackedInt32Array[LOT_CAPACITY]` mapping each lot
slot to its Gear row. Every lookup still validates occupancy, the recorded lot
slot and the full lot generation. Equipped-work proof additionally retains the
owner and Job generation checks, equipped flag and positive durability.

The index is not a public Gear handle. No caller receives a raw row, no
generation check is removed, and no claim, work rate or durability rule changes.
The earlier allocator decision explicitly excluded later reverse indexes from
its budget; this is the separately recorded and budgeted increment it required.

## Publication and restoration

Publish the index with row occupancy only after all fields are initialized.
Blanking a row removes its index before releasing it to the existing lowest-row
free heap. Clearing the store clears the entire index. The incremental legacy
restore path uses the same publication logic. Whole-column restoration builds
a private index from the validated incoming columns before any live assignment.
Source capture and diagnostic audit verify the complete two-way correspondence.
A corrupt old index does not prevent restoration of a valid replacement image.

This is category 2 derived state. Canonical wire fields, order, registry identity
and owner schema remain unchanged; loading rebuilds the index from occupied
rows. Failed whole-column restoration leaves the old index and payload intact.

## Memory and scope

The fixed index adds `4 * 16384 = 65536` live bytes. A cold whole-column restore
has a second private 65536-byte index until publication. Both lifetimes must be
included in the shared ledger and the eventual composed-loader peak; the save
input contains no index. No allocation is introduced in productive lookup.

This targets a measured cost without asserting that it alone meets the 2 ms
whole-tick budget. Compare the same equipped-tool workload and retain the
remaining spatial, owner-validation and qualification-floor limits explicitly.
The exact source passed independent review and 217 focused tests with 34020
assertions and zero failures. Every strict diagnostics and raw-log footer has
zero unexpected diagnostics and zero leaks; the changed-source analyzer reports
zero warnings in three files. Evidence and source hashes are retained under
[`underground-ug22-gear-index-2026-10-03`](../validation/evidence/underground-ug22-gear-index-2026-10-03/README.md).

The local 256-worker pass remains above the whole-tick target: 9728 µs mean,
9953 µs maximum. Concurrent verification makes this unsuitable for a controlled
speedup claim. UG22 closes the bounded lookup and its correctness/budget proof;
UG17 still owns complete-workload performance qualification. Ledger payload is
86405078 bytes, live plus reserve 94793686, arithmetic headroom 5206314. These
figures include both 65536-byte index lifetimes and do not claim a measured RAM
peak or a qualified composed loader.
