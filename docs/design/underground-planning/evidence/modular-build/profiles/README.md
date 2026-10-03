# Underground source measurements — UG08 B1

Measured 2026-10-02. **22 existing grounded GLBs; zero production-qualified
profiles.** These files are geometric evidence for subsequent authored connector
and profile work. They grant no movement, digging, carrying or building permission.
See [decision1063](../../../../../decisions/1063-source-bound-underground-profile-measurements.md).

## Artifacts and provenance

- [source-measurements.json](source-measurements.json) records exact source SHA256,
  bytes, cast/clip identity, all instantiated primitive IDs, continuous bounds,
  actual sample times, diagnostic posed bounds, missing coverage and tool hashes.
- [measurement.log](measurement.log) lists every measured source and the summary.
- [tests.log](tests.log) is the complete new adversarial-test output.
- [existing-envelope-tests.log](existing-envelope-tests.log) records the existing
  envelope conversion and qualification regression checks.

Sources were read directly from the main checkout's
`assets/library/creature/<cast>/grounded/<clip>.glb`. Every file matched its row
in `docs/art-reference/asset_library/grounded.json` from this worktree. The same
bytes are hashed and parsed. The report also hashes that manifest, the new tool,
and its three existing helper dependencies. No source bytes were copied into
this evidence directory, edited, imported, staged or generated. Total source
bytes read: **444971576**. This does not represent a runtime memory allocation.

The measurement transform is identity: source-local metres, intended +Y up and
−Z forward, with no anatomical rescale, root relocation or facing correction.
The intended axes and anatomical height are not a new acceptance of actual
facing, root/support placement or runtime profile dimensions. DEC-039's approved
adult heights remain mouse 1024u, mole 922u, squirrel 1178u, otter 1526u and badger
2611u. Posed mesh height varies with animation and must not replace that table.

## Actual measurements

The three spans below are axis-aligned **sampled** X/Y/Z extents over nine poses
of all embedded vertices, including all skin influences and rigid primitives.
They are rounded here to millimetres for readability. Exact outward diagnostic
micrometre bounds and sample times are in the JSON. These spans are not a
continuous clearance guarantee. Each source also has a conservative continuous
root-centered sphere; the final column is its radius rounded outward to 1/1024m
units with **no gameplay safety margin**. The sphere's coordinate intervals are
`[-R,+R]` on every axis, not a body box with radius mistaken for width.

| Cast | Clip | Sampled X span (m) | Sampled Y span (m) | Sampled Z span (m) | Continuous radius (u) |
| --- | --- | ---: | ---: | ---: | ---: |
| mouse_keeper | walk | 0.506 | 1.005 | 0.728 | 2480 |
| mouse_keeper | idle | 0.574 | 1.035 | 0.624 | 2473 |
| mouse_keeper | crouch | 0.682 | 0.873 | 0.908 | 2473 |
| mouse_keeper | carry | 0.603 | 1.052 | 0.538 | 2477 |
| mole_digger | walk | 0.826 | 0.904 | 0.819 | 2584 |
| mole_digger | idle | 0.756 | 0.836 | 0.571 | 2556 |
| mole_digger | crouch | 0.715 | 0.747 | 1.113 | 2556 |
| mole_digger | carry | 0.877 | 0.899 | 0.584 | 2575 |
| mole_digger | hammer | 0.910 | 1.294 | 1.203 | 2641 |
| squirrel_gatherer | walk | 0.543 | 1.187 | 1.287 | 3638 |
| squirrel_gatherer | idle | 0.795 | 1.141 | 1.182 | 3604 |
| squirrel_gatherer | crouch | 1.239 | 1.018 | 1.447 | 3604 |
| squirrel_gatherer | carry | 0.740 | 1.189 | 1.110 | 3664 |
| otter_boatwright | walk | 0.766 | 1.538 | 1.235 | 4077 |
| otter_boatwright | idle | 1.047 | 1.477 | 1.112 | 4023 |
| otter_boatwright | crouch | 1.254 | 1.263 | 1.539 | 4023 |
| otter_boatwright | carry | 1.010 | 1.596 | 0.921 | 4076 |
| badger_quarryman | walk | 1.838 | 2.557 | 1.632 | 6846 |
| badger_quarryman | idle | 1.546 | 2.383 | 1.108 | 6823 |
| badger_quarryman | crouch | 1.428 | 2.053 | 2.450 | 6823 |
| badger_quarryman | carry | 1.755 | 2.441 | 1.175 | 6823 |
| badger_quarryman | hammer | 1.662 | 3.053 | 2.659 | 7072 |

Clip labels above expand to `anim_walk`, `anim_idle`,
`anim_cautious_crouch_walk_forward`, `anim_carry_heavy_object_walk` and
`anim_heavy_hammer_swing`. A carrying/hammer animation filename does not prove
that an actual cargo/tool is present or that the action is permitted.

Unavailable matching hammer sources are mouse_keeper, squirrel_gatherer and
otter_boatwright. Their absence is explicit; no alternative clip or invented
body dimensions are substituted. Every walk/idle/crouch/carry source was present.

