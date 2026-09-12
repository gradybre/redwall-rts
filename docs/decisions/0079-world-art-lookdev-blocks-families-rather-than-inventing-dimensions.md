# 0079 — The world-art brief ships blocked families rather than invented dimensions
Date: 2026-09-11 · Status: Accepted for the brief's scope; the gaps it names remain open

## Decision

[`docs/art-reference/world_art_lookdev_brief.md`](../art-reference/world_art_lookdev_brief.md)
specifies four world-art families — representative residents, a dwelling/workspace,
ground/vegetation and practical props — as **18 asset entries**, and marks **six of them
blocked** instead of supplying the missing numbers itself.

Where a dimension, budget or convention is absent from the owning contract, the brief
names the gap (GAP-01 … GAP-10), records where it was searched, and states what would
settle it. Every non-sourced figure it does state is labelled **PROPOSED — NOT RATIFIED**
in place. No species height, building height, triangle ceiling or naming convention is
introduced as if it were settled.

The brief authors no asset, calls no paid tool, and carries its credit request as a
proposal under [the paid-asset process](../design/paid_asset_process.md) for Brendan's
decision.

## Why

Two failure modes were live. The first is inventing a constant to keep the document
tidy — the asset-pipeline skill already warns that re-running every asset after a late
scale ruling is the expensive path, and DEC-038 explicitly declined to give a species-size
specification. The second is the opposite: refusing to write anything concrete and
handing back a restatement of the handoff. Marking six entries blocked while fully
specifying the other twelve does the useful part of the job without the invention.

Two concrete conflicts surfaced during the search and are the reason this record exists
rather than a note in the brief alone:

**The two four-class ratio sets disagree.** The asset-pipeline skill derives Medium and
Large as ×1.49 and ×2.55 of the 1.0 m mouse and marks both "derived, unconfirmed".
`docs/crowd_rendering_architecture.md` independently gives small/medium/large/giant
collision radii of 184/246/461/922 units, whose ratios are 1 : 1.337 : 2.505 : 5.011.
Neither document claims its numbers are heights. Two of the twelve starting residents
are otters, so silently adopting either set would have written a species-size
specification into production geometry through the back door.

**L0 is unreachable at the settlement camera.** `docs/ui_ux_controls.md` §6 fixes a
55° vertical FOV and an 8–120 m orbit. Applying the crowd document's own LOD formula at
1920×1080 gives ≈130 px for a 1.0 m resident at the closest legal zoom, ≈26 px at the
40 m default and ≈8.6 px at 120 m. The crowd document admits L0 only at ≥180 px, and
`docs/game_gdd.md` §7 allows at most 24 conventional close-up skeletal actors without
stating what admits them. Under the screen-space rule alone the 12,000-triangle tier
would never be selected in the settlement. This is arithmetic over two sourced contracts,
not a measurement, and it needs a ruling before anyone budgets an L0.

## Consequences

- A1 (mouse keeper) and A5 (the paired hand tool that stands in for crowd §9.2's "one
  sword", since the settlement has no sword) are ready to start. A2 and A3 may be
  blocked out at a labelled 1.00 m candidate; A4 does not start.
- B1 and B2 may proceed as look-development studies with a labelled candidate height,
  not as production models. B3 stays blocked until cutaway geometry ownership exists.
- C1, C2 and C4 are ready; C3's 25 tile appearances wait on a geometry budget, because
  4096 permitted farm tiles make the per-tile number load-bearing.
- `prep_unit.py` joins all imported objects into one mesh and does not triangulate, check
  facing or check determinant. It is sufficient for a single-object creature and
  insufficient for any multi-part building. Recorded so the skill's one-command step is
  not read as covering every asset.
- No ART-LOCK-001 pigment, contour rule or light angle appears anywhere in the brief.
  That lock governs UI illustration; the world follows the DEC-038 example.
- Nothing here authorizes spending. The itemised 10 / 60 / 100-credit request in the
  brief's §9 is a proposal awaiting Brendan's reply.

## Source

DEC-036/037/038 in `docs/setting_decisions.md`; the approved image and its provenance
manifest; `docs/crowd_rendering_architecture.md` §2.7, §7 and §9; `docs/game_gdd.md`
§5.1, §5.9 and §7; `docs/ui_ux_controls.md` §6; `docs/setting_bible.md` §14.1/14.4/14.5/14.7;
`.claude/skills/asset-pipeline/SKILL.md` and `scripts/prep_unit.py`; direct inspection of
IMG-03, IMG-04, IMG-07, IMG-08, IMG-12, IMG-17, IMG-18 and IMG-25 at their manifest
regions; `godot/data/catalog_ids.json`; and direct inspection of
`godot/assets/units/species_mouse_body_a_lod0.glb`.

## Superseding authoring decisions — 2026-09-11, decision0080

The original blocked finding above remains historical evidence. Decision0080 and
[ART-GAP-R01–05](../planning/asset_dimensions_and_budgets.md) now explicitly adopt
building-height envelopes, non-creature/material/cutaway/naming budgets and
settlement L0 admission. GAP-03/04/05 and adjacent06–09 have authoring definitions;
their exported/runtime evidence remains open. GAP-01/02 now have exact comparison
candidates and measurement rules, but bulk-production proportions still await
decision0002's user-required review. GAP-10/Windows qualification and MOVE gates
remain open. Do not keep those authoring tasks blocked solely by the earlier
absence of these definitions, or mistake their adoption for performance evidence.
