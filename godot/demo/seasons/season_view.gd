extends Node3D
## The seasons on the village: the woods, the grass and the ground follow the demo's one calendar. Decision 0551
## (approved 2026-10-01; review UX-028's seasonal art). Presentation only: it reads the calendar, the stand, the
## weather's cover and the reduced-motion setting, and writes nothing any of them read.
##
## THE TREES. Every staged tree -- the world's woods, a regrown or replanted one, a sapling or shoot, the upper part
## of a falling one -- wears the ONE tree material of its model (canopy_clear.gd `fade_material_for`: the tree
## shader, demo/camera/canopy_fade.gdshader, with its own glTF maps) as its surface override, all year. Each tree's
## look is three INSTANCE uniforms (leaf tint, bare share, blossom; season_leaves.gdshaderinc) written from
## season_look.gd when the calendar's hour turns: no material is duplicated per tree, and the canopy's thinning,
## which puts the same material on as an override and takes it off again, changes nothing about the season. A
## placeholder tree (no staged texture) keeps its own material: its plain colour has no leaves to tell from bark.
## The weather's frost and snow (weather_view.gd `cover`, `frost`) are set on those few materials as they move.
##
## THE GROUND. The ground's grass and litter colours (its shader's own parameters, read once as the base) and its
## fallen leaves (`leaf_fall`, demo_ground.gdshader), and the grass tufts' albedo through ONE shared copy of their
## material, follow season_look.gd `ground_into` on the same hour.
##
## FALLING LEAVES (falling_leaves.gd): a few in autumn and winter's first days, over where the camera looks, at the
## game's speed; none with reduced motion.
##
## THE PREVIEW (the Demo Lab, F8): `next_preview` draws all of it at one of PRESET_NAMES -- presentation only; the
## calendar, the farm and the weather do not move -- and the last step hands it back to the calendar.
##
## OTHER OWNERS' TREES (decision 0677): the orchard's fruit trees wear the season too. An owner registered with
## `add_trees` answers `season_tree_count() -> int`, `season_tree_node(i) -> Node3D`, `season_tree_kind(i) -> int`
## (season_look.gd KIND_*), `season_tree_at(i) -> Vector2` and `season_trees_revision() -> int` (bumped whenever it
## makes or replaces a tree's node); they are dressed after the woods' own.
##
## THE AUTHORED BARE OAK (art pass 2, decision 0951; wired by the batch 8 integration, decision 0903): where the
## staged `oak_mature_bare` is given (`use_authored_bare`), a bare oak wears it instead of `bare_boughs.gd`'s cut of the
## leafed oak -- the same scale and origin as the oak's model, so the oak's own transform draws it -- in the tree shader
## made from ITS material (its leaf texels filled with bark, so the shader discards nothing). Without it, the cut.
##
## Per frame it compares two integers (the calendar's hour, the stand's revision) and each owner's revision, the
## weather's cover and the view's focus, and allocates nothing. On an hour or a revision it writes each tree's three numbers; only when a
## tree's node itself was made or replaced (a fall, a shoot, a replanting) does it collect the trees afresh.

