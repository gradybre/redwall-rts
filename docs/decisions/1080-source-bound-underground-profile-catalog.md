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

The complete native table has now been captured and independently reviewed as
source only:65536 entries,525013 stream bytes, no native diagnostics/leaks;
clean strict6 tests/35 assertions/0 failures, all strict/raw diagnostics/leaks0,
and analyzer0 warnings in0 of2 files. The observed diagnostic maximum squared
norm is1.00000008311477, so its consumer must retain the real finite coefficient
overshoot. `matrix-presentation/world-basis/` records exact source and output
hashes, engine/backend, commands and raw logs. No world clearance is yet claimed.

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

### Exact world-source renderer binding

The next Actor increment will stream the reviewed finite heading format into one
immutable shared presentation array. Complete digest, producer digest, byte count,
footer, finite coefficients and source backend are checked before the table is
observable. An exact actual Domain descriptor and palette/table digests bind the
renderer; this attests presentation source only, never physical permission.
Roots must stay in the bound half-open Domain and its integer bounds must remain
within the exact binary32 integer range before conversion from1024 units/metre.

Each world-bound MeshInstance becomes top-level and receives an explicitly
computed global transform. Body skin palettes remain unchanged. Static held
parts receive the same table coefficients, root and post-skin grounding. Scalar
composition is binary64 followed by explicit binary32 Vector3 storage; arbitrary
parent transforms, scales and rotations are excluded from this representation.
This keeps the renderer equation finite and source auditable while retaining the
original meshes, materials, skin weights, visible gear and blend weights.
Existing local presentation remains unchanged. Bound parts stay hidden until
both root and pose are initialized, and rejected updates preserve the prior
visible state. Native transformed-parent and body/attachment pixel checks are
required alongside unit tests. World enclosure remains unqualified until the
exporter includes these exact operations and the complete source/table hashes.

The exact world-source Actor implementation is independently reviewed. Its final
clean run reports20 tests/213 assertions/0 failures, both strict/raw unexpected
diagnostic and leak totals0, and analyzer0/4. Actual native table/pixel tests
report21 assertions/0; the complete native suite plus tree-entry/re-entry checks
report256 assertions/0, no unexpected diagnostics/leaks and analyzer0/3. The
visible witness keeps body and held-item placement despite extreme parent
transforms, mirrors both through the native half-turn, and moves both32 pixels
for each half-metre root or grounding change. These are synthetic meshes testing
the actual rendering equation, not production pose or contact qualification.

The reader admits at most1,024 text bytes, four JSON containers, two levels and64
member separators before parsing; its4,096-byte decoder/control plus16,384-byte
native reservation remains explicit. Actual observed retained allocator growth
is524,564 bytes, but an earlier larger process peak prevents isolated transient
loading qualification. Added per-Actor numeric state is53 bytes and one shared
source handle; it belongs to future presentation-pool admission, never the
simulation arenas. The exact evidence and rejected import/warning iterations are
in `matrix-presentation/world-basis/ACTOR_BINDING.md`. World enclosure, production
profiles, tight original-frame culling and full presentation budget remain open.

### Source-complete held-pick travel and world-model enclosure

The finite baker now has an explicit `held_tool_binding=set_work_tool` source
variant. It calls the existing DemoActor persistent right-hand tool API through
actual idle, walk and crouch clips for rigs that already have the actual hammer
source. Original raw/imported meshes, hand mapping and fitting remain unchanged.
The accepted live-capture harness is not edited, and no fake DIG state is used
to keep a travel tool visible. The source manifest and binary case record retain
this distinction. Carrying cargo and another tool together is not inferred;
unsupported combinations still need their actual source and grip contract.
This closes a measurable geometry gap without granting a new species, stage,
work, load or movement permission.

