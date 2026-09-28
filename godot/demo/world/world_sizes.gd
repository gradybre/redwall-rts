extends RefCounted
## How big every demo world asset is drawn. Decision 0196 (live demo).
##
## The staged Meshy models are all normalised to ~1.9 m on their longest axis, so none of them
## arrives at game scale. Every model is scaled UNIFORMLY (no squashing), by one of two rules:
##
##   * BUILDINGS: model height == the authoritative exterior envelope `BUILDING_MAX_Y_MM` in
##     `res://assets/lookdev/lookdev_dimensions.gd` (ART-GAP-R03, decision 0082). Not chosen here.
##   * EVERYTHING ELSE: model height == `DEMO_HEIGHT_M` below. THESE ARE DEMO-ONLY CHOICES. Trees,
##     props, crops and ground cover have no authoritative size anywhere in the project; the
##     numbers are judged against the approved creature heights (mouse 1.00 m, mole 0.90,
##     squirrel 1.15, otter 1.49, badger 2.55 -- DEC-039) and the 0.625 m work-surface candidate.
##     Nothing outside `godot/demo/` may read them as a sizing policy.
##
## `NATIVE_AABB` is the measured model bound copied from the staging manifest
## (tools/stage_demo_assets.py). The layout, obstacles and points of interest are derived from
## it, so they are identical whether or not the real models are staged; a staged model is scaled
## from the manifest's own measurement so its height lands exactly on target.

const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")

const MILLIMETRES_PER_METRE: float = 1000.0

## Demo-only target heights in metres, one rationale each. NOT a sizing policy.
const DEMO_HEIGHT_M: Dictionary = {
	&"oak_mature": 13.0,        # a mature Mossflower oak; ~5x the badger, towers over the hall
	&"beech_mature": 15.0,      # beeches run taller and narrower than oaks
	&"oak_sapling": 3.2,        # a young oak about three mice tall
	&"stump_mossy": 0.9,        # a felled-oak stump a mouse can sit on (model is 2:1 wide)
	&"mossy_boulder": 1.7,      # a boulder taller than a mouse, below a badger's shoulder
	&"rock_cluster": 0.8,       # knee-to-waist stones for a mouse
	&"fallen_log": 0.9,         # a log section roughly mouse-chest thick
	&"grass_tuft": 0.45,        # tussock to a mouse's hip; reads as ground cover from the camera
	&"mushroom_cluster": 0.45,  # woodland fungi at a mouse's hip -- storybook, not biological
	&"reeds": 1.5,              # reeds that rise just above a mouse's ears in the damp corner
	&"crop_grain_ripe": 0.82,   # chosen so the bed is ~3.0 m square; grain to a mouse's chest
	&"crop_cabbage_ripe": 0.39, # chosen so the bed is ~3.0 m square
	&"crop_roots_ripe": 0.63,   # chosen so the bed is ~3.0 m square
	&"barrel": 0.95,            # a cask a mouse can just see over
	&"crate": 0.75,             # a crate a mouse can lift one end of
	&"log_stack": 1.5,          # firewood stacked to a squirrel's head
	&"handcart": 1.05,          # handles at a mouse's waist, bed at its hip
	&"water_bucket": 0.55,      # a two-paw bucket, handle included
	&"sack_pile": 1.0,          # sacks on a pallet about a mouse tall
	&"wheelbarrow": 0.75,       # barrow handles at a mouse's waist
	&"cauldron_tripod": 1.6,    # tripod above a badger's elbow; the pot hangs at mouse-chest
	# table_stools: not here -- its top is the 0.625 m work-surface candidate, read below.
}

## The table model's highest point is its top, so it is scaled to the work-surface candidate.
const TABLE_KEY: StringName = &"table_stools"

