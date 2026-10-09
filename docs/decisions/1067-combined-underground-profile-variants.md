# 1067 — Combined underground profile source variants

Date: 2026-10-03 · Status: Implemented measurement increment; production qualification remains open

## Decision

Extend decision1063's offline evidence with the new read-only
`tools/measure_underground_variants.py`, importing the frozen B1 parser without
changing it. The tool combines actual grounded bodies, compatible animation
sets and existing held geometry. Its evidence lives in
`docs/design/underground-planning/evidence/modular-build/profiles/variants/`.

The actual batch measures 67 source variants: five unloaded bodies, five
procedural carried logs, 55 farm-cargo combinations and two tool combinations.
It reads five body GLBs, 22 clip GLBs and 12 original prop GLBs. It records 28
explicit source/binding gaps. Every result is
`PARTIAL_COMBINED_SOURCE_VARIANT`, with `admission_qualified: false`.

This adds measurement and evidence, not a runtime profile, a new species
permission, an item quantity/shape policy, a connector dimension or a movement
cost. No asset, demo script, existing movement profile or import pipeline is
modified, and no paid generation is performed. UG08 remains in progress.

## Combined body and blend proof

Taking the largest separate clip bound is insufficient: a blend can combine
large ancestor scale from one clip with large descendant translation from
another. A synthetic regression demonstrates a 27.5m blended point outside
both separately bounded clips. The new tool instead merges the key ranges
per named node, then applies B1's complete hierarchical bound. Every measured
variant includes every available clip of its cast, including previous-action
poses that may participate in a crossfade. This deliberately encloses some
combinations the demo never presents; it does not authorize those actions.

Body and clips must have the same complete named topology, rest transforms,
primitive positions, skinning attributes and inverse binds. Actual node
indices may differ: correspondence is by unique node name and parent name.
Unmatched nodes, geometry, influences or skin bindings refuse. No track is
silently ignored or attached to a coincident index.

For each node, B1 establishes `|world(p)| <= A*|p| + B`, with distance in
micrometres. Translation and scale ranges are closed under convex blends;
the rotation bound includes arbitrary unit rotations as well as the supported
raw-key interpolation allowance. Thus merging ranges before composition
encloses supported continuous clips and convex local TRS crossfades, including
root yaw. Additive animation, IK, arbitrary procedural deformation and runtime
rounding are not covered by this certificate.

The new skin bound applies each inverse bind only to vertices with a positive
influence from that joint. It retains all positive influence sets and bounds
both raw and normalized total weight. This tightens B1's whole-primitive
per-joint boxes without dropping tails, secondary influences or attachments
already present in the source body. All ceilings and inverse-bind interval
operations remain exact rational calculations.

The resulting source sphere produces three conservative intervals
`[-radius, radius]`. Its zero mathematical source-interpolation residual is
independent of sampling. These deliberately loose radii are not recommended
passage widths, floor heights or accepted movement envelopes. The outward
1024u fields explicitly have no safety margin and cannot be published as
schema-2 production profiles.

## Held geometry

The staged demo asset manifest is absent locally. Consequently the batch
does not claim to measure the final imported mesh. It measures original
highpoly prop bytes under the existing demo's mathematical fitting rules,
with exact source hashes and an explicit final-staging gap. The body files
are the actual grounded `rigged.glb` images copied unchanged from the tailed
or repaired source pass; their hashes must match those existing manifests.

The static reader scans every position of every instantiated primitive,
including affine node transforms. Fitting denominators and centers use exact
transformed-vertex extrema: an inflated interval image of the local box could
incorrectly shrink the fitted result. Only axis-aligned transformations use
the equivalent exact shortcut on coordinate extrema. It does not trust
accessor min/max metadata or measure only the first mesh. It refuses animation, skins, morphs,
extensions and normalized position accessors in this static path.

Existing authored constants are read from source rather than replaced with
new values. Seven fitting functions and all seven complete presentation source
files have reviewed hashes: an edited formula or indirect helper refuses even
if its constants and directly named functions are unchanged. This includes
`drawn_size_m`, `rule_of`, `_in_right_hand`, `set_tool` and
`_relative_transform`. Even unrelated changes in those files need a reviewed
hash update. The resident brain used to identify candidate state hooks is
included. Hashes establish which code was inspected; they do not turn
presentation code into gameplay authority.