The next exporter consumes the whole native heading stream, computes its maximum
squared norm with exact fractions, and carries the real norm overshoot into the
all-heading envelope. Explicit binary64 composition, binary32 stores and native
pre-view model arithmetic add source- and Domain-derived outward residuals.
No arbitrary safety margin or sampled heading substitutes for that proof. The
renderer binds the full actual Domain descriptor; the mathematical output is
parameterized by its finite coordinate bounds and still requires whole-body
translated admission by the actual spatial owner. View/projection/rasterization
error is not physical deformation and is not covered by this world-model claim.
Independent root review accepted this exact numerical/source increment. The
54-case report covers 4,158 finite frames and 188 parts, verifies 530 source
pins, and computes the exact native maximum norm squared as
281475000105385/281474976710656. The clean suite reports 21 tests, 225 assertions,
zero failures and zero unexpected diagnostics/leaks; the analyzer reports zero
warnings in five files. Python records 58 envelope and 12 reproducer tests, all
passing. `world-basis/world-proof-v1/` pins the complete evidence. Production
profile, state-union, productive-contact and animated quality gates remain
separate; this is zero production qualifications.

### Compact actual mole-worker content

The next component compiles the exact reviewed finite mole body and held pick
into an immutable presentation image, and a loader gives that same image to
the accepted Actor. Original meshes/materials remain borrowed from the actual
asset owner; body vertices, all skin influences, compression metadata and bind
counts must match their source fingerprint before an Actor is configured.
The compiler verifies complete required source-state lists and emits conservative
role unions; it does not set production certificate flags or infer missing
grips, cargo, life stages or climbing clips. Genuine active-tool geometry remains
in its work-stroke union, including its below-root extent.

The initial technical limits are eight parts, sixteen source clips, 2,048 frames,
and 1,048,576 combined matrix/grounding float32 scalars. Decode staging and the
Palette's immutable copy overlap once. A bounded mesh-fingerprint pass admits
at most 32,768 vertices and six indices per vertex in one surface before asking
the engine for its arrays. Its explicit 256-byte/vertex logical allowance covers
the original vertex/normal/tangent/color/UV/custom/skin/index packed fields.
The peak is retained palette bytes plus the larger of decode staging or one
mesh-array allowance, plus packed part/clip/hash tables and a 2 MiB reserved
reader/native-control allowance. The latter is not a native allocator measurement.
The shared WorldBasis is charged separately once. Original borrowed mesh/texture
storage, actor instance RIDs and the complete client/presentation pool remain
separate qualification obligations; the simulation memory ledger is not reused.

Root's independent visual inspection found an open source-quality issue in the
held-pick walk witness: the shaft appears behind the forearm and stops above the
hanging paw. Native matrix fidelity does not settle animated grip quality. The
compact loader's actual idle, walk and hammer sequence must be inspected from
close views; any corrected fit must explicitly regenerate its source matrices,
state unions and world envelopes. Existing source-faithful output remains
evidence of its previous fit, not a qualified final handling animation.

The compact compiler/loader component is independently accepted, with its exact
pins and scope in `mole-worker/evidence/frozen-v1/`. Clean validation reports
29 tests/334 assertions/0 failures, all strict/raw diagnostics and leaks zero,
and analyzer0/2. Eleven compiler tests pass. The actual native loader renders
all seven states and positive blends:731 poses/1,575 assertions/0 failures and
analyzer0/1. The final 426,888-byte source image retains426,216 palette bytes;
its explicit presentation admission is6,920,048 bytes plus one shared WorldBasis.
The observed428,476-byte live allocation increase does not establish a loading
peak or complete client budget. A separate reviewed wrapper fix and four mocked
regressions ensure zero exit cannot hide final-command diagnostics. The original
open-paw grip remains rejected visual quality; no production Profiles flags or
new worker capability are created by this accepted content owner.

### Authored mole hand grip correction

