# `godot/ui/` asset provenance

Every file under `godot/ui/` with its source, author, licence, alterations and where it is
used. Added for task 04.4's first-playable UI shell under
`docs/planning/ui_visual_direction.md`. **No paid generation was used or authorised.**

## Fonts — `godot/ui/fonts/`

SET-UX-001 §2.1 fixes the runtime paths: "`res://ui/fonts/NotoSans-Regular.ttf`,
`NotoSans-Medium.ttf`, `NotoSans-SemiBold.ttf`, `NotoSans-Bold.ttf`" and rules "No OS font
substitution in qualification builds."

| File | Source | Author | Licence | Alterations |
| --- | --- | --- | --- | --- |
| `NotoSans-Regular.ttf` | `notofonts/notofonts.github.io` → `fonts/NotoSans/hinted/ttf/` | The Noto Project Authors | SIL Open Font License 1.1 (`OFL.txt`) | None. Byte-identical to the upstream file. |
| `NotoSans-Medium.ttf` | same | same | same | None |
| `NotoSans-SemiBold.ttf` | same | same | same | None |
| `NotoSans-Bold.ttf` | same | same | same | None |
| `OFL.txt` | `google/fonts` → `ofl/notosans/OFL.txt` | The Noto Project Authors | SIL OFL 1.1 | None |

**These are four genuinely different weights, not one file renamed four times.** Each file's own
OpenType `name` table was read before vendoring: `NotoSans-SemiBold.ttf` reports family
"Noto Sans", subfamily "SemiBold" and licence "SIL Open Font License, Version 1.1"
(`https://scripts.sil.org/OFL`). `test_ui_theme_resource.gd` re-checks the four style names at
runtime, so a future substitution fails the suite rather than passing unnoticed.

SHA-256 as vendored, retrieved 2026-09-11:

```
1df075a380fc7cb898acf64c1f7b3b4dd780de3caa860178bf929de35817a913  NotoSans-Bold.ttf
635d93d1131d791f2576de90b3bb0f7cdf61929906e8420a61b5f7f8e76420bb  NotoSans-Medium.ttf
478c558ea716033cd60c03438f628dfa75694dcf6b5f6d505a2f05fd2b4f3823  NotoSans-Regular.ttf
a4e91fd530ac2b4ef5367240144ff37d7d65d66cf76f2e9a2187b93c676f92d0  NotoSans-SemiBold.ttf
```

Usage: `woodland_theme.tres` alone. Body 16/400, secondary 14/400, panel title 20/600, page
title 28/700, counters 18/600 with the `tnum` tabular-figure feature.

## Theme — `godot/ui/theme/`

| File | Origin | Notes |
| --- | --- | --- |
| `woodland_theme.tres` | Generated, this repository | A **build product** of `scripts/ui/ui_theme.gd`'s §2.1 tokens. Do not hand-edit; regenerate. |
| `build_woodland_theme.gd` | Original, this repository | The generator. `godot --headless --path godot --script ui/theme/build_woodland_theme.gd` |

The theme is applied once at the UI root (`ui_shell.gd`), and every control selects a theme type
variation named after its §2.2 profile. No control carries its own palette.

## Icons — `godot/ui/icons/`

**Original work for this repository**, authored as hand-written SVG paths. No icon pack, no
traced reference image, no generated art. Grid 24x24, nominal 2 px strokes, stroke colour
`#F5F0DF` (TEXT) tinted per state by the theme's `icon_*_color` entries. Licence: same as the
repository.

