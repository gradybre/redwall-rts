extends RefCounted
## How a bed LOOKS for its state: plant size, tint, soil sheen, and the words over it. Decision 0196.
## Presentation only -- every input is read from farm_sim.gd; nothing here decides an outcome.
##
## Stages (farm_sim STAGE_*): EMPTY bare soil; SOWN furrows; SPROUTING small bright shoots; GROWING
## plants that grow with the crop (SEEDLING_SCALE at 0 to full at ripeness); RIPE full plants in the
## item's own colour (leaf crops without a plant of their own show their heads); WITHERED shrunk,
## thinned, limp and drooping, bleached to dry straw-brown; BLIGHTED full-size, standing, but dark
## and blotched with black spots -- the two used to differ only in tint, and read alike.
##
## A library plant's cards come in four cells (tools/make_demo_props.py): FULL from the front, FULL
## from the side, THINNED (a third of its leaves gone) and SPARSE (two-thirds gone). A stage shows a
## SUBSET of them (stage_cells): a sprout its sparse cell only, a young plant sparse and thinned,
## then thinned, then all three views as it fills out; ripe the two full views; withered the thinned
## and sparse (it has lost leaves); blighted the full plant. The old atlases (wheat, the roots bed's
## turnips and carrots) have no such cells and show all of theirs at every stage. The soil sheen tells
## moisture at a glance: pale and dry; wet soil DARKENED and glossier, not tinted; waterlogged darker
## still, with small standing puddles of dark blue-grey water on it (playtest 2026-09-29: the old
## grey-teal film read as a flat bright blue slab). Colours are blends of the demo's ART-LOCK-001
## pigments (world/world_look.gd), tuned by eye on the staged atlases.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const LensPalette := preload("res://demo/lenses/lens_palette.gd")

const SEEDLING_SCALE: float = 0.14
const WITHERED_SCALE: float = 0.72
## Young plants are brighter and greener than ripe ones.
const YOUNG_TINT: Vector3 = Vector3(0.62, 1.12, 0.5)
## Plants keep their young green until this share of their growth, then turn to their ripe colour.
const TURN_FROM: float = 0.45
const WITHERED_TINT: Vector3 = Vector3(0.78, 0.6, 0.38)
const BLIGHT_TINT: Vector3 = Vector3(0.36, 0.38, 0.3)
## Plants lean this far (radians) when withered, and slump to this share of their height.
const WITHERED_DROOP: float = 0.55
const WITHERED_LIMP: float = 0.72
## How far withered leaves are bleached toward dry straw, and blighted ones (0..1, crop_card.gdshader).
const WITHERED_BLEACH: float = 0.85
const BLIGHT_BLEACH: float = 0.25
## The plant cells (FULL, SIDE, THINNED, SPARSE) each stage shows; see the header.
const CELL_FULL: int = 0
const CELL_SIDE: int = 1
const CELL_THINNED: int = 2
const CELL_SPARSE: int = 3
const CELLS_SPROUT: Array[int] = [CELL_SPARSE]
const CELLS_YOUNG: Array[int] = [CELL_SPARSE, CELL_THINNED]
const CELLS_FILLING: Array[int] = [CELL_THINNED]
const CELLS_FULL: Array[int] = [CELL_FULL, CELL_SIDE, CELL_THINNED]
const CELLS_RIPE: Array[int] = [CELL_FULL, CELL_SIDE]
const CELLS_WITHERED: Array[int] = [CELL_THINNED, CELL_SPARSE]
## Growth (permille) at which a growing plant moves from young to filling to full.
const YOUNG_UNTIL: int = 350
const FILLING_UNTIL: int = 700
## Soil sheen per moisture band (dry, low, good, wet, waterlogged); alpha 0 draws nothing. Wet and
## waterlogged are a near-black umber film over the soil (a milder one when merely wet), not a tint.
const SHEEN: Array[Color] = [
	Color(0.86, 0.74, 0.5, 0.42), Color(0.86, 0.76, 0.56, 0.18), Color(0.0, 0.0, 0.0, 0.0),
	Color(0.06, 0.045, 0.035, 0.3), Color(0.045, 0.035, 0.03, 0.58),
]
## How glossy each band's film is: dry dust is matte, wet soil shines, waterlogged soil most.
const SHEEN_ROUGHNESS: Array[float] = [0.95, 0.9, 0.9, 0.38, 0.14]
## A waterlogged bed's standing puddles: dark blue-grey, a little see-through and glossy -- water
## over dark soil reflecting a pale sky, never bright.
const PUDDLE_COLOR: Color = Color(0.15, 0.17, 0.19, 0.86)
const PUDDLE_ROUGHNESS: float = 0.05
const PUDDLE_SPECULAR: float = 0.9
## Overlay disc colours: moisture bands, then ripeness (growing -> ripe -> past its grace), then the leat's service.
## They are the map layers' colour tokens (demo/lenses/lens_palette.gd, decision 0581: colour-blind checked), so the
## discs, their legends, the hover readout and the compare outlines agree. Waterlogged stays a calm tint, not a slab.
const BAND_OVERLAY: Array[Color] = LensPalette.MOISTURE
const UNRIPE_OVERLAY: Color = LensPalette.GROWING
const RIPE_OVERLAY: Color = LensPalette.RIPE
const LATE_OVERLAY: Color = LensPalette.LATE
const NO_OVERLAY: Color = LensPalette.EMPTY
## The Water service layer (decision 0441), by the garden leat's service (weir_sluice.gd SERVICE_*): not served, dry
## (the leat empty), normal, wet.
const SERVICE_OVERLAY: Array[Color] = LensPalette.SERVICE
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


