extends RefCounted
## THE DAY AND THE NIGHT, AS DATA: every tunable of the demo's lighting cycle, in one file. Decision 0541. Presentation
## only: nothing here decides a gameplay outcome, and nothing reads it but the lighting (daylight.gd samples it,
## day_night.gd applies it, night_lights.gd lights by it).
##
## THE CLOCK. The cycle follows the demo's one calendar (demo_calendar.gd, a game hour every 25 s at 1x; decision
## 0421). Each day has four KEYS -- NIGHT, DAWN, DAY and DUSK -- and every named curve below gives its value at each:
##   * NIGHT holds from the end of dusk to the start of dawn, and DAY from the end of dawn to the start of dusk;
##   * DAWN is the value at the MIDDLE of the dawn window (sunrise), DUSK the value at the middle of the dusk window;
##   * between keys a curve eases (smoothstep): NIGHT -> DAWN over the dawn window's first half, DAWN -> DAY over its
##     second; DAY -> DUSK, then DUSK -> NIGHT, over the dusk window's halves.
##
## THE WINDOWS, AND THE SEASONS (the GDD's §5.10 "Daylight" column: spring 06:00-19:00, summer 05:00-21:00, autumn
## 07:00-18:00, winter 08:00-16:00). SUNRISE_MIN and SUNSET_MIN are that column. Dawn runs DAWN_HALF_MIN either side
## of sunrise; dusk runs DUSK_MIN on from sunset. In spring -- where the demo opens -- that is dawn 05:00-07:00 and
## dusk 19:00-21:00, the windows the brief set; summer's are 04:00-06:00 and 21:00-23:00, autumn's 06:00-08:00 and
## 18:00-20:00, winter's 07:00-09:00 and 16:00-18:00. Every window lies inside its own day, so midnight -- where the
## season changes (REQ-SET-141: "daylight ... at the exact boundary") -- is night in every season and the change
## shows nothing. THE SUN'S HEIGHT is not stated by the GDD or the calendar, so it is kept the same all year
## (SUN_PEAK_DEG; recorded in decision 0541).
##
## THE SUN AND THE MOON ARE ONE LIGHT (the world's one DirectionalLight3D, world_look.gd make_sun). By day it is the
## sun on its arc -- rising in the east, due south at the middle of the daylight, setting in the west, never lower
## than LIGHT_MIN_DEG so its shadows stay sane -- and by night the moon, from MOON_TOWARD. SUN_WEIGHT carries the
## light's direction from the moon's to the sun's; its shadow fades in and out with SHADOW, and with none (night) the
## shadow pass is switched off altogether (day_night.gd).
##
## THE DAY KEY IS THE WORLD'S OWN LOOK (decision 0301's targets, world_look.gd): the sun's colour and energy, the sky,
## the ambient, the haze and the adjustments at DAY are exactly the values the world was built and reviewed with (the
## sky's and the haze's mixes of the base tones written out, since a constant cannot call `lerp`;
## test_demo_daylight.gd holds them to world_look.gd's). The other keys move away from it.
##
## NIGHT STAYS PLAYABLE. Moon and starlight read the village: the ambient takes a cool moonlit colour of its own
## (SKY_SHARE lets the dark sky give way to AMBIENT_COLOUR), the moon is a soft key light, and the selection rings and
## marks are unshaded, so they read at any hour. BRIGHTER NIGHTS (the accessibility setting, demo_access.gd) raises
## the night's ambient, moon and exposure by the BRIGHT_* gains, in proportion to how much night there is (LAMPS).

const Look := preload("res://demo/world/world_look.gd")

## The four keys, in each curve's order.
const KEY_NIGHT: int = 0
const KEY_DAWN: int = 1
const KEY_DAY: int = 2
const KEY_DUSK: int = 3
const KEY_COUNT: int = 4
const KEY_NAMES: Array[String] = ["night", "dawn", "day", "dusk"]