Root's independent inspection accepts the firmer hand variant in
`mole-worker/evidence/grip-closed-v4/idle-030.png`, `walk-018.png` and
`heavy_hammer_swing-042.png`, plus `grip-angles-v1/left-side/walk-018.png`,
left-side and rear `heavy_hammer_swing-012.png`, `-030.png` and `-048.png`.
The shaft visibly passes through the gathered palm with a projecting butt;
these sampled views show no obvious wrist/forearm penetration. This is visual
approval of this grip change only, not exact intersection, physical contact,
full asset polish, gameplay camera or first-playable evidence.

The explicit additive ownership is
`godot/data/underground/mole-worker/mole_grip_source.gd` and
`godot/test/test_mole_grip_source.gd` plus its UID. The source recipe and original
fingerprint are recorded in `mole-worker/evidence/grip-authoring/README.md`.
The helper must keep original geometry and material resources immutable,
refuse another body/hand-bind/source-fit identity, and emit a separately pinned
fixed derivative. Only the actual right-hand distal geometry changes; skin,
rig, costume, scale and gameplay capabilities remain the original source.
Future native bakes and the renderer must consume that same derivative and
corrected socket fit. Old palettes, state unions and envelopes do not certify
the changed representation and must be regenerated before downstream use.

The additional exact baker lease is `tools/bake_mole_grip_content.gd` plus UID.
It subclasses the accepted finite baker without editing it, rejects every
non-mole/non-pick or mismatched derivative request, applies the source-pinned
mesh before body caching, and supplies the same corrected fit before attachment
capture. The seven selected actual mole states are rebaked under new case IDs;
the other 47 source cases retain their prior evidence. The new create-only
reproducer closes the imported Python palette helper as well as the GDScript
helper/renderer dependency graph, and preserves rejected/superseded evidence.

The helper's clean component checks report 36 tests/384 assertions/0 failures,
zero unexpected strict/raw diagnostics and leaks, and analyzer0/2. The new
baker's analyzer is0/1. Seven actual source cases produce354 frames and8,496
exact native skin-matrix checks with zero diagnostics/leaks. The final local
and finite-World envelope proof is regenerated from the new5,906,853-byte raw
source, with complete source/input hashes and0 production-qualified profiles.
The compact derivative image is426,888 bytes, retaining the existing6,920,048
byte content-reader presentation admission plus one separate shared WorldBasis.
That reader figure does not include new derivative mesh creation or the complete
client/presentation pool; those remain explicit separate native peak obligations.

Independent root review accepts this exact helper, test, narrow baker and
reproduction/native packet. The final runner correction pins sources before
engine execution and compares them afterward, refusing changes or deletion and
rejecting a dangling output link before resolution. Seven mocked regressions
pass. The fresh `grip-native-v2` records 731 poses, 1,578 assertions and zero
failures; all raw diagnostics/leaks are zero, analyzer is 0/2, and the pre/post
source pins match. V1 and its executed runner remain historical evidence.
`mole-worker/evidence/grip-final-v1/` records the accepted source and artifact
identities, exact reproduction commands, reviewed views and unqualified gates.
The compact image alone still provides zero production profile qualifications.

### Planar contact witness metadata

The additive source schema has `CONTACT_PATCH=6` and
`CONTACT_ANCHOR_AND_PATCH=2`. The existing seven-int box row stores a closed
planar source witness: exactly one zero normal axis and two positive spans.
Kind2 WORK requires exactly one patch and one coplanar contained CONTACT_POINT.
The point is an integer authored focus; the patch conservatively bounds where
the actual proven source tip crosses that face. Neither is occupied body volume.
Actual WorkFace must require kind2 and keep the whole translated patch inside
the selected target face, independently of the complete tool/body clearance.
Legacy kind1 anchor-only fixtures remain readable and grant no new production
contact qualification. Unknown/missing/duplicate/malformed patches refuse.

