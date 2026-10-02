# Art pass 3: icon briefs and prompts, in both candidate styles

[Decision 0971](../decisions/0971-art-pass-3-preserving-brewing-digging-and-free-effects.md). Brendan approved nine
icons on 2026-10-02:

- preserving and brewing: jam, pickles, dried fruit, cheese, ale and cider;
- digging finds: coins, an old map and a spring.

**Ruled 2026-10-02: style A.** Brendan ruled that item and dish icons stay in the 3D-render style of the pantry
icons, and the world keeps its look (decision 0971, after the icon-style probe, decision 0981). Style A's sheet was
generated as written below:
- **sheet:** `assets/library/icon/sheet_preserves_finds/sheet.png`, task `01a0fc94-6141-7684-be9b-4193024f9aab`, 6
  credits;
- **cut:** by `python3 tools/make_art_pass3.py --icons` into `godot/demo/assets/icons/<key>.png`, 128 px RGBA;
- **review:** `art3_check/icons_dark.png` and `icons_light.png` (native and 32 px, beside `item_strawberry` and
  `find_flint`).

Style B was not generated. Its prompts stay here as the record of what the comparison would have been. Each icon was
briefed once and prompted twice:

- **Style A, 3D render.** This matches the pantry icons already in the game:
  - pass 1's sheets (`assets/library/icon/sheet_foods_a`, `sheet_dishes_b`, `sheet_dishes_c`, decision 0941);
  - the finds' Blender renders (`find_flint`, `find_clay`, from `make_demo_props.py`).
- **Style B, watercolour with ink contours.** This is the UI art lock's production target
  ([`asset_generation_lock.md`](../design/ui_refinement/asset_generation_lock.md) §2–§4): storybook watercolour, I01
  ink contour, the twelve I-pigments, upper-left light, transparent RGBA, no backing disc.

Style A's map carries scribbled pseudo-lettering and a compass rose, and one of its coins has a square hole. Both
depart from the briefs but do not read at 128 px, so no redo was bought.

## The briefs (style-independent)

