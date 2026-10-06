# 1206 — Stone carry: the procedural stone lump as the hauled stone

Date: 2026-10-06 · Status: In progress. Step 1 (source capture) done; blocked on the carried scale (Brendan)

## Brendan's decisions (2026-10-06)

| Question | Decision |
|---|---|
| Stone inputs (ADR 1203) | **Author a stone carry**: carry, load and unload rows, with the same native capture, proofs and grip certificate as wood. |
| Which mesh is the carried stone | **The procedural stone lump**, `bore_dressing.gd::stone_mesh()` (`godot/demo/tunnel/bore_dressing.gd:329`). |

The pinned demo assets have no stone part. `all-cast-v5…v9`, `mole-grip-v1…v3` and `pilot-v1…v4` carry
only the body, `log`, `mole_pick` and eleven vegetable props. The demo's hall and infirmary draw carried stone
as a `basket` prop, which exists only in side checkouts. Brendan chose the lump.

Stone is compiled item **53** (ascending-ASCII ids over `item_definitions.json`, as wood is 60). Its catalog mass
is 5,000 g/unit, the same as wood, so a 1,000-milli trip needs no new balance constant.

## Step 1 — exact source capture (done)

`haul-handling-v1/native_capture_stone/capture_stone.gd` runs inside the game project and calls the real
factory, never a re-typed copy. Output is `evidence/stone-source-v1/native-stone.json`.

- **Capture.** It contains every committed vertex and index of surface 0: 70 vertices, 108 triangles, indexed
  `PRIMITIVE_TRIANGLES`, format `34359742487`. The unit lump's AABB is about 2.12 × 2.08 × 2.00 (radius ≈ 1).
- **Pins** (`evidence/stone-source-v1/source-sha256.json`):

  | File | SHA-256 |
  |---|---|
  | factory `bore_dressing.gd` | `31000317…` |
  | `capture_stone.gd` | `b2710cd4…` |
  | `native-stone.json` | `ddcb70bf…` |

- **Reproducible.** Two runs give identical bytes. `test_stone_source.py --godot godot` reruns the capture and
  requires identical bytes. It also checks the pins and topology (5 tests).

**No palette bake is needed for the geometry.** The wood stock also entered the haul image through a factory
capture (`native_capture/capture_stock.gd` → `native-stock.json`), not through a palette. The palette supplied
only the carry clip's body pose, and that pose is reused unchanged for stone. Baking a stone carry into a new
palette would first need a stone hold binding in `demo_actor.gd`, which does not exist. Authoring one would
invent presentation. So no palette was written. The existing palettes are untouched.

## Blocked — the carried stone's size (needs Brendan)

The factory makes a **unit** lump. The wood's carried size came from demo constants, `0.9 × 0.055` radius, in
`demo_actor.gd::_build_load`. No constant gives a carried stone's size. The only existing values are the
tunnel dressing's:

- `STONE_MIN_M` 0.035 and `STONE_MAX_M` 0.09;
- the dressing's literal 0.8 vertical squash;
- a random orientation.

Every later step depends on this choice: the grip contact, the program, the loaded gait, the boxes and the
certificate offsets.

**Recommendation:** use `STONE_MAX_M` with the 0.8 squash and identity orientation. This gives about
0.191 × 0.150 × 0.180 m. Both values are existing constants, and it is the largest stone the world already
draws. **Consequence:** the hands sit about 0.19 m apart, against about 0.68 m on the log. That is a new
two-hand grip, not a retargeted one, so it needs the full static-contact candidate series and its review
(ADR 1144 took eight candidates for wood).

**Alternative:** a larger stone sized to the existing carry clip's hand span. That would be a new size
constant, so it needs Brendan's explicit approval.

## Remaining steps (after the size is set)

1. Static contact candidates and the exact hand–stone witnesses. Then a grip review, as wood's
   static-contact-review-v1 had.
2. The four-phase program.
3. The loaded gait.
4. The stand/walk joins.
5. Native image v9, using sibling tools; v8 stays untouched.
6. The integer rows, with the corrected `clipped_triangle_floor` maximum.
7. Content 6, as the successor of `qualified-haul-v6`.
8. The certificate extension, the consumer switch and renewed pins.
9. The Delivery test for a tool-free stone haul from R to M.

Image sizes and the joint memory census (ADR 1198 open item, 100 MB gate) are recorded at step 5.