No wire width, retained column, bank, capacity or persistent control changes.
The bounded cold validation adds fewer than128 logical bytes of nested scalar
locals; it remains within the existing32768-byte control reservation, which is
reserved rather than a measured native peak. All public readers preserve their
full identity and refused-output contracts. Current Routes/WorldRoutes collision,
stance, endpoint and motion consumers explicitly select physical roles and
already skip contact metadata; WorkFace is the new planar consumer.

Independent root review accepts source c0064e3ce55fdaa8df33ce4d0b7f54a37fc49ff938f70461ea40f58ef90ef8c2
and test395f40c9b94a2f4b8c03e2edaf2a625a934a2b2824986c6721f40bf603aec37e.
Clean assets-aside import and strict focused checks report21 tests,454 assertions,
zero failures, all strict/raw unexpected diagnostics and leaks zero; the analyzer
reports zero warnings in two files. Raw evidence lives in
`mole-worker/evidence/contact-qualification/profile-schema-v1/`. These are
component/schema checks, not production source contact or motion qualification.

### Source-bound productive mole motion and contact qualification

The next owned increment is `mole-worker/compile_profiles.py`, its Python test,
`mole_profile_driver.gd`, `qualified-v1/`, and
`evidence/contact-qualification/`, with the new Godot tests
`test_mole_profile_driver.gd` and `test_mole_qualified_profiles.gd`.
The accepted firm-grip source remains immutable. The imported full hammer cycle
has genuine pick geometry below the floor, including a late sweep beside a
planted foot; that source cannot be declared safe by trimming its box. A useful
source-indexed forward strike and exact retrace may instead be authored from
its finite matrices, preserving the original cycle and recording every chosen
source frame. The candidate must pass native animated review before promotion.

The proof partitions actual triangle primitives, not merely vertices, whenever
the floor-contact portion of a body is separated from its upper volume. The
new bounded `evidence/contact-qualification/capture_topology.gd` captures native
primitive/index data after the same accepted Grip and Content geometry identity
checks. Its source hashes and complete output hash are required inputs to the
offline proof. This closes a missing primitive-topology input in the older raw
palette stream; it grants no new movement permission or simulation state.

Travel and turn keep every attached tool in BODY_HELD_LOAD. Productive WORK may
exclude only the exact Gear-bound active pick from BODY_HELD_LOAD, because that
same complete pick geometry is separately enclosed by WORK_STROKE. Body,
non-active equipment, approach and safe recovery remain outside the operation's
solid target. STANCE_SUPPORT is separately derived and only excuses the exact
authored floor-contact intersection; a whole body rectangle is not a substitute
for feet/support evidence. A real source tip/face witness must establish the
CONTACT_POINT, and the spatial owner still proves actual support, completed
approach, the paid target and all other physical obstruction checks.

The renderer state driver must bind the exact compact source and profile digest,
actual adult mole/rig/tool manufacture, supported state and positive finite
interpolation. Missing identity, state, tool, cargo or source refuses. Static
descriptor reads remain available before a Job exists, while productive runtime
selection requires actual assigned Work and Gear. Numerical/native proof,
authored source motion, source-manufacture binding, primitive contact proof,
state transitions and presentation/cold coexistence are all separate closure
gates. No production certificate is written until every required gate passes;
component tests and compact images alone remain zero qualifications.

The first source-indexed0–17–0 candidate is rejected: native review shows a
backward tap while the mole looks away from its target. The late original full
cycle drives the handle butt below the floor rather than the head. The next
explicit authored candidate reverses the pick about the actual source fit's
shaft-grip pivot only during productive motion, then uses the overhead source
segment and exact retrace. Body, hand geometry, carry/idle orientation and
original source remain unchanged. The pivot is captured from actual Props fit
and drawn bounds, never inferred from a rounded screenshot. Entry, exit and
contact require their own native and continuous proof; this is an authored
presentation choice, not a new item or work capability.

