# 1190 — Fixed entry source publication contract

Date: 2026-10-05 · Status: Accepted interface; bundle published (see "Publication"), runtime activation pending

## Decision

The original Session selects its fixed ground or first-entry source before
binding WorldRoutes. A repeated request must match that original choice. A
caller cannot provide a file, capacity, owner tuple or replacement live Catalog.
Both Catalogs have revision 1; their complete source digests and profile-content
revision distinguish them. A larger revision does not authorize replacement.

The entry accessor will be the generated, immutable
`godot/data/underground/first-entry-prefix-v1/qualified-handling-v1/catalog_source.gd`.
It is published only after the actual source, paid execution, consumers and
independent review pass. Until then the path is reserved, not a runtime stub.
The current diagnostic packet uses content revision 4; a changed physical
source requires an explicit reviewed successor, not an unchanged digest claim.

The accessor exposes typed constants:

- `CATALOG_PATH` / `CATALOG_SHA`, `GROUPING_PATH` / `GROUPING_SHA`,
  `RECIPE_PATH` / `RECIPE_SHA`, `FRONTIER_PATH` / `FRONTIER_SHA`,
  `WORKPIECES_PATH` / `WORKPIECES_SHA`, and `GROUND_PATH` / `GROUND_SHA`.
- `CATALOG_REVISION`, `GROUPING_REVISION`, `RECIPE_REVISION`,
  `FRONTIER_REVISION`, `WORKPIECES_REVISION`, and `CONTENT_REVISION`.
- `INSTALL_COUNT`, `STATION_COUNT`, `CUT_COUNT`, `BEARING_COUNT`,
  `ENDPOINT_COUNT`, and `EPISODE_COUNT`, decoded from the accepted Frontier.
- `CATALOG_DIGEST_0` through `CATALOG_DIGEST_3` and `GROUND_DIGEST_0`
  through `GROUND_DIGEST_3`: signed little-endian I64 words of the same SHA256
  values. These permit repeated exact comparison without a new decode buffer.

All referenced assets reside beside the accessor. The create-only publisher
checks exact source bytes and linked headers, recomputes every digest, verifies
the finite table census, and emits the accessor from those accepted bytes.
Existing source publications and their strict historical checks remain intact.

## Startup and lifetime

The order is route-owner composition, original SurfaceAnchor-owner composition,
entry-owner composition, then actual SurfaceAnchor/access publication. Entry
composition refuses an occupied graph before it allocates. Private partial
constructor prefixes remain stopped and retained for exact owner retirement.
The original Host Planner, StorePolicy and command clock are retained; there is
no second owner tuple. Constructor temporaries, including the six-count input,
remain within the existing counted reservations.

## Why and limits

Session composition and physical source qualification are being built in
parallel. This fixes their interface without granting permission from a
diagnostic fixture or manufacturing a successful production mount. Repeated
source checks remain allocation-bounded and cannot select different assets.
The diagnostic source's current standing/retreat collision after timber staging
is still an actual paid-execution blocker; this interface does not waive it.

Authority: decision 1051, approved D20, and the original-owner contracts in
1167/1171/1184. Physical source and paid handling remain the responsibilities of
1178/1183; root owns publication and its independent acceptance evidence.

## Publication (2026-10-05, branch `claude/ug-paid-start`)

`publish_qualified_handling.py` created `qualified-handling-v1/` once, from the
exact bytes executed by the passing real paid-L0 suite. That suite had 10 tests
and 0 failures, and the full suite was green on `c7f63b49`. The publisher
checks every input digest and the Frontier header's revision (2), census
(2/8/2/10/12/6) and links (catalog, grouping, recipe and the published actor
`adc61764…`). The accessor also exposes `PROFILE_PATH`/`PROFILE_SHA` (content
4) and `ACTOR_SHA`. The interface above did not list those, but the Frontier
and the paid fixture bind them.

The work-area and paid fixtures now load only through this accessor. Runtime
activation is not done: route composition and the motion catalog still load
the content-3 `qualified-step-v4` publication, which has no handling row. The
independent review required above has not been done; ADR 1192 replaces it with
review of the commit diff.
