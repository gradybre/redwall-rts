extends Node3D
## The live demo's world: a small Mossflower village clearing. Decision 0196. Presentation only.
##
## Interface (stable; the cast and camera build against it):
##   GROUND_Y              the ground is flat at this height.
##   build(manifest)       terrain, sun/sky and the village. With no staged world assets
##                         (`manifest["world"]` empty -- CI, a fresh clone) it builds the SAME
##                         layout from placeholder shapes of the same footprints.
##   points_of_interest()  where residents stand to work, drink, wave or idle.
##   obstacles()           circles residents walk around, as Vector3(x, radius, z): x and z the
##                         centre, y the radius. (world_layout.gd keeps its own (x, z, radius)
##                         form internally; obstacles() converts at this boundary.)
##   bounds()              the walkable area.
##   building_obstacles()  the obstacle circles of the buildings and the well alone -- what no
##                         player-dug tunnel may pass under (demo/tunnel/).
##   hide_cover(...)       hide the ground cover over a new tunnel's holes, heaps and route, so no
##                         grass pokes up through a hole or a mound.
##   trees()               every tree placement -- the authored ones and the woods' -- in a fixed
##                         order; `tree_node(i)` is the node drawing tree i once built (the woods,
##                         demo/forestry/, fell, regrow and replace them).
##   woods_obstacles(r)    the woods' blocking circles standing beyond the play area's report margin
##                         but within `r` m of the square: the ground the forestry crew walks.
##   make_piece(...)       one more model of a world key, drawn exactly as the world draws it.
##   piece_transform(...)  where a placed model stands: scaled, turned, and a staged model let down
##                         into the ground by its baked base (world_sizes.gd SINK_M).
##   placed_node(id)       the node drawing authored placement `id` (null before build()).
##   stage_node(id)        placement `id`'s LATER STAGE, built hidden (null when not staged; see STAGES).
##   window_glow(id)       lit home `id`'s window materials (see THE HOMES' WINDOWS): the night lights drive them.
## The three queries are pure functions of the authored layout: they answer identically before
## or after `build()`, and whether or not assets are staged.
##
## Scale: buildings are drawn at their authoritative envelope height; everything else at the
## demo-only heights in `world_sizes.gd`. Layout: `world_layout.gd`. Dressing: `world_scatter.gd`.
## Ground and light: `world_look.gd`.