## Continuous enclosure and its deliberately limited scope

The source proof is independent of frame sampling. It uses exact rational
representations of decoded accessor and node values, then rounds squared norms
outward with integer square roots. For each hierarchy node, `A,B` certify
`|world(p)| <= A*|p| + B`. Translation norms and absolute scale components are
bounded by their rest/key maxima because supported translation/scale curves
are LINEAR or STEP. Unit rotations preserve norm. Raw stored quaternions have
an additional exact factor `max(1,2*|q|²-1)`, covering their nonunit float32
values without assuming exact normalization. The same factor covers a raw
linear blend between those keys. Parent and child bounds compose as
`A' = A*S*Q`, `B' = B+A*T`, so no possible intermediate rotation is omitted.

For each skin joint, exact affine interval arithmetic maps the entire primitive
position box through its inverse bind, then the joint hierarchy bound applies.
The maximum is multiplied by the greater of one and the largest nonnegative
total vertex weight. This encloses both raw weighted sums and normalized convex
skinning. Every JOINTS_n/WEIGHTS_n pair is included. Every rigid mesh instance
uses its own hierarchy bound. Unreferenced source meshes are not scene geometry;
every node in the source must occur in the selected complete scene.

The union is enclosed by a root-centered sphere; its `[-R,+R]` intervals are
then converted with the existing schema-2 outward quantizer. Since all supported
rotation directions and translation/scale ranges are enclosed, the source
interpolation residual is zero. This is a proof for the supported mathematical
source transform/skin model, **not** a claim that runtime float/GPU arithmetic,
procedural deformation or contact errors are zero. That distinction remains
in each record's certificate and qualification refusals.

The sphere is loose because it permits each local rotation independently and
uses the full primitive's box at each influenced joint. Its size must not become
a proposed passage width, roof height, maximum species size or furniture margin.
The sampled spans are useful for deciding which tighter sweep to measure next,
but cannot replace the proof or authorize a narrower opening.

## Qualification still missing

Every record remains partial for these concrete reasons:

- ENTRY, TRAVEL, HOLD, TURN, REVERSAL, RETREAT and EXIT have no accepted actual
  owner mappings. Nine snapshots of one clip do not supply those states or their
  transitions. Existing child/elder/body variants are not qualified by scaling
  these five adult sources.
- Actual equipped gear, carried cargo and runtime support attachments have not
  been supplied as bound variants. Embedded geometry is fully included, but an
  absent external tool or load cannot be treated as empty space.
- Grounded source files are not the final live/baked asset pipeline. The demo's
  runtime tail, procedural pose/terrain effects, and staged crouch repinning
  (decision0371) need their own exact final-asset/runtime binding and error proof.
  The source sphere includes arbitrary source-joint rotations, but does not
  certify that runtime processing preserves that hierarchy, scale and support.
- Profile revision/owner acceptance, actual root anchor and facing, runtime
  numerical margins, and support/traction/load/contact truth are absent.
  Missing margins are `null`, not silently zero.

The local coverage gate refuses omitted legal states, omitted embedded or
external attachments, and any per-axis margin below a declared residual.
It always retains `RUNTIME_PROFILE_OWNER_BINDING_MISSING`; this evidence format
cannot turn a favorable sample or forged completeness flag into runtime approval.
UG08 B2 may proceed with the real sparse owner while these gates remain closed.
UG08 B3 must bind accepted profiles and all five actual connector families.

## Reproduction and tests

From the isolated checkout, with the existing library available read-only:

```sh
python3 tools/measure_underground_profiles.py \
  --asset-root /Users/brendan/Developer/redwall-rts/assets/library \
  --manifest docs/art-reference/asset_library/grounded.json \
  --output docs/design/underground-planning/evidence/modular-build/profiles/source-measurements.json \
  --sample-poses 9
python3 tools/test_measure_underground_profiles.py
python3 tools/test_movement_envelopes.py
python3 -m py_compile tools/measure_underground_profiles.py tools/test_measure_underground_profiles.py
```

```text
measurement: 22 source(s), 0 production-qualified profile(s); 3 missing optional source(s)
Ran 22 tests
OK
test_movement_envelopes: PASS -- 191 check(s), 0 failure(s)
```

The synthetic tests exercise source hash tampering, a mid-rotation extent absent
from both sampled endpoints, translated/scaled hierarchy composition, additional
influence sets and inverse binds, rigid attachments, incomplete states, missing
attachments, understated margins, nonunit stored quaternions, bounded reads,
bad chunks/scene coverage/accessors, morphs/cubic curves/extensions, negative
weights, fractional integer normalization, attempted manifest overwrite and
nonfinite values. Changing diagnostic sample count cannot change
the continuous enclosure. Synthetic dimensions never become creature profiles.

This increment changes offline Python tooling and evidence only. It does not
claim another Godot suite run, runtime visual review, actor/connector fit, save
integration or measured 256-resident performance.
