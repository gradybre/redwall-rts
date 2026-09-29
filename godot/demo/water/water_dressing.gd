extends RefCounted
## Water-side dressing from EXISTING library assets (no generation): the boathouse, the weir, the
## fisher shelter, the mill with its waterwheel, fish creels, and reeds along the banks -- plus the
## obstacle circles and resident spots they bring. Decision 0196 (live demo), water foundation.
##
## PRESENTATION ONLY, in the shapes world_layout.gd already publishes: placements are float metres
## {id, key, at, yaw, size, block, sink}; obstacles are layout circles (x, z, radius) internally and
## (x, radius, z) at the public boundary, exactly as demo_world.gd converts them; points of interest
## are {name, position, face, activities, capacity}. All of it is a pure function of the authored
## tables below and the recorded NATIVE_AABB, so it is identical with or without staged models.
##
## SIZE. Buildings (boathouse 5.0 m, weir 1.5 m, fisher shelter 3.5 m, mill 7.0 m) are drawn at the
## authoritative envelope height, through world_sizes.gd (which reads lookdev_dimensions.gd). Reeds
## reuse world_sizes.gd's demo height. The fish creel is the one new demo-only height: 0.5 m, a
## creel a mouse carries on its back -- NOT a sizing policy.
##
## FIT. The library models are dioramas that carry their own patch of water and earth. `sink` lowers
## each so its baked water meets the demo surface (LEVEL_DROP_U, 0.18 m, below the datum). Each
## baked level was MEASURED as the area-weighted height of the model's flat, upward-facing
## triangles at drawn scale: boathouse water 0.78 m (base top 1.08 m), fisher shelter water 0.38 m,
## weir tail water 0.25 m (its pool stands higher, as a weir's does), mill plinth 0.50 m. The
## boathouse and shelter sit a few centimetres deeper still, so their baked water lies just under
## the demo surface and their base blocks hide beneath it and the bank. Reeds sink their mud plate
## 0.1 m into the bank. Presentation only.
##
## NOT PLACED: the saltpan. GDD §5.7 accepts salt only from "coastal-brine provenance; well/river
## water is rejected", so a saltpan beside a freshwater pond would read as a working salt source the
## rules forbid. It stays unplaced until the demo has a coast.

