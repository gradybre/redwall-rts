# Baseline helper breakdown

This baseline uses committed hot-6 production code and adds only the bounded
phase benchmark in the Routes test. The five manifest files remained unchanged
through clean import, Locations 57/1731, Routes 62/10393 and WorldRoutes 26/1711:
145 tests / 13835 assertions / zero failures. Every strict/raw diagnostic and
leak footer is zero; analyzer 0/5. Original project bytes and assets were restored.

The full query uses 256 actual living residents, actual O2048 source capacity,
and a three-span committed path. Each of 20 batches runs 256 calls; separate
helper batches measure the same source/search/endpoint obligations under the
existing scratch guards, between valid complete production queries.

P95 milliseconds per 256 calls: full query 25.710; both source attestations
8.462; descriptor 0.406; Dijkstra 6.865; full chain 1.682; selected endpoint and
source proof 5.438. Independent measurement boundaries mean these phase values
need not sum to the full query. No physical Terrain scan occurs in this static
certificate query; Contacts retains that separate current obligation.

This is failed timing qualification, not a complete simulation benchmark or a
native/transient allocation proof. The shared reproduction script and exact
commands are recorded in `invocation.json`; it uses the isolated user directory
`Redwall-ug-geometry-hot-tests`, temporarily parks only this worktree's demo
assets, then restores the project and assets. Reproduce with:

```sh
python3 docs/validation/evidence/underground-connector-placements-2026-10-03/reproduce-hot.py --out docs/validation/evidence/underground-connector-placements-2026-10-03/hot-profile-recheck --port 6254
```
