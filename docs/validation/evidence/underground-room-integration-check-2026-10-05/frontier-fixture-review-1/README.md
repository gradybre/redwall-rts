# Independent frontier fixture renewal review

The source-only correction is accepted at test SHA-256
`43345305a871d94625928e35a6c68eeec53a5e324c7ef227b8badb2224c13383`.
The reviewer compared the complete file against frozen checkpoint
`9dad696ddb6485e9a8c4b8efd8c8dcee52c9c4c0` and verified that the only changes
are two `runtime_sources_refusal()` expectations and one scope docstring.
`review.json`, the complete before/after snapshots and `test.diff` retain the
exact comparison.

ADR1170 renewed the current consumer hashes without changing the source
geometry. These two tests still expected the old `MOLE_CATALOG_SOURCE_DRIFT`
result. The correction now requires the actual current source check to pass;
it does not remove that check or change production code.

The following meaningful assertions remain byte-identical: the complete
one-cube geometry refusal; all paid, physical, Location, graph, certificate
and actor snapshots; the lateral two-endpoint/four-edge atomic publication;
all old rows, paths and certificate masks; and the absence of extra cuts,
movement or a paid Project. The qualified-profile suite separately retains
the actual nine cached-source success check and changed, empty and oversized
source refusals. Its source and the unchanged production Catalog are pinned
in `review.json`.

The author's three strict suites passed **37 tests / 1,149 assertions / zero
failures**; the reviewer independently parsed each complete raw log with the
strict shard parser. Every unexpected, expected, tolerated and leak counter
is zero. The analyzer passed with zero warnings in three files. The original
source, project, registry, assets, sidecars and HEAD were restored/unchanged,
and the reviewed source hash still matches. `verification-review.json` pins
the exact inspected evidence. No duplicate engine was launched by this
reviewer. The separate full local run remains on the original unmodified
`9dad696d` checkpoint so its original result is preserved.