## THE WINDOWS (see THE WINDOWS, AND THE SEASONS): minutes after midnight, per §4.3 season (spring, summer, autumn,
## winter).
const SUNRISE_MIN: PackedInt32Array = [360, 300, 420, 480]
const SUNSET_MIN: PackedInt32Array = [1140, 1260, 1080, 960]
const DAWN_HALF_MIN: int = 60
const DUSK_MIN: int = 120
const MINUTES_PER_DAY: int = 1440

## THE SUN'S ARC: its height at the middle of the daylight (degrees; ~50 degrees at half past ten in spring, the
## late-morning sun the world was reviewed under), and the least height the light is ever given.
const SUN_PEAK_DEG: float = 57.0
const LIGHT_MIN_DEG: float = 12.0
## Where the moon stands (a unit vector toward it): high in the south-west, so the night's light falls from behind
## the camera's right shoulder as the day's does from its left.
const MOON_TOWARD: Vector3 = Vector3(-0.36, 0.8, 0.48)

# --- the named curves: NIGHT, DAWN, DAY, DUSK ------------------------------------------------------------------

## The one light's energy and colour: the moon, a rose dawn, the world's sun, an amber dusk.
const LIGHT_ENERGY: PackedFloat32Array = [0.4, 0.66, Look.SUN_ENERGY, 0.62]
const LIGHT_COLOUR: PackedColorArray = [Color(0.6, 0.7, 1.0), Color(1.0, 0.8, 0.66), Look.SUN_COLOR,
	Color(1.0, 0.7, 0.5)]
## How far the light's direction is the sun's (1) rather than the moon's (0).
const SUN_WEIGHT: PackedFloat32Array = [0.0, 0.85, 1.0, 0.85]
## The sun's shadow opacity (0: the shadow pass is off). It is OFF from the middle of the dusk to the middle of the dawn
## -- the halves in which the light's direction swings between the moon's and the sun's (SUN_WEIGHT 0 .. 0.85), so no
## shadow is seen stepping round with it -- and fades in over the dawn's second half and out over the dusk's first.
const SHADOW: PackedFloat32Array = [0.0, 0.0, 1.0, 0.0]
## The ambient: its energy, how much of it the sky gives (the rest is AMBIENT_COLOUR), and that colour.
const AMBIENT_ENERGY: PackedFloat32Array = [0.72, 0.64, 0.65, 0.64]
const SKY_SHARE: PackedFloat32Array = [0.2, 0.8, 1.0, 0.75]
const AMBIENT_COLOUR: PackedColorArray = [Color(0.32, 0.4, 0.62), Color(0.62, 0.6, 0.62), Color(0.86, 0.85, 0.78),
	Color(0.56, 0.52, 0.58)]
## The procedural sky (world_look.gd `_sky`): overhead, the horizon, the ground's horizon and below, and its energy.
const SKY_TOP: PackedColorArray = [Color(0.03, 0.045, 0.1), Color(0.32, 0.4, 0.6), Color(0.36, 0.52, 0.7),
	Color(0.24, 0.27, 0.48)]
const SKY_HORIZON: PackedColorArray = [Color(0.07, 0.09, 0.16), Color(0.92, 0.77, 0.64), Color(0.8305, 0.83225, 0.767),
	Color(0.9, 0.63, 0.48)]
const GROUND_HORIZON: PackedColorArray = [Color(0.06, 0.07, 0.11), Color(0.76, 0.68, 0.6),
	Color(0.7783, 0.78875, 0.7238), Color(0.7, 0.56, 0.48)]
const GROUND_BOTTOM: PackedColorArray = [Color(0.03, 0.04, 0.05), Color(0.197, 0.2896, 0.2168),
	Color(0.21, 0.308, 0.227), Color(0.197, 0.2896, 0.2168)]
const SKY_ENERGY: PackedFloat32Array = [0.55, 0.85, 1.0, 0.8]
## The haze: its colour and density (a little morning mist at dawn).
const FOG_COLOUR: PackedColorArray = [Color(0.1, 0.12, 0.19), Color(0.8, 0.75, 0.7), Color(0.8044, 0.8105, 0.7454),
	Color(0.68, 0.58, 0.54)]