static func limp(stage: int) -> float:
	"""How much of its height a plant keeps (a withered one slumps)."""
	return WITHERED_LIMP if stage == SimScript.STAGE_WITHERED else 1.0


static func bleach(stage: int) -> float:
	"""How far the leaves are bleached toward dry straw (0: not at all)."""
	match stage:
		SimScript.STAGE_WITHERED:
			return WITHERED_BLEACH
		SimScript.STAGE_BLIGHTED:
			return BLIGHT_BLEACH
	return 0.0


static func spots(stage: int) -> float:
	"""How strongly the leaves are blotched (blight only)."""
	return 1.0 if stage == SimScript.STAGE_BLIGHTED else 0.0


static func stage_cells(stage: int, growth_permille: int) -> Array[int]:
	"""Which of a library plant's four cells a stage shows (see the header)."""
	match stage:
		SimScript.STAGE_SPROUTING:
			return CELLS_SPROUT
		SimScript.STAGE_RIPE:
			return CELLS_RIPE
		SimScript.STAGE_WITHERED:
			return CELLS_WITHERED
		SimScript.STAGE_BLIGHTED:
			return CELLS_FULL
	if growth_permille < YOUNG_UNTIL:
		return CELLS_YOUNG
	return CELLS_FILLING if growth_permille < FILLING_UNTIL else CELLS_FULL


static func shows_head_mesh(stage: int, growth_permille: int) -> bool:
	"""Whether a head plant (farm_catalog PLANT_HEAD_MESH) draws its mesh: filled out, or ripe."""
	return stage == SimScript.STAGE_RIPE or (stage == SimScript.STAGE_GROWING and growth_permille >= FILLING_UNTIL)


static func shows_heads(stage: int, item: int) -> bool:
	"""Whether a bed shows the staged cabbage heads (a ripe leaf crop)."""
	return stage == SimScript.STAGE_RIPE and Catalog.is_item(item) and Catalog.ITEM_RIPE_HEADS[item]


static func sheen(band: int) -> Color:
	"""The soil sheen for a moisture band."""
	return SHEEN[band]


static func sheen_roughness(band: int) -> float:
	"""How glossy the soil sheen is for a moisture band."""
	return SHEEN_ROUGHNESS[band]


static func shows_puddles(band: int) -> bool:
	"""Whether a bed shows standing puddles (waterlogged only)."""
	return band == SimScript.BAND_WATERLOGGED


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
	@warning_ignore("integer_division") var line: String = "%d%%" % (growth_permille / 10)
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
