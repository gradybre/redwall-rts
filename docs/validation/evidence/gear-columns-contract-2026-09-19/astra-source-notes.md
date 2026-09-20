# Gear owner boundary — feasibility notes

2026-09-19 · Astra · planning only, no implementation packet released.

Section7 owner2 has12canonicalarrays:10i32 and2u8,42Rbytes. RowIDs are bare
indices and cannot compact; one gear record per Inventory lot SLOT, including
stale generations, so no duplicates of a lot slot. Runtime R<=16384. Derived
minheap, free/active/equipped counts. Five cached item IDs, collaborator bindings,
wear math and starter-seed buffers are noncanonical with differing semantics.

Existing begin_restore/restore_row/finish_restore is not atomic and restore_row
has no equipped parameter: _write_new_row sets_equipped0, so it cannot serve as
the complete canonical boundary. Do not replay it as a hidden shortcut.

The registry says _seed_count is0 outside seeding, but successful
seed_starter_tools returns with24. Do not use nonzero_seed_count as a busy gate;
it is stale category3 rollback scratch after a completed successful call.
Source is synchronous; caller must exclude reentry/half-seed callbacks. Preserve
scratch unless an explicit reason requires reset. Registry must correct its
count description and account for equipped_count, bindings and wear scratch.

Unlike StockAge, cached item IDs cannot simply be invalidated: equipment
attestation can depend on them immediately. Determine exact cache refresh,
verified-catalog and binding prerequisites without introducing a failure-path
mutation. Existing capture_item_ids can leave some keys unresolved (-1) legally;
do not invent all-five-positive requirement. New owner boundary should preserve
structural saved domain; catalog membership, owner liveness/mirror and equipped
Inventory biconditional are separate coordinator reconciliation responsibilities.

bind_equipment registers Gear as Inventory authority and refuses when equipped
rows exist. Initial target must bind before installation; a reused world's
collaborator objects may remain identical while their arrays are restored.
Inventory.restore_canonical_columns explicitly skips gear attestation until all
section7 owners are restored. Therefore full coordinator owns ordering and
reconciliation, not an invented row replay or post-install blind rebind.

Likely design: unique owner column methods, separate single-OwnerRecord adapter,
total shape gates, _restoring refusal, safe source minheap/count validation,
O(R+LOT_CAPACITY) unique-lot membership and exact occupied/blank/ref/durability/
manufacture checks matching existing codec, private validation then independent
publication. Need full source audit for reachable wire-domain mismatches,
binding/cache choices, equipment authority and future-operation tests before
writing a contract. No new gameplay or fullworld save claim.
