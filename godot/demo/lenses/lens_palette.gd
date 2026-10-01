extends RefCounted
## The map layers' colour tokens (decision 0581): every colour a layer paints an AREA with, in one place, so the
## overlays, their legends, the hover readout and the compare outlines all draw the same colour for the same thing.
## The overlays read them (farm_look.gd's bed discs, water_overlay.gd's zone paint); nothing else defines a layer's
## area colour. Presentation only.
##
## COLOUR-BLIND SAFE, AND CHECKED (lens_colour_check.gd; test_demo_lens_kit.gd). Every ramp below keeps every pair of
## its colours at least MIN_DE_DAY apart (CIE76 delta E) for normal vision and simulated deuteranopia and
## protanopia (Machado 2009, full severity) -- drawn alone (the legend), composited at its own alpha over the ground it
## is painted on (the day), and that composite dimmed by the night's grade (MIN_DE_NIGHT) -- so no two areas of one
## layer depend on red-green hue to be told apart. The moisture and ripeness ramps were changed for this (decision
## 0581: dry/low and wet/waterlogged fell to 7, and growing/past-its-best to 3.7 under protanopia); the water's zone
## ramp and the leat's service ramp already passed and are unchanged.
##
## Moisture is a DIVERGING ramp around "good": warm and dark for dry, pale for low, a sage green for good, pale blue
## for wet and deep indigo for waterlogged -- told apart by lightness as much as hue. Waterlogged stays a calm tint
## (alpha under 0.5, not a blue slab: test_demo_farm_ui.gd).

## Soil moisture by farm_sim.gd BAND_*: dry, low, good, wet, waterlogged.
const MOISTURE: Array[Color] = [
	Color(0.82, 0.47, 0.03, 0.6), Color(1.0, 0.89, 0.55, 0.55), Color(0.49, 0.61, 0.47, 0.55),
	Color(0.61, 0.66, 0.92, 0.5), Color(0.22, 0.19, 0.43, 0.48),
]
## Ripeness: growing, ripe (within its grace), past its best or lost, empty.
const GROWING: Color = Color(0.46, 0.67, 0.74, 0.55)
const RIPE: Color = Color(1.0, 0.87, 0.13, 0.6)
const LATE: Color = Color(0.47, 0.09, 0.47, 0.6)
const EMPTY: Color = Color(0.4, 0.35, 0.3, 0.25)
## The garden leat's service (weir_sluice.gd SERVICE_*): not served, dry (the leat empty), normal, wet.
const SERVICE: Array[Color] = [EMPTY, Color(0.86, 0.66, 0.3, 0.55), Color(0.36, 0.64, 0.4, 0.55),
	Color(0.3, 0.46, 0.7, 0.58)]
## The water's zones for a body (water_rules.gd ZONE_*): wade, swim, dive.
const WADE: Color = Color(1.0, 0.86, 0.3, 0.55)
const SWIM: Color = Color(0.3, 0.8, 1.0, 0.5)
const DIVE: Color = Color(0.45, 0.25, 0.9, 0.55)

## The compare outlines' core line and the hover readout's text: the woodland skin's own ink (woodland_palette.gd).
const OUTLINE_INK: Color = Color("#14211B")

## What each layer's areas are painted over, for the check: the beds' soil, the stream's water, the woods' grass.
const OVER_SOIL: Color = Color(0.33, 0.26, 0.18)
const OVER_WATER: Color = Color(0.22, 0.3, 0.3)
const OVER_GRASS: Color = Color(0.3, 0.38, 0.22)

## THE NIGHT, for the check: the lighting cycle's full-night grade (decision 0541, demo/world/daylight_curves.gd on the
## lighting branch -- SATURATION 0.74 at night, and its haze, FOG_COLOUR at FOG_DENSITY 0.0026, which takes about an
## eighth of a mark seen from the camera's usual 50 m). Every layer's marks are UNSHADED, so the moon's dimmer light
## does not reach them; only this post-process grade and the haze do.
const NIGHT_SATURATION: float = 0.74
const NIGHT_HAZE: Color = Color(0.1, 0.12, 0.19)
const NIGHT_HAZE_SHARE: float = 0.12
