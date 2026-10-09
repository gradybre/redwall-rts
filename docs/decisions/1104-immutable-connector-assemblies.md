# 1104 — Immutable billable connector assemblies

Date: 2026-10-03  
Status: scoped component accepted; active content/Placement/contacts and joint admission remain open

## Context and boundary

Decision1101 separates a real permanent Corridor entry from ordinary flat room
confirmation. Decision1102 supplies real purpose8 installation accounting and an
immutable recipe reader. One priced tread includes its bearer and timber joinery;
a visual prism is not independently billable. Brendan approved wood only:
1000 milli-U wood and12000 milli-WU per tread assembly,4000 milli-U wood and32000
milli-WU per landing assembly. The proposed20-tread/six-landing entry totals44000
wood and432000 milli-WU. These values remain a separately authored content
obligation: this increment adds no active numeric source or installation recipe.

The grouping reader owns only `kind`, `first_part`, `part_count`, and
`recipe_anchor`. It cannot prove cut order, material contacts, work profiles,
retreat, bearing geometry, installed support, entrance existence or physical
frontier eligibility. No placement, cut history, Project, escrow or work column
is added. The later actual Placement and ConnectorWork composition remains
required. Current candidate26 groups are content, not a new room/player limit.

## Source protocol and complete ownership

`underground_connector_assemblies.gd` configures one finite immutable bank,
binds the exact actual Catalog/Recipes/Items/Inventory objects, and streams one
source file. The first successful load is immutable. A refused initial load
clears unpublished rows and can retry without allocating another bank.

Wire version1 begins with `UGASMB01`, u32 version, I64 grouping/Catalog/Recipe
revisions, I32 Catalog row, I64 variant revision, u32 group and actual-part
counts, and the32-byte Catalog digest:88 bytes. Each16-byte row contains the
four I32 fields above; the final eight bytes are `UGAEND01`. Exact file extent,
positive revisions, finite counts, kind domain LANDING0/TREAD1, nonempty ordered
ranges and contained anchors are mandatory. Ranges start at zero and meet
without gaps or overlaps; the final end equals the exact actual Catalog variant
part census. A source cannot omit real parts by declaring a smaller count.

Every actual Recipe row must correspond to exactly one canonical group anchor,
in the same increasing order. A missing group bill, extra included-bearer bill,
wrong anchor or invented part refuses the entire source. The reader returns a
caller-owned32-byte `AssemblyRecord`; refused reads preserve all four fields.
The allocation-free `assembly_count(expected_grouping_revision)` uses the same
pure current-source leaf and returns a positive actual count or zero on refusal.
Placement must independently retain a valid current binding before comparing a
prefix with that count; zero never means a successfully completed empty entry.

The pins are acyclic. Grouping bytes pin Catalog digest/revision, variant
ordinal/revision and expected Recipe revision. Recipe bytes pin the grouping
digest/revision in the existing1102 `frontier_hash` fields. Here that name means
the billable-group source, **not** proof of physical construction frontiers. The
group loader independently receives the expected actual Recipe digest and
checks both directions against the actual already-loaded Recipe bank. A later
physical-frontier source must separately pin this grouping and prove its own
contacts/dependencies; no unvalidated frontier ranges are stored here.

## Final source and lifetime proof

Every group/hash/binding query observes the actual Recipe owners and then uses
callback-free actual source facts. The final leaf compares exact Recipe bank
revisions/digests/anchors, actual Items registration, Catalog variant/count and
the1102 `SourceFacts` World/Profile/Level/Movement owner proof. A final overridable
Recipe observer cannot leave a stale successful answer after replacing a
Profile, retiring/reusing the World or re-registering Items. Entry exclusivity
precedes source callbacks. Final output-shape validation prevents an observer
from resizing a supplied hash destination before the copy. Both actual source
digest callbacks also have a post-callback32-byte shape guard before any hash
index; a source observer that resizes borrowed scratch fails without a partial
result or script diagnostic.

This is a cold metadata reader. Full-source/partition validation is bounded by
at most256 groups; do not invoke it per resident productive tick. Future
ConnectorWork must retain and attest its actual prepared/pinned source facts
without allocating a quote or scanning this grouping on each worker update.

## Exact finite memory and persistence

Configured G is1..256 (the existing Catalog part engineering ceiling), refused
before allocation outside that range. Four I32 columns use16G bytes. Seven
I64 header values use56 bytes; three exact hashes use96. The one immutable
bank is therefore **16G+152**, at most4248 bytes. No second bank or full source
image is retained. Reused32-byte hash plus nine-I32 actual-part packet use68
bytes; the capacity and configured/loaded/busy controls use11 logical bytes.

The explicit512-byte logical fixed allowance covers those79 reused bytes,
up to192 bytes of this reader's synchronous scalar/stream/hash frames, and a
conservative224-byte nested pure-source helper allowance:495 bytes before17
bytes slack. Streaming keeps at most the88-byte header or16-byte row, not both;
final source validation instead retains the32-byte actual digest,32-byte Recipe
digest and transient32-byte grouping digest slice. Those mutually exclusive
paths and their integer argument/index frames fit the192 allowance. Existing
Recipe/Catalog owner controls remain charged in their own composed reserves.
Packed/String/RefCounted/FileAccess/HashingContext headers, actual references,
hash-text temporaries and allocator growth are native overhead, not measured or
claimed zero by this census. The caller's32-byte result is separate.

`required_bytes(G) = 16G+152+512`, maximum4760; a26-group configuration needs1080.
The reflected actual packed payload is16G+220 (4316 at256), excluding numeric
frames/native headers. At the current known composed controls reserve, the
proposed Placement maximum151552 plus group maximum4760 exceeds the152976
remaining bytes by3336, before remaining adapter/frontier/native needs. Thus
neither independent maximum activates production; the joint pack must admit
actual configured sizes or reduce/restructure the proposed Placement envelope.

Immutable group rows/source pins are category2 source state in the registry:
composed save/load must pin and rebind the exact content and actual owners before
activating a placement. No live codec or release-save completeness is claimed.
Scratch, configuration, loaded/busy controls and actual object wiring are
category3; no process pointer or busy state is serialized. Canonical integration
is root-owned after the reviewed source schema is frozen.

## Verification

Final clean-import strict focused evidence is55 tests,2203 assertions,0 failures:
Assemblies17/1002, actual Recipes20/869 and Catalog18/332. Every accepted suite
reports both zero unexpected error/warning diagnostics and zero raw-log
unexpected error/warning counts, with zero leaked objects/resources. The final
two-file editor analyzer reports `0 GDScript warning(s) in 0 of 2 file(s)`.
Registry coverage passes130 modules,650 rows,998 packed columns. All22 source
functions and34 test helpers stay within30 lines.

Independent root review accepted source62144588bea85df8eae608a821b5f62e62dde8427574805d815673ab146354a4
and test24b02399ac773faecfc6cccbedc06917a83826c33cb64dad7220ea30133c7c5b
with no blocking source finding. The complete hashes, raw accepted/rejected
logs, manifests, analyzer and review are under
`docs/validation/evidence/underground-ug1104-assemblies-2026-10-03/`.
Tests use real Catalog/Recipe/Items/Inventory/World owners with explicitly
synthetic geometry and prices; they do not certify entry art, constructibility,
install contact, runtime memory or playable stairs.
