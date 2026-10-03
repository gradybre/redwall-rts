# 1080 — Source-bound underground profile catalog

Date: 2026-10-03
Status: implementation in progress. The exact Residents reader and immutable catalog/actual-owner selection prerequisite are independently reviewed; authored production clearance remains in progress.

## Decision

Profile selection will use actual full Resident/Job identities and the current
Residents species, life stage and existing logical rig. It will not accept a cast name
or caller-proposed species as proof. The additive allocation-free
`spatial_profile_identity_into(ref, scratch)` requires exactly three integer outputs,
validates the Directory kind and both owner mirror fields, and writes only after all
checks pass. It deliberately refuses absent child/elder rig bindings, preserving the
existing catalog rather than substituting an adult body. The movement/contact owner
separately checks life and eligibility.

The physical catalog is immutable integer content, with a finite
per-selection box bound and streamed replacement. Source extraction, mathematical
continuous enclosure, runtime numerical enclosure, setting permissions and real
world contact are separate evidence obligations. Existing sampled captures cannot
be relabeled as clearance certificates. Exact level spacing and local offsets are
engineering content choices authorized by the approved levels-and-connections plan;
new grip/load permissions or economic recipes are not implied by geometry.

## Verified prerequisite

The independent root review accepted the two source hashes recorded under
`godot/data/underground/evidence/resident-identity-v1/`. The clean CI-style focused
Residents suite reports 98 tests, 2,019 assertions, zero failures, zero unexpected
diagnostics and zero leaks. The analyzer reports zero warnings in two files.
No persistent columns, memory schema or balance rules changed.

## Immutable catalog and actual-owner lookup

`underground_profiles.gd` admits two fixed packed content banks before allocation.
The loader streams the exact bytes it hashes, validates the expected SHA-256,
source census, contiguous box ownership, canonical physical-key ordering and every
descriptor before swapping banks. A failed replacement preserves the live content.
Content revisions increase; a selection from an older revision cannot read boxes.
The module has no fallback content and does not infer a physical permission from a
cast name, sampled pose, unqualified certificate or caller-supplied species.

Lookup reads full actual Resident and Job identities, the actual Transform pose,
Work/Gear tool ownership and claim, and HaulCarry/Inventory cargo lot, recipe and
quantity. Exact borrowed-owner binding is rechecked after collaborator rebinding.
Empty tool hints cannot conceal an actually equipped tool. Absent life-stage rigs,
unsupported posture, connector family, quantity or yaw refuse while leaving caller
outputs unchanged. A successful geometric lookup does not grant movement or work:
the owning contact/route provider must still prove current support, route, contact
and eligibility. All-yaw envelopes require an explicit content certificate; exact
yaw is never rounded to a cardinal. Work-contact profiles require exact yaw.

`Selection` and `Box` are caller-owned scratch. Box roles distinguish occupied
body/held/load, stance/support, turn/recovery, work approach, productive stroke and
one exact contact point. Boxes already contain the selected orientation. Consumers
translate them with checked integer arithmetic and must not rotate them again.
This preserves below-root body extent; the contact provider must not clip geometry
at the floor to manufacture clearance.

The content boundary trusts an externally approved digest and certificate flags;
it is not a proof verifier for arbitrary user files. Actual World/save composition
must pin the complete authored digest and revision. That owning save field is not
added by this prerequisite and composed production activation is not claimed.

## Finite storage and query work

One bank uses 18 I32, three I64 and two byte fields per descriptor, seven I32 fields
per box, 32 bytes per source bundle and a four-I64 header. Two banks at the admitted
maxima (256 descriptors, 3,072 boxes, 64 source bundles) use exactly 226,368 packed
bytes. A separate 32,768-byte control/native/stream reservation includes 52 packed
scratch bytes, both Bank objects, borrowed references, reusable output/math objects,
bounded streamed rows and digest state. The total is 259,136 bytes under the
262,144-byte arena, leaving 3,008 bytes unallocated. The native reservation is not a
measured allocator result. No third full image or full JSON image is loaded.

Each selection has at most 12 boxes. Lookup uses a binary search followed by at
most 16 exact-key variants using a bounded while loop; it does not scan every box
for every resident. Replacement admission is cold and may compare descriptor pairs
to reject ambiguous ranges and orientation/family overlaps.

## Catalog verification and scope