Each brief follows the lock's §5 columns. The **object** and its **state** are the same in both styles, so the two
probes compare finish, not content. The keys are proposed; the preserving and brewing branches name the final ones and
wire icons by key (pass 1's `index_collisions` note).

| Key | Exact object | Angle / state | Shape that survives 24 px | Pigments (style B) |
|---|---|---|---|---|
| `item_jam` | One squat glass preserve jar of deep red berry jam, a cloth cover tied on with string; no spoon, bread or label. | Front, 25° elevation; jar upright. Full and sealed. | A squat jar with a frilled cloth cap wider than its neck. | I10 jam with I02 depth; I03 cloth; I09 string; I04 glass edge light |
| `item_pickles` | One taller stoneware crock-jar showing green pickled gherkins and onions through its open mouth, a sprig of dill; no lid on it. | Front, 30° elevation. Full; brine at the brim. | A tall rounded jar with a small green cluster at its top. | I12 stoneware; I06 pickles; I05 dill; I03 onion |
| `item_dried_fruit` | A small heap of dried apple rings and dark dried berries on a square of cloth; no basket, no string of rings. | Front-right three-quarter, 35° elevation. Dry, wrinkled. | A low mound of pale rings (each with a hole) over a dark speckle. | I11/I03 apple rings; I09 berries; I03 cloth |
| `item_cheese` | One wedge cut from a round yellow cheese, its rind on the curved back, a few small holes; no knife, board or mouse. | Front-left three-quarter, 30° elevation; point to the screen left. Fresh cut. | A clean triangular wedge with one curved side. | I11 cheese; I08 rind; I04 cut-face light |
| `item_ale` | One wooden tankard of brown ale with a white head, stave-built with two hoops and a handle at screen right; no barrel, no spill. | Front, 20° elevation. Full; the foam just over the rim. | A cylinder with a foam cap and a side handle loop. | I08 staves; I09 hoops/handle; I10 ale; I03/I04 foam |
| `item_cider` | One stoneware jug of golden cider with one red apple beside it at the foot; no cup, no barrel. | Front, 25° elevation; handle at screen right. Sealed with a cork. | A round jug with a narrow neck and a small round apple at its foot. | I12/I08 jug; I11 cider glimpse at the lip; I10 apple; I09 cork |
| `find_coins` | Five old dull bronze-and-silver coins in a small spill, two on edge in a little heap of earth; no chest, purse or gleam. | Front, 30° elevation. Just dug: earth on them. | A small cluster of overlapping discs. | I07 bronze; I12 silver; I09 earth |
| `find_old_map` | One rolled parchment map half unrolled, a faint inked path and a tree mark on it, a torn corner; no lettering, seal or compass. | Front-right three-quarter, 30° elevation; roll at the left. Old and creased, earth-stained. | A wide sheet with a curled roll at one end. | I03 parchment; I09 stains and roll recess; I01 faint path |
| `find_spring` | Clear water welling up between three wet stones and running away in a short trickle; no well, bucket or pipe. | Front, 35° elevation. Fresh, rising; ripple rings on the pool. | A small round pool with a bright welling centre among dark stones. | I12 stones; I05/I04 water (no new blue: lock §3); I02 wet shade |

**Already in the game: style A's cheese.** Pass 1's `sheet_dishes_c` cell (1, 2) is a wedge of yellow cheese in
exactly style A, and it was never cut. If Brendan chooses style A, `item_cheese` is that cell, cut by
`make_demo_food_art.py`'s own cutter at no cost. The sheet below keeps a cheese cell anyway, so the two can be
compared; either may be used.

## Style A — the 3D render style (matches the pantry icons)

**One call: a 3×3 sheet** on nano-banana-2 image-to-image (6 credits). It is conditioned on pass 1's
`assets/library/icon/sheet_foods_a/sheet.png`, as `sheet_dishes_b` and `sheet_dishes_c` were. It is cut into 128 px
transparent PNGs by `make_demo_food_art.py`'s cutter: the border flood fill, the soft edge and the 4 px margin.

The finds sit in the same sheet. Unlike `find_flint`/`find_clay`, they have no library model to render, and a sheet
keeps the nine consistent.

Sheet `sheet_preserves_finds`, cells in reading order:

> Icons in exactly the reference's style: painted stylized-realistic 3D, soft light from upper left, three-quarter
> view from above. 3x3 grid, nine separate items centred in cells, wide margins: 1 squat jar of red jam, cloth cover
> tied with string; 2 stoneware jar of green pickles, dill; 3 dried apple rings and dark berries on cloth; 4 wedge
> of yellow cheese; 5 wooden tankard of ale, white head; 6 stoneware cider jug, red apple; 7 old bronze and silver
> coins in earth; 8 half-unrolled old parchment map; 9 clear water welling between wet stones. Flat light grey
> background, no shadows, no text.

That prompt is 595 characters, under Meshy's 600 limit. It is image-to-image, with reference
`assets/library/icon/sheet_foods_a/sheet.png`.

## Style B — the UI lock's watercolour with ink contours

**Three calls: three-cell sheets** (lock §6: three equal cells in one row, at least 12.5% empty margin per cell, no
cell borders, captions or touching shadows). Each call gets the same references, palette and light:

1. `docs/design/ui_refinement/visuals/05_woodland_art_concept.png`, the family finish (lock §2);
2. IMG-04 (`docs/art-reference/reference_manifest.json`), for domestic objects and cloth (DEC-036);
3. a swatch strip of I01–I12, made locally from the lock's §3 hex values;
4. after the first call, its chosen output as a fourth reference (lock §6: "retain that probe as an additional style
   input").

The model is nano-banana-pro image-to-image (9 credits each, **27** for the three). At nano-banana-2 it would be 18.
The pro model is proposed because the lock's 24 px diagnostics are strict.

The cut follows the lock, not pass 1's cutter:
- native 24/32/48/64 px exports;
- an I01 contour of 1 px (1.5 px at 48/64);
- the FOREST surface's I04 keyline variant;
- the shadow clipped to §4's offsets;
- the sheet and crop manifest saved.

Every prompt opens with the same family clause:

> Storybook watercolour game icons, dark green-black ink contour round each silhouette, soft pigment washes in clear
> forms, the finish of image 1, only the colours of image 3. Diffuse light from upper left, no glow or gloss. Three
> equal cells in a row, one object centred in each, wide margins, plain off-white paper, no frames, no text.

Then one sentence per cell, from the briefs:

- **Sheet B1, preserves:**
  > Left: squat glass jar of red jam, cloth cover tied with string. Middle: tall stoneware jar of green pickles and
  > onions, dill sprig. Right: low heap of dried apple rings and dark berries on a cloth.
- **Sheet B2, dairy and drink:**
  > Left: wedge of yellow cheese, rind on its curved back, small holes. Middle: stave-built wooden tankard of brown
  > ale, white head, handle right. Right: corked stoneware cider jug, a red apple at its foot.
- **Sheet B3, digging finds:**
  > Left: five dull old bronze and silver coins in a little heap of earth. Middle: half-unrolled creased parchment
  > map, faint inked path, no lettering. Right: clear water welling between three wet stones into a small rippled
  > pool.

Each full prompt (the family clause and one sheet's cells) is 533–562 characters, under Meshy's 600. If a call refuses for
length, trim adjectives in the family clause, never the object.

## Cost of either ruling

| Ruling | Calls | Credits |
|---|---|---|
| Style A | 1 sheet (nano-banana-2) | **6** (the cheese then comes free from pass 1's sheet) |
| Style B | 3 sheets (nano-banana-pro) | **27** (18 on nano-banana-2) |
| Both, for a side-by-side probe | 4 | 33 |

Style A was ruled and made: 6 credits. Pass 3 spent 228 of its 270-credit cap.
