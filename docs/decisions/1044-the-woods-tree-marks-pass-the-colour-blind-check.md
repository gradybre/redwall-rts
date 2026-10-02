# 1044 — The Woods' tree marks pass the colour-blind check

Date: 2026-10-02 · Status: Accepted (colour choice is a PROPOSAL for Brendan, below)

## Decision

The Woods layer has six marks: the forestry zone, the conservation zone, and four
tree states. All six now clear decision 0581's floors over the grass
(`lens_colour_check.gd`). The floors are CIE76 ΔE 10 in the legend and by day,
and 8 by night, for normal vision and for full-severity deuteranopia and
protanopia.

The colours live in `godot/demo/forestry/forest_marks.gd`, which the forestry
code owns. The village's legend now reads them from there
(`ForestMarks.LEGEND_COLOURS` / `LEGEND_NAMES`) instead of repeating them inline.

| Mark | Was | Now |
|---|---|---|
| forestry zone | BRASS | BRASS (unchanged) |
| conservation zone | SAGE | SAGE (unchanged) |
| mature tree | LEAF | LEAF (unchanged) |
| young tree | **BRASS** (same as the forestry zone) | **#A6C24A**, a spring green |
| stump | **UMBER #594332** | **#44392B**: UMBER taken 30% of the way to DEEP_SHADE |
| cleared spot | CLAY | CLAY (unchanged) |

## Why these

- Decision 0581 measured mature (LEAF) against stump (UMBER) at 8.6 with
  deuteranopia in the legend and by day, and 7.8 by night. It also noted that
  BRASS was both the forestry zone's colour and the young tree's. Both findings
  are reproduced exactly by the new test
  `test_the_old_woods_marks_fail_where_decision_0581_measured`.
- Darkening the stump toward DEEP_SHADE keeps it a brown. The mature/stump pair
  then rises to 1.44 times its floor in the worst viewing. The six-colour set's
  worst pair is mature against cleared, LEAF against CLAY: two colours that were
  not changed, at 1.12 times the floor.
- The young tree was first tried as OAT, a pale new growth. It passed the check,
  but the 1080p frame showed its legend chip vanishing into the parchment card,
  which is itself OAT-coloured. The check compares marks with each other, not
  with the card. The spring green passes with its nearest pair, the forestry
  zone, at 1.68 times the floor. It is about 42 ΔE from the parchment in every
  vision, and it reads as young growth beside the mature tree's darker LEAF.
- The two zone colours are unchanged. They are outlines and washes, and the guide
  and README describe other brass things (the guide marker) without naming the
  zones' colour.

## Verification

- `test_demo_lens_probes.gd`: the six legend colours have no failures in any
  viewing or vision, each tree state draws its legend entry's colour, and the old
  set fails where 0581 measured it.
- `demo_lens_live.gd` at 1920x1080 with frames: `LIVE-SUMMARY 30 0`. The frame
  `lens_readout_tree` (hovering a young oak) shows the spring-green disc, the
  brass zone edge and a readable legend.

## PROPOSAL for Brendan

The two new colours sit outside the woodland palette's twelve pigments, though
the stump's is a mix of two of them. Options:

1. Keep them as they are (recommended).
2. Add a "SPRING" pigment to `woodland_palette.gd`.
3. Pick other hues; the check and test pin the floors, not these values.
