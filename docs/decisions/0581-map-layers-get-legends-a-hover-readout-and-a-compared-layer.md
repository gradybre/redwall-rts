# 0581 — Map layers get legends with units, a hover readout and a compared layer drawn as outlines
Date: 2026-10-01 · Status: Accepted (feature #40, approved by Brendan 2026-10-01); the PROPOSALS below await his ruling

Feature #40, "better map layers", over the layers decision 0292 built (`demo/map_lenses.gd`, the Map layer picker):
a legend with units and thresholds, a hover readout of the exact value under the pointer, a way to compare two
layers, the picker kept with V still cycling, and quality -- one set of colour tokens, a colour-blind check, reduced
motion, and overlays that read under the lighting branch's night. Decision numbers 0581–0589 were assigned; this
record uses 0581 only.

## Rules used

- **UI §1.1 / UI-SET-022**: the layers belong with the minimap, bottom left. The picker keeps decision 0292's slot;
  the legend and the compare row live in its card, which already scrolls where its slot is short (decision 0391).
- **UI §2.1**: text never relies on a variable world background -- the readout is an opaque card (the parchment of the
  demo's own tooltips, `woodland_styles.gd PIECE_MAP`); 14 px floor; 32 px targets (the ✕ is 32 px square).
- **UI §2.2 OVERLAY profile**: "dedicated opaque PANEL label if text; world shape outlined INK then …; fade 80 ms unless
  reduced motion". The readout fades over 80 ms and appears at once with Reduced motion on (REQ-UX-008, UX-T13); the
  compare outlines carry an INK core.
- **UI §3 layer 60** (tooltips IGNORE the mouse, never trap focus): the readout ignores the mouse and hides while the
  pointer is over any panel.
- **The numbers are the rules' own**, never restated by hand: moisture bands are farm_sim.gd `band_at` over §5.6's crop
  ranges with farming.gd's MOISTURE_NEAR_MARGIN; ripeness is farm_look.gd's 48 h grace and farming.gd's
  RIPE_WITHER_HOURS (120); the leat is farm_sim.gd's LEAT_PER_DAY and WET_ABOVE_TOP; the water is the water map's
  integer depth against water_rules.gd's per-body thresholds; the woods are §5.9's floors (forest_zones.gd).
  `lens_scales.gd check_figures` fails a test if a legend's quoted figure drifts from its rule.
- **Decision 0292's ONE AT A TIME** (two layers' marks never share the map) is kept: the compared layer never shows
  its own marks; it is drawn only as outlines (below). This record amends 0292 to say so.

## Decision

### 1. A layer is data, with a scale, its areas and an optional probe

`map_lenses.gd` rows gain a **scale** (which swatches form the ordered ramp, a threshold line per ramp entry, a caption
with units), the swatches that are **areas**, the ground they are painted **over** (for the colour check), and a
**probe** (`lenses/lens_probe.gd`) that says what lies at a ground point. A whole layer can be added as one record,
`lenses/lens_def.gd`, through `add_def` -- this is how the seasonal-trees and winter-fuel branches should add theirs
(the record's header and `godot/demo/README.md` "Adding a layer" show it). The village's existing layers get their
scales from one table (`lenses/lens_scales.gd`, found by group and label) and their probes from the kit, so their
registration lines in `demo_farm.gd` and `demo_village.gd` are untouched.

### 2. The legend

`ui/demo_lens_legend.gd`: the caption, then the ramp as one continuous colour bar with each entry's word under its
segment and its threshold under that ("wade / ≤0.25 m"), then the other entries as key chips. The segments flow onto
a second line where the card is too narrow, rather than widening it.

**Kept short for 1280x720.** A first version drew a row per ramp entry and a "Compare with… ▾" row in the card; the
moisture card grew from 127 px to 273 px and the layout harness's check that the guide's objective card still shows
above the picker at 1280x720 100 % (decision 0481) failed. The bar form and the compare control in the header bring
the moisture card to 154 px, and the check passes again. The Water range's depths and caption come from its probe for whoever is painted
(a group by its shortest member, decision 0292 §3). A layer given its scale after its legend was built is rebuilt on
the next re-text.

### 3. The hover readout

`ui/demo_lens_readout.gd`, driven by `lenses/demo_lens_kit.gd`. Ten times a second on real time (it works paused) the
kit picks the ground under the pointer (`demo_layers.gd pick_ground`) and asks the shown layer's probe, and the
compared layer's, for a Reading -- integers only: legend entry, area class, exact value, whose. Words are formatted
only when a Reading or a probe's field revision changes. The pointer is followed from its motion events (a headless
window reports no position of its own). Probes: the three Growing layers (`bed_lens_probe.gd`, which caches each bed
per sim revision because the sim's readouts hand back result objects), the Water range (`water_lens_probe.gd`, one
field evaluation into a kept sample), the Woods (`woods_lens_probe.gd`: a tree within 1 m, else the zone). Routes and
Underground have none.

### 4. Comparing two layers: outlines

Picked from the picker's header (the button between the layer's name and Off -- two overlapping squares -- which
unfolds the layers that can be outlined, in the card); while one is outlined the button stays pressed and the card
says "Outlined: Growing: Water service ✕"; picking it again or ✕ turns it off. The compared layer's areas
are traced by marching squares over its probe's field (`lenses/lens_contours.gd`), each area as a strip in its own
legend colour on its inside round an ink core, time-sliced at about 1 ms a frame, redrawn only when the compared
probe's field revision moves. Only layers whose probe can outline are offered (the Growing layers, the Water range,
the Woods' zones while any exist); none while the Underground (U's view) is shown; the compared layer is dropped when
it becomes the shown one or no layer is shown, and kept when V or the list moves the shown layer to another.

