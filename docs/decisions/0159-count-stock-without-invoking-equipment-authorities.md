# 0159 — Count stock without invoking equipment authorities

Date: 2026-09-19 · Status: Implemented candidate; independent source review and tests passed, merge pending

[INIT-COUNT-R01v2](../planning/inventory_stock_counts_contract.md) supplies a cold,
read-only whole-Inventory count record: live, loose, equipped and unreserved loose
milli-units, four256-entry i64 arrays. A single checked scan stages results and
replaces caller fields only on success. Existing owner scratch is never borrowed.

Classification uses local placement structure; it does not invoke duck-typed
attestation callbacks or certify cross-owner equipment legality. The existing
Gear/Directory audit remains required before a world can be published. This
avoids adding reentrancy and nested gear scans to a presentation read. Unregistered
or partially restored stores refuse explicitly until composition is complete.

Publication adopts independent staging buffers, including when the caller fields
were aliased. Old held arrays remain old snapshots. This is a cold8192B output plus
8192B staging payload, not a new simulation owner or save field. Runtime consumer
performance and the single-inventory boot remain separate acceptance obligations.
