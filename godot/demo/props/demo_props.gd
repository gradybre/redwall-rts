extends RefCounted
## The demo's staged small props, their drawn sizes and their icons. Decision 0196. Presentation only.
##
## tools/make_demo_props.py makes a game-budget L0 of every new library prop (items, finds, relics,
## tunnel brace and rubble, the mole's pick, boats, jetty, fishing gear) into the gitignored
## res://demo/assets/props/, bottom origin and facing +Z, with a 128 px icon for the items, finds
## and relics; stage_demo_assets.py stages the older library L0s this pass uses (lantern, bed, jars,
## shelf, tools) as world rows. Every row is in the manifest's `world`. This loads each model's ONE
## mesh once, so any number of placements can share it -- as MultiMesh instances, or as
## MeshInstance3D nodes over the same Mesh.
##
## SIZE. Every model is drawn at a DEMO-ONLY size (SIZES), judged against the approved creature
## heights (mouse 1.00 m, mole 0.90, squirrel 1.15, otter 1.49, badger 2.55 -- DEC-039) as the rest of
## the demo's props are (world/world_sizes.gd). A prop that stands (a lantern, a shelf) is sized by
## its HEIGHT; one that lies or is carried (a fish, a bunch of carrots, a boat) by its LONGEST side,
## because its height says nothing about how big it looks. NOT a sizing policy.
##
## NOTHING STAGED (CI, a fresh clone): every key still draws, as a plain box of its drawn size
## standing on y = 0, and every icon is a fallback roundel in the swatch colour asked for -- so the
## demo, and the tests, run the same code either way.

