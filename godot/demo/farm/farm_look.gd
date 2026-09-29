extends RefCounted
## How a bed LOOKS for its state: plant size, tint, soil sheen, and the words over it. Decision 0196.
## Presentation only -- every input is read from farm_sim.gd; nothing here decides an outcome.
##
## Stages (farm_sim STAGE_*): EMPTY bare soil; SOWN furrows; SPROUTING small bright shoots; GROWING
## plants that grow with the crop (SEEDLING_SCALE at 0 to full at ripeness); RIPE full plants in the
## item's own colour (leaf crops show their heads); WITHERED shrunk, brown and drooping; BLIGHTED
## the growing plants darkened and spotted. The soil sheen tells moisture at a glance: pale and dry,
## dark and wet, standing water when waterlogged. Colours are blends of the demo's ART-LOCK-001
## pigments (world/world_look.gd), tuned by eye on the staged atlases.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const SEEDLING_SCALE: float = 0.14
const WITHERED_SCALE: float = 0.72
## Young plants are brighter and greener than ripe ones.
const YOUNG_TINT: Vector3 = Vector3(0.62, 1.12, 0.5)
## Plants keep their young green until this share of their growth, then turn to their ripe colour.
const TURN_FROM: float = 0.45
const WITHERED_TINT: Vector3 = Vector3(0.78, 0.6, 0.38)
const BLIGHT_TINT: Vector3 = Vector3(0.36, 0.38, 0.3)
## Plants lean this far (radians) when withered.
const WITHERED_DROOP: float = 0.55
## Soil sheen per moisture band (dry, low, good, wet, waterlogged); alpha 0 draws nothing.
const SHEEN: Array[Color] = [
	Color(0.86, 0.74, 0.5, 0.42), Color(0.86, 0.76, 0.56, 0.18), Color(0.0, 0.0, 0.0, 0.0),
	Color(0.13, 0.17, 0.2, 0.32), Color(0.32, 0.46, 0.5, 0.62),
]
## Overlay disc colours: moisture bands, then ripeness (growing -> ripe -> past its grace).
const BAND_OVERLAY: Array[Color] = [
	Color(0.85, 0.45, 0.2, 0.55), Color(0.9, 0.72, 0.3, 0.5), Color(0.3, 0.62, 0.32, 0.45),
	Color(0.25, 0.45, 0.7, 0.5), Color(0.15, 0.3, 0.75, 0.6),
]
const UNRIPE_OVERLAY: Color = Color(0.32, 0.6, 0.3, 0.45)
const RIPE_OVERLAY: Color = Color(0.93, 0.74, 0.25, 0.6)
const LATE_OVERLAY: Color = Color(0.85, 0.35, 0.2, 0.6)
const NO_OVERLAY: Color = Color(0.4, 0.35, 0.3, 0.25)
## Label colours: calm, needs attention, urgent.
const LABEL_CALM: Color = Palette.CREAM
const LABEL_ATTENTION: Color = Color("#F2C46B")
const LABEL_URGENT: Color = Color("#FF8A65")
## Hours after ripening when the grace ends (§5.6's 48) and the last day before withering (120-24).
const GRACE_HOURS: int = 48
const LAST_DAY_HOURS: int = 96


static func plant_scale(stage: int, growth_permille: int) -> float:
	"""How big the plants stand, 0 for none (bare, sown)."""
	match stage:
		SimScript.STAGE_EMPTY, SimScript.STAGE_SOWN:
			return 0.0
		SimScript.STAGE_RIPE:
			return 1.0
		SimScript.STAGE_WITHERED:
			return WITHERED_SCALE
	return lerpf(SEEDLING_SCALE, 1.0, clampf(float(growth_permille) / 1000.0, 0.0, 1.0))