Frames looked at (1920x1080): moisture filled with the leat's service outlined reads as each bed tinted by its band
and ringed by its service (`lens_compare_beds`); the water range with the moisture outlined shows both at once
without either's colours mixing (`lens_compare_water_moisture`).

Rejected: a **split screen** (each overlay is its own node tree, several with their own shaders; clipping every one to
a screen half means editing every overlay's material, and the two halves show different ground); **both layers'
fills at once** (decision 0292's fault: two translucent fills multiply into colours neither legend has); **iso-lines
from a float field** (the layers are classes, not continuous fields; bed and zone layers have no gradient).

### 5. Colours: one set of tokens, checked for colour blindness

`lenses/lens_palette.gd` holds every area colour; `farm_look.gd`'s disc colours and `water_overlay.gd`'s zone colours
now read it. `lenses/lens_colour_check.gd` simulates deuteranopia and protanopia (Machado, Oliveira and Fernandes
2009, full severity, on linear RGB) and requires every pair of a layer's area colours to stay at least delta E 10
apart (CIE76) in the legend and by day (composited at its alpha over its ground), and 8 by night. Measured before this
change: moisture's wet/waterlogged pair was 7.6 by day for normal vision and dry/low 7.4 with deuteranopia; ripeness's
growing/past-its-best was **3.7** with protanopia (green against red-orange). New ramps (worst pair after): moisture
22.9 by day, 17.8 by night; ripeness 22.4 / 19.5. Waterlogged stays a calm tint (alpha under 0.5, not a blue slab:
test_demo_farm_ui.gd). The water's zones and the leat's service already passed and are unchanged. The live harness
runs the check over every layer the village has, so a layer added later is checked too.

### 6. Night lighting

Every layer's marks were already **unshaded** (bed discs, the water's zone shader, the forest marks, the route lines,
the tunnel overlay), so the moon's dimmer light and the lamps do not reach them. The new outlines are unshaded, ignore
the fog (`disable_fog`) and the depth test, and take their vertex colours as sRGB. What still reaches every overlay is
the frame's post-process: the lighting branch's (decision 0541, not on this branch) night saturation of 0.74 and its
haze (about an eighth at the camera's distance). The colour check's night viewing applies exactly that, and every
ramp passes it. The harness's capture also renders a stand-in night (that saturation, haze and a 0.34 blue moon):
`lens_night_moisture_service` and `lens_night_water` show the tints and outlines as clear as by day.

### 7. Keys

No key is added. V still steps the shown layer, U still follows the underground; compare is in the picker only.

## PROPOSALS for Brendan

1. **Compare as outlines** (built). Options: (a) outlines of the second layer's areas over the first's fills -- built;
   (b) a draggable screen split; (c) a quick toggle that flips between the two layers. Recommendation: (a); (c) could
   be added as a key later if wanted.
2. **The outline's colours.** UI §2.2 says world shapes are "outlined INK then GOLD"; GOLD is the selection colour,
   so the outlines use INK then the area's own legend colour. Options: keep, or add a GOLD rim. Recommendation: keep.
3. **The readout beside the pointer** (built) rather than a fixed line in the picker card. Options: beside the
   pointer; in the card; both. Recommendation: beside the pointer (it is where the eye is), as built.
4. **The colour-blind floors** (delta E 76 of 10 by day, 8 by night; Machado full severity). No document sets them.
   Recommendation: keep; tighten to CIEDE2000 if a reviewer wants a perceptual metric.
5. **The new moisture and ripeness colours** (orange / pale tan / sage / periwinkle / indigo; blue-grey growing, gold
   ripe, plum past its best). An art call: growing is no longer green, because green against red is the classic
   protanopia confusion. Recommendation: keep; any replacement must pass `test_every_ramp_passes_the_colour_blind_check`.
6. **No readout for Routes and Underground.** Routes are lines, not areas; a readout could name the nearest drawn
   stretch. Recommendation: leave until asked.
7. **"Not served" and "empty" are outlined too** (in their dull colour), so every bed is ringed when the leat's
   service or the ripeness is compared. Options: outline them; leave them out. Recommendation: outline (it says
   "not on the leat" rather than leaving a gap).
8. **No keyboard or gamepad route to the readout** (UI §8 asks keyboard alternatives for world picks). Options: read
   at the camera's centre when no pointer is in use; read at the keyboard-focused object (the F6 object list); leave
   it to the bed, water and woods panels, which give the same figures. Recommendation: the camera's centre, behind a
   setting, if wanted.

## Not done, and why

- **The Woods' tree marks** (`forest_marks.gd STATE_COLOURS`, the woodland palette's LEAF / UMBER / CLAY / BRASS) fall
  under the floor for one pair: mature (LEAF) against stump (UMBER), 8.6 with deuteranopia in the legend and 7.8 by
  night. They are point marks drawn on the trees themselves (a standing tree and a stump look different), not area
  fills, so they are outside the area check; they belong to the forestry owner. Also, BRASS is both the forestry
  zone's colour and the young tree's (a zone is an outline, a tree a disc).
- **The lighting branch is not merged here**; the night is checked numerically against its published curves and
  rendered with a stand-in, not with its own nodes.

## The independent review, and what changed

The code review (HIGH findings, all fixed): (1) the moisture readout kept the old band edges after a crop was chosen
-- the moisture and band were unchanged, so the Reading was; probes now have a `words_revision` (the bed probe's is
the sim's revision) and the readout re-words when it moves; (2) the water readout kept an old body's name at the same
height, and every millimetre of ice re-traced the outline -- the water's `field_revision` is now the areas' alone
(height, ice state) and its `words_revision` adds the ice's thickness and the body's name; (3) a slice could overrun
its millisecond by tens of milliseconds, because a whole row was sampled between looks at the clock and the Woods
probe searched every tree for every grid corner -- sampling now looks at the clock every 16 corners, through a new
cheap `area_at_into` (the Woods': zones only); (4) the readout drew on canvas layer 0, under the picker -- it is on UI
§3's tooltip layer (60), at the OVERLAY profile's 16 px. Also fixed: a compared layer that loses its field (the last
zone removed) is dropped (`settle_compare`); the pointer is forgotten when it leaves the window; Off can never take a
probe; a treeless village skips the tree check instead of passing it. Not changed: outlines over the stream are drawn
at y 0.05 while its paint lies about 0.14 m lower (about a strip's width of parallax at the camera's pitch), and the
readout picks the y = 0 plane; the colour check composites in sRGB where the renderer blends in linear, so its
figures are approximate (both recorded here).

## Consequences

- Shared files touched: `map_lenses.gd` (the scale, areas, probe and compared-layer columns and rules; decision 0292's
  file), `ui/demo_lens_picker.gd` (the legend class and the compare row), `demo_village.gd` (three lines in
  `_build_lens_picker`, a preload, a var and `lens_kit()`), `farm/farm_look.gd` and `water/water_overlay.gd` (their area
  colours read the tokens).
- New: `demo/lenses/` (lens_def, lens_probe, bed/water/woods probes, lens_scales, lens_palette, lens_colour_check,
  lens_contours, demo_lens_kit), `ui/demo_lens_readout.gd`, `ui/demo_lens_legend.gd`.
- Tests: `test_demo_lens_probes.gd` (each probe at its boundaries, the words, allocation, the scales' figures, the
  tokens, the colour check and that the old ramps fail it), `test_demo_lens_kit.gd` (the record, areas, the compare
  rules, the outlines' marching squares, slicing and material, the readout's words, place, fade and reduced motion,
  the legend, the kit's throttle and tracing, the picker's compare row), `test_demo_lens_live.gd` running
  `test/live/demo_lens_live.gd` at 1280x720 and 1920x1080 (legends, readouts on the real village, compare, reduced
  motion, the colour check over every layer).
- Allocation checks count objects and retained static memory over hundreds of reads; transient Variant allocation is
  not observable from GDScript.
- Mutation testing (65 mutants of the new logic, one at a time in a copy of the tree, each file hash-checked on
  restore): 57 killed at first; the 8 survivors (an area past its swatches, `find` ignoring the group, a record's
  areas, the pond's ice, the woods' tree entries, the readout's second line, the over-a-panel check -- masked off-tree
  by the missing camera, so it became its own `may_read` -- and a new shown layer with the same reading) each got a
  test, and all 65 were killed. The review's fixes added 14 more (the words and field revisions, the zone-only
  sampling, the per-corner slicing, settling, the forgotten pointer, the readout's layer, the legend's freeing): 12
  killed at first, the 2 survivors (a test probe whose words and field revisions were the same; a pointer never set
  before it was forgotten) got sharper tests, and all 14 are killed. One known survivor: reading at once on a layer
  change rather than on the next tenth of a second (`_process` needs a live tree; the live harness exercises it but
  would pass either way).

## Source

Feature #40's brief (2026-10-01); UI §1.1, §2.1, §2.2 (OVERLAY), §3, UI-SET-022, REQ-UX-008, UX-T13; GDD §5.6, §5.9;
decisions 0206 (render layers), 0292 (map layers), 0391 (the picker's slot), 0441 (the leat), 0541 (night lighting,
on the lighting branch); Machado, Oliveira & Fernandes, "A Physiologically-based Model for Simulation of Color
Vision Deficiency", IEEE TVCG 15(6), 2009.
