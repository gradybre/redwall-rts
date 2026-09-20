# 0176 — Validate ResourceNode columns and preserve stump history

Date2026-09-20. Status: Accepted. Contract RESOURCE-NODES-S4-VALIDATE-R01v1.

Add a pure static ten-column predicate and section4 owner13 bridge, preserving existing version1/4096rows and all ordinary resource/section1 behavior. ResourceNode IDs are compiled output ItemDefinition IDs, settled by ADR0052; this local primitive enforces scalar range only. The already-correct owner header stays intact; repair its one stale reader docstring and the old unit test comments.

Validate flags, nonnegative scalar fields, stock bounds, present positive capacity/day, exhaustion equivalence, tile/global Directory reference domains, and mandatory inactive quantity/exhaustion/tile/ref sentinels in exact global gate order. Retain nonnegative inactive capacity/ID/regrow/planted-day history without arbitrary tuple reconstruction. Positive i64 extrema remain legal and no sum-fit restriction is added to the existing explicit due-date OVERFLOW behavior.

No local uniqueness scan, live owner/catalog lookup, scratch allocation, projection, normalization or bulk restoration. Caller172032packedbytes remain within the accepted stream allowance; native overhead unmeasured. Mandatory RESOURCE-NODES-SAVED-BINDINGS will establish same-file section1 inverse, Directory kind/typed-row/ref and uniqueness, verified catalog output-ID membership and full-file provenance before semantic publication. Local acceptance is not that proof.

Independent review re-derived schema and metadata arithmetic. Actual publichistory24assertions and typedAPI12assertions pass without failures/shutdown warnings. Capacity-nonnegative omission is a refusal-code identity mutant (STOCK rather than CAPACITY), not an acceptance-domain mutation. Thirty required assertion mutants,18metadata cases, source review, full checks and exact-head CI gate merge. Author owns only resource_nodes.gd/new bridge; parent owns tests/tools/docs. Production intake follows PR166 merge.
