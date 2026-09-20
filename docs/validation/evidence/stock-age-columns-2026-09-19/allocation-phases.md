# Storage-aging cold-path allocation accounting

This is source accounting, not measured RSS or a performance qualification.
Packed backing storage only; object headers, Array containers, allocator overhead,
retained caller references and unrelated owners are additional.

| Object | Packed bytes |
|---|---:|
| Existing live StockAge canonical arrays | 1,013,760 |
| One CanonicalColumns record | 1,013,760 |
| One section 7 StockAge OwnerRecord | 1,013,776 |
| One validation membership buffer | 101,376 |

Owner capture allocates membership only after validating all rows and the native
count. It releases that local buffer when validation returns, then duplicates
four live arrays into the caller record. Old caller arrays can remain alive if
another caller reference holds them. No membership array becomes owner state.

Adapter capture starts with a local Columns constructor and existing caller block.
Owner capture replaces the constructor buffers with independent duplicates.
After membership is released, a private OwnerRecord constructor allocates its
own arrays. Mapping replaces those constructor arrays with the local Columns
arrays and creates two independent scalar cells. The codec performs its separate
membership validation, then publication replaces the caller's typed groups.
Private records leave scope. External references to the caller's previous groups
or buffers can retain those allocations; do not count them as freed unconditionally.

Adapter apply constructs one local Columns (including its initial buffers), then
replaces its fields with borrowed input buffers. Owner validation temporarily
allocates membership and releases it before installation. Four independent
array duplicates replace the live arrays one at a time. A caller retaining old
live/output buffers may keep them alive. The input block remains owned by the
caller; this adapter neither releases it nor installs its buffers directly.

No six-owner Record, second Inventory, permanent bitmap, or per-tick allocation
is introduced by these APIs. The tests that use a small Inventory still allocate
StockAge's compiled 101,376-row domain, as required by the existing owner schema.