| File | Subject | Used by |
| --- | --- | --- |
| `provisions.svg` | A provision bowl | UI-SET-002 food counter, UI-SET-030 food orders |
| `fuel.svg` | A hearth flame | UI-SET-003 fuel counter |
| `wood.svg` | Stacked logs seen end-on | UI-SET-004 wood counter |
| `stone.svg` | A cut block | UI-SET-005 stone counter |
| `residents.svg` | Two figures | UI-SET-006 population counter, UI-SET-031 roster |
| `beds.svg` | A bed with a bolster | UI-SET-007 bed counter |
| `ledger.svg` | A ruled page | UI-SET-008/009 ledger, UI-SET-102 history |
| `calendar.svg` | A ruled calendar leaf | UI-SET-101 date trigger |
| `pause.svg` | Two bars | UI-SET-014 pause |
| `map.svg` | A folded map | UI-SET-022 minimap layers |
| `brush.svg` | A marking brush | UI-SET-028 zone command, UI-SET-059/062 brush |
| `build.svg` | A builder's square | UI-SET-027 build, UI-SET-029 jobs |
| `cancel.svg` | A struck circle | UI-SET-067 cancel, UI-SET-093 close |
| `menu.svg` | Three rules | UI-SET-019 game menu |
| `lock.svg` | A closed lock | §2.2's "disabled PANEL/MUTED+lock icon", on every unavailable control |
| `warning.svg` | A warning triangle | UI-SET-085's refusal display, so a failure carries an icon and words, never colour alone |

## Ornament — `godot/ui/ornaments/`

| File | Subject | Used by |
| --- | --- | --- |
| `sprig.svg` | A restrained leaf sprig rule, GOLD `#E6C77A`, 48x16 | The detail panel and workspace frame title margins |

**Original work for this repository.** Drawn sparsely and at 55% alpha so that selection and
keyboard focus stay the most prominent gold on screen. Every ornament instance ignores the
mouse, cannot take keyboard focus and carries an empty accessible name, so it is outside both
the hit-test table and the screen-reader tree.

## Reference material

`ImageReference/` and `docs/art-reference/` informed the tone only. **No reference screenshot was
cropped, traced or shipped as an asset**, and none is a production UI asset or a gameplay rule.

---

# Task 04.5b woodland art family — ART-UI-01 to 08 and 11

Added by the art pass for [SET-UX-VIS-002 revision 3](../../docs/ui_visual_refinement_amendment.md)
under [the art-finish specification](../../docs/design/ui_refinement/visual_art_direction.md)
and [ART-LOCK-001](../../docs/design/ui_refinement/asset_generation_lock.md), which settles
the sixteen asset identities, the twelve illustration pigments, the numeric light rig and
the contour ruling. **No paid generation was used or authorised. Every file below is
hand-authored SVG committed as its own editable source.**

## Where the machine-readable record lives

`godot/ui/ui_art_manifest.json` is the manifest ART-UI-11 asks for: 80 rows, each with the
stable ID, the single source path, the category, the optical widths it is delivered at, the
document size, the **measured** opaque bounding box and the source SHA-256. It is generated
by `ui/tools/build_manifest.gd` from the real rasters, never written by hand, and
`test/test_ui_art.gd` re-checks every digest against the file on disk, so an edited source
with a stale manifest fails the suite.

`godot/ui/ui_art.gd` is the registry the manifest, the exporter and the tests all read. It
holds the IDs, paths, categories, optical sizes, stretch margins and corner extents. It
declares **no colour token**: the twelve pigments listed there are decorative inks used
inside illustrations, and `test_ui_art.gd` proves none of them shadows a §2.1 token.

## Illustration pigments (ART-LOCK-001 §3) — decorative, not UI tokens

| ID | Hex | Role |
| --- | --- | --- |
| I01 Ink | `#25372D` | Permanent object contour, facial ink, dark linework |
| I02 Deep shade | `#14211B` | Occlusion, ember base, cast shadow |
| I03 Oat | `#EAE1C8` | Pale cloth, bowl interior, medallion field |
| I04 Cream | `#F5F0DF` | Small highlights and the FOREST separation keyline |
| I05 Sage | `#708171` | Cool leaf variation, muted cloth |
| I06 Leaf | `#466647` | Stew greens and the shared garment green |
| I07 Brass | `#B49A58` | Muted medallion ring, restrained fittings |
| I08 Timber | `#91613E` | Wood, warm mouse and squirrel fur base |
| I09 Umber | `#594332` | Bark, dark fur, straps, wooden recesses |
| I10 Clay | `#B76545` | Ceramic, roots in stew, ear interior, flame edge |
| I11 Ember | `#D99743` | Flame core and small warm highlights |
| I12 Flint | `#8A8D84` | Stone, metal, mole and otter cool fur |

Blends between these carry the watercolour shading; this is not indexed quantisation.

## Construction rule, applied to every object icon