## Measured model bounds [min, max] in metres, from the staging manifest. Y-up, front +Z.
const NATIVE_AABB: Dictionary = {
	&"residence": [Vector3(-0.8769, 0.0, -0.776), Vector3(0.8792, 1.9004, 0.7759)],
	&"hall": [Vector3(-0.943, 0.0, -0.5184), Vector3(0.9478, 1.1535, 0.5173)],
	&"kitchen": [Vector3(-0.8697, 0.0, -0.9361), Vector3(0.8698, 1.726, 0.9507)],
	&"well": [Vector3(-0.8824, 0.0, -0.8717), Vector3(0.8727, 1.9027, 0.8698)],
	&"workbench": [Vector3(-0.9513, 0.0, -0.7173), Vector3(0.9507, 1.5386, 0.7222)],
	&"covered_store": [Vector3(-0.9507, 0.0, -0.7368), Vector3(0.9492, 1.2723, 0.7212)],
	&"open_stockpile": [Vector3(-0.9414, 0.0, -0.9506), Vector3(0.9408, 0.6667, 0.9507)],
	&"fence": [Vector3(-0.938, 0.0, -0.4438), Vector3(0.9371, 1.0048, 0.4351)],
	&"oak_mature": [Vector3(-0.9293, 0.0, -0.7769), Vector3(0.9232, 1.8977, 0.768)],
	&"beech_mature": [Vector3(-0.5307, 0.0, -0.4848), Vector3(0.5475, 1.9004, 0.4888)],
	&"oak_sapling": [Vector3(-0.3719, 0.0, -0.1772), Vector3(0.3838, 1.9007, 0.1693)],
	&"stump_mossy": [Vector3(-0.9507, 0.0, -0.9217), Vector3(0.9472, 0.9494, 0.9324)],
	&"mossy_boulder": [Vector3(-0.7325, 0.0, -0.9114), Vector3(0.7995, 1.511, 0.9225)],
	&"rock_cluster": [Vector3(-0.9523, 0.0, -0.8745), Vector3(0.9507, 0.8433, 0.8667)],
	&"fallen_log": [Vector3(-0.8699, 0.0, -0.3725), Vector3(0.944, 0.7296, 0.3399)],
	&"grass_tuft": [Vector3(-0.9272, 0.0, -0.9077), Vector3(0.8488, 1.3713, 0.8756)],
	&"mushroom_cluster": [Vector3(-0.8595, 0.0, -0.95), Vector3(0.8686, 1.1711, 0.9077)],
	&"reeds": [Vector3(-0.8473, 0.0, -0.8648), Vector3(0.7769, 1.5574, 0.8348)],
	&"crop_grain_ripe": [Vector3(-0.948, 0.0, -0.9388), Vector3(0.9456, 0.5193, 0.9476)],
	&"crop_cabbage_ripe": [Vector3(-0.9517, 0.0, -0.9458), Vector3(0.9501, 0.2459, 0.9445)],
	&"crop_roots_ripe": [Vector3(-0.9371, 0.0, -0.948), Vector3(0.9469, 0.398, 0.9489)],
	&"barrel": [Vector3(-0.8322, 0.0, -0.9508), Vector3(0.8317, 1.8791, 0.937)],
	&"crate": [Vector3(-0.9512, 0.0, -0.7995), Vector3(0.9511, 1.6519, 0.8004)],
	&"log_stack": [Vector3(-0.5912, 0.0, -0.9495), Vector3(0.604, 1.8623, 0.9411)],
	&"handcart": [Vector3(-0.9498, 0.0, -0.605), Vector3(0.949, 0.9437, 0.606)],
	&"water_bucket": [Vector3(-0.9454, 0.0, -0.8378), Vector3(0.9509, 1.637, 0.8128)],
	&"sack_pile": [Vector3(-0.9466, 0.0, -0.7768), Vector3(0.949, 1.2764, 0.7691)],
	&"table_stools": [Vector3(-0.9478, 0.0, -0.6748), Vector3(0.9479, 0.6808, 0.6784)],
	&"wheelbarrow": [Vector3(-0.9508, 0.0, -0.3619), Vector3(0.9508, 0.7507, 0.3611)],
	&"cauldron_tripod": [Vector3(-0.9328, 0.0, -0.9333), Vector3(0.9507, 1.892, 0.9421)],
}


static func is_building(key: StringName) -> bool:
	"""Whether `key` is sized by the authoritative building envelope rather than the demo table."""
	return Dimensions.BUILDING_KEY.has(key)


static func target_height_m(key: StringName) -> float:
	"""The height `key` is drawn at, in metres. 0.0 for a key nothing sizes (a programming error)."""
	if is_building(key):
		var row: int = Dimensions.BUILDING_KEY.find(key)
		return float(Dimensions.BUILDING_MAX_Y_MM[row]) / MILLIMETRES_PER_METRE
	if key == TABLE_KEY:
		return float(Dimensions.WORK_SURFACE_TOP_U) / float(Dimensions.UNITS_PER_METRE)
	if DEMO_HEIGHT_M.has(key):
		return float(DEMO_HEIGHT_M[key])
	push_error("world_sizes: no size for '%s'" % key)
	return 0.0


static func uniform_scale(key: StringName, aabb_min: Vector3, aabb_max: Vector3) -> float:
	"""The one scale factor that makes a model with this bound exactly `target_height_m` tall."""
	var height: float = aabb_max.y - aabb_min.y
	if height <= 0.0:
		push_error("world_sizes: '%s' has a flat or inverted bound" % key)
		return 1.0
	return target_height_m(key) / height


static func native_scale(key: StringName) -> float:
	"""`uniform_scale` against the recorded native bound of `key`."""
	var bound: Array = NATIVE_AABB[key]
	return uniform_scale(key, bound[0], bound[1])


static func scaled_rect(key: StringName, size: float) -> Rect2:
	"""The model's footprint in its own XZ frame (x along +X, y along +Z), at drawn scale."""
	var bound: Array = NATIVE_AABB[key]
	var lo: Vector3 = bound[0]
	var hi: Vector3 = bound[1]
	var s: float = native_scale(key) * size
	return Rect2(Vector2(lo.x, lo.z) * s, Vector2(hi.x - lo.x, hi.z - lo.z) * s)
