extends RefCounted
## The demo skin's colours: ART-LOCK-001's twelve pigments, and the tone ranges drawn from them.
##
## `docs/design/ui_refinement/asset_generation_lock.md` §3 names twelve pigments as the colour
## authority for the woodland family. Every colour the skin paints is one of them or a stated
## blend between two of them -- nothing here is sampled from the concept PNG, which ASSETS.md
## rules "is not a runtime atlas or a source of sampled UI constants".
##
## DEMO-ONLY. The game's own semantic tokens stay in `scripts/ui/ui_theme.gd`, untouched: the
## lock itself says its pigments "do not replace semantic UI tokens". This palette dresses the
## live demo's HUD and nothing else reads it.
##
## ---------------------------------------------------------------------------------------
## EVERY SURFACE PUBLISHES THE RANGE ITS TEXTURE IS ALLOWED TO SPAN. The procedural grain in
## `woodland_textures.gd` mottles a face between `face_dark()` and `face_light()` and never
## outside them, so `test_demo_ui.gd` can prove each text colour against BOTH extremes rather
## than against one average swatch that the grain then wanders away from.

# --- ART-LOCK-001 §3, exactly as written ---------------------------------------------------------

const INK: Color = Color("#25372D")
const DEEP_SHADE: Color = Color("#14211B")
const OAT: Color = Color("#EAE1C8")
const CREAM: Color = Color("#F5F0DF")
const SAGE: Color = Color("#708171")
const LEAF: Color = Color("#466647")
const BRASS: Color = Color("#B49A58")
const TIMBER: Color = Color("#91613E")
const UMBER: Color = Color("#594332")
const CLAY: Color = Color("#B76545")
const EMBER: Color = Color("#D99743")
const FLINT: Color = Color("#8A8D84")

const PIGMENTS: Array[Color] = [
	INK, DEEP_SHADE, OAT, CREAM, SAGE, LEAF, BRASS, TIMBER, UMBER, CLAY, EMBER, FLINT,
]

# --- surfaces -------------------------------------------------------------------------------------

## A light, mottled paper field: counters, the journal, the time plate, rows and fields.
const SURFACE_PARCHMENT: int = 0
## Carved dark wood: buttons, toggles and the command dock.
const SURFACE_WOOD: int = 1
## The brass face a pressed or selected control wears.
const SURFACE_BRASS: int = 2
## Deep green lacquer: notices and the pause banner.
const SURFACE_LACQUER: int = 3
## The map-paper inset of the minimap and tooltips: parchment washed toward sage.
const SURFACE_MAP: int = 4
## Wood that is switched off: darker, and washed toward flint.
const SURFACE_WOOD_DISABLED: int = 5
## Parchment that is switched off: washed toward flint.
const SURFACE_PARCHMENT_DISABLED: int = 6
const SURFACE_COUNT: int = 7
## A Control drawn straight onto the world with no surface of its own.
const SURFACE_NONE: int = -1

## Which surfaces are light, so text on them is dark ink.
const LIGHT_SURFACES: Array[int] = [
	SURFACE_PARCHMENT, SURFACE_BRASS, SURFACE_MAP, SURFACE_PARCHMENT_DISABLED,
]


static func is_surface(surface: int) -> bool:
	"""True for one of the seven surfaces this palette defines."""
	return surface >= 0 and surface < SURFACE_COUNT


static func is_light(surface: int) -> bool:
	"""True when a surface is light, so the text drawn on it must be dark ink."""
	return LIGHT_SURFACES.has(surface)


static func face_dark(surface: int) -> Color:
	"""The darkest tone a surface's grain may reach under text."""
	match surface:
		SURFACE_PARCHMENT:
			return OAT.lerp(TIMBER, 0.16)
		SURFACE_WOOD:
			return DEEP_SHADE.lerp(UMBER, 0.20)
		SURFACE_BRASS:
			return BRASS.lerp(EMBER, 0.30)
		SURFACE_LACQUER:
			return DEEP_SHADE.lerp(INK, 0.40)
		SURFACE_MAP:
			return OAT.lerp(SAGE, 0.30)
		SURFACE_WOOD_DISABLED:
			return DEEP_SHADE.lerp(FLINT, 0.10)
		SURFACE_PARCHMENT_DISABLED:
			return OAT.lerp(FLINT, 0.34)
	return DEEP_SHADE


static func face_light(surface: int) -> Color:
	"""The lightest tone a surface's grain may reach under text."""
	match surface:
		SURFACE_PARCHMENT:
			return CREAM
		SURFACE_WOOD:
			return UMBER
		SURFACE_BRASS:
			return EMBER.lerp(OAT, 0.45)
		SURFACE_LACQUER:
			return INK.lerp(LEAF, 0.45)
		SURFACE_MAP:
			return OAT.lerp(SAGE, 0.10)
		SURFACE_WOOD_DISABLED:
			return DEEP_SHADE.lerp(FLINT, 0.24)
		SURFACE_PARCHMENT_DISABLED:
			return OAT.lerp(FLINT, 0.18)
	return DEEP_SHADE


static func text_on(surface: int) -> Color:
	"""The primary text colour for a surface: ink on the light ones, cream on the dark."""
	match surface:
		SURFACE_BRASS:
			return DEEP_SHADE
		SURFACE_WOOD_DISABLED:
			return CREAM.lerp(FLINT, 0.40)
		SURFACE_PARCHMENT_DISABLED:
			return UMBER
	return INK if is_light(surface) else CREAM


static func secondary_on(surface: int) -> Color:
	"""The secondary (caption, rate, note) text colour for a surface."""
	if surface == SURFACE_BRASS:
		return DEEP_SHADE
	if is_light(surface):
		return UMBER
	return OAT.lerp(SAGE, 0.25)


## The need track's edge and fill on parchment: an umber edge and a leaf-green fill.
const TRACK_EDGE: Color = UMBER
const TRACK_FILL: Color = LEAF
## The focus ring's outer and inner lines. Its middle line is `focus_bright()`, so the ring
## holds 3:1 against a light panel and a dark button alike.
const FOCUS_DARK: Color = DEEP_SHADE


static func track_well() -> Color:
	"""The need track's empty well: parchment washed toward timber, paler than any fill."""
	return OAT.lerp(TIMBER, 0.22)


static func focus_bright() -> Color:
	"""The bright brass line at the centre of the focus ring: ember lifted toward cream."""
	return EMBER.lerp(CREAM, 0.35)