One light rig: azimuth 225 degrees (upper left), elevation 45, cast shadow toward the lower
right at offset (+1,+1) and 16 percent opacity. Every part carries an I01 ink contour. On
FOREST surfaces an outer I04 separation keyline is drawn **once, behind every part**, so
cream survives only outside the union of the parts — that is, on the primary silhouette and
never as a web of lines through the middle of a 24 px drawing. On JOURNAL surfaces the
keyline is omitted and the dark contour alone separates the form. There is no opaque disc
or plaque behind any resource or toolbar icon. At 24 px every visible pixel, keyline and
shadow included, fits a 22x22 box centred in the canvas; `test_ui_art.gd` measures that.

## Painted object icons — `godot/ui/painted/`

**ART-UI-03**, delivered at 24 and 32 logical px. **ART-UI-04**, delivered at 24 (the wide
and standard TOOL_COMMAND change from 18 to 24; no other toolbar geometry moves).

| Stable ID | Source | Subject (ART-LOCK-001 §5) |
| --- | --- | --- |
| `ART.RES.FOOD_READY` | `res_food_ready.svg` | One shallow olive ceramic bowl of stew, two cream roots, one leaf |
| `ART.RES.FUEL` | `res_fuel.svg` | One upright flame over two dark ember stones. No timber |
| `ART.RES.WOOD` | `res_wood.svg` | Three cut logs, two below and one above, circular cut ends |
| `ART.RES.STONE` | `res_stone.svg` | Three rough angular stones, one large rear peak |
| `ART.RES.POPULATION` | `res_population.svg` | Three upper-chest busts: mouse centre front, mole left, otter right |
| `ART.RES.BEDS` | `res_beds.svg` | One low wooden bed, cream pillow, folded moss-green blanket |
| `ART.CMD.BUILD` | `cmd_build.svg` | One wooden carpenter mallet, unbroken T silhouette |
| `ART.CMD.ZONE` | `cmd_zone.svg` | Four survey stakes joined by one slack rope into an empty diamond |
| `ART.CMD.WORK` | `cmd_work.svg` | One hand spade and one mallet crossed |
| `ART.CMD.FOOD` | `res_food_ready.svg` | **The RES-FOOD artwork exactly.** One source, two IDs |
| `ART.CMD.PEOPLE` | `res_population.svg` | **The RES-POP artwork exactly.** One source, two IDs |
| `ART.CMD.GOALS` | `cmd_goals.svg` | One partly unfurled blank oat scroll with rolled top and bottom |

Sixteen logical rows, fourteen distinct designs. Food and People do not have their own files
at all, so they cannot drift away from the art they are supposed to share.

## Narrow symbolic variants — `godot/ui/symbolic16/`

`ART.NARROW.BUILD` / `ZONE` / `WORK` / `FOOD` / `PEOPLE` / `GOALS`, 16x16 grid, 1.5 px
strokes, `#F5F0DF`. These restate the same objects in the simpler form the lock asks for at
narrow sizes rather than shrinking painted detail into noise.

## Functional glyphs — `godot/ui/icons/`

**ART-UI-05.** The task-04.4 line icons are unchanged; `check.svg` and `center_view.svg` are
new. All seven functional controls are delivered at 16, 18 and 24. They stay monochrome
single-stroke drawings on purpose: the selected check and the disabled lock are drawn at
12 px, where painted artwork is unreadable and would obscure the state it is marking.

| Stable ID | Source |
| --- | --- |
| `ART.SYM.CLOSE` | `cancel.svg` |
| `ART.SYM.CHECK` | `check.svg` (new) |
| `ART.SYM.LOCK` | `lock.svg` |
| `ART.SYM.WARNING` | `warning.svg` |
| `ART.SYM.CAMERA` | `center_view.svg` (new) |
| `ART.SYM.PAUSE` | `pause.svg` |
| `ART.SYM.DATE` | `calendar.svg` |

## Species medallions — `godot/ui/emblems/`

**ART-UI-06.** Four generic species identifiers, two optical variants each, eight files.
`ART.EMBLEM.MOUSE_48` and `_64`, and the same for `MOLE`, `OTTER` and `SQUIRREL`.

