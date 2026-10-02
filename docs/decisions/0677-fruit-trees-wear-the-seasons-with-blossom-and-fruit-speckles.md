# 0677 — Fruit trees wear the seasons: a fruit kind, their own blossom and a fruit speckle
Date: 2026-10-01 · Status: Accepted; the drawn size is 0671's proposal 8

## Decision

- **The orchard's trees and bushes are season trees** (decision 0551's system): `season_view.gd add_trees(owner)` dresses
  another owner's trees after the woods', each in its model's one tree material, re-collecting when the owner's
  revision moves (a sapling grown into a tree). The owner answers five calls (count, node, kind, spot, revision);
  nothing is duplicated per tree.
- **`season_look.gd KIND_FRUIT`**: deciduous, never holding dry leaves, full blossom in spring (the catkins' days 0.5–9),
  its autumn colour, bare boughs in winter (the oak model's own, `bare_boughs.gd`).
- **Two per-tree instance numbers** in `season_leaves.gdshaderinc` (both tree shaders include it, so their lists stay
  equal): `leaf_blossom_tint` -- a tree's own blossom colour and the share of leaf cells in flower (apple pink-white and
  pear white at 42%, the bushes 22%; 0 for every woods tree, which keeps the material's catkins at 12%) -- and
  `leaf_fruit` -- the fruit's colour and how much of its coarser speckle shows (0 for every woods tree).
  `orchard_view.gd` writes them on the hour: green fruit swelling from summer day 5, red apples and yellow pears through
  autumn until the tree is picked, fewer on a tree in poor health, none on a tree that does not bear this year; the
  bushes' berries by the hedge's stock above its floor while §5.5 lets them be picked.

## Why

Brendan's brief: "Fruit trees must use it: blossom in spring, fruit in season, bare in winter." A speckle reads at the
RTS camera, costs two instance floats a tree and no draw call, and needs no new art (none is staged; 0671's art gap).

## Source

Decision 0551; the brief of feature #20.
