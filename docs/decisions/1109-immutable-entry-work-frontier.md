# 1109 — Immutable entrance work frontier

Date: 2026-10-03 · Status: implementation in progress; no physical permission is qualified.

## Decision

A source-bound, finite EntryFrontier complements the Catalog, billable assembly
partition and Recipes. It describes the authored order and physical prerequisites
for excavation and installation. It owns no Site phase, installed prefix, work,
worker, inventory balance or runtime endpoint identity. Those remain in their
existing actual owners. Root owns this reader and actual EntryBindings;
Construction owns the concrete ConnectorContacts consumer.

The reader streams one immutable source into pre-admitted packed columns. A
failed first load clears unpublished rows; a successful source cannot be replaced.
There are six tables: installation, station, required cut ranges, bearing targets,
endpoint selectors and excavation episodes. Installation rows are exactly the
Grouping ordinals, each billed once through its canonical Recipe anchor. Source
identity pins the actual Catalog row/variant, Grouping, Recipes and Profiles
content revision plus the exact animation-program source digest. Profiles has no
public binary-image digest; its monotonic content revision and source digest are
used explicitly rather than mislabelling a program digest as an image digest.

The agreed installation row is nine int32 fields: assembly ordinal, station,
fastening target, cut-range start/count, bearing-range start/count, material
endpoint and retreat endpoint. Stations contain endpoint, integer root XYZ, yaw,
profile, posture, face and work kind, plus four exact int64 profile revisions and three additional int32 profile IDs.
Each80-byte station explicitly maps every Catalog-admitted quarter-turn to its
qualified exact-yaw WORK profile. Unadmitted rotations carry(-1,0); a missing or
wrong-yaw admitted profile refuses. Geometry rotation1 maps(x,z) to(-z,x), while
Routes heading0=-Z/+quarter=-X, so world yaw is(local yaw - rotation×16384)
mod65536. The nine-field output retains local root/yaw/face while returning the
selected actual world-yaw profile and revision; the physical owner transforms
that source-local frame. The
whole contact patch comes from that actual profile. A source row cannot invent or
shrink the patch. Required-cut rows contain a canonical relative cube-union box
and one exact physical phase. Physical phases are tags, never numerically ordered
progress thresholds.

Bearing targets name retained natural material or a part of an earlier installed
assembly, with exact relative bounds. Endpoint selectors name the natural surface
anchor or an earlier installed contact, its assembly/datum/role and integer point. An installed datum is an exact
variant-relative Catalog LANDING region ordinal with pointY at its lower floor
and X/Z within its half-open footprint. The live corresponding FLOOR_DATUM and
actual completed support still require the physical owner's separate proof. A separate SURFACE_CONTACT selector
resolves a unique already-live World-owned contact on the exact full section of
the natural anchor; this permits a real exterior storage Location distinct from
the WORK anchor. It creates no endpoint or support and still needs fresh
Terrain/Location/Space proof. Material selectors require actual ROLE_STORAGE
and Inventory binding, never an unlimited unlocated container.
Each endpoint also explicitly names its transit profile and full int64 revision.
Its40-byte row is seven selector int32 fields, one travel-profile int32 and one
revision int64. The selector reader remains seven fields; a separate paired
reader refuses aliased outputs. A WORK profile cannot imply WALK, CARRY or CLIMB.
No adopted connector delivery distance was found: current exact STORAGE binding
and certified actual route remain required without inventing a new radius.
No Location, container, Room, worker or Project handle is serialized in this
immutable content. An excavation episode contains19 int32 fields: one exact canonical relative
cube-union box, BRACE/CUT/FINISH mask, required installed prefix, one station per
enabled phase, dependency and bearing ranges, material/output/retreat selectors
and target face. The mask names authored opportunities; actual Sites remains
the sole physical phase/history owner. Overlapping ranges cannot duplicate an
operation. A shared station never permits unreachable cuts within a range. The runtime
resolves these selectors through the current full Placement and actual owners.

## Physical meaning

Source validation checks bounded complete tables and cross-references, unique
operation identity, canonical cut geometry and prior-only support. It does not
prove that a worker can stand, swing, fasten, turn, carry or retreat there. Actual
EntryBindings must validate the complete source and claim union against the
actual World. ConnectorContacts must observe the current Placement prefix,
real Sites in its Corridor, actual terrain and already installed geometry,
qualified profile, actual resident/tool/cargo/pose and supported material/retreat
endpoints. A completed prefix alone grants no clearance or support.

INSTALL requires a separately qualified fastening motion and its real existing
bearing target. A digging pick touching an earth face is not an installation
certificate. A pending tread or landing cannot supply its own stance, bearing or
retreat. CUT still removes the full paid cube and yields the adopted earth amount;
none of these tables creates partial free dirt platforms or routes through solid
material. The timber recipe remains wood only as approved in1101.

## Lifetime and verification

The configurable immutable bank, streamed decoder and fixed controls must fit
the existing bindings allocation together with actual Placement and ConnectorWork.
The older146152-byte remaining figure excluded Placement: its conditional maximum
108800 bytes plus ConnectorWork563 leaves only36789 bytes for Frontier, Contacts,
EntryBindings and native growth. The first proposed131072-byte reader ceiling
would overbook that reserve and is rejected before allocation. Concrete authored
row counts, shared exact selectors and streamed ranges must establish the whole
coexistence census; no approved shape/population capacity is silently reduced.
The reader ceiling is28597 bytes, leaving4096 each for Contacts and EntryBindings
within the corrected36789-byte remainder. Actual smaller source counts must
retain room for unmeasured native/helper growth. No maximum-sized table allocates
by default. A single bank suffices
because this content is loaded once before world activation. Native overhead
and the composed100MB qualification remain separate obligations.

Reads fill caller-owned fixed outputs only after current source and shape checks;
refusal preserves them. Planned checks include malformed/truncated/extra source,
capacity and digest mismatch, unknown/future support, duplicate cut identity,
wrong phase, actual source reload/World generation/owner drift, output aliasing
and refusal purity. Synthetic source tests establish decoder semantics only.
Actual entrance confirmation, paid worker progression, timber installation,
safe retreat, save/resume, native720p quality and256-resident qualification remain
required under1051/1101/1108.


The corrected component check passes51 tests/2188 assertions across the new
reader and its actual Assembly/Recipe source dependencies, with all unexpected
diagnostics and leak counters zero; analyzer reports0 warnings in0 of2 files.
Exact pins, refused iterations and commands are retained in
`docs/validation/evidence/underground-entry-frontier-2026-10-03/`. Independent
review is still pending; no active physical content is authored by these tests.


Independent source review requested the explicit four-rotation work mapping and
exact installed LANDING cross-reference above, plus an explicit six-I32 capacity
resize/copy for accurate registry accounting. These corrected semantics are
under focused revalidation; the earlier51/2188 result excludes those additions.


The corrected final packet passes54 tests/2273 assertions, all strict/raw
unexpected diagnostics and leak counters zero, with0 analyzer warnings across
2 files. Construction independently rehashed and accepted the corrected source
and test pins with no remaining high/medium finding in the metadata reader.
No active physical content, installed contact or gait is qualified here.