const Palette := preload("res://demo/ui/woodland_palette.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const DemoManifestScript := preload("res://demo/demo_manifest.gd")

const RULE_HEIGHT: int = 0
const RULE_LONGEST: int = 1
## Demo-only drawn size per key: [rule, metres]. One rationale per group; see the header.
const SIZES: Dictionary = {
	# Harvested items, as carried in a mouse's arms and set on a shelf: a bunch or a head of a hand
	# or two, leeks, celery and sheaves the length of a mouse's forearm and more.
	&"item_radish": [RULE_LONGEST, 0.26], &"item_turnip": [RULE_LONGEST, 0.3], &"item_carrot": [RULE_LONGEST, 0.42],
	&"item_beetroot": [RULE_LONGEST, 0.32], &"item_onion": [RULE_LONGEST, 0.24], &"item_leek": [RULE_LONGEST, 0.55],
	&"item_lettuce": [RULE_LONGEST, 0.3], &"item_celery": [RULE_LONGEST, 0.5], &"item_strawberry": [RULE_LONGEST, 0.26],
	&"item_peas": [RULE_LONGEST, 0.26], &"item_barley": [RULE_LONGEST, 0.55], &"item_oats": [RULE_LONGEST, 0.55],
	# Catches: a trout a mouse holds in both arms, a perch a little smaller, an eel longer still.
	&"item_trout": [RULE_LONGEST, 0.45], &"item_perch": [RULE_LONGEST, 0.34], &"item_eel": [RULE_LONGEST, 0.6],
	&"item_shrimp": [RULE_LONGEST, 0.26], &"item_mussels": [RULE_LONGEST, 0.28], &"item_hotroot": [RULE_LONGEST, 0.3],
	# Finds and relics: pocket-sized to a mole (0.90 m); the banner a folded cloth a paw across.
	&"find_flint": [RULE_LONGEST, 0.26], &"find_clay": [RULE_LONGEST, 0.3], &"relic_bell": [RULE_LONGEST, 0.22],
	&"relic_key": [RULE_LONGEST, 0.22], &"relic_banner": [RULE_LONGEST, 0.45],
	# Tunnel and mole: the pick a mole swings one-pawed; rubble a fall a metre and a half across.
	&"mole_pick": [RULE_LONGEST, 0.55], &"tunnel_rubble": [RULE_LONGEST, 1.6],
	# The brace is fitted to each bore (tunnel_marks.gd); this is only its standalone size.
	&"tunnel_brace": [RULE_HEIGHT, 0.9],
	# Lanterns hung at a mole's head height; room furniture at mole scale (a 0.9 m mole).
	&"wall_lantern": [RULE_HEIGHT, 0.36], &"basket": [RULE_HEIGHT, 0.34],
	&"clay_jars": [RULE_HEIGHT, 0.55], &"pantry_shelf": [RULE_HEIGHT, 1.35],
	# The fit-out (decision 0210): a bed long enough for the otters (1.49 m; bed_allocation.gd BED_LENGTH_U), a stone
	# hearth whose mantel stands at a mole's head, a table and stools for a burrow's corner, and sacks, a barrel and a
	# crate a size that stands on a cellar's rack.
	&"bed": [RULE_LONGEST, 1.6], &"hearth": [RULE_HEIGHT, 1.15], &"table_stools": [RULE_LONGEST, 1.1],
	&"sack_pile": [RULE_LONGEST, 0.55], &"barrel": [RULE_HEIGHT, 0.5], &"crate": [RULE_HEIGHT, 0.4],
	# Farm tools lying by the beds and an axe at the woodpile, mouse-sized (a 1.00 m mouse).
	&"spade": [RULE_LONGEST, 0.8], &"hoe": [RULE_LONGEST, 0.9], &"sickle": [RULE_LONGEST, 0.45],
	&"axe": [RULE_LONGEST, 0.6],
	# Water: a one-otter coracle, a four-mouse rowboat, a raft for two, and a jetty out to deep water.
	&"boat_coracle": [RULE_LONGEST, 1.4], &"boat_rowboat": [RULE_LONGEST, 3.2], &"boat_raft": [RULE_LONGEST, 2.2],
	&"jetty": [RULE_LONGEST, 3.4], &"fishing_rod": [RULE_LONGEST, 1.8], &"fishing_net": [RULE_LONGEST, 0.9],
	&"eel_trap": [RULE_LONGEST, 0.85], &"smoking_rack": [RULE_HEIGHT, 1.5],
	# The woods (demo/forestry/): a felled oak's bole and the beaver's gnawed one lying where they fell
	# (a 13 m oak, world_sizes.gd); the sawhorse with its frame saw at a squirrel's height; a plank stack
	# a mouse sees over; the chopping block and its axe to a mouse's hip; a sapling in its basket carried
	# in both arms; a stock log and a plank the length a mouse carries on its shoulder.
	&"felled_trunk": [RULE_LONGEST, 5.5], &"gnawed_log": [RULE_LONGEST, 5.0], &"sawhorse": [RULE_HEIGHT, 1.3],
	&"plank_stack": [RULE_HEIGHT, 0.9], &"chopping_block": [RULE_HEIGHT, 0.8], &"sapling_basket": [RULE_HEIGHT, 0.95],
	&"bridge_log": [RULE_LONGEST, 1.8], &"bridge_plank": [RULE_LONGEST, 1.6],
	# The bridges' piers (demo/waterplay/): a post standing from the stream's bed to a deck, its standalone
	# size; a bridge draws each to its own depth (bridge_view.gd).
	&"bridge_pier": [RULE_HEIGHT, 1.6],
}
## Library BUILDINGS this pass draws as props: drawn at their authoritative envelope height
## (world_sizes.gd, lookdev_dimensions.gd BUILDING_MAX_Y_MM) -- the root cellar's door-in-a-mound
## (2.0 m) and the compost bins (1.25 m).
const BUILDINGS: Array[StringName] = [&"cellar", &"composter"]
## Placeholder box proportions (width, height, depth over the drawn size) by rule.
const PLACEHOLDER_STANDING: Vector3 = Vector3(0.6, 1.0, 0.6)
const PLACEHOLDER_LYING: Vector3 = Vector3(1.0, 0.35, 0.5)
const PLACEHOLDER_COLOUR: Color = Palette.TIMBER
## Fallback icons: a roundel this many pixels across, ringed in brass.
const ROUNDEL_PX: int = 64
const ROUNDEL_RING_PX: float = 4.0

## key -> manifest row (the staged ones only).
var _rows: Dictionary = {}
## key -> [Mesh, Transform3D]: the model's mesh and the transform that draws it at its size.
var _meshes: Dictionary = {}
var _icons: Dictionary = {}
var _roundels: Dictionary = {}


func load_from(manifest: Dictionary) -> void:
	"""Remember every staged row this table sizes (loading waits until a mesh is asked for)."""
	var world: Dictionary = manifest.get("world", {})
	for key: StringName in SIZES.keys() + BUILDINGS:
		var row: Dictionary = world.get(String(key), {})
		if not row.is_empty() and ResourceLoader.exists(String(row.get("path", ""))):
			_rows[key] = row


func is_staged(key: StringName) -> bool:
	"""Whether `key`'s real model is staged (else it draws as a placeholder box)."""
	return _rows.has(key)


static func is_known(key: StringName) -> bool:
	"""Whether `key` has a drawn size here."""
	return SIZES.has(key) or BUILDINGS.has(key)


static func rule_of(key: StringName) -> int:
	"""RULE_HEIGHT or RULE_LONGEST: what `key`'s drawn size measures."""
	return RULE_HEIGHT if BUILDINGS.has(key) else int((SIZES[key] as Array)[0])


static func drawn_size_m(key: StringName) -> float:
	"""The size `key` is drawn at, along its rule's measure (metres)."""
	if BUILDINGS.has(key):
		return Sizes.target_height_m(key)
	return float((SIZES[key] as Array)[1])


static func scale_for(key: StringName, aabb_min: Vector3, aabb_max: Vector3) -> float:
	"""The one uniform scale that draws a model with this bound at its demo size."""
	var extent: Vector3 = aabb_max - aabb_min
	var measure: float = extent.y if rule_of(key) == RULE_HEIGHT else maxf(extent.x, maxf(extent.y, extent.z))
	if measure <= 0.0:
		push_error("demo_props: '%s' has a flat or inverted bound" % key)
		return 1.0
	return drawn_size_m(key) / measure


static func placeholder_size(key: StringName) -> Vector3:
	"""The box a missing model is drawn as: its drawn size, standing or lying by its rule."""
	var proportion: Vector3 = PLACEHOLDER_STANDING if rule_of(key) == RULE_HEIGHT else PLACEHOLDER_LYING
	return proportion * drawn_size_m(key)


func mesh_of(key: StringName) -> Mesh:
	"""`key`'s mesh (shared by every placement), staged or its placeholder box."""
	return _entry(key)[0]


func fit_of(key: StringName) -> Transform3D:
	"""The transform that draws `mesh_of(key)` at its demo size, its base on y = 0, centred on X/Z."""
	return _entry(key)[1]


func drawn_bound(key: StringName) -> AABB:
	"""`key`'s bound as drawn (metres, in its own frame)."""
	return fit_of(key) * mesh_of(key).get_aabb()


func instance(key: StringName) -> MeshInstance3D:
	"""A new node drawing `key` at its size (place it by its parent, or by `transform * fit_of`)."""
	var node := MeshInstance3D.new()
	node.name = String(key)
	node.mesh = mesh_of(key)
	node.transform = fit_of(key)
	return node


func _entry(key: StringName) -> Array:
	"""[mesh, fit] for `key`, made once."""
	if not _meshes.has(key):
		_meshes[key] = _staged_entry(key) if _rows.has(key) else _placeholder_entry(key)
	return _meshes[key]


func _staged_entry(key: StringName) -> Array:
	"""The staged model's first mesh, and its scale from the manifest's measured bound."""
	var row: Dictionary = _rows[key]
	var root: Node = (load(String(row["path"])) as PackedScene).instantiate()
	var found: Array = first_mesh(root, Transform3D.IDENTITY)
	root.free()
	if found.is_empty():
		push_warning("demo_props: '%s' is staged with no mesh; drawing a placeholder" % key)
		return _placeholder_entry(key)
	var lo: Array = row["aabb_min"]
	var hi: Array = row["aabb_max"]
	var s: float = scale_for(key, Vector3(lo[0], lo[1], lo[2]), Vector3(hi[0], hi[1], hi[2]))
	var centre := Vector3((float(lo[0]) + float(hi[0])) * 0.5, float(lo[1]), (float(lo[2]) + float(hi[2])) * 0.5)
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * s), -centre * s) * (found[1] as Transform3D)
	return [found[0], fit]