const LookScript := preload("res://demo/seasons/season_look.gd")
const LeavesScript := preload("res://demo/seasons/falling_leaves.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ViewScript := preload("res://demo/forestry/forest_view.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const CanopyScript := preload("res://demo/camera/canopy_clear.gd")
const IN_LEAF_SHADER := preload("res://demo/seasons/season_tree.gdshader")
const BoughsScript := preload("res://demo/seasons/bare_boughs.gd")

const PARAM_TINT: StringName = &"leaf_tint"
const PARAM_BARE: StringName = &"leaf_bare"
const PARAM_BLOSSOM: StringName = &"leaf_blossom"
const PARAM_COVER: StringName = &"snow_cover"
const PARAM_FROST: StringName = &"frost_cover"
const PARAM_ROOTS: StringName = &"roots_y"
const PARAM_LEAF_FALL: StringName = &"leaf_fall"
const PARAM_LEAF_FALL_COLOUR: StringName = &"leaf_fall_color"
const GROUND_GRASS: Array[StringName] = [&"grass_color", &"grass_sun_color"]
const GROUND_LITTER: StringName = &"litter_color"
const TUFT_NODE: String = "Cover_grass_tuft"
## Each tree model's kind (season_look.gd KIND_*).
const KIND_OF_KEY: Dictionary = {
	&"oak_mature": LookScript.KIND_OAK, &"beech_mature": LookScript.KIND_BEECH, &"oak_sapling": LookScript.KIND_YOUNG_OAK,
	&"pine_scots": LookScript.KIND_EVERGREEN, &"yew_ancient": LookScript.KIND_EVERGREEN,
}
## The weather's cover is set on the trees in steps this fine.
const COVER_STEP: float = 0.02
## Leaves fall while season_look.gd `leaf_drop` is above this.
const LEAF_DROP_ON: float = 0.3
## What a dressed mesh wears: its in-leaf variant (no leaf down), the tree shader (some leaves down), or its model's
## bare boughs in the tree shader (every leaf down; bare_boughs.gd).
const WEAR_LEAFY: int = 0
const WEAR_FULL: int = 1
const WEAR_BARE: int = 2
## Each tree's nodes the woods may make or replace: its tree, its sapling or shoot, its falling upper part.
const NODES_PER_TREE: int = 3
## The prewarm's leaves fall this far below the focus: drawn (their pipelines compile), behind the ground.
const PREWARM_DEPTH_M: float = 25.0

## The Demo Lab's season presets: what the button says, the season, the day into it.
const PRESET_NAMES: Array[String] = ["Mid-spring", "Mid-summer", "Early autumn", "Late autumn", "Mid-winter"]
const PRESET_SEASONS: PackedInt32Array = [0, 1, 2, 2, 3]
const PRESET_DAYS: PackedFloat32Array = [6.0, 6.0, 3.0, 10.0, 6.0]
const PREVIEW_LABEL: String = "Season preview"
const PREVIEW_TIP: String = "Draw the woods, grass and ground at the next season (the calendar, farm and weather do not move)"
const PREVIEW_DONE: String = "The village is drawn as the Season preview button says. Presentation only: the calendar has not moved."
const PREVIEW_OFF: String = "Season preview: the calendar's (next: %s)"
const PREVIEW_ON: String = "Season preview: %s (next: %s)"

## Autumn's falling leaves (falling_leaves.gd), built in `configure`.
var leaves: LeavesScript = null

var _calendar: CalendarScript = null
var _clock: DemoClockScript = null
var _stand: StandScript = null
var _view: ViewScript = null
var _weather_view: WeatherViewScript = null
var _material_for: Callable = Callable()
var _look: LookScript = LookScript.new()
var _sample: LookScript.Sample = LookScript.Sample.new()
var _ground: LookScript.Ground = LookScript.Ground.new()
## The dressed tree meshes, and per mesh its kind and hash.
var _meshes: Array[GeometryInstance3D] = []
var _kinds: PackedInt32Array = PackedInt32Array()
var _hashes: PackedInt64Array = PackedInt64Array()
## The tree materials in use -- per model, the tree shader and its in-leaf variant -- which take the weather's cover.
var _materials: Array[ShaderMaterial] = []
## Per model (its own glTF material): its in-leaf variant (season_tree.gdshader).
var _in_leaf: Dictionary = {}
## Per dressed mesh: its model's tree material and in-leaf variant, its own mesh and bare boughs (null: none made),
## and what it wears now (WEAR_*).
var _full: Array[ShaderMaterial] = []
var _leafy: Array[ShaderMaterial] = []
var _own_mesh: Array[Mesh] = []
var _bare_mesh: Array[Mesh] = []
var _wearing: PackedByteArray = PackedByteArray()
## Per model mesh: its bare boughs (prepare_bare; null: it has none), and per bare boughs its model mesh.
var _bare_of: Dictionary = {}
var _own_of: Dictionary = {}
## THE AUTHORED BARE OAK: model mesh -> its authored bare mesh, and per authored bare mesh its tree material.
var _authored: Dictionary = {}
var _bare_material: Dictionary = {}
## The world's own tree nodes, keys and spots (collected once), and each stand tree's nodes when last collected.
var _world_nodes: Array[Node3D] = []
var _world_keys: Array[StringName] = []
var _world_at: PackedVector2Array = PackedVector2Array()
var _known: PackedInt64Array = PackedInt64Array()
var _seen_hour: int = -1
var _seen_revision: int = -1
var _cover: float = -1.0
var _frost: float = -1.0
var _season: int = 0
var _day: float = 0.0
## The preview preset drawn (-1: the calendar's own season).
var _preview: int = -1
var _lab_button: Button = null
## While the boot prewarm's frame step runs, every leaf is out, below the ground (see begin_prewarm), and one sample
## of each model's bare boughs is drawn there.
var _prewarming: bool = false
var _samples: Array[MeshInstance3D] = []
var _ground_material: ShaderMaterial = null
var _ground_base: Array[Color] = []
var _litter_base: Color = Color.BLACK
var _tufts: StandardMaterial3D = null
var _tuft_base: Color = Color.WHITE
## OTHER OWNERS' TREES: the owners, and each one's revision when its trees were last collected.
var _owners: Array[Object] = []
var _owner_revisions: PackedInt64Array = PackedInt64Array()


func configure(calendar: CalendarScript, clock: DemoClockScript, world: DemoWorldScript, stand: StandScript,
		view: ViewScript, weather_view: WeatherViewScript, material_for: Callable) -> void:
	"""Dress `world`'s trees and the stand's (drawn by `view`) for the season on `calendar`, each in
	`material_for(mesh) -> ShaderMaterial` (the canopy's tree material), with `weather_view`'s cover (null: none);
	the falling leaves run on `clock` (null: 1x)."""
	name = "SeasonView"
	process_priority = 1
	_calendar = calendar
	_clock = clock
	_stand = stand
	_view = view
	_weather_view = weather_view
	_material_for = material_for
	_known.resize(StandScript.MAX_TREES * NODES_PER_TREE)
	_known.fill(-1)
	_read_world(world)
	leaves = LeavesScript.new()
	add_child(leaves)
	leaves.build()
	_collect()
	refresh()


func _read_world(world: DemoWorldScript) -> void:
	"""The world's trees (kept), its ground's grass and litter colours (the base each season moves from), and the
	grass tufts' shared material."""
	if world == null:
		return
	var placements: Array[Dictionary] = world.trees()
	for i: int in placements.size():
		_world_nodes.append(world.tree_node(i))
		_world_keys.append(placements[i]["key"])
		_world_at.append(placements[i]["at"])
	var ground := world.find_child("Ground", true, false) as MeshInstance3D
	_ground_material = ground.get_active_material(0) as ShaderMaterial if ground != null else null
	if _ground_material != null:
		for param: StringName in GROUND_GRASS:
			_ground_base.append(_colour_param(param))
		_litter_base = _colour_param(GROUND_LITTER)
		_ground_material.set_shader_parameter(PARAM_LEAF_FALL_COLOUR, LookScript.FALLEN_LEAVES)
	_read_tufts(world.find_child(TUFT_NODE, true, false) as MultiMeshInstance3D)


func _colour_param(param: StringName) -> Color:
	"""One of the ground's colour parameters as it stands (black if it was never set)."""
	var value: Variant = _ground_material.get_shader_parameter(param)
	return value as Color if value is Color else Color.BLACK


func _read_tufts(tufts: MultiMeshInstance3D) -> void:
	"""The grass tufts drawn through one shared copy of their own material, whose albedo the season multiplies."""
	if tufts == null or tufts.multimesh == null or tufts.multimesh.mesh == null:
		return
	var own := tufts.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	if own == null:
		return
	_tufts = own.duplicate() as StandardMaterial3D
	_tuft_base = own.albedo_color
	tufts.material_override = _tufts


# --- per frame -----------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""The season when the hour or the woods change; the weather's cover on the trees; the falling leaves."""
	if _stand == null:
		return
	var hour: int = _calendar.hour_index()
	var hour_turned: bool = hour != _seen_hour
	var owners_moved: bool = _owners_moved()
	if hour_turned or _stand.revision != _seen_revision or owners_moved:
		_seen_hour = hour
		_seen_revision = _stand.revision
		var changed: bool = nodes_changed() or owners_moved
		if changed:
			_collect()
		if hour_turned or changed:
			refresh()
	follow_cover()
	_run_leaves()


func nodes_changed() -> bool:
	"""Whether the woods made or replaced a node of any tree since the trees were last collected."""
	for t: int in _stand.count():
		var k: int = t * NODES_PER_TREE
		if _id(_view.tree_node(t)) != _known[k] or _id(_view.young_node(t)) != _known[k + 1]:
			return true
		if _id(_view.upper_part(t)) != _known[k + 2]:
			return true
	return false


func add_trees(trees_owner: Object) -> void:
	"""Dress `trees_owner`'s trees for the season too, from now on (see OTHER OWNERS' TREES)."""
	_owners.append(trees_owner)
	_owner_revisions.append(-1)
	if _stand != null:
		_collect()
		refresh()


func _owners_moved() -> bool:
	"""Whether an owner made or replaced a tree's node since the trees were last collected."""
	for k: int in _owners.size():
		if is_instance_valid(_owners[k]) and int(_owners[k].call(&"season_trees_revision")) != _owner_revisions[k]:
			return true
	return false


static func _id(node: Node) -> int:
	"""A node's instance id (0: none)."""
	return node.get_instance_id() if node != null else 0


func follow_cover() -> void:
	"""Set the weather's frost and snow on the tree materials, in COVER_STEP steps (only when it moved)."""
	if _weather_view == null:
		return
	var cover: float = snappedf(_weather_view.cover(), COVER_STEP)
	var frost: float = snappedf(_weather_view.frost(), COVER_STEP)
	if cover == _cover and frost == _frost:
		return
	_cover = cover
	_frost = frost
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(PARAM_COVER, _cover)
		material.set_shader_parameter(PARAM_FROST, _frost)


func _run_leaves() -> void:
	"""Leaves fall over the view's focus while the season drops them, at the game's speed; none with reduced
	motion."""
	if _prewarming:
		leaves.run(true, _focus() + Vector3.DOWN * PREWARM_DEPTH_M, 1.0)
		return
	leaves.run(leaves_fall(), _focus(), float(_clock.speed) if _clock != null else 1.0)


func leaves_fall() -> bool:
	"""Whether leaves fall now: the season drops them (season_look.gd `leaf_drop`) and motion is not reduced."""
	return LookScript.leaf_drop(_season, _day) > LEAF_DROP_ON and not DemoMotion.reduced


func _focus() -> Vector3:
	"""Where the camera looks at the ground (the origin outside the tree or with no camera)."""
	if not is_inside_tree():
		return Vector3.ZERO
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var origin: Vector3 = camera.global_position
	var ahead: Vector3 = -camera.global_basis.z
	var reach: float = -origin.y / ahead.y if ahead.y < -0.01 else 0.0
	return origin + ahead * reach


# --- the trees -----------------------------------------------------------------------------------------

func _collect() -> void:
	"""Dress every tree node now drawn -- the world's, then each stand tree's own -- once each."""
	_meshes.clear()
	_kinds.resize(0)
	_hashes.resize(0)
	_full.clear()
	_leafy.clear()
	_own_mesh.clear()
	_bare_mesh.clear()
	_wearing.resize(0)
	var seen: Dictionary = {}
	for i: int in _world_nodes.size():
		_dress(_world_nodes[i], _world_keys[i], _world_at[i], seen)
	for t: int in (_stand.count() if _stand != null else 0):
		var key: StringName = StandScript.LOOK_KEYS[_stand.look[t]]
		var k: int = t * NODES_PER_TREE
		_known[k] = _id(_view.tree_node(t))
		_known[k + 1] = _id(_view.young_node(t))
		_known[k + 2] = _id(_view.upper_part(t))
		_dress(_view.tree_node(t), key, _stand.at[t], seen)
		_dress(_view.young_node(t), StandScript.SAPLING_KEY, _stand.at[t], seen)
		_dress(_view.upper_part(t), key, _stand.at[t], seen)
	_dress_owners(seen)
	_cover = -1.0
	follow_cover()


func _dress_owners(seen: Dictionary) -> void:
	"""Every registered owner's trees (see OTHER OWNERS' TREES), its revision noted."""
	for k: int in _owners.size():
		var trees_owner: Object = _owners[k]
		if not is_instance_valid(trees_owner):
			continue
		_owner_revisions[k] = int(trees_owner.call(&"season_trees_revision"))
		for i: int in int(trees_owner.call(&"season_tree_count")):
			_dress_kind(trees_owner.call(&"season_tree_node", i) as Node, int(trees_owner.call(&"season_tree_kind", i)),
				trees_owner.call(&"season_tree_at", i) as Vector2, seen)


func _dress(node: Node, key: StringName, at: Vector2, seen: Dictionary) -> void:
	"""Every staged mesh at or under `node` (a tree of model `key` standing `at`) wears its model's tree material
	and is written each hour; a placeholder's, or one already dressed, is left."""
	if KIND_OF_KEY.has(key):
		_dress_kind(node, KIND_OF_KEY[key], at, seen)


func _dress_kind(node: Node, kind: int, at: Vector2, seen: Dictionary) -> void:
	"""`_dress` for a tree of season_look.gd `kind`."""
	if node == null or not is_instance_valid(node):
		return
	var found: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		found.append(node)
	for item: Node in found:
		var mesh := item as MeshInstance3D
		if seen.has(mesh) or not is_staged(mesh):
			continue
		seen[mesh] = true
		mesh.mesh = _own_of.get(mesh.mesh, mesh.mesh)
		_full.append(_keep_material(_material_for.call(mesh) as ShaderMaterial, mesh.mesh))
		_leafy.append(_keep_material(in_leaf_material(mesh), mesh.mesh))
		mesh.set_surface_override_material(0, _leafy[-1])
		_own_mesh.append(mesh.mesh)
		_bare_mesh.append(_bare_of.get(mesh.mesh) as Mesh)
		_wearing.append(WEAR_LEAFY)
		_meshes.append(mesh)
		_kinds.append(kind)
		_hashes.append(LookScript.tree_hash(at))


func in_leaf_material(mesh: MeshInstance3D) -> ShaderMaterial:
	"""The in-leaf variant of `mesh`'s model (season_tree.gdshader with its own glTF maps; one per model)."""
	var own: Material = CanopyScript.own_material(mesh)
	if not _in_leaf.has(own):
		_in_leaf[own] = CanopyScript.make_fade_material(own as BaseMaterial3D, IN_LEAF_SHADER)
	return _in_leaf[own]


func _keep_material(material: ShaderMaterial, model: Mesh) -> ShaderMaterial:
	"""`material`, remembered (once) as one the weather's cover is set on, its roots mask taken from `model` -- the
	first mesh dressed in it, always a whole model: the world's trees are dressed before any falling part."""
	if not _materials.has(material):
		_materials.append(material)
		material.set_shader_parameter(PARAM_ROOTS, BoughsScript.roots_mask(model))
		_cover = -1.0
	return material


static func is_staged(mesh: MeshInstance3D) -> bool:
	"""Whether a tree mesh is a staged model (its own material carries a texture), which the season can dress."""
	var own := (mesh.mesh.surface_get_material(0) if mesh.mesh != null else null) as BaseMaterial3D
	return own != null and own.albedo_texture != null


func refresh() -> void:
	"""Write every dressed tree's look, and the ground's, for the season now (the preview's, while one is on)."""
	_read_time()
	for i: int in _meshes.size():
		if not is_instance_valid(_meshes[i]):
			continue
		var mesh: GeometryInstance3D = _meshes[i]
		_look.sample_into(_kinds[i], _hashes[i], _season, _day, _sample)
		_wear(i, wear_for(_sample.bare, _bare_mesh[i] != null))
		mesh.set_instance_shader_parameter(PARAM_TINT, _sample.tint)
		mesh.set_instance_shader_parameter(PARAM_BARE, _sample.bare)
		mesh.set_instance_shader_parameter(PARAM_BLOSSOM, _sample.blossom)
	_refresh_ground()


static func wear_for(bare: float, has_boughs: bool) -> int:
	"""What a tree with `bare` of its leaves down wears (WEAR_*): its bare boughs once every leaf is down (if its
	model has them), the tree shader while some are, else the in-leaf variant."""
	if bare >= 1.0 and has_boughs:
		return WEAR_BARE
	return WEAR_FULL if bare > 0.0 else WEAR_LEAFY


func _wear(i: int, wear: int) -> void:
	"""Dressed mesh `i` in `wear` (WEAR_*): its mesh and material, set only on a change (an authored bare oak in its own
	material: THE AUTHORED BARE OAK)."""
	if _wearing[i] == wear:
		return
	_wearing[i] = wear
	var mesh := _meshes[i] as MeshInstance3D
	mesh.mesh = _bare_mesh[i] if wear == WEAR_BARE else _own_mesh[i]
	var material: ShaderMaterial = _full[i]
	if wear == WEAR_LEAFY:
		material = _leafy[i]
	elif wear == WEAR_BARE and _bare_material.has(_bare_mesh[i]):
		material = _bare_material[_bare_mesh[i]]
	mesh.set_surface_override_material(0, material)


func use_authored_bare(model_path: String, bare_path: String) -> bool:
	"""Wear the staged bare model at `bare_path` for every tree of the model at `model_path` once it is bare (THE
	AUTHORED BARE OAK); false (the cut stays) when either does not load or has no textured surface."""
	var model: Mesh = first_mesh_of(model_path)
	var bare: Mesh = first_mesh_of(bare_path)
	if model == null or bare == null or bare.get_surface_count() != 1:
		return false
	_authored[model] = bare
	return true


static func first_mesh_of(path: String) -> Mesh:
	"""The first mesh of the staged model at `path` (null when it is not there or will not load)."""
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		found.push_front(root)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh


func _bare_for(own: Mesh) -> ArrayMesh:
	"""A model's bare boughs: its authored bare model (made a tree material once) or the cut of its leaves."""
	if not _authored.has(own):
		return BoughsScript.bark_only(own)
	var bare := _authored[own] as ArrayMesh
	if bare != null and not _bare_material.has(bare):
		_bare_material[bare] = _keep_material(_fade_material_of(bare), bare)
	return bare


func _fade_material_of(bare: ArrayMesh) -> ShaderMaterial:
	"""The tree material for an authored bare model: the canopy's own for its glTF material (`material_for`, so a faded
	bare oak wears the material the weather's cover is set on), else one made here (a check with no canopy)."""
	if not _material_for.is_valid():
		return CanopyScript.make_fade_material(bare.surface_get_material(0) as BaseMaterial3D)
	var probe := MeshInstance3D.new()
	probe.mesh = bare
	var made := _material_for.call(probe) as ShaderMaterial
	probe.free()
	return made


func prepare_bare() -> int:
	"""Make each dressed model's bare boughs (bare_boughs.gd), once per model mesh: the boot prewarm's step, so the
	first winter makes nothing. Returns how many were made."""
	var made: int = 0
	for i: int in _meshes.size():
		var own: Mesh = _own_mesh[i]
		if _kinds[i] == LookScript.KIND_EVERGREEN:
			continue
		if not _bare_of.has(own):
			var bare: ArrayMesh = _bare_for(own)
			_bare_of[own] = bare
			if bare != null:
				_own_of[bare] = own
				made += 1
		_bare_mesh[i] = _bare_of[own] as Mesh
	if not _meshes.is_empty() and not _bare_mesh.any(func(bare: Mesh) -> bool: return bare != null):
		push_warning("seasons: no staged tree model gave bare boughs (its albedo would not read back); winter draws every leaf discarded")
	refresh()
	return made


func _read_time() -> void:
	"""The season and the day into it: the preview's, else the calendar's now."""
	if _preview >= 0:
		_season = PRESET_SEASONS[_preview]
		_day = PRESET_DAYS[_preview]
		return
	var now: SimClock.Calendar = _calendar.now()
	_season = now.season
	_day = LookScript.day_in_season(now.season_day, now.tick_of_day)


func _refresh_ground() -> void:
	"""The ground's grass, litter and fallen leaves, and the tufts' albedo, for the season now."""
	_look.ground_into(_season, _day, _ground)
	if _ground_material != null:
		for k: int in _ground_base.size():
			_ground_material.set_shader_parameter(GROUND_GRASS[k], LookScript.grass_target(_ground_base[k], _ground))
		_ground_material.set_shader_parameter(GROUND_LITTER, LookScript.litter_target(_litter_base, _ground))
		_ground_material.set_shader_parameter(PARAM_LEAF_FALL, _ground.leaves)
	if _tufts != null:
		_tufts.albedo_color = _tuft_base * LookScript.tuft_multiply(_ground)


# --- the preview (the Demo Lab) ---------------------------------------------------------------------------

func bind_lab(button: Button) -> void:
	"""The Demo Lab's Season preview button: it names what is drawn and what comes next."""
	_lab_button = button
	_say_preview()


func next_preview() -> void:
	"""Draw the next preset (after the last, the calendar's own season again)."""
	_preview = _preview + 1 if _preview + 1 < PRESET_NAMES.size() else -1
	refresh()
	_say_preview()


func set_preview(preset: int) -> void:
	"""Draw preset `preset` (-1: the calendar's own season)."""
	_preview = clampi(preset, -1, PRESET_NAMES.size() - 1)
	refresh()
	_say_preview()


func preview_text() -> String:
	"""What the Lab's button says: the preset drawn (or the calendar's) and the next."""
	var next: int = _preview + 1 if _preview + 1 < PRESET_NAMES.size() else -1
	var next_name: String = PRESET_NAMES[next] if next >= 0 else "the calendar's"
	return PREVIEW_OFF % next_name if _preview < 0 else PREVIEW_ON % [PRESET_NAMES[_preview], next_name]


func _say_preview() -> void:
	"""The Lab's button names the preview."""
	if _lab_button != null:
		_lab_button.text = preview_text()


# --- the prewarm (demo_prewarm.gd add_frame_step) and read-back ---------------------------------------------

func begin_prewarm() -> void:
	"""Every falling leaf out at once for the prewarm's frames, below the ground, so their first autumn compiles
	nothing."""
	_prewarming = true
	leaves.burst(true)
	_run_leaves()
	_sample_boughs()


func end_prewarm() -> void:
	"""Back to what the season says, the prewarm's leaves gone."""
	_prewarming = false
	leaves.burst(false)
	_run_leaves()
	for sample: Node3D in _samples:
		sample.queue_free()
	_samples.clear()


func _sample_boughs() -> void:
	"""One sample of each model's bare boughs in its tree material, below the ground, for the prewarm's frames: the
	village opens in spring, so no tree wears them before the first winter."""
	var below: Vector3 = _focus() + Vector3.DOWN * PREWARM_DEPTH_M
	for i: int in _meshes.size():
		if _bare_mesh[i] == null or _sampled(_bare_mesh[i]):
			continue
		var sample := MeshInstance3D.new()
		sample.mesh = _bare_mesh[i]
		sample.material_override = _full[i]
		add_child(sample)
		sample.position = below + Vector3.RIGHT * float(_samples.size())
		_samples.append(sample)


func _sampled(mesh: Mesh) -> bool:
	"""Whether a prewarm sample already draws `mesh`."""
	for sample: MeshInstance3D in _samples:
		if sample.mesh == mesh:
			return true
	return false


func preview() -> int:
	"""The preview preset drawn (-1: the calendar's own season)."""
	return _preview


func season() -> int:
	"""The season drawn now (0 spring .. 3 winter)."""
	return _season


func day() -> float:
	"""The day into that season drawn now."""
	return _day


func dressed_count() -> int:
	"""How many tree meshes wear the season."""
	return _meshes.size()


func dressed(i: int) -> GeometryInstance3D:
	"""Dressed tree mesh `i` (checks)."""
	return _meshes[i]


func kind_of(i: int) -> int:
	"""Dressed tree mesh `i`'s kind (season_look.gd KIND_*)."""
	return _kinds[i]


func hash_of(i: int) -> int:
	"""Dressed tree mesh `i`'s hash."""
	return _hashes[i]


func tree_materials() -> Array[ShaderMaterial]:
	"""The tree materials in use (per model, the tree shader and its in-leaf variant)."""
	return _materials


func wearing(i: int) -> int:
	"""What dressed mesh `i` wears now (WEAR_*)."""
	return _wearing[i]


func tuft_material() -> StandardMaterial3D:
	"""The grass tufts' shared material (null: none)."""
	return _tufts
