# 1063 — Source-bound underground profile measurements
Date: 2026-10-02 · Status: Accepted measurement increment; gameplay qualification open

## Decision

UG08 B1 adds the read-only `tools/measure_underground_profiles.py` and source-bound
evidence under `docs/design/underground-planning/evidence/modular-build/profiles/`.
It measured 22 existing grounded creature clips for the five DEC-039 species.
Every result is `PARTIAL_SOURCE_GEOMETRY`, with `admission_qualified: false`.
No movement profile, runtime constant, source asset, import pipeline or world
authority is changed.

The artifact uses its own `redwall.underground.source_measurement/1` format.
It records the target envelope contract as schema 2 and reuses the existing
exact outward micrometre-to-1024u conversion. It is deliberately not a schema-2
production movement profile. A successful tool exit means the measurements
were produced, not that any actor can traverse a connector.

## Why

Nine sampled poses show actual skinned extents and help inspect sources, but
cannot establish continuous extrema. The separate conservative enclosure uses
exact rational arithmetic on decoded values, every scene primitive, every
skinning influence set, inverse binds, and the complete node hierarchy.

For each node, a bound has the form `|world(p)| <= A*|p| + B`, with distance in
integer micrometres. Translation length is bounded by the maximum outward
Euclidean norm among rest and LINEAR/STEP keys; scale by the maximum absolute
component. All unit rotations preserve length. A stored quaternion also has
allowance `Q = max(1, 2*|q|² - 1)`, using the identity
`R(q) = |q|² R(q/|q|) + (1-|q|²) I`. This covers literal stored-key roundoff
as well as unit interpolation; raw linear quaternion interpolation is bounded
by the endpoint norms. Composition is `A' = A*S*Q`, `B' = B+A*T`.

Each primitive's full position box is transformed through each used inverse
bind with exact interval arithmetic. Its farthest possible corner gives an
outward integer radius. Joint bounds are combined with nonnegative skin weights
and an upper bound on the total weight; both normalized and raw weighted sums
are enclosed. Rigid attached primitives use their own actual world transform.
Integer square roots and ceilings are outward. The resulting root-centered
sphere gives three conservative intervals `[-radius, radius]`, independent of
pose sample count. See the evidence README and tests for the derivation and
intermediate-rotation counterexample to endpoint-only sampling.

This enclosure has zero *mathematical source interpolation* residual because
it covers all supported local rotations and key ranges, rather than sampling
them. It does not certify runtime float/GPU error, procedural deformation,
terrain adaptation, root placement, external equipment or cargo. Its loose
radius is not an authored passage width or a recommended connector size.

## Refusals and capacity

Source SHA256 must match the existing manifest before parsing the exact same
bytes. Actual reads stop at their cap plus one byte, closing a growing-file
allocation gap. The supported image is one embedded GLB buffer, one animation,
a complete non-cyclic selected scene, TRS nodes, LINEAR/STEP channels, affine
inverse binds, and complete paired joint/weight sets. Unsupported extensions,
morph targets, cubic interpolation, external buffers, omitted roots, malformed
chunks/accessors, normalized accessors, negative or zero-total weights and
nonfinite values refuse. Normalized integer accessors need a future exact rational
decoder; the shared helper's float division cannot support a zero-residual proof.
CLI output cannot resolve to the source library or source manifest.

Limits are 64 MiB/source, 4 MiB/manifest, 512 nodes, 256 instantiated primitives,
100000 vertices, 2000000 decoded accessor scalar values, 2048 channels,
8192 keys/channel and 33 diagnostic poses. Source numeric magnitudes and
composed transform bounds are checked; output must fit signed int32 units.
The batch is the fixed five casts by five candidate clip names. These are
offline refusal limits, not per-tick budgets or measured 256-resident performance.

Every result retains missing legal states, attachments, margins and acceptance
as explicit refusals. ENTRY, TRAVEL, HOLD, TURN, REVERSAL, RETREAT and EXIT need
actual owner-qualified mappings; a clip filename grants none. A reduced
required-state set, omitted primitive/attachment, or any axis margin smaller
than the stated residual is refused. Even locally complete synthetic metadata
still reports `RUNTIME_PROFILE_OWNER_BINDING_MISSING`.

## Consequences

UG08 B2 can build the sparse actual spatial owner independently. It must keep
profile/support qualification closed. UG08 B3 still needs measured, accepted
body/age/gear/load variants, runtime deformation and numeric margins, state
transitions, full connector sweeps and actual contact/support/economy bindings.
The five approved connector families and their numerical authoring gates remain
as documented in decision1058. This increment does not close UG08.

The asset-pipeline skill's tier table still lists moles/squirrels at 1m and
otter/badger heights as unconfirmed. That lower-authority text contradicts
`setting_decisions.md` DEC-039. DEC-039 wins: mouse 1024u, mole 922u, squirrel
1178u, otter 1526u, badger 2611u. No source was rescaled here, and a posed mesh's
span is not an anatomical-height reapproval. The stale skill is outside this
lane's file lease; the conflict is recorded for its owner instead of silently
using its superseded table.

## Validation

Actual local grounded sources matched all 22 manifest hashes; no asset was
rewritten, imported, staged or generated. The report binds the manifest and
measurement tool/dependency hashes. Exact commands and complete logs are in
the evidence directory.

```text
measurement: 22 source(s), 0 production-qualified profile(s); 3 missing optional source(s)
Ran 22 tests
OK
test_movement_envelopes: PASS -- 191 check(s), 0 failure(s)
```

The 22 new tests include hash tampering, omitted states/attachments, understated
margins, continuous rotation beyond sampled endpoints, inverse binds, additional
influence sets, nonunit stored quaternions, bounded reads, fractional normalization, attempted
manifest overwrite and malformed sources.
Fixtures are synthetic; the real-asset evidence is separately identified.
Python compilation passed for both new tools. This is Python-only measurement
work; no additional Godot run or production clearance qualification is claimed.

## Source

`setting_decisions.md` DEC-039; `movement_direction_amendment.md` and the existing
schema-2 envelope contract; approved underground `levels-and-connections.md`;
decision1058 B1–B3; `art-reference/asset_library/grounded.json` and its exact local
source bytes. Existing rig and accessor helpers are reused read-only.
