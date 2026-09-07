# 0002 — Model scale is anchored on a 1.0 m mouse
Date: 2026-09-05 · Status: Accepted · **Amended 2026-09-06 (Brendan)**

## Decision
The Small tier is **1.00 m**. Medium (1.49 m) and Large (2.55 m) are derived and
**unconfirmed**; Giant is **undefined**.

## Why
`docs/crowd_rendering_architecture.md` §9.1 fixes prototype mouse height at
1.0 m — "gameplay scale; fantasy relative scale, not biological meters". It is
the **only species height stated in any document**.

An earlier tier table used 0.55 m for Small, chosen by eye before the crowd
document was in the repository. It was wrong, and it was wrong in the anchor
rather than the ratios — a plausible-looking scheme built on nothing.

## Consequences
- Do not substitute a biologically plausible mouse. This is deliberate.
- Medium and Large are placeholders. Settle them by eye with two tiers side by
  side **before bulk generation**; changing them later means re-running every asset.
- Every generated asset is normalised to its tier by
  `.claude/skills/asset-pipeline/scripts/prep_unit.py --height`.

## Source
`docs/crowd_rendering_architecture.md` §9.1.


## Amendment — approve a comparison, not final heights (Brendan, 2026-09-06)

**Small stays 1.00 m.** Medium 1.49 m and Large 2.55 m are **comparison
candidates only**, not approved values.

Build a review scene containing:
- Mouse beside hare/otter
- Mouse and hare beside badger
- All three beside the **same doorway, table and workbench**
- Standing, walking, carrying and crouched poses
- Both close inspection and the normal gameplay camera

This tests community proportions and usable spaces, not only silhouette
readability. **Define how height is measured** first, so ears, equipment and pose
do not accidentally drive body normalisation.

**Giant is deferred entirely.** The GDD excludes Giant residents from settlement
release 1. Birds and serpents later need creature-specific body length, wingspan
and clearance measurements — not one universal standing height.

**No bulk generation until the applicable proportions are approved.**
Decision 0020 puts scale on the critical path for movement assets (gate G04).
