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