Native local-joint entry closes the rejected detached-limb transition. Exact
continuous head-triangle separation also resolves the apparent brow crossing
in projection. A broader check nevertheless finds real shaft/wrist penetration
in the original imported carrying pose, outside the authored grasp. Changing
only the shaft angle trades this intersection for a floor strike and is rejected.
The next explicit source correction borrows the actual local right arm,
forearm and hand pose from the existing forward-work source while retaining
each travel clip's torso, legs and other arm. Its reversed pick remains fixed
to the same palm grip. This authors finite pose matrices, not new mesh geometry,
reach or item permission. All resulting intervals, transitions, source identities
and native views must be regenerated and reviewed; the original and rejected
angle-only candidates remain evidence. The current downward source still does
not qualify the Kitchen's roof-adjacent course. That needs a distinct actual
front/high-wall source and planar contact witness from a real supported station.

The resulting raised ready carry uses actual right-arm source frame48, without
changing the other arm, torso, legs, mesh, weights, scale or materials. Native
side/front/RTS witnesses provisionally accept its grasp. A full source-local
self-contact proof retains9,761 body and1,150 pick triangles and omits only448
triangles wholly inside the intentionally authored palm-grip patch. The complete
meshes still contribute to physical world envelopes. A genuine stone-head
vertex crosses the downward face; its complete conservative face patch is
`[-190,0,-678 ..49,0,-536]u`, with integer focus `(42,0,-673)` rounded from the
exact ideal trajectory. The patch, not that rounded focus alone, owns uncertainty.

Independent review rejected the first interval proof because the real Content
loader closes linear loops penultimate→first rather than penultimate→stored-last.
`review-motion-v2/` preserves that rejection and corrects decoder timing, exact
rendered-edge enumeration and proof reuse. All386 rendered intervals now pass
the same bounded primitive proof; the adversarial separating-plane regression
would fail the old edge set. The native retry reports2,335 poses/5,349 assertions
and the tip witness9/61, all with zero failures, raw diagnostics or leaks and no
source drift. Forty-seven Python tests pass; the analyzer inspects four files
with zero warnings. This is exact-yaw0 component evidence, not an all-yaw or
arbitrary cross-clip guarantee. Source arrays and animation timing are unchanged
by the loop correction; its derivative hash refreshes proof provenance only.

Independent root re-review accepts that corrected motion component and the
unchanged historical motion-capture helper. The reviewed source manifests and
all rejected evidence remain in `review-motion-v2/` and its preceding packet.
Acceptance is explicitly bounded to source-local/yaw0 and native interval/census
correctness, with no remaining high/medium review finding in that slice.

The distinct high-wall candidate retains actual source frames30–43–30 and
authors a finite15° right-clavicle retraction during entry to keep the tool below
the proposed upper target course. These are presentation engineering choices;
the lower approach, bench, retreat, complete role union and actual paid frontier
remain separate owner obligations. Neither this candidate nor the downward
component enables a production profile until its remaining source/state,
contact, world and memory gates are closed.

### Exact productive contact selection

One actual adult mole with one BASIC tool and BUILD assignment can have distinct
downward and upper-wall contact sources. Their logical worker/tool keys are the
same; silently selecting the first file row would lose the contact selected by
the actual work-face owner. The bounded immutable catalog therefore permits
overlapping MODE_WORK keys, still within the existing16-variant per-key limit.
All movement modes retain the prior cold ambiguity rejection. Ordinary
`query_into` returns `PROFILE_SELECTION_AMBIGUOUS` if more than one current row
matches, without writing the caller's previous selection.

`query_work_profile_into(worker, job, profile_id, profile_revision, revision,
posture, connector_family, equipped_tool_hint, out)` adds exact current content
and profile identity to the existing real-owner checks. It accepts only a WORK
row, reads the same full Resident/assigned Job/Work/Gear/Inventory/Haul identities,
and matches the actual manufacture, load, posture, yaw and connector family.
Wrong or stale chosen content refuses without falling back to a different row.
Every row still passes the same source digest, certificate, required-state,
role/contact and bounded input validation. No source is qualified by this API.