Independent geometry review accepted the immutable catalog and actual-owner lookup
scope. Its two low follow-ups added a successful actual assigned BUILD Job with a
real Work/Gear claim (followed by stale tool-claim and Job-assignment refusals), and
removed a per-query `range` allocation. Final evidence is under
`godot/data/underground/evidence/catalog-v4/`:

```text
13 test(s), 245 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

The wrapper moves assets aside, deletes `godot/.godot`, imports with the exact
headless editor command, and invokes unchanged `tools/run_tests.sh` through the
existing CI suite-selection runner. The first rejected attempt supplied a non-JSON
selector and ran zero tests; v2 passed tests but had six analyzer warnings. Those
logs remain alongside corrected v3/v4 evidence. Exit status alone is not used as
evidence. All profile certificates and dimensions in the tests are explicitly
synthetic fixtures; none qualifies a production body or connector.

The continuous native-source exporter, numerical/presentation enclosure, authored
profile/stance/contact content and five-family engineering pack remain active work.
This record does not mark UG08, production profiles or those families complete.

## Underground presentation representation

The initial actual native source inspection covers seven case variants, 1,920
animation tracks and 113,826 mesh vertices. Godot 4.7.2 mixes rotations as a product
of rest-relative quaternion powers, not a direct convex quaternion blend. Its live
tail also includes a spring and a final ground constraint. Source-math enclosures
of unrestricted clip products and tail rotations remain too broad to choose useful
connector dimensions. They are retained as unqualified diagnostics, not production
clearance and not a reason to widen tunnels. Exact native tail-scale premisses are
also checked rather than treating near-unit imported scales as exactly one.

For the bounded underground presentation adapter, use the global-matrix blending
representation already adopted in crowd architecture sections 2.4–2.5. Bake the
actual final poses of each exact source body, skin, clip and modifier configuration.
Between baked frames and during transitions, linearly blend those global skin
matrices. This is a deliberately specified renderer: its source poses are finite
content, not samples claimed to bound a different live quaternion/spring continuum.
Matrix blending can shrink joints under large rotations, so close-view error and
visible animation quality are acceptance gates before activation.

The adapter retains the original mesh, bind-index mapping, weights and materials.
For vertex `p`, bind `b`, source pose `f` and inverse bind `I[b]`, its native skin
matrix is `S[f,b] = G[f,b] * I[b]`; its local position remains
`sum_b weight[b] * S[f,b] * p`. An owned RenderingServer skeleton RID receives the
linearly blended final matrices directly. The implementation must not decompose
them through a Skeleton3D quaternion path or introduce a substitute shader. Rigid
tools use the same global hand socket and authored fitting transform. Held goods
use the actual hand-midpoint/forward-offset equation. The dynamic log basis needs
its own baked final matrix rather than a new unproved nonlinear interpolation.

`godot/demo/cast/underground_actor.gd` and its tests own only this presentation
adapter. `tools/bake_underground_matrices.gd` records the real final matrices and
attachments using the existing source-pinned capture harness; evidence lives under
`godot/data/underground/evidence/matrix-presentation/`. No source state silently
inherits another species, life-stage, rig, equipment or cargo qualification. The
actual renderer/palette digest must equal the profile's content binding during
underground work/travel. Surface Actor behavior remains a regression requirement.

Qualification still requires exact interpolation coverage, all attachment envelopes,
an outward arithmetic residual, actual backend/palette update and RID cleanup tests,
and native close-view comparison of the real cast and transitions. No gameplay
capability, grip/load permission, speed or economy recipe changes follow from this
presentation choice. The standard-level and local-offset pack will be authored
against the completed envelopes, relative to the immutable World datum at Y=512u.

The new underground content and its endpoint headings use the GDD's 65,536 yaw
units per turn and −Z forward convention explicitly: yaw 0 faces −Z, 16,384
faces −X, 32,768 faces +Z and 49,152 faces +X. Positive yaw is a right-hand
rotation around +Y, matching Godot's native positive-Y basis. The existing demo
cast faces +Z in local space, so baking multiplies by the exact diagonal basis
`diag(-1, 1, -1)` before storing final matrices; no approximate `sin(PI)` is used.
The new route provider may adopt this engineering convention without changing
the existing surface mover's historical behavior. Deriving a noncardinal heading
must use an integer algorithm with a documented tie rule; physical selection
never rounds an unsupported heading to a cardinal. All-yaw envelopes can cover
the continuous presentation turn, while work contacts keep exact authored yaw.

This heading convention does not settle connector speed. Decision0212's demo
ramp-at-walk-speed and stair-at-500-permille behavior is explicitly labeled
`DEMO VALUES` in `tunnel_rules.gd`; it is evidence of existing presentation, not
a production climbing or load permission. The initial compiled connector pack
must carry an explicit, separately justified pace/duration contract, including
ladder/hatch movement, before the new route provider activates those edges.

## Native matrix adapter component evidence

The new adapter and tests passed independent component review after correcting a
SceneTree lifecycle defect: MeshInstance3D resolves an empty skeleton path on
entry, so configuring outside the tree could detach an already assigned native
skeleton. Configuration now requires the actor to be in the tree before any native
allocation, and the child enters before attachment. Exit releases owned RIDs and
parts; re-entry requires fresh configuration. A native rendered-pixel regression
proves deformation after both entry and re-entry, in addition to matrix readback.
Original mesh and material identities are preserved, including actual instance
material overrides. Unsupported displacement and later material passes refuse.

`matrix-presentation/adapter-component-v1/` records source/log hashes and the
native command. The final assets-aside, fresh-import strict check reports 21 tests,
2,713 assertions, zero failures, all diagnostic/leak counts zero; the analyzer
reports zero warnings in two files. Native execution reports 117 assertions with
zero failures and the expected displaced pixels on both lifecycle cycles.
This verifies the bounded presentation component only. Source extraction,
continuous bounds, shared presentation-palette admission, original-cast visual
quality and the production profile binding remain separate content gates.

## Catalog broadphase extent reader

The allocation-free `body_extent_into(content_revision, out_six_ints)` performs
a bounded cold scan over all admitted body/held-load and turn/recovery boxes.
Routes can size a conservative spatial search before indexing actors, even when
an actor later changes to a larger already-authored tool/load variant. It is not
a selected movement or work profile; candidates still require actual identity
queries. Stance/support-only boxes do not inflate collision search. Replacement
invalidates the old extent by exact content revision. Every refusal preserves
output; no persistent columns or additional profile image are added.

Independent review accepted the reader and replacement/refusal tests. Evidence
`catalog-extent-v1/` records the exact source hashes, clean import, 15 tests,
279 assertions, zero failures, zero unexpected diagnostics/leaks and analyzer
zero warnings in two files. Fixture bounds remain explicitly synthetic.

## Cold authored contact inspection

Static excavation admission precedes the Construction/Job that would assign an
actual worker. `profile_count(content_revision)` and
`descriptor_into(profile_id, content_revision, caller_descriptor)` therefore
expose the immutable authored physical key and constraints without fabricating a
Job. The returned exact profile/content revisions pair with `box_into` for the
body, stance, approach, stroke and contact roles. This cold descriptor is a
different type from the actual-worker Selection; it has no worker, Job or lot
reference and provides no permission to perform work. START/WORK still use the
actual owner-bound query and fresh route/support/contact checks.

The descriptor consists of 23 caller-owned GDScript integer fields (184 logical
scalar bytes), charged by its consuming cold owner. No module columns, scratch
image or persistent field were added. Every refusal precedes all output writes;
catalog replacement invalidates a prior descriptor by exact content revision.
Independent root review accepted the frozen source. `catalog-descriptor-v2/`
records 17 tests, 348 assertions, zero failures, zero unexpected diagnostics/leaks
and analyzer zero warnings in two files. The first source-identical import
crashed in native font import before any test ran; its raw log remains in
`catalog-descriptor-v1/`. The import qualification is superseded below.


## Corrected focused-check asset isolation

The earlier focused wrapper moved assets beside their original directory inside
`godot/demo/`. Godot still scanned that directory, so the import was not the
required assets-absent CI import and rewrote generated source/remap paths. This
invalidates that import-condition claim; the original logs and source hashes
remain available. The wrapper now moves assets to the worktree root's
`.profile-clean-assets-aside`, outside the Godot project, refuses an existing
saved directory, deletes the project cache and restores the assets in `finally`.

Independent root review accepted this narrow correction and source-identical
`catalog-descriptor-v3/` evidence: exact clean import completed, followed by
**17 tests / 348 assertions / 0 failures**. The strict diagnostic line reports
**0 unexpected errors, 0 unexpected warnings, 0 expected, 0 tolerated;
0 leaked objects and 0 leaked resources**; the raw-log footer also reports zero
unexpected diagnostics/leaks. Analyzer: **0 GDScript warning(s) in 0 of 2 file(s)**.
This supersedes the earlier descriptor import-condition claim without changing
the accepted Profiles source or claiming production clearance qualification.


## Finite engineering level catalog

`underground_level_catalog.gd` is the sole authored level-height source for the
initial estuary pack. Its exact root-approved Domain is datum `(0,512,0)`, minimum
quantum `(0,-32,0)`, size `(256,48,256)` at 1024 units/metre; the vertical range is
`[-32256,16896)`. The initial clear room shell is 4096u high, base floors are 5120u
apart, and the 1024u band above each roof remains a local structural obligation.
The choice fits the measured upright cast and current work envelopes while
retaining separation; it does not qualify every posture, load or connector. The
parent accepted these as engineering dimensions within approved D06/D07, pending
complete continuous physical/profile/contact and fixed-family evidence.

The number of levels is derived from the actual depth and complete 1024u footing,
not an old four-level demo assumption. Levels 1..6 have base floorY values
`-4608,-9728,-14848,-19968,-25088,-30208`. Surface ID0 is the actual 512u datum,
with no invented roof or completed floor. The optional section offsets are
`-1024,0,+1024u`; the roof stays fixed while headroom and footing change. The
fixed short-rise menu is 1024/2048u. A listed rise only identifies an exact height
match; the five-family catalog must still supply a complete fixed piece with
valid openings, landings, support, motion and contact. There is no stretch-to-fit.

Each lookup returns an exact world/content identity and floor/roof plus local
protected and required-footing Y intervals. The consuming room owner intersects
these with its actual XZ footprint and validates actual terrain/support facts.
No whole-map support layer, lower-level void, route, free excavation or completed
structure is published by this metadata. Sunken floors that interfere with a
lower room's protected band must be refused by the actual spatial owner, even
when both catalog heights individually fit. An intentional connector opening
must deliberately edit its exact local band and clear all affected room/item
obstacles. The first room also needs an actual reachable surface/access contact.

The tiny reviewable integer JSON source compiles to a 108-byte immutable image.
The runtime loader checks a bounded exact-length wire image and SHA256 over the
same decoded bytes; no JSON float affects authority. It binds the full actual
Directory/World generation, Domain shape, capacities and RoomSpace version.
A refused load/bind leaves no usable content/binding; stale generations and
out-of-domain full footing refuse without changing caller output. Local arithmetic
uses int64 and validates resulting int32 ranges before publication.

At the source maxima, retained arrays use 236 bytes plus one 8-byte revision.
The separate 2048-byte control/loading/native allowance includes the decode peak:
wire 156 + staged config/offset/rise 120 + digest 32 + published immutable content 152
=460 packed bytes simultaneously before temporary release (plus the8-byte
revision), with small header/footer slices, descriptor/identity arrays, hash/file
objects, strings and other transient controls charged inside that allowance.
This is a bounded reservation, not a measured native allocation. The level
catalog's 2292 bytes plus Profiles' 259136 reserve total 261428, leaving 716 inside
the unchanged 262144 arena. The caller's Record is 89 logical bytes and is charged
by its consuming owner, never allocated once per level or resident.

Independent root review accepted the exact source, tests, compiler and storage
arithmetic. `levels-v1/` records exact assets-outside-project clean import,
**10 tests / 179 assertions / 0 failures**, zero strict/raw unexpected diagnostics
and leaks, and **0 GDScript warning(s) in 0 of 2 file(s)**. Six Python compiler
checks also passed. This verifies the metadata component; continuous profiles,
contacts, all five connector families and gameplay/save integration remain open.


## Common finite grounding transform

The finite underground renderer needs one actual floor root rather than preserving
a source clip that dips through that floor. Baking therefore records one binary32
Y offset per frame from the actual deformed body minimum. Body skin matrices and
attachment/socket matrices remain otherwise unchanged. The offset is applied as
a common instance translation after skinning, not once inside each bone matrix:
source weights need not sum exactly to one, so bone-wise translation would give
different vertices different shifts. Every held item receives the identical
common translation. No source weight is normalized, no limb is rescaled, and the
existing surface Actor remains untouched.

The Y sequence uses exactly the same positive fixed time/transition weights as
the final matrices. Thus each complete output vertex is still a convex combination
of complete grounded endpoints before bounded native arithmetic error. The finite
source format versions this additional sequence; original ungrounded records and
failed proof attempts remain evidence. A numerical residual and visual/native
checks are still required; a sampled minimum is not asserted to bound another
animation system. The additional frame scalars count within the existing finite
palette ceiling, with no increase to that ceiling. Physical contacts will retain
the complete resulting bounds, including any certified below-root residual.

The renderer's culling AABBs use the MeshInstance's coordinates before its instance
transform. A skinned part needs the pre-common-translation palette envelope; a
static item needs its original mesh-local envelope before its complete item
matrix. The final grounded actor-space physical envelope must not be supplied as
either culling AABB: the renderer would translate it again. Current generous
synthetic native culling boxes establish deformation and lifecycle behavior,
not tight production culling. Production binding must supply these distinct,
source-derived bounds.

Independent construction-lane review accepted the exact Actor/test/native-probe
source delta. `matrix-presentation/grounding-v1/` preserves the clean-import
**14 tests / 113 assertions / 0 failures**, every strict/raw diagnostic and leak
count zero, and corrected analyzer **0 warnings in 0 of 7 files**. The native
probe renders a synthetic body with non-unit weights and a static attachment:
both shift exactly 32 pixels under the same common translation, **8 assertions /
0 failures**. The separate existing native lifecycle harness reports **140 total
assertions / 0 failures** including tree exit/re-entry. A rejected analyzer CLI
invocation and Python module-path invocation are retained beside their corrected
results. None of these synthetic checks grants a production profile, movement
permission or complete source-enclosure certificate.

## Fixed connector content and pace owner

`underground_connector_catalog.gd` owns immutable streamed connector content in
the existing524288-byte bindings reservation, separate from Profiles/LevelCatalog.
Root approved190448 bytes: two86008-byte packed banks,2048 bytes for bounded row
decoding, fixed controls and one set of caller query packets, plus16384 bytes of
explicitly unmeasured native/loading reservation. The root's159744-byte certificate
banks and4096-byte controls plus this catalog leave170000 bytes in the unchanged
bindings ceiling, before other owners' separately reconciled reservations.
There is no third bank or whole JSON/wire image. Complete render compilation
needs its own shared cold lease; this catalog returns scalar records and fixed
caller-owned point/box scratch.

Each bank admits16 variants,512 four-integer path points,1024 eight-integer
role/relative-level boxes,256 nine-integer parts,2048 three-integer part vertices,
16 material periods and256 pace rows. Variants have26 int32 fields plus an int64
revision; pace rows have7 int32 fields plus an int64 profile revision. Eleven
int64 headers and three32-byte digests finish the86008-byte bank. Source content
explicitly names fixed endpoints/yaws, level offsets, whole physical/opening/
landing/support volumes, primitive parts, material metre periods and path
vertices. No run/rise/width stretching or automatic paid-cut rounding occurs.
The exact opening count is stored in the existing26-field variant record and
checked against OPENING region rows, with a finite16-target maximum per variant.
Opening rows are observed in catalog order. The catalog owns no actual target
Room refs: placement must pin those full refs/revisions, its exact installed
source/Room identity, catalog identity, integer origin and rotation, and the real
paid publication. ENVELOPE includes the complete reservation and physical SOLID
parts; it is not required to be empty. Completed clear space plus matching actual
built solids/support must cover it, while actual body/stance/contact proof still
checks collision separately. Arbitrary coincident support or another object's
obstacle can never substitute the installed connector's own physical source.

Ground pace uses family=-1 and variant=0 only. Each pace row pins the immutable
physical profile id/revision/content/source, this connector content revision,
and actual Movement species/stage/profile revision. Ground rows delegate to the
actual inherited Movement cap. Other families require an explicit authored
positive integer rate; no ground or demo rate fills a missing family entry.
Catalog pace is geometry/timing content, not species, grip, load, work or route
permission. Missing current badger Movement profiles refuse rather than borrowing
another large species. The narrowly additive `Movement.is_bound_owners` reader
checks exact Directory, Residents and Transforms instances; it changes no motion
state, profile, speed or policy. All numerical production rows still require
their actual source/proof/native quality evidence before activation.

`connector-catalog-v1/` records the clean-import component run:96 tests,
3092 assertions,0 failures; both strict/raw diagnostic and leak counts zero;
analyzer0 warnings in0 of4 files. The catalog's14 tests use clearly synthetic
wire fixtures and actual identity/pace owners. Bounded metadata/primitive readers
do not replace full connector compilation, continuous body/work/gear evidence,
actual installation, production visual review or movement authorization. No
production row is shipped by this prerequisite. Independent root review accepted
the four exact source/test files in this scoped contract, requesting one hot-path
array literal be replaced by direct integer comparisons. That narrow cleanup
changed no query behavior. The final `connector-catalog-v2/` clean run reports
14 tests/263 assertions/0 failures, every strict/raw diagnostic and leak count0,
and analyzer0 warnings in0 of2 files. Final source hashes are recorded alongside
the raw logs; v1 remains the prior broader regression evidence rather than a
claim that its earlier source hashes describe the final cleanup.

## Accepted local finite presentation enclosure

The local matrix baker/exporter now encloses42 actual source cases,3566 finite
frames and164 original body/attachment parts. Its complete stream is consumed
with a footer and source digest, and529 original/imported/source pins are
rechecked. Positive fixed-weight interpolation has a convex endpoint hull;
outward Q24 operations and explicit rational CPU, native float32, UNORM16 and
compressed-attribute residuals enclose that chosen representation on the pinned
official4.7.2 desktop OpenGL path. The previous unrestricted live-animation
estimates remain diagnostic history, not alternative production certificates.

Independent construction-lane review found no high/medium blocker in this
bounded local proof. Its low material follow-up now rejects every unrecorded
attachment per-surface override before export; explicitly captured safe global
overrides remain supported. Final `native-v8/` and `proof-v4/` retain the new
source pins, unchanged geometry, native skin checks and comparison images.
Clean focused validation is15 tests/120 assertions/0 failures, all strict/raw
diagnostics and leaks0. Native adapter/lifecycle validation reports147 assertions
with0 failures and native grounding8 assertions with0 failures. This is still
zero qualified production profiles: exact renderer/source binding, world-root
arithmetic, actual state unions, contact permissions and animated quality remain
separate gates. Native heading behavior cannot borrow the ideal all-yaw rotation
bound in this local diagnostic report.

## Finite world-heading source and productive tool roles

The next numerical increment uses a complete native table for the65536 possible
16-bit Y headings. Each entry contains the exact two binary32 coefficients that
reconstruct the native pure-Y basis. The baker checks the other seven components
and matrix symmetries for every entry. The eventual underground Actor selects
that exact finite entry rather than introducing an unbounded trigonometric
operation into the physical representation. A presentation heading can still
smooth toward the actual heading at the existing turn rate; quantizing the
display index to1/65536 turn does not alter authoritative yaw, routes or progress.
Source metadata pins the actual Godot build/backend and the complete baker and
consumer. Native renderer acceptance and source hash binding remain required.

The65536×2×4=524288-byte table is shared presentation content, not simulation
storage. Its planned streaming load needs one retained524288-byte image, a
4096-byte bounded metadata/row/control budget and a16384-byte explicit unmeasured
native allowance:544768 bytes. It is immutable once admitted, with no replacement
bank or per-resident copy. A failed initial load releases the partial candidate;
full-process/native measurement and the actual loading implementation must
verify this reservation before qualification. Nothing borrows from the existing
simulation profile or bindings arenas.

World placement will use the real finite Domain descriptor and an explicit
top-level transform. Within the initial actual bounds, integer1/1024m root
coordinates convert exactly to binary32. The proof must still cover matrix
composition, skin/static attachment arithmetic and outward translation of the
whole body/held/load extent; it must refuse a foreign or oversized domain rather
than silently expanding it. All65536 basis entries are finite source data, so
their exact maximum norm can be proved without treating a few sampled headings
as a continuous trigonometric certificate. This increment does not add pitch,
scale or an arbitrary parent transform; slope/posture remains in its explicitly
baked content. Both close native views and actual rendered backend behavior
remain separate acceptance evidence. No world certificate is yet published.

For productive work, the owning source must identify the exact active tool.
Travel and turn profiles retain all actual held gear and cargo. A WORK profile
may exclude solely that identified active tool from BODY_HELD_LOAD when its
complete physical geometry is separately enclosed by WORK_STROKE. The resident,
nonproductive equipment and cargo cannot disappear into that exception.
Only the exact active-tool stroke may intersect the exact paid operation target;
other walls, floors, items and protected structure still block it. Recovery has
an independent clear-space envelope before travel can resume. This is a geometric
representation contract, not a new phase, digging, grip or load permission.
The actual mole-pick source dips133u below the grounded body root: it cannot be
clipped away or excused by generic BUILD identity. A downward target and a wall
target require their own valid source/contact placement. Production qualification
remains absent until these distinctions are bound and proved.