Two sizes are two files because the lock fixes the frame per size: on a 48 px canvas the
roundel is 44 px across with a 1 px ring and a 6x8 sprig; on 64 px it is 60 px with a 1.5 px
ring and an 8x11 sprig. Scaling one file would miss both. The **subject** is drawn once in a
64-unit space and placed into both canvases, so the two sizes cannot become different
animals; only the frame weights are tuned. The roundel, ring and sprig are one shared
authored overlay, not redrawn per species.

Each is an opaque I03 field inside a thin I07 brass ring inside an I01 ink contour, with the
subject at eye level, a 30-degree three-quarter turn toward screen-left, and the same plain
I06 tunic with an I03 neck edge. No hat, hood, rank, jewellery, weapon or occupation prop.

**These are species identifiers. They are not portraits, and none of them depicts a named
resident.** A resident surface must present them as their species.

### Reference provenance (DEC-036)

Anatomy was drawn from **IMG-25**, `ImageReference/Screenshot 2026-09-06 at 2.26.38 PM.png`
(1366x1026, SHA-256 `1fc1b690d54745da09b08cc21a3d0b6b19d3daa5a78182384c34a8dfbd9677f2`),
registered region `IMG-25/woodland_lineup`, pixels `[413,247,1304,565)`. DEC-036 and
ART-LOCK-001 §1 authorise using Brendan's supplied images directly as drawing references.
The image was opened and used that way; the slide's labels, arrows and count tables are
excluded from every asset, and none of its unit counts or mechanics is adopted. No pixel of
the reference is present in any delivered file — every SVG path is an original drawing.

## Ornament — `godot/ui/ornaments/`

**ART-UI-07.** The vocabulary is oak leaf, acorn, binding seam and a restrained page edge.
`sprig.svg` from task 04.4 is retained. Ornament appears at component anchors only: one oak
spray at the resource tray's top-left corner, one acorn drop at the time group's top-right,
the seam on the journal spine. There is no ornament around a row, no vine, and no gold
around a value.

| Stable ID | Source | Size | Note |
| --- | --- | --- | --- |
| `ART.ORN.SPRIG` | `sprig.svg` | 48x16 | Unchanged from task 04.4 |
| `ART.ORN.OAK_LEAF` | `oak_leaf.svg` | 28x14 | |
| `ART.ORN.ACORN` | `acorn.svg` | 12x16 | |
| `ART.ORN.BINDING_SEAM` | `binding_seam.svg` | 16x48 | Constant along Y, so it stretches |
| `ART.ORN.PAGE_EDGE` | `page_edge.svg` | 48x8 | Constant along X, so it stretches |

## Panel silhouettes — `godot/ui/frames/`

**ART-UI-01, 02 and 08.** Five containers, each with four **stretchable** edge strips and
four **non-stretching** corner pieces. The renderer owns the flat interior fill; the art
never paints over a text region, and the centre of every text region keeps its exact token
colour.

An edge strip is constant along the axis it stretches on, so it scales to any length without
a seam or a distorted motif — `test_ui_art.gd` checks that every column of a horizontal
strip equals its first column, and every row of a vertical one. All motif lives in the
corners, which are never scaled. Each corner carries its own opaque field cut to the
silhouette, which is what lets a notch, a chamfer or an angled shoulder actually cut the
outline instead of decorating a rectangle; a renderer therefore fills the cross between the
corners, not the whole rectangle.

One shallow relief direction throughout, lit from the upper left. No large bevel, no glass
highlight, no inner box around a datum.

### Stretch margins, measured from the art that exists

| Silhouette | Top | Right | Bottom | Left | Corner extents TL / TR / BL / BR | Distinguishing outline |
| --- | --- | --- | --- | --- | --- | --- |
| `resource_tray` | 8 | 8 | 8 | 8 | 18x18 all four | Thick cover frame, deep mitred notch, one oak-and-acorn spray |
| `time_group` | 5 | 5 | 5 | 5 | 16x16 all four | Thin octagonal plate, chamfered corners, one acorn drop |
| `map_folio` | 6 | 6 | 6 | 6 | 18x18 all four | Stitched leather welt, three folio pockets, one dog-eared corner |
| `journal` | 5 | 5 | 5 | **12** | 12x16 / 14x14 / 12x16 / 14x14 | Paper fore-edge, sewn spine, brass rings, closing strap |
| `command_dock` | 7 | 7 | 7 | 7 | 22x22 all four | Hexagonal plinth, deep 45-degree shoulders |

