# Combined body, blend and held-geometry measurements

2026-10-03. Decision [1067](../../../../../../decisions/1067-combined-underground-profile-variants.md)
records this increment. It imports the frozen B1 measurement tool; it does not
change the existing source assets, profile catalog, demo or asset pipeline.

`combined-variants.json` contains **67 measured source variants and zero
production-qualified movement profiles**. A successful run does not permit a
resident to use a tunnel, connector or work face.

## Actual coverage

| Input | Actual measured coverage |
| --- | --- |
| Bodies | Grounded `rigged.glb` for mouse keeper, mole digger, squirrel gatherer, otter boatwright and badger quarryman |
| Animation sources | All 22 existing grounded idle, walk, cautious crouch, carry and available hammer clips |
| Static held meshes | Existing mole pick plus radish, turnip, carrot, beetroot, onion, lettuce, leek, celery, peas, barley and oats highpoly sources |
| Procedural cargo | Existing carried log, including changing distance between the hands, complete overhang and radial extent |
| Variants | Five unloaded, five log, 55 farm-item and two pick combinations |
| Explicit batch gaps | Three absent hammer sources; five items without prop bindings for each of the five casts |

There is no local final staged asset manifest. Original meshes under the
reviewed demo fitting formulas are therefore explicitly partial source
evidence. Actual body bytes match the existing tailed/repaired manifest;
actual clip bytes match the grounded manifest; actual props match `files.json`.
The output fingerprints those four manifests, all five measurement/dependency
tools, seven reviewed presentation source files and seven reviewed fitting
functions. A changed indirect fitting/hand helper refuses too; provenance
alone cannot silently accept a changed formula.

Every variant includes every available clip of its cast. Combining the local
transform ranges **before** composing the skeleton covers crossfades from a
prior action. In contrast, the maximum of separate clip bounds can miss a
blended pose. The fixture demonstrates that case; the source proof uses no
pose samples.

The body enclosure retains every positive skinning influence, exact inverse
binds and all body primitives. Joint boxes contain only the vertices actually
influenced by each joint. Static geometry includes every node instance and
vertex under exact affine transforms. Fitted scale and center use actual
transformed-vertex extrema; an inflated interval box can incorrectly shrink
the fit. The tool does not use mesh metadata boxes or select a visual proxy.

## What the measurements mean

The output is a conservative **root-centered radius**, converted into a box
`[-radius,+radius]` on each axis. It is not body height or passage width. The
symmetric sphere is deliberately loose: it covers all supported rotations,
key ranges, included crossfades and attachments, and can substantially exceed
an actual pose's visible span. Do not turn it into a production connector
minimum or propose a room size from it.

The certificate proves zero residual for its exact mathematical source model.
It does **not** prove the final imported geometry, runtime float/GPU error,
procedural tail/stoop, contact/root placement, animation-state policy or cargo
and gear identity. The 1024u output field explicitly says
`outward_diagnostic_bounds_u_no_safety_margin`. No field is a schema-2 accepted
movement envelope.

The declared source candidates for ENTRY, TRAVEL, HOLD, TURN, REVERSAL,
RETREAT and EXIT are all `PRESENTATION_CANDIDATES_ONLY`. Their runtime binding
is null. Useful existing hooks are named, including `_enter_tunnel_leg`,
`choose_clip`, `_enter_hold`, `_enter_turn`, `turn_back`, `_walk_out` and
`_walk_out_from`; those presentation functions do not settle authoritative
state, cost, recovery or loaded traversal policy.

The missing props are parsnip, cabbage, spinach, broad bean and wheat. The
missing hammer clips are mouse, squirrel and otter. An absent source does not
grant or remove a species capability. No substitute dimensions or paid asset
was introduced. All `core_item_variant`, `cargo_quantity_milli`,
`cargo_lot_ref` and `gear_lot_ref` fields stay null.

The final binding work remains explicit: final staged body/clip/prop hashes;
the staged mouse crouch repin; actual imported transforms and the `+Z` staging
versus `-Z` simulation axis contract; procedural pose bounds and numerical
margin; real resident life stage and rig; current gear and cargo generations;
accepted profile revision; and actual state, root, support and contact owners.
See [NEXT_IMPLEMENTATION.md](../NEXT_IMPLEMENTATION.md) for the owning APIs.

## Reproduce

From the isolated checkout, with the existing main asset library read-only:

```sh
python3 tools/measure_underground_variants.py \
  --asset-root /Users/brendan/Developer/redwall-rts/assets/library \
  --output docs/design/underground-planning/evidence/modular-build/profiles/variants/combined-variants.json
python3 tools/test_measure_underground_variants.py
python3 tools/test_measure_underground_profiles.py
python3 tools/test_movement_envelopes.py
python3 -m py_compile tools/measure_underground_variants.py tools/test_measure_underground_variants.py
```

Exact result summaries retained in this directory:

```text
variants: 67 measured combined source(s), 0 production-qualified profile(s); 12 actual prop source(s), 28 explicit source/binding gap(s)
Ran 25 tests
OK
Ran 22 tests
OK
test_movement_envelopes: PASS -- 191 check(s), 0 failure(s)
```

`measurement.log`, `tests.log`, `b1-regression.log` and
`envelope-regression.log` retain the actual outputs. These are offline Python
checks. No new Godot suite, diagnostics/leak result, process-memory result or
256-resident performance claim is made for this increment.

`provenance-check.log` records the final count/hash cross-check and verifies
that all 22 previously retained B1 sample images lie inside the new combined
body intervals. That is an additional consistency check, not a replacement
for the continuous proof or a runtime qualification.
