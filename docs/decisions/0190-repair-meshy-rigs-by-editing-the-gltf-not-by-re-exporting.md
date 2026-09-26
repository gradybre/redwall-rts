# 0190 — Repair Meshy's rigged output by editing the glTF, not by re-exporting it
Date: 2026-09-26 · Status: Accepted

## Decision

`tools/repair_meshy_rig.py` repairs all 110 rigged and animated GLBs in the asset library
([decision 0188](0188-the-meshy-asset-library-is-provisional-and-lives-outside-git.md)'s addendum
has the defects). Each repaired file is written to `assets/library/creature/<key>/repaired/`,
and the original is never modified. The repair:

1. **Material.** Sets `metallicFactor` 0.0 and `roughnessFactor` 1.0, attaches the L0's own
   metallic-roughness and normal maps, removes emission, and drops `KHR_materials_specular` and
   `KHR_materials_ior`.
2. **Height.** Uniformly scales the scene's single root. That applies to three creatures: mole_digger ×1.2269,
   mole_mason ×1.1860 and badger_cellarer ×1.2020. The other seven are within 1 mm and are untouched.

[`docs/art-reference/asset_library/repaired.json`](../art-reference/asset_library/repaired.json)
records each file's source and output SHA-256, its height before and after, and its factor.

## Why edit the glTF directly

A Blender import and re-export would also fix the material, but it would **re-encode every
texture** and **re-sample every animation**. It would also bring in Blender's own importer
artefacts, such as the bone-display `Icosphere` found on 2026-09-26. Editing the glTF touches
only what is broken:

- the source BIN chunk survives byte for byte, as a prefix of the output, and the tool checks this;
- the L0's two maps are **appended**, not re-encoded;
- the only changes to the JSON are the material fields, the root node's `scale`, and a stamp
  in `asset.extras`.

It needs only the Python standard library and runs in about 1.6 s for all 110 files.

## The one assumption, proved rather than trusted

The L0's maps are only correct if the rigged mesh uses the L0's UV atlas. The tool **refuses**
any file whose colour map is not byte-identical to its L0's. All 110 passed. This is also why the
rigged mesh counts as "the L0 mesh": the triangle counts are identical, and the only extra
vertices are splits at skinning seams.

## Heights come from the file that owns them

Targets are read from `SPECIES_HEIGHT_U` in `godot/assets/lookdev/lookdev_dimensions.gd`, the
authoritative 1/1024 m column (decision 0082). They are not a copied table. So a mole's target
is 922/1024 = **0.9004 m**, not 0.900. A test pins the parse to the literal DEC-039 values, and a
mutant that reads the derived millimetre column instead is caught.

## Why scaling the root is correct for a skinned mesh

A skinned vertex is drawn at `joint_world × inverse_bind × v`. Every joint descends from the
scene root, so scaling the root by *k* multiplies every `joint_world` by `S(k)`. At bind pose
`joint_world × inverse_bind` is the identity, so the whole creature scales by *k* about the
origin — its feet — and the animation scales with it.

The "height after" check does **not** read back the factor the tool chose, which would agree
with itself by construction. It measures the source file's geometry extent times the ratio of
the output file's root scale to the source file's, each read from its own bytes.

## Evidence

- `tools/test_repair_meshy_rig.py`: **30 checks, 0 failures**. Seven negative cases come first:
  - a different atlas;
  - a re-repair;
  - two roots;
  - a matrix root;
  - a non-uniform root;
  - a broken species table;
  - a missing species column.

  Expected values are literals, and the written GLB is read back with `struct`, not with
  the tool's own parser. It runs in CI's contracts job.
- **Seven mutants, all killed:**
  - skip the atlas proof;
  - leave metallic unset;
  - keep the emission;
  - allow a re-repair;
  - always rescale;
  - read the derived mm column;
  - wire the normal map to the roughness texture.

  The file was restored byte-identical after each.
- **The real library:** 110 of 110 repaired, every height within 1 mm of target, sources
  untouched (SHA-256 unchanged).
- **Godot 4.7.2 on the repaired files, with no viewer-side corrections:** every imported material
  reads `metallic=0.00 roughness=1.00`, with a roughness texture and a normal texture, and emission
  off. Drawn heights stand in exactly DEC-039's ratios, 0.90 : 1.00 : 1.15 : 1.49 : 2.55. Before
  the repair the same measure read 0.73 for the moles and 2.12 for the badger cellarer.

## Not done here

The Meshy rig itself is unchanged: 24 joints, no tail chain and no sockets. The production rig
is still to be built. The repaired files are still provisional library items, not accepted assets.