const FOG_DENSITY: PackedFloat32Array = [0.0026, 0.0034, 0.0022, 0.0026]
## The adjustments: saturation and the tonemap's exposure.
const SATURATION: PackedFloat32Array = [0.78, 0.94, 1.0, 0.94]
const EXPOSURE: PackedFloat32Array = [1.08, 1.0, 1.0, 1.0]
## How lit the lamps are (night_lights.gd), and how much night there is for BRIGHTER NIGHTS: full at night, half at
## the middle of either window (they are lit before the sun is gone and put out after it is up).
const LAMPS: PackedFloat32Array = [1.0, 0.5, 0.0, 0.6]
## What lights an UNSHADED thing that stands in the world's light -- the falling rain and snow, the chimney smoke --
## so it darkens with the evening rather than glowing in the night. Marks and rings are never tinted.
const UNLIT_TINT: PackedColorArray = [Color(0.3, 0.34, 0.48), Color(0.82, 0.74, 0.72), Color(1.0, 1.0, 1.0),
	Color(0.76, 0.62, 0.58)]

# --- brighter nights -----------------------------------------------------------------------------------------

## BRIGHTER NIGHTS (see the header): at full night the ambient energy is BRIGHT_AMBIENT_GAIN times, the moon
## BRIGHT_LIGHT_GAIN times, the sky gives BRIGHT_SKY_SHARE_CUT less of the ambient (more of the moonlit colour), and
## the exposure is BRIGHT_EXPOSURE_ADD more.
const BRIGHT_AMBIENT_GAIN: float = 1.75
const BRIGHT_LIGHT_GAIN: float = 1.5
const BRIGHT_SKY_SHARE_CUT: float = 0.1
const BRIGHT_EXPOSURE_ADD: float = 0.22

# --- the weather on top --------------------------------------------------------------------------------------

## A gloomy sky (weather_view.gd `gloom`: overcast, rain, a storm, snow) darkens and greys whatever the hour is: at full
## gloom the ambient and the sky lose GLOOM_DARKEN of their energy, the saturation GLOOM_DESATURATE, the sky's and
## the haze's colours go GLOOM_GREY of the way to their own grey, and the sun's shadow GLOOM_SHADOW of its opacity.
const GLOOM_DARKEN: float = 0.35
const GLOOM_DESATURATE: float = 0.35
const GLOOM_GREY: float = 0.7
const GLOOM_SHADOW: float = 0.6

# --- the night lights (night_lights.gd) ----------------------------------------------------------------------

## The pool: at most NIGHT_LIGHTS omni lights on the surface, shadowless, given to the spots nearest the camera's focus.
const NIGHT_LIGHTS: int = 8
## A home's lamplight at its door (the building models carry one baked material and no window slot, so the homes are
## lit by the spill at their fronts, not by glowing windows): its colour, energy, range, how far out from the front
## and how high.
const HOME_COLOUR: Color = Color(1.0, 0.7, 0.42)
const HOME_ENERGY: float = 1.1
const HOME_RANGE_M: float = 4.2
const HOME_GAP_M: float = 0.55
const HOME_UP_M: float = 1.1
## The homes that are lit (world_layout.gd BUILDINGS ids).
const LIT_HOMES: Array[StringName] = [&"hall", &"residence_a", &"residence_b", &"residence_c", &"kitchen"]
## A tunnel mouth's lantern (tunnel_mouth.gd: the arch's wall lantern, or the gateway's own).
const LANTERN_COLOUR: Color = Color(1.0, 0.72, 0.4)
const LANTERN_ENERGY: float = 1.4
const LANTERN_RANGE_M: float = 4.0
## The lamps waver FLICKER either side of their energy, gently, on the demo clock (still with reduced motion).
const FLICKER: float = 0.05
const FLICKER_HZ: Vector2 = Vector2(0.9, 2.3)
## Glow (bloom) in the surface's environment while the lamps are lit: its intensity at full night, and from what
## lamps' level it is on at all.
const GLOW_INTENSITY: float = 0.55
const GLOW_FROM: float = 0.05
