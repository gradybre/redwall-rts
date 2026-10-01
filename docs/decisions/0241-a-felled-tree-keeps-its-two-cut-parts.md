# 0241 — A felled tree keeps its two cut parts across fall and regrowth
Date: 2026-09-30 · Status: Accepted

**Numbering.** The highest decision on this branch (`fix/review-d-tree-leak`, from `feat/live-demo` at 43d9654) is
0211. Other review fixes are being written in parallel on other branches, so this one takes **0211 + 30 = 0241** to
avoid a collision; the gap is deliberate.

Review finding **F18** (CRITICAL under `CLAUDE.md`'s memory-leak grade): repeated felling and regrowth retained
hidden scene nodes in the woods' drawing (`godot/demo/forestry/forest_view.gd`, decision 0196). Presentation only;
nothing here changes a row, a rate or the wood a tree yields.

## What was wrong

`_start_fall` made two new `MeshInstance3D` nodes (the stub below the felling cut and the trunk and crown above it)
on every fall and wrote them over `_lower_nodes[t]` and `_upper_nodes[t]`. The old pair stayed parented to the view,
hidden. Only a change of look (`_replace_tree_node` → `_forget_parts`) freed the current pair, and ordinary
same-species regrowth never takes that path. So each fell → haul → regrow cycle added two hidden children per tree.

`_replace_tree_node` had a second, smaller retention: it only hid the tree it replaced, even when the view had made
that tree itself. A beech blown down or grubbed out and replanted (planting is always an oak) left its old node
hidden under the view for good.

Reproduced on this branch before the fix with the review's own sequence on the real staged oak. The view's children
after each cycle were 10, 12, 14, 16 … 52 over 22 cycles, the same as the review's first four.

## Decision

1. **Reuse the tree's cut parts.** `_part_node(part, mesh, xform)` takes the tree's existing part node. It sets that
   node's mesh and transform back to the standing pose, and makes a new node only when there is none: the tree's
   first fall, or its first since its look changed. A tree therefore owns at most two part nodes for its whole life.
   The meshes were already shared, split once per model key (`forest_split.gd`).
   - Resetting the transform matters. Without it, a paused game would show the crown lying where it landed last
     time for as long as the pause lasts, because `_pose_fall` only rewrites it while `advance` runs.
2. **Free what the view made; hide what the world owns.** `_replace_tree_node` now `queue_free`s the old tree node
   when the view is its parent (every node the view makes is its own child; the world's trees live under the
   world's village node, and nothing reparents either), and only hides it when it is the world's node (demo_world.gd owns that one). The old
   tree's cut parts are still forgotten there, because a new model is cut afresh.

The other per-tree nodes were already bounded, so they are unchanged:
- The young node is made once and reused.
- The stump node is replaced (the old one freed) when its key changes: fresh to mossy as it ages, and back to
  fresh at the next fell. Each cycle makes and frees two stump nodes, but no more than one is ever held.
- The trunk pivot is replaced (the old one freed) only when its key changes between the felled trunk and the
  gnawed log.

## Evidence

- **Regression tests** in `godot/test/test_demo_forestry.gd` (no staged assets needed; they use the suite's fake
  staged column):
  - The first test runs 20 complete cycles after a 2-cycle warm-up. The oak is felled (by axe and by gnawing, in
    turn, so its trunk swaps between the felled trunk and the gnawed log), hauled a load at a time and regrown.
    Beside it the second tree is blown down (uprooted) or felled and grubbed out, then replanted. The test asserts
    that these stay equal from warm-up to the end: the view's child count per cycle, `OBJECT_NODE_COUNT` and
    `OBJECT_COUNT`. It also asserts that the oak keeps the same two part nodes, and that the re-felled crown stands
    on its stub until it falls.
  - Species replacement happens once per tree: planting is always an oak, so the beech becomes an oak in warm-up
    cycle 0, and the 20 measured cycles never replace a tree. Two separate tests pin replacement. The view's own
    replaced beech and its parts are freed. The world's own beech is only hidden and stays parented to the world.
- **Staged probe** (`scratchpad/rv_d_agent/tree_cycle_probe.gd`, not committed), real oak and beech, 2 warm-up and
  20 measured cycles, with frames run between cycles:

  | Sequence | View children before the fix | View children after the fix | Process nodes after the fix |
  |---|---|---|---|
  | The review's sequence (oak only) | 10 → 52 (+2 per cycle) | 10, constant | 34, constant |
  | Oak plus uprooted/grubbed/replanted beech | 16 → 96 (+4 per cycle) | 13, constant | 38, constant |

  In the second sequence, `OBJECT_COUNT` stays level after the fix (2048 → 2048), where it grew by 80 before.
  `OBJECT_RESOURCE_COUNT` was 133 throughout, both before and after.

- **Mutation run** (each applied alone to `forest_view.gd`, the forestry suite run, the file restored and its
  shasum checked): 11 mutants, 10 killed. The survivor sets the fall's rest pose to the tree node's transform
  instead of `node.transform * parts[2]`. It is equivalent under the suite's fake column, whose mesh sits at
  identity in its model, so `parts[2]` is identity. This line predates the fix (it was
  `_rest[t] = _upper_nodes[t].transform`).

## Not done here

F52 (the tree's jump from sapling to mature silhouette, and a stump shoot's jump to the trunk's centre on regrowth)
was assessed but is out of this fix's scope. See the review hand-back.