const Layout := preload("res://demo/world/world_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const Look := preload("res://demo/world/world_look.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const Rules := preload("res://demo/water/water_rules.gd")

## Measured model bounds [min, max] in metres, from the staging manifest (tools/stage_demo_assets.py,
## WATER). Y-up, front +Z.
const NATIVE_AABB: Dictionary = {
	&"boathouse": [Vector3(-0.7144, 0.0, -0.9508), Vector3(0.7128, 1.2721, 0.9508)],
	&"weir": [Vector3(-0.9502, 0.0, -0.9233), Vector3(0.9493, 1.0679, 0.9244)],
	&"fisher_shelter": [Vector3(-0.8644, 0.0, -0.9414), Vector3(0.8622, 1.899, 0.9406)],
	&"mill": [Vector3(-0.7223, 0.0, -0.6578), Vector3(0.7243, 1.9006, 0.6562)],
	&"fish_creel": [Vector3(-0.9384, 0.0, -0.8095), Vector3(0.9252, 1.0386, 0.8012)],
}
## Demo-only prop heights in metres (see the header). NOT a sizing policy.
const DEMO_HEIGHT_M: Dictionary = {&"fish_creel": 0.5}

## Hand-placed dressing. `sink` (m) lowers a diorama so its baked water meets the demo surface.
const PLACEMENTS: Array[Dictionary] = [
	{"id": &"boathouse", "key": &"boathouse", "at": Vector2(22.9, 23.4), "yaw_deg": 0.0,
		"sink": 1.02},
	{"id": &"fisher_shelter", "key": &"fisher_shelter", "at": Vector2(22.9, 7.3),
		"yaw_deg": 90.0, "sink": 0.84},
	{"id": &"weir", "key": &"weir", "at": Vector2(23.8, -14.0), "yaw_deg": 0.0, "sink": 0.43},
	{"id": &"mill", "key": &"mill", "at": Vector2(27.9, -19.5), "yaw_deg": 0.0, "sink": 0.48},
	{"id": &"creel_shelter", "key": &"fish_creel", "at": Vector2(19.75, 5.7), "yaw_deg": 25.0,
		"sink": 0.0},
	{"id": &"creel_weir", "key": &"fish_creel", "at": Vector2(19.75, -16.3), "yaw_deg": -35.0,
		"sink": 0.0},
]

## Reed clumps: each snaps to the waterline nearest its point (m), at a demo size.
const REED_SINK_M: float = 0.1
const REEDS: Array[Vector3] = [
	Vector3(21.0, 31.2, 0.8), Vector3(22.0, 33.6, 0.95), Vector3(25.0, 36.8, 0.85),
	Vector3(30.6, 32.0, 0.9), Vector3(34.6, 26.8, 0.8), Vector3(33.4, 22.2, 0.9),
	Vector3(21.6, 27.3, 0.75), Vector3(21.9, 13.9, 0.85), Vector3(27.6, 8.4, 0.8),
	Vector3(21.7, -9.4, 0.9), Vector3(27.3, -11.5, 0.85), Vector3(21.4, -29.5, 0.9),
]

## Resident spots at the water, just inside the play square (see water_layout.gd).
const POINTS: Array[Dictionary] = [
	{"name": &"fishing_spot", "at": Vector2(19.35, 9.5), "face_to": Vector2(23.0, 8.6),
		"activities": [&"collect_object", &"idle"], "capacity": 1},
	{"name": &"weir_work", "at": Vector2(19.35, -13.1), "face_to": Vector2(23.8, -14.0),
		"activities": [&"collect_object", &"idle"], "capacity": 1},
	{"name": &"boat_landing", "at": Vector2(19.3, 19.25), "face_to": Vector2(22.9, 22.4),
		"activities": [&"collect_object", &"wave_one_hand"], "capacity": 1},
]

## The woods' blockers reach this far past the WATERLINE; world_scatter.gd then keeps a tree
## trunk 2.0 m and a log or rock 1.5 m beyond them -- 2.45 m and 1.95 m past the waterline, both
## beyond the 1.2 m bank -- so nothing grows on the bank, and nothing further out is disturbed.
const WOODS_MARGIN_M: float = 0.45


static func target_height_m(key: StringName) -> float:
	"""The height `key` is drawn at: the demo prop table here, else world_sizes.gd's rule."""
	if DEMO_HEIGHT_M.has(key):
		return float(DEMO_HEIGHT_M[key])
	return Sizes.target_height_m(key)


static func uniform_scale(key: StringName, aabb_min: Vector3, aabb_max: Vector3) -> float:
	"""The one scale factor that draws a model with this bound at `target_height_m(key)`."""
	var height: float = aabb_max.y - aabb_min.y
	if height <= 0.0:
		push_error("water dressing: '%s' has a flat or inverted bound" % key)
		return 1.0
	return target_height_m(key) / height


static func native_bound(key: StringName) -> Array:
	"""[min, max] recorded for `key`: this module's table, else world_sizes.gd's."""
	if NATIVE_AABB.has(key):
		return NATIVE_AABB[key]
	return Sizes.NATIVE_AABB[key]


static func scaled_rect(key: StringName, size: float) -> Rect2:
	"""The model's footprint in its own XZ frame at drawn scale (x along +X, y along +Z)."""
	var bound: Array = native_bound(key)
	var lo: Vector3 = bound[0]
	var hi: Vector3 = bound[1]
	var s: float = uniform_scale(key, lo, hi) * size
	return Rect2(Vector2(lo.x, lo.z) * s, Vector2(hi.x - lo.x, hi.z - lo.z) * s)


static func placements() -> Array[Dictionary]:
	"""Every hand-placed dressing piece, normalised: {id, key, at, yaw (rad), size, block, sink}."""
	var out: Array[Dictionary] = []
	for entry: Dictionary in PLACEMENTS:
		var p: Dictionary = Layout.normalised(entry)
		p["sink"] = float(entry["sink"])
		out.append(p)
	return out


static func placement_circles(p: Dictionary) -> Array[Vector3]:
	"""Layout circles (x, z, radius) ringing one placement's footprint -- world_layout.gd's ring
	(`cell_grid`, `cell_radius`, `rotate_xz`) over this module's sizes."""
	var out: Array[Vector3] = []
	var rect: Rect2 = scaled_rect(p["key"], p["size"])
	var grid: Vector2i = Layout.cell_grid(rect)
	var cell := Vector2(rect.size.x / grid.x, rect.size.y / grid.y)
	var radius: float = Layout.cell_radius(rect)
	for ix: int in grid.x:
		for iz: int in grid.y:
			if ix > 0 and iz > 0 and ix < grid.x - 1 and iz < grid.y - 1:
				continue
			var local: Vector2 = rect.position + cell * (Vector2(ix, iz) + Vector2(0.5, 0.5))
			var world: Vector2 = (p["at"] as Vector2) + Layout.rotate_xz(local, p["yaw"])
			out.append(Vector3(world.x, world.y, radius))
	return out


static func footprint_circles() -> Array[Vector3]:
	"""Every placement's layout circles, whether or not they reach the play area."""
	var out: Array[Vector3] = []
	for p: Dictionary in placements():
		out.append_array(placement_circles(p))
	return out


static func obstacles() -> Array[Vector3]:
	"""The dressing circles residents walk round, in the PUBLIC form (x, radius, z): those that come
	within world_layout.gd's report margin of the play area."""
	var out: Array[Vector3] = []
	for circle: Vector3 in footprint_circles():
		if Layout.circle_reaches_play(circle):
			out.append(Vector3(circle.x, circle.z, circle.y))
	return out


static func woods_blockers() -> Array[Vector3]:
	"""Layout circles no tree, log, stump or rock may stand in: the water and its banks, and every
	dressing footprint. demo_world.gd adds them to its woodland blockers."""
	var out: Array[Vector3] = WaterLayout.water_circles_m(WOODS_MARGIN_M)
	out.append_array(footprint_circles())
	return out


static func points_of_interest() -> Array[Dictionary]:
	"""The water's resident spots in world_layout.gd's published shape."""
	var out: Array[Dictionary] = []
	for point: Dictionary in POINTS:
		var at: Vector2 = point["at"]
		var face: Vector2 = ((point["face_to"] as Vector2) - at).normalized()
		var activities: Array[StringName] = []
		for activity: StringName in point["activities"]:
			activities.append(activity)
		out.append({
			"name": point["name"], "position": Vector3(at.x, Layout.GROUND_Y, at.y),
			"face": Vector3(face.x, 0.0, face.y), "activities": activities,
			"capacity": int(point["capacity"]),
		})
	return out


static func reed_placements(map: WaterMapScript) -> Array[Dictionary]:
	"""Every reed clump snapped to the waterline nearest its authored point, standing on the bank
	(or bed) there. Deterministic: the map's shore samples and a fixed yaw per clump."""
	var out: Array[Dictionary] = []
	var bank := WaterMapScript.Bank.new()
	for k: int in REEDS.size():
		var near := Vector2i(Rules.to_u(REEDS[k].x), Rules.to_u(REEDS[k].y))
		if not map.nearest_bank(near, bank):
			continue
		out.append({"id": &"", "key": &"reeds", "at": Vector2(Rules.to_m(bank.x), Rules.to_m(bank.z)),
			"yaw": float(k) * 2.4, "size": REEDS[k].z, "block": false,
			"sink": REED_SINK_M - Rules.to_m(map.ground_height_at(bank.point()))})
	return out


# --- drawing -----------------------------------------------------------------------------------

static func build(parent: Node3D, world_manifest: Dictionary, map: WaterMapScript) -> Array[Node3D]:
	"""Instance every dressing piece and reed under `parent`; the staged model where there is one,
	else a box of the same footprint. Returns the pieces made (presentation only)."""
	var made: Array[Node3D] = []
	var scenes: Dictionary = {}
	var all: Array[Dictionary] = placements()
	all.append_array(reed_placements(map))
	for p: Dictionary in all:
		var piece: Node3D = _piece(world_manifest, scenes, p)
		parent.add_child(piece)
		made.append(piece)
	return made


static func _piece(world_manifest: Dictionary, scenes: Dictionary, p: Dictionary) -> Node3D:
	"""One placed model, or its placeholder, at its drawn scale, yaw and sink."""
	var key: StringName = p["key"]
	var entry: Dictionary = world_manifest.get(String(key), {})
	var scene: PackedScene = _scene(scenes, entry)
	var piece: Node3D
	var scale_factor: float
	if scene != null:
		piece = scene.instantiate() as Node3D
		var lo: Array = entry["aabb_min"]
		var hi: Array = entry["aabb_max"]
		scale_factor = uniform_scale(key, Vector3(lo[0], lo[1], lo[2]), Vector3(hi[0], hi[1], hi[2]))
	else:
		piece = _placeholder(key)
		var bound: Array = native_bound(key)
		scale_factor = uniform_scale(key, bound[0], bound[1])
	piece.name = "Water_%s" % (p["id"] if p["id"] != &"" else key)
	var at: Vector2 = p["at"]
	var basis := Basis(Vector3.UP, float(p["yaw"])).scaled(Vector3.ONE * scale_factor * float(p["size"]))
	piece.transform = Transform3D(basis, Vector3(at.x, Layout.GROUND_Y - float(p["sink"]), at.y))
	return piece


static func _scene(scenes: Dictionary, entry: Dictionary) -> PackedScene:
	"""The staged scene of a manifest entry, loaded once per path; null when it is not staged."""
	var path: String = entry.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not scenes.has(path):
		scenes[path] = load(path) as PackedScene
	return scenes[path]


static func _placeholder(key: StringName) -> Node3D:
	"""A box filling the recorded native bound, in native units (the transform scales it)."""
	var bound: Array = native_bound(key)
	var lo: Vector3 = bound[0]
	var hi: Vector3 = bound[1]
	var box := BoxMesh.new()
	box.size = hi - lo
	var material := StandardMaterial3D.new()
	material.albedo_color = Look.LEAF if key == &"reeds" else Look.TIMBER
	material.roughness = 0.9
	box.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.position = (lo + hi) * 0.5
	var holder := Node3D.new()
	holder.add_child(instance)
	return holder