const Layout := preload("res://demo/world/world_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const DemoManifestScript := preload("res://demo/demo_manifest.gd")
const Scatter := preload("res://demo/world/world_scatter.gd")
const Look := preload("res://demo/world/world_look.gd")
const CropCards := preload("res://demo/world/crop_cards.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const Curves := preload("res://demo/world/daylight_curves.gd")

const GROUND_Y: float = 0.0

## THE HOMES' WINDOWS (decision 0541; art pass 2, decision 0951). A lit home (daylight_curves.gd LIT_HOMES) whose
## `<key>_windows` row is staged -- the same L0 with an emissive window mask, I11 Ember -- is drawn with that model
## instead. Its emissive materials are duplicated per home and start dark (energy 0); night_lights.gd drives them from
## the home's own lamp flag (`window_glow`). Not staged (CI, a fresh clone): the plain model, as before.
const WINDOWS_SUFFIX: String = "_windows"
## LATER STAGES (decision 0771): a placement's later model, drawn with the placement's own transform and scale (not by
## its own DEMO_HEIGHT_M) and built hidden with the village -- so the weather's overlay finds it like any piece -- for
## its view to show (hall_view.gd): the hall's stone stage 2. Built only when it and the placement's own model are
## staged; its windows model in its place when that is staged, its glow listed under the placement's id.
const STAGES: Dictionary = {&"hall": &"hall_stage2"}

## Ground cover is drawn as one MultiMesh per key rather than one node per tuft.
const MULTIMESH_KEYS: Array[StringName] = [&"grass_tuft", &"mushroom_cluster"]

## Albedo corrections for staged textures, as a multiply on a shared duplicate of the model's own
## material (the staged texture is untouched). Each is MEASURED, never chosen by eye.
##   crop_cabbage_ripe: the savoy's blue-green is authored (its concept is blue-green) and is kept.
##   The texture runs a little bluer and more saturated than its own concept: median leaf RGB
##   (62, 109, 110) against the concept's (81, 123, 118). The ratio, normalised on green so
##   brightness is unchanged, is (1.16, 1.0, 0.95): it moves the leaves' hue onto the concept's,
##   and nothing further.
const MATERIAL_TINT: Dictionary = {
	&"crop_cabbage_ripe": Color(1.16, 1.0, 0.95),
}

const PLACEHOLDER_TREES: Array[StringName] = [&"oak_mature", &"beech_mature", &"oak_sapling"]
const PLACEHOLDER_GREEN: Array[StringName] = [
	&"grass_tuft", &"reeds", &"crop_cabbage_ripe", &"crop_roots_ripe",
]
const PLACEHOLDER_STONE: Array[StringName] = [&"mossy_boulder", &"rock_cluster"]
## A ground-cover piece this close to a hidden area is hidden too: its tufts spread about this far.
const COVER_MARGIN_M: float = 0.45

var _layout_ready: bool = false
## The manifest's world rows (for make_piece after build).
var _world_rows: Dictionary = {}
## Per tree placement (trees() order): the node drawing it (null before build).
var _tree_nodes: Array[Node3D] = []
var _structure: Array[Dictionary] = []
var _dressing: Array[Dictionary] = []
var _cover: Array[Dictionary] = []
var _obstacles: Array[Vector3] = []
var _points: Array[Dictionary] = []
var _scenes: Dictionary = {}
var _placeholder_meshes: Dictionary = {}
var _card_textures: Dictionary = {}
var _tinted_materials: Dictionary = {}
## Only what build() made; anything the integrator parents under this node survives a rebuild.
var _built: Array[Node] = []
var _cover_nodes: Array[MultiMeshInstance3D] = []
## Per cover node: where each piece stands (x, z), and whether it has been hidden. Kept here rather
## than read back from the MultiMesh, whose transforms only the renderer holds.
var _cover_at: Array[PackedVector2Array] = []
var _cover_hidden: Array[PackedByteArray] = []
## Per authored placement id: the node drawing it, and its later stage (STAGES; built hidden).
var _placed_nodes: Dictionary = {}
var _stage_nodes: Dictionary = {}
## Per lit home id: its window materials (Array[BaseMaterial3D]), each list kept across rebuilds (emptied, refilled) so
## a holder of it reads the current ones.
var _glow: Dictionary = {}


func build(manifest: Dictionary) -> void:
	"""Build ground, light and village from the staged manifest (placeholders when none)."""
	_clear_built()
	_ensure_layout()
	var world: Dictionary = manifest.get("world", {})
	_world_rows = world
	var village := Node3D.new()
	village.name = "Village"
	_built = [Look.make_ground(), Look.make_sun(), Look.make_environment(), village]
	for node: Node in _built:
		add_child(node)
	_build_pieces(world, village)
	_cover_nodes.clear()
	_cover_at.clear()
	_cover_hidden.clear()
	for key: StringName in MULTIMESH_KEYS:
		_cover_nodes.append(_make_cover(world, key))
		village.add_child(_cover_nodes[-1])


func _build_pieces(world: Dictionary, village: Node3D) -> void:
	"""Every placed model under `village`: the trees listed, each authored placement and its later stage kept by id, a
	lit home's windows glow listed."""
	_tree_nodes.clear()
	_placed_nodes.clear()
	_stage_nodes.clear()
	for list: Array in _glow.values():
		list.clear()
	for p: Dictionary in _placed():
		var model: StringName = _windows_key(world, p)
		var piece: Node3D = _make_piece(world, p, model)
		village.add_child(piece)
		if PLACEHOLDER_TREES.has(p["key"]):
			_tree_nodes.append(piece)
		var id: StringName = p.get("id", &"")
		if id != &"":
			_placed_nodes[id] = piece
			if model != p["key"]:
				_collect_glow(id, piece)
			_add_stage(world, p, piece, village)


func _windows_key(world: Dictionary, p: Dictionary) -> StringName:
	"""The model a placement is drawn with: a lit home's `<key>_windows` when it and its plain model are staged (THE
	HOMES' WINDOWS), else its own key."""
	var key: StringName = p["key"]
	if not Curves.LIT_HOMES.has(p.get("id", &"")):
		return key
	return _staged_variant(world, key, StringName(String(key) + WINDOWS_SUFFIX))


func _staged_variant(world: Dictionary, key: StringName, variant: StringName) -> StringName:
	"""`variant` when both it and `key` are staged and load, else `key`."""
	if _staged_scene(world, key) != null and _staged_scene(world, variant) != null:
		return variant
	return key


func _add_stage(world: Dictionary, p: Dictionary, piece: Node3D, village: Node3D) -> void:
	"""Placement `p`'s later stage (STAGES), hidden, with `piece`'s own transform: only when it and the placement's own
	model are staged; its windows model when that is."""
	var id: StringName = p["id"]
	if not STAGES.has(id):
		return
	var key: StringName = STAGES[id]
	if _staged_scene(world, p["key"]) == null or _staged_scene(world, key) == null:
		return
	var model: StringName = _staged_variant(world, key, StringName(String(key) + WINDOWS_SUFFIX))
	var stage: Node3D = _staged_scene(world, model).instantiate() as Node3D
	stage.name = "Stage_%s" % key
	stage.transform = piece.transform
	stage.visible = false
	village.add_child(stage)
	_stage_nodes[id] = stage
	if model != key:
		_collect_glow(id, stage)


func _collect_glow(id: StringName, piece: Node3D) -> void:
	"""List `piece`'s emissive materials under home `id`, each a dark duplicate of its own on that piece alone (the
	shared model untouched): a staged windows model's mask. Called for windows models only."""
	for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not source.emission_enabled:
				continue
			var dark := source.duplicate() as BaseMaterial3D
			dark.emission_energy_multiplier = 0.0
			mesh_instance.set_surface_override_material(surface, dark)
			_glow_list(id).append(dark)


func _glow_list(id: StringName) -> Array:
	"""Home `id`'s window materials list, made once."""
	if not _glow.has(id):
		_glow[id] = []
	return _glow[id]


func placed_node(id: StringName) -> Node3D:
	"""The node drawing authored placement `id` (null before build(), or for no such placement)."""
	return _placed_nodes.get(id, null) as Node3D


func stage_node(id: StringName) -> Node3D:
	"""Placement `id`'s later stage (STAGES), built hidden; null when it is not staged or before build()."""
	return _stage_nodes.get(id, null) as Node3D


func window_glow(id: StringName) -> Array:
	"""Lit home `id`'s window materials (BaseMaterial3D; THE HOMES' WINDOWS): its windows model's and its later
	stage's. The same list for the life of this world, refilled by each build(); empty with nothing staged."""
	return _glow_list(id)


func points_of_interest() -> Array[Dictionary]:
	"""Spots residents walk to: {name, position, face, activities, capacity}. A fresh copy."""
	_ensure_layout()
	return _points.duplicate(true)


func obstacles() -> Array[Vector3]:
	"""Circles residents must walk around: Vector3(x, radius, z) -- x, z the centre, y the radius (m)."""
	_ensure_layout()
	var out: Array[Vector3] = []
	for circle: Vector3 in _obstacles:
		out.append(public_circle(circle))
	return out


static func public_circle(from_layout: Vector3) -> Vector3:
	"""A layout circle (x, z, radius) in the published form (x, radius, z)."""
	return Vector3(from_layout.x, from_layout.z, from_layout.y)


static func layout_circle(public: Vector3) -> Vector3:
	"""A published circle (x, radius, z) back in world_layout.gd's (x, z, radius) form."""
	return Vector3(public.x, public.z, public.y)


func building_obstacles() -> Array[Vector3]:
	"""The obstacle circles of the village's buildings and its well only, as Vector3(x, radius, z)."""
	_ensure_layout()
	var ids: Array[StringName] = []
	for entry: Dictionary in Layout.BUILDINGS:
		ids.append(entry["id"])
	var buildings: Array[Dictionary] = []
	for p: Dictionary in _structure:
		if ids.has(p["id"]):
			buildings.append(p)
	var out: Array[Vector3] = []
	for circle: Vector3 in Layout.obstacles_for(buildings):
		out.append(public_circle(circle))
	return out


func hide_cover(route: PackedVector2Array, route_radius: float, circles: PackedVector3Array) -> int:
	"""Hide every ground-cover piece standing within `route_radius` (plus COVER_MARGIN_M) of the polyline
	`route`, or within any of `circles` (x, radius, z; plus the margin). Returns how many were hidden.
	Once per tunnel dug, never per frame."""
	var hidden := 0
	for k: int in _cover_nodes.size():
		for i: int in _cover_at[k].size():
			var at := _cover_at[k][i]
			if _cover_hidden[k][i] == 0 and _covered(at, route, route_radius, circles):
				_cover_nodes[k].multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(at.x, GROUND_Y, at.y)))
				_cover_hidden[k][i] = 1
				hidden += 1
	return hidden