func _placeholder_entry(key: StringName) -> Array:
	"""A plain box of the drawn size standing on y = 0."""
	var size: Vector3 = placeholder_size(key)
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = PLACEHOLDER_COLOUR
	material.roughness = 0.9
	box.material = material
	return [box, Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, 0.0))]


static func first_mesh(node: Node, parent: Transform3D) -> Array:
	"""[mesh, accumulated transform] of the first MeshInstance3D under `node`, or [] (setup only)."""
	var here: Transform3D = parent * (node as Node3D).transform if node is Node3D else parent
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return [(node as MeshInstance3D).mesh, here]
	for child: Node in node.get_children():
		var found: Array = first_mesh(child, here)
		if not found.is_empty():
			return found
	return []


func warm_all() -> int:
	"""Load now every staged model and icon this table knows, which would otherwise load the first time
	one is shown -- mid-game, a hitch (demo_prewarm.gd, decision 0205). Returns how many were loaded."""
	var loaded: int = 0
	for key: StringName in _rows.keys():
		if not _meshes.has(key):
			_entry(key)
			loaded += 1
		if has_icon(key) and not _icons.has(key) and _warm_icon(key):
			loaded += 1
	return loaded


func _warm_icon(key: StringName) -> bool:
	"""Read `key`'s staged icon into the cache; false (nothing cached) when it will not load, so a later
	`icon_of` still falls back to its roundel."""
	var image := Image.load_from_file(DemoManifestScript.readable_path(String(_rows[key]["icon"])))
	if image == null or image.is_empty():
		return false
	_icons[key] = ImageTexture.create_from_image(image)
	return true