The change adds no packed columns, retained scalar fields, banks, wire bytes or
capacity. It adds only bounded scalar selection/dispatch locals and call frames,
conservatively covered by256 logical bytes inside the existing32768 control/native
reservation; that reservation remains unmeasured. The exact query performs one
row match, while the ordinary query retains its bounded binary search and at
most16 matches. The geometric source/state driver must bind the same chosen
profile/content identity. Routes owns its corresponding consumer change; its
actual committed actor identity must supply those pins rather than choosing a
new work source at contact time. WorkFace continues to select prospective
geometry from exact static descriptors before a Job exists.

Independent root review accepts the exact selector source/test component at
the hashes preserved in `profile-selection-v1/source-sha256.json`. Its clean
selected strict suite reports25 tests/601 assertions/zero failures, both
diagnostics and raw log counts entirely zero including leaks, and analyzer0
warnings over2 files. That run used the existing CI selector through a temporary
PATH shim with unchanged strict guards; it is not a full no-argument suite.
The evidence records that scope and the future direct singleton-shard invocation
improvement. Actual production source/state and geometry qualification stay open.


### Routes preserve the selected WORK identity

The actual Routes actor owner now exposes `admit_work_actor` and
`refresh_work_actor` with explicit current profile ID, profile revision and
content revision. Both wrappers run the existing complete admission/refresh
proof twice around collaborator observations, using the exact Profiles selector.
Ordinary ambiguous WORK admission still refuses. Committed contact, current
actor and occupancy checks requery that same selected profile; they never choose
a different face source from an ordinary WORK lookup. Travel edges already
reject MODE_WORK and retain their existing selection path.

This adds no retained fields, banks, wire bytes or capacities. Three invocation
integers (24 logical bytes) reuse the existing fixed control allowance; the
selected profile identity was already retained by every actor. Actual owner
fixtures with two qualified synthetic WORK rows cover selection, refresh,
contact and occupancy, stale pins, released tool claims, lost real assignments,
pose changes and callback reentry. These fixtures do not qualify production
source motion or first entry.

Independent furnishing review accepted Routes source
`4e202c64c991bdfd786ebc3d34daec194832f2d6b452e587d80a0ebe431d6639`
and test
`f9154863371f124ae5a7d90dae3e53c2f4efc30f3217d6081cbacaf2ab3e93b6`.
Strict Routes 49 tests / 9507 assertions and Profiles 25 / 601 passed with all
strict/raw diagnostics and leaks zero. Analyzer reports zero warnings across
the pinned Owner/Routes source/test pairs. Evidence is retained in
`docs/validation/evidence/underground-connector-placements-2026-10-03/work-choice-1/`;
the shared analyzer and four source pins are in the adjacent `scoped-copy-4/`.

### Upper-wall source component

`review-high-wall-v1/` records the distinct30–43–30 upper-wall source, the
15-degree shoulder entry correction, its complete source-local primitive proof
and the actual native tip witness. The contact focus is `(122,1039,-536)u` with
planar source patch `[120,1038,-536 ..123,1041,-536]u`. The fully enclosed entry
portion ahead of the face ends at1017u; the lower approach still must already be
complete. The visible target/bench remains an engineering fixture, not an
installed structure or a constructible first-entry claim.

The native repeat uses exact archived import-cache bytes in this isolated
checkout and a separately recorded current runtime closure. The offline source
proof uses the verifier's existing project-root parameter to reproduce the one
historical Profiles script from its exact accepted commit/hash. Other source
bytes remain fully checked; no live source is replaced and no arbitrary source
drift is allowed. Every finite matrix/timing/grounding value is rederived from
the pinned parent and the authored correction. Source and runtime provenance
are explicit separate records. Complete state/role and actual owner integration
continue after this component's independent review; production qualification
is still zero.