func cover_positions(k: int) -> PackedVector2Array:
	"""Where each piece of cover node `k` stands (x, z)."""
	return _cover_at[k]


func cover_hidden(k: int) -> PackedByteArray:
	"""Which pieces of cover node `k` have been hidden (1)."""
	return _cover_hidden[k]


static func _covered(p: Vector2, route: PackedVector2Array, route_radius: float, circles: PackedVector3Array) -> bool:
	"""Whether a cover piece at `p` stands on the route or in a circle (see hide_cover)."""
	for circle: Vector3 in circles:
		if Vector2(circle.x, circle.z).distance_to(p) < circle.y + COVER_MARGIN_M:
			return true
	for k: int in range(1, route.size()):
		if Geometry2D.get_closest_point_to_segment(p, route[k - 1], route[k]).distance_to(p) < route_radius + COVER_MARGIN_M:
			return true
	return false


func set_view_distance(camera_distance_m: float) -> void:
	"""Fit the sun's shadow range to how far the camera is from what it looks at."""
	for node: Node in _built:
		if node is DirectionalLight3D:
			(node as DirectionalLight3D).directional_shadow_max_distance = Look.shadow_distance_for(camera_distance_m)


func bounds() -> AABB:
	"""The walkable area, from the ground up to a badger's head."""
	return Layout.bounds()


