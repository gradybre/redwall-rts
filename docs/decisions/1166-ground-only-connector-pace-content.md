# 1166 — Ground-only ConnectorCatalog pace content

Date: 2026-10-04 · Status: independently accepted component; runtime activation remains separate

## Decision

Preserve the existing `UGCONN01` version1 fixed-connector form exactly. Add an
explicit version2 ground-only form with zero rows in **all six** geometry and
material tables (variants, points, regions, parts, vertices, materials), and
one or more pace rows within the existing maximum. Mixed zero/nonzero geometry,
missing pace rows and unsupported wire versions refuse before payload decoding.
Version2 cannot carry a fake fixed variant or a stair pace.

The existing streamed loader, two fixed banks, hashes, exact actual owner
binding and pace readers remain the only runtime APIs. The six zero counts are
the complete distinction; no additional retained version field, content bank,
global reservation or permission state is needed. Existing variant/material
readers correctly report absence for a successfully loaded ground-only image.
Every rejected replacement preserves the previous live image and caller output.

## Initial authored artifact

The additive `godot/data/underground/ground-pace-v1/` compiler reads the exact
reviewed mole `profile-publication-v3` wire (26 rows,250 boxes,content2) and the
existing initial level pack. It derives the supported MODE_WALK rows rather
than naming a STAND, WORK, CARRY or climbing row as a substitute. The exact
adult-mole Movement identity is the existing `starter.ground.adult.mole` row,
with its current original revision; the compiler records that source authority.

Each pace is an exact Profile ID/revision, family−1, variant0, Movement
ID/revision, `P_RATE=0`, `RATE_GROUND_CAP=0`. Zero is the existing instruction to
read the actual Movement speed cap, not an adopted zero speed or a new number.
The immutable image pins the Profiles content revision/source ID/source digest
and exact Levels revision/digest. The manifest also pins the complete input
wire and compiler/Movement inputs. No wood, labour, haul, stair or turn tuning
changes follow from this content.

## Boundaries and memory

Content supplies pace only. It grants no clearance, source-state transition,
actor binding, support, route, placement or excavation permission. The original
actual Movement/Residents/Transforms/Levels/World composition must still match,
and stale source/movement revisions refuse on load and current queries. Full
runtime consumer renewal remains root/Geometry-owned; tests may inspect the
exact immutable wire without claiming mounted production activation.

The runtime continues to admit `2*86008 + 2048 + 16384 =190448` bytes before
packed growth, with the existing32-byte digest scratch inside fixed controls.
No retained member, array capacity, constructor or allocation lifetime changes.
The final source census must account for any new count-check helper frame inside
the existing fixed reserve; native allocation/timing are not qualified here.
The offline compiler and its input/output images are build-time artifacts, not
an additional resident runtime image.

## Verification and ownership

Own only ConnectorCatalog and its existing test, the new content subtree, this
ADR and dedicated1166 evidence. Preserve other agents' changes and leave shared
registry, ledger, Catalog consumer renewal, host and routing files untouched.
Freeze exact source/artifact/test pins for independent review before commit.

Tests retain the full legacy catalog suite and add actual current-wire ground
pace load/query, empty geometry readers, v1 zero rejection, v2 mixed geometry,
missing/duplicate pace, wrong row/mode/kind/rate, stale Profiles/Levels/Movement,
foreign owner binding and atomic replacement cases. An independent offline
rebuild must reproduce the artifact bytes and manifest exactly. Run clean import,
strict focused regressions and analyzer with isolated user data, record every
diagnostic and restore the original project/assets/registry.

Authority is the parent's explicit bounded1166 lease on2026-10-04 and the
existing Movement profile policy; this is an engineering wire/content decision,
not a new gameplay balance ruling.

## Frozen component evidence

`underground-ground-pace-2026-10-04/source-review-1` pins the exact six source,
test, compiler and artifact inputs. The current immutable artifact is468 bytes
with nine actual WALK rows; its digest is
`1880788c064b87424c203509a7ad65498b9d11fc18842affe909364b8a8aca4a`.
An offline CLI rebuild reproduced both wire and manifest exactly; seven compiler
tests pass. The final four strict suites pass118 tests/3,730 assertions, every
diagnostic/leak counter zero, analyzer zero in two files, with all original
project/registry/assets/source bytes restored. All legacy Catalog tests remain.

The source census finds no retained or allocation vocabulary delta. The new
32-byte count helper's Catalog call chain is96 bytes, below the unchanged
273-byte own maximum. Fixed payload227 + conservative stream/digest328 +
helpers913 =1,468 within the existing2,048 fixed reserve; the16,384 native
allowance and190,448 total remain unchanged and unmeasured. The independent
review corrected the stream allowance to include both previous/source and
incoming maximum row buffers, rather than assuming loop-temporary destruction.
The original1,356-byte report remains in `source-review-1`; the corrected
metadata is retained separately in `review-correction-1`.

Furnishing independently verified all six frozen pins and seven producer
inputs, passed all seven Python tests, reproduced wire and manifest exactly,
and found no high/medium source or wire issue. Root accepted the frozen
component with the corrected conservative census. No executable or artifact
bytes changed for that correction, so no new engine run was required. Mounted
consumer/host, physical clearance and playable qualification remain separate.