Independent root source/evidence review accepts this bounded upper-wall packet:
all six source and253 output pins matched, seven Python checks pass, and the
native537 poses/1283 assertions plus analyzer0/1 show zero failures or unexpected
diagnostics/leaks. The9 tip points and26+30 finite intervals were checked against
the stated source equations. Visual witnesses cover the selected upper strike
and corrected entry only. Complete state unions, actual support and the first
paid construction frontier remain required; no production flag is emitted.

### Finite presentation driver component

`mole-worker/mole_profile_driver.gd` now owns an integer source clock with ready,
idle, walk, fixed fade, entry, productive, recovery and partial-entry retrace
phases. It reads actual Profiles/Job/Work/Gear/Transforms identities on every
step and preserves its prior output/state on refusal. A work interruption
retains the exact Job, tool, selected profile and spatial observation through
the return motion. A lost claim or displaced worker refuses the update; the
runtime host must explicitly retire the visible Actor before relinquishing an
uncompleted source observation. Readiness never grants productivity or travel.

The source program's fixed profile roles are stand0, ground-walk1, down2 and
high3. Independent review caught that exchanging two otherwise valid WORK
tuples could pair the wrong clip and contact. Binding now rejects any changed
role order before lookup. Source catalogs with another arrangement require an
explicit new program version. The complete eight-clip source/proof compiler
and native state composition remain separate qualification work.

The retained component has360 packed bytes plus168 logical Selection bytes,
16 handle bytes and one boolean. Caller Frame adds28 packed and77 logical
numeric bytes. Its cold nested reader peak includes two184-byte Descriptors
and32 digest bytes, plus18 IntResult bytes;8-byte timing scratch is sequential.
Scalar stack and native object/allocator costs remain unmeasured presentation
costs. No simulation arena or whole-client memory qualification is borrowed.

The construction lane independently accepted the corrected source/test pins.
`contact-qualification/driver-check-v3` records clean import,6 tests/117
assertions/0 failures, strict/raw diagnostics and leaks all0, and analyzer0/2.
Tests use actual identity/equipment owners and deliberately synthetic source
geometry; rejected parser and role-binding evidence remain in v1/v2. No
production profile flag, Work credit or actual construction is created here.

### Exact finite carry-handoff proof accepted

The fixed-ready driver program now has a complete offline intersection proof:
155 emitted fades,7,962,301 exact separating checks and0 unresolved primitive
pairs. It includes every actual idle/walk loop edge, the one ready-to-walk
start fade, and each source interval returning to idle frame8. Common positive
source coefficients permit subtracting one shared body/tool origin; outward
barycentric subdivision preserves the full covered simplex. Exhaustion refuses.
Native error is conservatively mapped back through all65,536 finite WorldBasis
rows without assuming unit norm. No new rig, tool geometry or speed is used.

The 9,761 non-grip body triangles and1,150 complete pick triangles are checked;
448 intentional palm-grip triangles are omitted only from this self-contact
question and remain in physical bounds. The accepted source/test/report pins,
exact NumPy interpreter, full raw log and rejected broad-hull/capacity attempts
are retained in `contact-qualification/review-state-handoffs-v1` and its linked
source evidence. Root independently reviewed the math/source closure and ran
all8 adversarial tests successfully. This qualifies the finite offline source
proof only: native complete-state replay, immutable physical-profile binding,
actual support/target/approach and presentation peak remain open; production
profiles stay0.

### Eight-clip physical-role source compiler accepted

The exact idle, ground-walk, down work/entry/recovery and high work/entry/recovery
are now assembled into one344-frame image after reconstruction from the pinned
original source and exact endpoint/retrace/loop verification. Its four role IDs
match the finite driver. The accepted carry-handoff proof is rechecked against
the full producer closure; a changed source refuses compilation.