func trees() -> Array[Dictionary]:
	"""Every tree placement (oak, beech, sapling) in the order the world draws them: the authored ones,
	then the woods'. A fresh copy; the same before or after build()."""
	_ensure_layout()
	var out: Array[Dictionary] = []
	for p: Dictionary in _placed():
		if PLACEHOLDER_TREES.has(p["key"]):
			out.append(p.duplicate())
	return out


func tree_node(i: int) -> Node3D:
	"""The node drawing tree `i` (trees() order), or null before build()."""
	return _tree_nodes[i] if i >= 0 and i < _tree_nodes.size() else null


func make_piece(key: StringName, at: Vector2, yaw: float, size: float) -> Node3D:
	"""A new model of `key` standing at `at`, drawn as the world draws it (staged, or its placeholder of
	the same footprint). The caller parents it."""
	return _make_piece(_world_rows, {"key": key, "at": at, "yaw": yaw, "size": size})


func is_staged(key: StringName) -> bool:
	"""Whether `key`'s model is staged and loads (otherwise `make_piece` draws its placeholder): an owner that has an
	older stand-in for a new model (the orchard's oak, decision 0903) draws the stand-in instead."""
	return _staged_scene(_world_rows, key) != null


func woods_obstacles(reach_m: float) -> Array[Vector3]:
	"""The woods' and the authored nature's blocking circles (x, radius, z) that obstacles() leaves out
	-- beyond its report margin -- but that come within `reach_m` of the square (Chebyshev)."""
	_ensure_layout()
	var out: Array[Vector3] = []
	for p: Dictionary in _placed():
		for circle: Vector3 in Layout.placement_circles(p):
			var reach: float = reach_m + circle.z
			if Layout.circle_reaches_play(circle) or absf(circle.x) > reach or absf(circle.y) > reach:
				continue
			out.append(public_circle(circle))
	return out


func _ensure_layout() -> void:
	"""Derive placements, obstacles, points and dressing once; all deterministic."""
	if _layout_ready:
		return
	_structure = Layout.placements()
	var blockers: Array[Vector3] = Layout.obstacles_for(_structure)
	blockers.append_array(WaterDressing.woods_blockers())  # demo/water/: no woods in the water
	_dressing = Scatter.tree_ring(blockers)
	var with_trees: Array[Vector3] = blockers.duplicate()
	with_trees.append_array(Layout.obstacles_for(_dressing))
	_dressing.append_array(Scatter.forest_debris(with_trees))
	_obstacles = Layout.obstacles_for(_placed())
	_points = Layout.points_of_interest_for(_structure)
	var spots: Array[Vector2] = []
	for point: Dictionary in _points:
		var at: Vector3 = point["position"]
		spots.append(Vector2(at.x, at.z))
	_cover = Scatter.ground_cover(_obstacles, spots)
	_layout_ready = true


