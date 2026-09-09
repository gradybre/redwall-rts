# 0029 — A 4×4 deposit is sixteen independently exhaustible nodes
Date: 2026-09-09 · Status: **Accepted — planner ruling**
Amends: `game_gdd.md` §5.1

## The gap
§5.1 specifies "stone deposit origin (44,70), footprint 4×4, quantity 1200 U"
and an iron equivalent, but §4.2's `ResourceNode` row has **no footprint field,
no origin and no extent**, and `WorldTileMaps` holds one `resource_slot` per
tile. The deposit could not be represented as written. This blocked REQ-SET-009.

## The ruling — Option A
Sixteen independently exhaustible `ResourceNode` rows per deposit. **Per-tile
depletion is the intended visible behaviour**, not a side effect to be hidden.

| Deposit | Footprint (inclusive) | Nodes | Per node (milli-U) | Total (milli-U) |
|---|---|---:|---:|---:|
| Stone | `x=44..47, z=70..73` | 16 | 75000 | 1200000 |
| Iron | `x=32..35, z=60..63` | 16 | 18750 | 300000 |

Tile index remains `tile_id = z * 128 + x`.

- Nodes are created in **ascending tile-index order**.
- An ore footprint tile containing a tree node has that node **replaced before**
  the ore node is published, preserving one-resource-node-per-tile.
- Each node exhausts independently of the other fifteen.
- The two deposits occupy **32 of the 4096** `ResourceNode` rows.

§5.1 is amended to state that a deposit's listed quantity is the **sum across
its footprint**. **No `ResourceNode` footprint column is added.**

The separately specified renewable bedrock access at `(48,70)` is unchanged and
is not part of either deposit total.

## Why this over one spanning node
Option A needs no schema change and divides exactly in the units the schema
stores — `1200/16 = 75 U` and `300/16 = 18.75 U = 18750 milli`, both exact. The
alternative required either a footprint field or making the store's node→tile
map one-to-many, and it hid per-tile depletion the planner wants visible.

## Consequences
- A quarry visibly works out one tile at a time.
- Verification covers node counts, coordinates, per-node quantities, the summed
  totals, tree replacement, and independent exhaustion.

## Source
Planner ruling, 2026-09-09, responding to `chatgpt-prompts/READY_05_planner_rulings.md`.