Every primitive retains an explicit phase role. BODY covers the productive
body; TURN_RECOVERY covers the whole entry and retrace with the held pick;
WORK_APPROACH covers the ready arrival pose; only the complete productive pick
is separated into WORK_STROKE. Exact whole-triangle partitions at Y0 or the
source contact plane remove empty AABB corners without discarding geometry.
Down11 and high12 rows fit the existing ceiling. Actual WorkFace checks every
complete-space role; ground route proof cannot replace that work-face proof.

Stance is the full foot/toe triangle projection. The measured downward source
also braces its left palm, explicitly restricted to that actual source influence
and contact; it is not called a foot or generalized to another body/tool part.
Down requires759u support depth and high625u. The separately authored planted
variant must close narrower512u tread work; no implicit step or scaffold exists.

Root independently reviewed compiler/test3e223cde/b401b9c0, all13 packet and9
producer pins, and reran all8 adversarial tests successfully. The exact v4
source, outputs and earlier refused/over-conservative versions are retained in
`contact-qualification/review-state-program-v1` and linked folders. Its logical
presentation load reservation is6,908,056 bytes plus shared WorldBasis544,768;
this is not a measured native/whole-client peak and uses no simulation reserve.
Native complete-state quality, production-profile binding, actual terrain/work
contact and the paid frontier remain open. The compiler emits0 qualified flags.

### Complete native state-driver component accepted

The eight-clip compact image now runs through the actual integer presentation
driver, actual Job/Work/Gear/Transforms readers and original-mesh native Actor.
The witness loads the compiler’s physical-role boxes through the real Profile
reader using explicitly synthetic admission flags; it creates no production
profile, support, movement or work permission. Real equipment ownership stays
unchanged throughout entry, productive interruption, recovery and travel fades.

Native evidence records1,536 poses,6,358 assertions and0 failures across all9
phases, with no unexpected diagnostics/leaks or executable-source drift. The
outer exact duration/phase checker passes6 adversarial tests; the new capture
script analyzer is clean. Parent reviewed all108 packet hashes, the553-file
pre/post closure and native three-view images, independently reran the6 tests
and accepted this source/presentation component. PNG existence follows the
native save-success assertions plus retained image hashes; the outer checker
requires only a nonempty image list. Evidence lives in
`contact-qualification/review-native-state-v1` and `native-state-program-v1`.

This remains an isolated1280x720 source witness, not final HUD/multilevel or
terrain gameplay. Native/whole-client presentation peak, real qualification
flags, complete contact support and paid construction remain open. A following
version uses one compact carry hub to support the separately authored planted
front-strike; the accepted v1 data and evidence remain unchanged.

### Planted low/front source component accepted

The compact carry and planted low/front source now keep the actual ready
hips/feet while authoring connected local-rig arm motion and exact recovery.
The full foot/toe support is573u wide by343u deep. Productive BODY remains122u
behind theZ=-768 face; only the active pick enters the synthetic target course,
with a genuine source patch[4,705,-768 ..7,710,-768]u. Complete entry body/tool
stay behind the face. These are actual source-derived bounds, not a relabelled
downward profile or an implied platform/step permission.

Independent review accepted the seven exact source files and146 source/output
pins under `contact-qualification/review-planted-front-v1`. Five local-rig and
six target/native/provenance tests pass. Continuous source-local/yaw0 checks
cover productive36, entry30, idle121 and walk33 intervals with zero unresolved
pairs; exact recovery is checked. Native evidence has597 poses,1,427 assertions
and0 failures, clean diagnostics/leaks and equal558-file pre/post closure.
Nine actual native tip observations are independently enclosed. Candidate and
plan bytes must match their immutable source-image header before target proof.

Rejected earlier candidates and the prior verifier remain historical evidence.
The accepted packet emits0 production flags. Complete versioned state unions,
actual footprint support, paid approach/retreat and step traversal still need
qualification. Its logical presentation allowance is6,969,508 bytes plus shared
WorldBasis544,768, with native/whole-client peak explicitly unmeasured.