func _placed() -> Array[Dictionary]:
	"""Every placement drawn as its own node: the authored village plus the woods and debris."""
	var all: Array[Dictionary] = _structure.duplicate()
	all.append_array(_dressing)
	return all


func _clear_built() -> void:
	"""Remove what a previous build() made, so build() can be called again."""
	for node: Node in _built:
		remove_child(node)
		if is_inside_tree():
			node.queue_free()
		else:
			node.free()
	_built.clear()


static func piece_transform(p: Dictionary, scale_factor: float, sink: float) -> Transform3D:
	"""Placement transform: uniform scale, yaw about +Y, base on the ground let down `sink` m into it."""
	var at: Vector2 = p["at"]
	var facing := Basis(Vector3.UP, float(p["yaw"])).scaled(Vector3.ONE * scale_factor)
	return Transform3D(facing, Vector3(at.x, GROUND_Y - sink, at.y))


func _staged_scene(world: Dictionary, key: StringName) -> PackedScene:
	"""The staged model for `key`, loaded once; null when it is not staged or will not load."""
	if _scenes.has(key):
		return _scenes[key]
	var scene: PackedScene = null
	var entry: Dictionary = world.get(String(key), {})
	var path: String = entry.get("path", "")
	if not path.is_empty() and ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	if scene == null and not entry.is_empty():
		push_warning("demo world: '%s' is staged but did not load; using a placeholder" % key)
	_scenes[key] = scene
	return scene


func _staged_scale(world: Dictionary, key: StringName) -> float:
	"""Scale from the manifest's own measured bound, so the drawn height lands exactly."""
	var entry: Dictionary = world[String(key)]
	var lo: Array = entry["aabb_min"]
	var hi: Array = entry["aabb_max"]
	return Sizes.uniform_scale(key, Vector3(lo[0], lo[1], lo[2]), Vector3(hi[0], hi[1], hi[2]))


func _make_piece(world: Dictionary, p: Dictionary, model: StringName = &"") -> Node3D:
	"""One placed model: the staged asset let into the ground by its baked base (world_sizes.gd SINK_M),
	or a placeholder of the same footprint standing on it. Every construction path comes through here
	(build(), make_piece()), so a replanted tree sits as deep as the one it replaces. `model`: a staged
	variant drawn in its place at its key's own scale (a home's windows model; none: the key's own)."""
	var key: StringName = p["key"]
	var scene: PackedScene = _staged_scene(world, key if model == &"" else model)
	var piece: Node3D
	var scale_factor: float
	var sink: float = 0.0
	if scene != null:
		piece = scene.instantiate() as Node3D
		scale_factor = _staged_scale(world, key)
		sink = Sizes.sink_m(key, float(p["size"]))
		_apply_tint(piece, key)
		_add_cards(world, key, piece)
	else:
		piece = _placeholder(key)
		scale_factor = Sizes.native_scale(key)
	piece.transform = piece_transform(p, scale_factor * float(p["size"]), sink)
	return piece


func _card_texture(path: String) -> Texture2D:
	"""The staged card atlas, loaded once with mipmaps; null if it is missing or unreadable.

	Read as an Image rather than through the importer so the mipmaps are always generated
	(a PNG's import defaults depend on what the editor guessed it was for) and so a freshly
	staged atlas works before the editor has imported it. Where it is read from -- the project folder, or
	an exported pack -- is `DemoManifest.readable_path`.
	"""
	if _card_textures.has(path):
		return _card_textures[path]
	var image := Image.load_from_file(DemoManifestScript.readable_path(path))
	var texture: Texture2D = null
	if image != null and not image.is_empty():
		image.generate_mipmaps()
		texture = ImageTexture.create_from_image(image)
	else:
		push_warning("demo world: card atlas %s did not load; the bed is drawn bare" % path)
	_card_textures[path] = texture
	return texture


func _add_cards(world: Dictionary, key: StringName, piece: Node3D) -> void:
	"""Plant a staged carded bed (make_demo_crop_cards.py) with its cards."""
	var entry: Dictionary = world.get(String(key), {})
	if not entry.has("cards") or not CropCards.has_layout(key):
		return
	var cards: Dictionary = entry["cards"]
	var texture: Texture2D = _card_texture(cards["texture"])
	var top_texture: Texture2D = null
	if cards.has("tops"):
		top_texture = _card_texture((cards["tops"] as Dictionary)["texture"])
	if texture != null:
		piece.add_child(CropCards.build(key, cards, texture, top_texture))