static func plant_tint(stage: int, item: int, growth_permille: int) -> Vector3:
	"""The plants' colour: young green toward the item's ripe colour; brown when withered; darkened
	when blighted."""
	var ripe: Color = Catalog.ITEM_TINT[item] if Catalog.is_item(item) else Color.WHITE
	var ripe_v := Vector3(ripe.r, ripe.g, ripe.b)
	match stage:
		SimScript.STAGE_WITHERED:
			return WITHERED_TINT
		SimScript.STAGE_BLIGHTED:
			return BLIGHT_TINT
		SimScript.STAGE_RIPE:
			return ripe_v
	return YOUNG_TINT.lerp(ripe_v, smoothstep(TURN_FROM, 1.0, float(growth_permille) / 1000.0))


static func droop(stage: int) -> float:
	"""How far the plants lean over."""
	return WITHERED_DROOP if stage == SimScript.STAGE_WITHERED else 0.0


static func shows_heads(stage: int, item: int) -> bool:
	"""Whether a bed shows the staged cabbage heads (a ripe leaf crop)."""
	return stage == SimScript.STAGE_RIPE and Catalog.is_item(item) and Catalog.ITEM_RIPE_HEADS[item]


static func sheen(band: int) -> Color:
	"""The soil sheen for a moisture band."""
	return SHEEN[band]


static func ripeness_overlay(stage: int, ripe_hours: int) -> Color:
	"""The ripeness overlay's colour: growing, ripe, or past its grace."""
	if stage == SimScript.STAGE_RIPE:
		return RIPE_OVERLAY if ripe_hours < GRACE_HOURS else LATE_OVERLAY
	if stage == SimScript.STAGE_WITHERED or stage == SimScript.STAGE_BLIGHTED:
		return LATE_OVERLAY
	if stage == SimScript.STAGE_EMPTY:
		return NO_OVERLAY
	return UNRIPE_OVERLAY


static func title(item: int, chosen: int, stage: int) -> String:
	"""The label's first line: the crop, or what the bed waits for."""
	if Catalog.is_item(item):
		return Catalog.ITEM_LABELS[item]
	if Catalog.is_item(chosen) and stage == SimScript.STAGE_EMPTY:
		return "%s (to sow)" % Catalog.ITEM_LABELS[chosen]
	return "Empty bed"


static func status(stage: int, chosen: int, growth_permille: int, band: int, ripe_hours: int) -> String:
	"""The label's second line: the stage, with the most pressing need."""
	match stage:
		SimScript.STAGE_EMPTY:
			return "choose a crop" if not Catalog.is_item(chosen) else "waiting to be sown"
		SimScript.STAGE_SOWN:
			return "sowing"
		SimScript.STAGE_RIPE:
			if ripe_hours >= LAST_DAY_HOURS:
				return "RIPE — withers soon!"
			return "RIPE — harvest" if ripe_hours < GRACE_HOURS else "RIPE — spoiling"
		SimScript.STAGE_WITHERED:
			return "withered — clear it"
		SimScript.STAGE_BLIGHTED:
			return "BLIGHT — clear it"
	var line: String = "%d%%" % (growth_permille / 10)
	if band == SimScript.BAND_DRY:
		return line + " · too dry"
	if band == SimScript.BAND_LOW:
		return line + " · dry"
	if band == SimScript.BAND_WET or band == SimScript.BAND_WATERLOGGED:
		return line + (" · waterlogged" if band == SimScript.BAND_WATERLOGGED else " · wet")
	return line


static func urgency(stage: int, band: int, ripe_hours: int) -> Color:
	"""The label's colour: calm, attention, or urgent."""
	if stage == SimScript.STAGE_BLIGHTED or stage == SimScript.STAGE_WITHERED:
		return LABEL_URGENT
	if stage == SimScript.STAGE_RIPE:
		return LABEL_URGENT if ripe_hours >= GRACE_HOURS else LABEL_ATTENTION
	if stage != SimScript.STAGE_EMPTY and (band == SimScript.BAND_DRY or band == SimScript.BAND_WATERLOGGED):
		return LABEL_URGENT
	if stage != SimScript.STAGE_EMPTY and band != SimScript.BAND_GOOD:
		return LABEL_ATTENTION
	return LABEL_CALM