func loaded_count() -> int:
	"""How many models are loaded (checks)."""
	return _meshes.size()


# --- icons -----------------------------------------------------------------------------------

func has_icon(key: StringName) -> bool:
	"""Whether `key` has a staged icon."""
	return _rows.has(key) and String((_rows[key] as Dictionary).get("icon", "")) != ""


func icon_of(key: StringName, swatch: Color) -> Texture2D:
	"""`key`'s staged icon, or -- when it has none, or none is staged -- a roundel in `swatch`. Read from
	`DemoManifest.readable_path`, so an exported build finds it in its pack."""
	if not has_icon(key):
		return roundel(swatch)
	if not _icons.has(key):
		var image := Image.load_from_file(DemoManifestScript.readable_path(String(_rows[key]["icon"])))
		_icons[key] = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else roundel(swatch)
	return _icons[key]


func roundel(swatch: Color) -> Texture2D:
	"""The fallback icon: a disc of `swatch`, lit from the upper left, ringed in brass. One per colour."""
	if not _roundels.has(swatch):
		_roundels[swatch] = ImageTexture.create_from_image(roundel_image(swatch))
	return _roundels[swatch]


static func roundel_image(swatch: Color) -> Image:
	"""The roundel's pixels (see `roundel`)."""
	var image := Image.create_empty(ROUNDEL_PX, ROUNDEL_PX, false, Image.FORMAT_RGBA8)
	var centre := Vector2(ROUNDEL_PX, ROUNDEL_PX) * 0.5
	var radius: float = ROUNDEL_PX * 0.5 - 1.0
	for y: int in ROUNDEL_PX:
		for x: int in ROUNDEL_PX:
			var offset := Vector2(x + 0.5, y + 0.5) - centre
			var d: float = offset.length()
			if d > radius:
				continue
			var light: float = 1.0 + 0.25 * (-offset.x - offset.y) / (radius * 1.414)
			var colour: Color = Palette.BRASS if d > radius - ROUNDEL_RING_PX else swatch * light
			colour.a = clampf(radius - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, colour)
	return image