func _tinted(source: Material, key: StringName) -> Material:
	"""The shared tinted duplicate of `source` for `key` (made once, reused by every instance)."""
	if _tinted_materials.has(source):
		return _tinted_materials[source]
	var copy: BaseMaterial3D = (source as BaseMaterial3D).duplicate() as BaseMaterial3D
	copy.albedo_color = copy.albedo_color * (MATERIAL_TINT[key] as Color)
	_tinted_materials[source] = copy
	return copy


func _apply_tint(piece: Node3D, key: StringName) -> void:
	"""Apply MATERIAL_TINT to every standard material on a staged model of `key`."""
	if not MATERIAL_TINT.has(key):
		return
	for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.mesh.surface_get_material(surface)
			if source is BaseMaterial3D:
				mesh_instance.set_surface_override_material(surface, _tinted(source, key))


func _cover_mesh(world: Dictionary, key: StringName) -> Array:
	"""[mesh, mesh-to-model transform, model scale] for a ground-cover key."""
	var scene: PackedScene = _staged_scene(world, key)
	if scene == null:
		return [_placeholder_mesh(key), Transform3D.IDENTITY, Sizes.native_scale(key)]
	var root: Node3D = scene.instantiate() as Node3D
	var found: Array = _first_mesh(root, Transform3D.IDENTITY)
	root.free()
	if found.is_empty():
		return [_placeholder_mesh(key), Transform3D.IDENTITY, Sizes.native_scale(key)]
	return [found[0], found[1], _staged_scale(world, key)]


func _first_mesh(node: Node, parent: Transform3D) -> Array:
	"""[mesh, accumulated transform] of the first MeshInstance3D under `node`, or []."""
	var here: Transform3D = parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return [(node as MeshInstance3D).mesh, here]
	for child: Node in node.get_children():
		var found: Array = _first_mesh(child, here)
		if not found.is_empty():
			return found
	return []


func _make_cover(world: Dictionary, key: StringName) -> MultiMeshInstance3D:
	"""Every ground-cover piece of `key` as one MultiMesh."""
	var source: Array = _cover_mesh(world, key)
	var pieces: Array[Dictionary] = []
	for p: Dictionary in _cover:
		if p["key"] == key:
			pieces.append(p)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source[0]
	multimesh.instance_count = pieces.size()
	var mesh_local: Transform3D = source[1]
	var at := PackedVector2Array()
	for i: int in pieces.size():
		var p: Dictionary = pieces[i]
		var placed: Transform3D = piece_transform(p, float(source[2]) * float(p["size"]), 0.0)
		multimesh.set_instance_transform(i, placed * mesh_local)
		at.append(p["at"])
	_cover_at.append(at)
	var hidden := PackedByteArray()
	hidden.resize(pieces.size())
	_cover_hidden.append(hidden)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Cover_%s" % key
	instance.multimesh = multimesh
	return instance


func _placeholder_color(key: StringName) -> Color:
	"""A locked-palette colour that says roughly what the missing model was."""
	if Sizes.is_building(key):
		return Look.TIMBER
	if PLACEHOLDER_TREES.has(key) or PLACEHOLDER_GREEN.has(key):
		return Look.LEAF
	if PLACEHOLDER_STONE.has(key):
		return Look.FLINT
	if key == &"crop_grain_ripe" or key == &"mushroom_cluster":
		return Look.BRASS
	return Look.UMBER


func _placeholder_mesh(key: StringName) -> Mesh:
	"""A box filling the model's recorded native bound, shared by every placement of `key`."""
	if _placeholder_meshes.has(key):
		return _placeholder_meshes[key]
	var bound: Array = Sizes.NATIVE_AABB[key]
	var lo: Vector3 = bound[0]
	var hi: Vector3 = bound[1]
	var box := BoxMesh.new()
	box.size = hi - lo
	var material := StandardMaterial3D.new()
	material.albedo_color = _placeholder_color(key)
	material.roughness = 0.9
	box.material = material
	var mesh := ArrayMesh.new()
	var arrays: Array = box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		verts[i] += (lo + hi) * 0.5
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	_placeholder_meshes[key] = mesh
	return mesh


func _placeholder(key: StringName) -> Node3D:
	"""A placeholder model in native units, so the placement transform scales it like the asset."""
	var instance := MeshInstance3D.new()
	instance.name = "Placeholder_%s" % key
	instance.mesh = _placeholder_mesh(key)
	return instance
