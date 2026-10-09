# 1076 — Spatial Inventory endpoints retain the actual location

2026-10-03. Implementation decision for UG09/UG20/UG21. Inventory component
implemented and independently reviewed; actual world integration remains open.
This packet does not yet activate underground hauling or close MOVE-G05.

## Problem and ownership

Inventory's ground-pile map and container anchors name one of 16384 surface
placement tiles. Reusing one for an underground container aliases different
floors. Creating an unlimited ordinary container instead would bypass the
adopted local finite output contract. Per-container XYZ columns would charge
all 101376 possible container rows even when very few have underground
endpoints, and would duplicate the actual Locations owner's space identity.

The actual Inventory owner will therefore own a finite sparse endpoint table
and include its changes in the existing Inventory undo journal. The actual
Locations owner introduced by 1075 remains the only owner of location XYZ,
Room/section identity, support qualification and connectivity. A typed weak
adapter connects them through `inventory_spatial_contract.gd`. Numeric equality
between different Inventory, World or location-owner objects is insufficient.

Root owns this contract, the Inventory changes, `test_inventory_spatial.gd` and
this decision on `codex/underground-inventory-locations`. UG21 owns the actual
Locations adapter. UG07 retains the shared Funding/Construction/Work files;
its later promotion dispatch will call the real Inventory API. No shared file
is concurrently edited by those lanes.

## Exact representation

For an explicit admitted capacity C, the sparse table has four int32 columns
(container slot/generation, location slot/generation) and one int64 column
(location-payload revision): **24C packed live bytes**. An unused row is
canonical null refs `(-1,0)` with revision zero. Its row is a private index, not
an EntityRef and not a location handle. The full actual container identity
must reverse-match before any encoded row is accepted. Cold admission finds
the lowest unused row in a bounded scan; there is no additional free stack,
per-container index or per-endpoint object.

The existing int32 container anchor reserves values `-2-row` for these private
rows. Surface anchors keep their existing `0..16383` domain, and `-1` keeps its
unplaced meaning. Ordinary anchor setters cannot mint this encoding. Flat
authority readers must explicitly refuse a spatial anchor instead of treating
it as a real surface cell or silently answering unplaced. Diagnostic readers
may expose the encoding but must not be used as a location proof.
The complete flat footprint query also refuses while any spatial endpoint is
live, without writing a partial result. Its cursor remains a surface-only
candidate iterator, never a completeness or destructive-clearance proof.

The complete identity is the actual Locations object, full local location
ref and its positive payload revision. This revision identifies the immutable
location payload, not every unrelated global geometry revision. Fresh support
and containment are revalidated through the actual provider. Retiring or
moving a location with an owned endpoint is forbidden until the real goods,
capacity and job claims have been resolved.

The uniqueness key is actual World + full floor-section reference + the exact
2048u placement cell in X/Z relative to the world datum. This extends the
existing 2m pile address across floors; it never rounds a pile envelope through
a wall. Duplicate location handles for the same storage cell cannot mint two
piles or independent staging reservations. Ordinary transit/work contacts are
not automatically valid storage endpoints.

## Transactions and lifetime

The new door creates a finite World-owned staging container at the actual
storage endpoint. It keeps the existing 400000g pile capacity, all-material
filter and real row/lot capacity rules. First output publication releases the
owned capacity claim, creates the actual output lot and promotes that same
nonempty container to a ground pile in one explicit Inventory transaction.
No extra source, receipt account, teleport or capacity credit is introduced.

Every sparse-row change journals its five-field preimage in the existing
4096-entry, 14-int64-stride journal. Existing per-operation journal admission
must cover both container and endpoint preimages. Abort restores both. The
current fixed journal is not duplicated or expanded. Ordinary empty-container
destruction and automatic empty-pile reclamation release the exact endpoint;
an empty claimed pile still refuses commit. Audit includes reverse identity,
canonical unused rows, fixed pile shape and unique live placement keys.

Bindings remain weak and exact. A once-bound spatial provider cannot be
replaced with a foreign object after its history has been admitted. Authority
callbacks execute inside Inventory's existing reentry guard. Admission and
promotion recheck current source identity, location revision and storage
qualification before the first mutation.
The guard covers transaction begin/commit/abort, reset and non-journaled catalog
or authority wiring as well as goods operations. A callback cannot close its
caller's transaction: an attempted mutation poisons an existing transaction
while preserving its journal until the real caller regains control and rolls
everything back. During a cold read with no open transaction, those doors
refuse without opening a transaction or changing catalog/binding state.

## Capacity, save and qualification

The initial technical pack proposes C=1024, admitted once by the 1072/1075
joint capacity gate. That is 24576 live packed bytes. One simultaneous raw
image adds 24576 bytes; a current column conversion can add at most 8192 bytes.
These do not by themselves qualify the reserved 131072-byte endpoint-provider
envelope: scalar state, component/native allocations and all simultaneously
retained cold output must be counted and measured before activation. The
existing shared journal is already budgeted. Exhaustion refuses before
mutation; this is an implementation arena, not a room-size or room-count rule.

The raw refusal/rollback image includes the table when configured. Existing
flat canonical save and restore doors must refuse while spatial endpoints are
live. UG16 must author an explicit versioned extension and restore it atomically
with actual Locations, Inventory containers/lots, jobs and output claims; a
legacy flat anchor must never be silently reinterpreted. No release-save
readiness is claimed by this packet.

Required tests cover stacked same-X/Z piles, duplicate handles for one cell,
stale/foreign provider identities, exact finite capacity, output promotion and
rollback, journal exhaustion, endpoint capacity exhaustion, reentry, empty
pile retirement, full-generation container reuse, flat-reader refusals and
legacy codec refusal. Actual multilevel haul/contact tests follow the complete
1075 composition. All engine validation uses the clean CI import procedure and
strict diagnostic/leak accounting; exit zero alone is insufficient.

The accepted six focused suites passed 265 tests / 2330 assertions / 0 failures,
with zero unexpected diagnostics and zero leaked objects/resources in every
runner and raw footer. The three-file analyzer reports zero warnings. Source
hashes, raw logs, the two independent-review corrections and reproducible
commands are recorded in
`docs/validation/evidence/underground-inventory-spatial-2026-10-03/README.md`.
These tests use actual Inventory with explicitly synthetic location geometry;
they are not a full-suite or actual-world qualification.