* The actual mole pick uses its existing right-hand bone and fitted grip.
  Its local radius includes every transformed vertex and both quarter turns.
  The full hand bound gives `A_hand * local_radius + B_hand`.
* Farm cargo uses the existing uniform fit and a centered item box at the
  hands' midpoint, plus the authored forward offset. The bound is
  `(B_left + B_right)/2 + forward_offset + local_radius`.
* The procedural carried log retains the complete changing hand span and
  authored overhang/radius. Since `|right-left| <= B_left+B_right`, the bound
  is `(B_left+B_right)/2 + (B_left+B_right+overhang)/2 + radius`.

These are source constructions, not a substitute for actual equipped
InventoryLot identity, Gear claim, carried quantity or core item variant.
The report keeps all those bindings null. Missing required attachment IDs,
duplicate IDs, undeclared attachments and absent attachment bones refuse.

## State and source gaps

Each record enumerates ENTRY, TRAVEL, HOLD, TURN, REVERSAL, RETREAT and EXIT.
Each is explicitly `PRESENTATION_CANDIDATES_ONLY`, with all measured clip
candidates and a null runtime binding. This is an honest mapping of useful
source candidates, not seven completed movement states. A missing state,
different candidate set or fabricated runtime approval refuses.

The 28 batch gaps are three absent hammer clips (mouse, squirrel and otter)
and five unbound farm item props for each cast: parsnip, cabbage, spinach,
broad bean and wheat. No replacement mesh or generic item dimensions are
invented. Available hammer sources permit measurement for mole and badger;
that fact does not grant either a new digging capability or restrict digging
to those species.

Every variant additionally retains six production gates: final staged asset
set; runtime deformation and numerical margin; legal state/cost owner; live
gear/cargo variant owner; accepted profile revision; and actual support,
contact and root anchor. The existing `+Z` staging-facing declaration versus
the authoritative `-Z` simulation convention, the staged mouse crouch repin,
procedural tail/stoop motion and actual imported fit remain engineering work.
The source sphere's rotational symmetry does not resolve those bindings.

## Bounds and failure behavior

The animated parser retains B1's finite limits and normalized-accessor
refusal. A combined set contains at most eight clips and sixteen attachments.
Static sources are bounded to 128 MiB, two million instantiated vertices,
512 nodes and 256 primitives; the larger byte/vertex allowance is needed for
the existing highpoly crop sources and does not affect runtime budgets.
Static affine rational results are bounded in magnitude and to 4096-bit
numerators/denominators. Manifests/declarations are bounded to 4 MiB and
10000 indexed rows; duplicate identities refuse. Output must fit int32
simulation units.

All source hashes are checked against existing manifests before measurement.
A changed prop hash aborts the batch; it is not downgraded to a missing item.
Unsupported or absent optional props remain named gaps. The CLI cannot write
inside the selected asset library or the repository's asset-manifest, tool
or Godot input areas. It neither stages sources nor invokes the engine.

## Validation and continuation

The actual command and logs are retained beside `combined-variants.json`.
The new suite reports `Ran 25 tests` / `OK`. The unchanged B1 suite reports
`Ran 22 tests` / `OK`; existing movement envelope validation reports
`test_movement_envelopes: PASS -- 191 check(s), 0 failure(s)`.

Adversarial coverage includes cross-clip scale/translation, continuous tool
rotation, named-node reorder, altered rest/mesh/inverse bind, secondary
weights, unrelated joint boxes, omitted/duplicate gear and cargo, changed
cargo dimensions, all prior-action clips, missing states and invented
runtime binding, additional static instances, bad accessor/hash/capacity,
changed direct/indirect fitting functions, a sheared model whose transformed
local box would understate the final fit, and protected CLI input output paths. Fixtures
are explicitly synthetic and their dimensions grant no production fit.

This Python-only increment changes no Godot execution path; it does not
claim a new full Godot suite, runtime diagnostics or 256-resident performance
qualification. Independent review found and resolved the transformed-fit
denominator and indirect-helper drift defects; the reviewer reran all three
test groups and approved the corrected source. Subsequent work must bind
final imported body/clip/prop variants, prove
procedural/runtime residual, and attach accepted profiles to actual
Residents/Gear/Inventory/Haul and movement-state owners. Connector authoring
and UG21/UG06 spatial/contact composition remain separate required work.