The journal is the one asymmetric case, and it is asymmetric on purpose: the bound side is a
12 px spine and the fore-edge is a 5 px paper edge. Its corner extents differ per corner for
the same reason, which is why the registry stores four corners rather than one size.

`ART.FRAME.JOURNAL.RING` (10x14) and `ART.FRAME.JOURNAL.STRAP` (14x40) are non-stretching
binding hardware, placed at intervals rather than scaled. **They are not part of the
eight-piece assembly below and have no declared anchor**, so the builder does not place them.

### How a frame is assembled — `ui/ui_frame_geometry.gd`

The table above says what the pieces are. It does not say where they go, and two attempts to
guess put the corners outside their panels. [Decision
0077](../../docs/decisions/0077-container-frame-placement-contract.md) settles it and
`ui/ui_frame_geometry.gd` is the executable copy:

* a **stretch margin** is a thickness measured **across** the strip — the height of the top
  and bottom strips, the width of the left and right ones. It is not a square extent, and not
  a gap between the panel edge and the strip: every strip is flush with the panel boundary;
* a **corner extent** is the exact draw size of that corner, equal to its source document. No
  bleed, no nine-patch margin, never scaled;
* **corners own the corners, and each strip runs between the two that bracket it**, so no
  strip is drawn underneath a corner motif;
* a panel smaller than both corner pairs plus one pixel of run is **refused by name**, not
  clamped, and a frame already applied to a panel that shrinks that far is hidden.

Applying a frame is one call, and the caller owns no geometry:

```gdscript
const UiFrameBuilder := preload("res://ui/ui_frame_builder.gd")
UiFrameBuilder.apply(panel, UiFrameBuilder.FRAME_RESOURCE_TRAY)
```

Every piece is decorative under ART-UI-07/08: `MOUSE_FILTER_IGNORE`, `FOCUS_NONE` and an
empty accessibility name, on the holder and on all eight pieces.

## Tools and review artefacts

| File | What it does |
| --- | --- |
| `ui/tools/build_manifest.gd` | Measures every source and writes `ui_art_manifest.json` |
| `ui/tools/export_art_pngs.gd` | Rasterises every asset at every declared optical size into `ui/review/exports/` |
| `ui/tools/build_specimen.gd` | Assembles the five silhouettes from their own edge and corner art on a neutral background |
| `ui/tools/build_contact_sheets.py` | Composes the labelled review sheets from those exports. Needs Pillow |
| `ui/tools/render_frame_panels.gd` | Composes each silhouette onto a flat panel at three sizes, **through `ui_frame_geometry.gd`**, into `ui/review/exports/` |
| `ui/tools/build_frame_sheet.py` | Labels and assembles those panels into `ui/review/sheets/art_frame_geometry.png`. Needs Pillow. Computes no geometry |

```bash
godot --headless --path godot --editor --quit            # import first, always
godot --headless --path godot --script ui/tools/build_manifest.gd
godot --headless --path godot --script ui/tools/export_art_pngs.gd
godot --headless --path godot --script ui/tools/build_specimen.gd
python3 godot/ui/tools/build_contact_sheets.py
godot --headless --path godot --script ui/tools/render_frame_panels.gd
python3 godot/ui/tools/build_frame_sheet.py
```

`godot/ui/review/` carries a `.gdignore`, so Godot does not import the review renders as
game resources. The five contact sheets in `ui/review/sheets/` show every icon at its
**actual delivered pixel size**, with magnified studies drawn nearest-neighbour and labelled
as such, so nothing on a sheet looks better than the asset does in the game.
`art_frame_geometry.png` is the placement sheet: all five silhouettes applied to real panels
at 132x76, 300x120 and 760x96, composed through the same `ui_frame_geometry.gd` the runtime
builder uses, so it is evidence about the contract rather than about the sheet script.

**No review render is a runtime asset.** Nothing under `ui/review/` is loaded by the game,
and the AI concept image at `docs/design/ui_refinement/visuals/05_woodland_art_concept.png`
was never cropped into a panel, never sampled for a colour and never baked into a texture.
