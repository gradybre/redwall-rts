extends SceneTree
## Offline evidence from actual staged imports and the demo's pose/attachment implementations.
## Every bound is SAMPLED ONLY. No result authorizes a movement profile, room or connector.
## Usage: godot --headless --path godot --script ../tools/capture_underground_profiles.gd -- spec.json out.json

const Actor := preload("res://demo/cast/demo_actor.gd")
const CastSpace := preload("res://demo/cast/cast_space.gd")
const Props := preload("res://demo/props/demo_props.gd")
const Goods := preload("res://demo/farm/farm_goods.gd")
const Farm := preload("res://demo/farm/farm_catalog.gd")
const Tunnel := preload("res://demo/tunnel/tunnel_rules.gd")
const MAX_JSON_BYTES: int = 1048576
const MAX_SOURCES: int = 1024
const MAX_CASES: int = 128
const MAX_MESHES: int = 32
const MAX_VERTICES: int = 200000
const MAX_BONES: int = 512
const MAX_STEPS: int = 1200
const MAX_SOURCE_BYTES: int = 134217728
const REQUIRED_SOURCE_PATHS: PackedStringArray = ["res://demo/cast/demo_actor.gd", "res://demo/cast/resident_brain.gd",
	"res://demo/cast/stoop_modifier.gd", "res://scripts/presentation/tail_rig.gd",
	"res://scripts/presentation/tail_ground_constraint.gd", "res://scripts/presentation/tail_flat_roll.gd",
	"res://demo/props/demo_props.gd", "res://demo/farm/farm_goods.gd", "res://demo/farm/farm_catalog.gd",
	"res://demo/tunnel/tunnel_ext.gd", "res://demo/tunnel/tunnel_rules.gd", "res://project.godot"]
const SAMPLE_HZ: int = 30 # Evidence sampling schedule, not a gameplay clearance margin.
const WARM_STEPS: int = 90 # Existing tail bake's three-second warm-up; transient proof remains open.
const MISSING: PackedStringArray = ["CONTINUOUS_RUNTIME_RESIDUAL", "TRANSITION_AND_RECOVERY_COVERAGE",
	"ACTUAL_RESIDENT_LIFE_STAGE", "GEAR_AND_CARGO_IDENTITY", "AUTHORITATIVE_STATE_COST_BINDING",
	"ACTUAL_ROOT_SUPPORT_CONTACT", "ACCEPTED_PROFILE_REVISION"]
const SCENARIOS: PackedStringArray = ["plain", "standard_bore", "ramp_up", "ramp_down", "turn"]

var _spec: Dictionary = {}
var _manifest: Dictionary = {}
var _out: String = ""
var _error: String = ""
var _report: Dictionary = {}
var _cases: Array = []
var _case_index: int = -1
var _actor: Actor = null
var _skeleton: Skeleton3D = null
var _player: AnimationPlayer = null
var _props: Props = Props.new()
var _goods: Goods = null
var _body: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _row: Dictionary = {}
var _step: int = 0
var _steps: int = 0
var _pending: bool = false
var _await_palette: bool = false
var _parity: Array[Dictionary] = []
var _configured: bool = false
var _finished: bool = false
var _self_test: bool = false
var _tunnel_ext: GDScript = null


func _initialize() -> void:
	"""Read bounded input before touching a scene; protected output paths only receive a stderr refusal."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: capture_underground_profiles.gd -- spec.json out.json (or --self-test out.json)")
		quit(2)
		return
	_out = args[1]
	if _output_exists():
		printerr("CAPTURE_OUTPUT_EXISTS")
		quit(2)
		return
	_self_test = args[0] == "--self-test"
	if not _self_test and _same_path(args[0], _out):
		printerr("CAPTURE_OUTPUT_OVERWRITES_INPUT")
		quit(2)
		return
	if _self_test:
		return
	_load_spec(args[0])


func _load_spec(path: String) -> void:
	"""Retain exact source pins and diagnostic limitations before any runtime instance is created."""
	_spec = _read_json(path)
	_error = _spec_error()
	if _error != "":
		_finish()
		return
	_props.load_from(_manifest)
	_goods = Goods.new(_props)
	_cases = _spec.cases
	_report = {"schema": 1, "status": "SAMPLED_RUNTIME_ONLY", "production_qualified": false,
		"engine": Engine.get_version_info(), "spec_sha256": FileAccess.get_sha256(path),
		"display_driver": DisplayServer.get_name(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"manifest": _spec.manifest, "sources": _spec.sources, "cases": [],
		"sample_hz": SAMPLE_HZ, "warm_steps": WARM_STEPS, "missing_bindings": Array(MISSING),
		"continuous_residual_um": null, "qualified_profile_count": 0}


static func _same_path(a: String, b: String) -> bool:
	"""Resolve resource and relative paths before guarding read-only evidence inputs."""
	return ProjectSettings.globalize_path(a).simplify_path() == ProjectSettings.globalize_path(b).simplify_path()


func _output_exists() -> bool:
	"""Reports are create-only, including on refusal, so no manifest/source/report can be truncated."""
	return FileAccess.file_exists(_out) or DirAccess.dir_exists_absolute(_out)


func _read_json(path: String) -> Dictionary:
	"""Refuse excessive or non-object JSON; never replace missing input with defaults."""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_JSON_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _spec_error() -> String:
	"""Pin exact source bytes, cast identity and selected state before the first resource load."""
	if _spec.get("schema") != 1 or not _spec.get("manifest") is Dictionary \
			or not _spec.get("sources") is Array or not _spec.get("cases") is Array:
		return "CAPTURE_SPEC_FORMAT"
	if _spec.sources.is_empty() or _spec.sources.size() > MAX_SOURCES \
			or _spec.cases.is_empty() or _spec.cases.size() > MAX_CASES:
		return "CAPTURE_CAPACITY"
	var pins: Dictionary = {}
	for source: Variant in [_spec.manifest] + _spec.sources:
		var refusal: String = _pin_error(source, pins)
		if refusal != "":
			return refusal
	for path: String in REQUIRED_SOURCE_PATHS:
		if not pins.has(path):
			return "CAPTURE_IMPLEMENTATION_UNPINNED"
	var self_pinned: bool = false
	for path: String in pins:
		self_pinned = self_pinned or _same_path(path, get_script().resource_path)
	if not self_pinned:
		return "CAPTURE_IMPLEMENTATION_UNPINNED"
	var implementation_refusal: String = _implementation_error(pins)
	if implementation_refusal != "":
		return implementation_refusal
	return _cases_error(pins)


func _cases_error(pins: Dictionary) -> String:
	"""Validate every request before any resource load so a later bad case cannot cause partial capture."""
	_manifest = _read_json(_spec.manifest.path)
	if not _manifest.get("cast") is Dictionary or not _manifest.get("world") is Dictionary:
		return "CAPTURE_MANIFEST_FORMAT"
	var ids: Dictionary = {}
	for request: Variant in _spec.cases:
		var refusal: String = _case_error(request, pins, ids)
		if refusal != "":
			return refusal
	return ""


func _implementation_error(pins: Dictionary) -> String:
	"""Pin the static script dependency closure and project autoloads, not just the entry helpers."""
	var pending: Array[String] = []
	for path: String in REQUIRED_SOURCE_PATHS:
		if path.ends_with(".gd"):
			pending.append(path)
	var project: ConfigFile = ConfigFile.new()
	if project.load("res://project.godot") != OK:
		return "CAPTURE_IMPLEMENTATION_UNPINNED"
	for key: String in project.get_section_keys("autoload"):
		pending.append(str(project.get_value("autoload", key)).trim_prefix("*"))
	var references: RegEx = RegEx.create_from_string("(?:preload|load)\\(\\s*\"(res://[^\"]+\\.gd)\"\\s*\\)")
	var seen: Dictionary = {}
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		if seen.size() >= MAX_SOURCES or not pins.has(path):
			return "CAPTURE_IMPLEMENTATION_UNPINNED"
		seen[path] = true
		for match_result: RegExMatch in references.search_all(FileAccess.get_file_as_string(path)):
			var dependency: String = match_result.get_string(1)
			if not seen.has(dependency) and not pending.has(dependency):
				pending.append(dependency)
	return ""


func _pin_error(source: Variant, pins: Dictionary) -> String:
	"""Hashes bind bytes, not merely an asset name or a refreshed provenance claim."""
	if not source is Dictionary or not source.get("path") is String or not source.get("sha256") is String:
		return "CAPTURE_SOURCE_FORMAT"
	var path: String = source.path
	if source.sha256.length() != 64 or not FileAccess.file_exists(path):
		return "CAPTURE_SOURCE_MISSING"
	var source_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if source_file == null or source_file.get_length() > MAX_SOURCE_BYTES:
		return "CAPTURE_SOURCE_CAPACITY"
	if _same_path(path, _out):
		return "CAPTURE_OUTPUT_OVERWRITES_SOURCE"
	if pins.has(path) or FileAccess.get_sha256(path) != source.sha256:
		return "CAPTURE_SOURCE_HASH"
	pins[path] = source.sha256
	return ""


func _case_error(request: Variant, pins: Dictionary, ids: Dictionary) -> String:
	"""No absent species, life stage, clip or fitted prop can inherit a neighboring variant."""
	if not request is Dictionary or not request.get("id") is String or request.id == "" \
			or ids.has(request.id) or not request.get("cast") is String:
		return "CAPTURE_CASE_FORMAT"
	ids[request.id] = true
	var cast_row: Variant = _manifest.cast.get(request.cast)
	if not cast_row is Dictionary or request.get("species") != cast_row.get("species") \
			or request.get("life_stage") != "adult_presentation_candidate":
		return "CAPTURE_CAST_IDENTITY"
	if not SCENARIOS.has(str(request.get("scenario", ""))) or not request.get("clip") is String \
			or not cast_row.get("clips") is Dictionary or not cast_row.clips.has(request.clip):
		return "CAPTURE_STATE_MISSING"
	for path: String in [str(cast_row.get("body", ""))] + cast_row.clips.values():
		if not pins.has(path):
			return "CAPTURE_STATE_SOURCE_UNPINNED"
		if _import_error(path, pins) != "":
			return "CAPTURE_IMPORTED_SOURCE_UNPINNED"
	if not request.get("attachments") is Array or request.attachments.size() > 16:
		return "CAPTURE_ATTACHMENTS_FORMAT"
	for key: Variant in request.attachments:
		if not key is String or not _attachment_compatible(key, request.clip):
			return "CAPTURE_ATTACHMENT_STATE"
		if key != "log" and (not _manifest.world.has(key) or not pins.has(str(_manifest.world[key].get("path", "")))):
			return "CAPTURE_ATTACHMENT_SOURCE_UNPINNED"
		if key != "log" and _import_error(str(_manifest.world[key].path), pins) != "":
			return "CAPTURE_IMPORTED_SOURCE_UNPINNED"
	return ""


static func _import_error(path: String, pins: Dictionary) -> String:
	"""Imported scene bytes can differ from their GLB; pin the actual remap and every declared destination."""
	if not pins.has(path + ".import"):
		return "CAPTURE_IMPORTED_SOURCE_UNPINNED"
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(path + ".import") != OK:
		return "CAPTURE_IMPORTED_SOURCE_UNPINNED"
	var destinations: Variant = settings.get_value("deps", "dest_files", [])
	if not (destinations is Array or destinations is PackedStringArray) or destinations.is_empty() \
			or destinations.size() > MAX_MESHES or not destinations.has(settings.get_value("remap", "path", "")):
		return "CAPTURE_IMPORTED_SOURCE_UNPINNED"
	for target: Variant in destinations:
		if not target is String or not pins.has(target):
			return "CAPTURE_IMPORTED_SOURCE_UNPINNED"
	return ""


static func _attachment_compatible(key: String, clip: String) -> bool:
	"""Only the demo's authored carry/pick bindings are available to this measurement harness."""
	if key == "mole_pick":
		return clip == "heavy_hammer_swing"
	return clip == "carry_heavy_object_walk" and (key == "log" or Farm.ITEM_PROP.has(StringName(key)))


func _process(_delta: float) -> bool:
	"""One deterministic pose step per engine frame; the skeleton callback reads final modifiers."""
	if _finished:
		return false
	if _self_test:
		_report = _self_checks()
		_finish()
		return false
	if _actor == null:
		_start_case()
	elif not _configured:
		_configure_case()
	elif not _pending and not _await_palette:
		_step_pose()
	return false


func _start_case() -> void:
	"""Create a fresh real body per scenario so spring and pose history cannot leak across variants."""
	_case_index += 1
	if _case_index >= _cases.size():
		_finish()
		return
	var request: Dictionary = _cases[_case_index]
	var space: CastSpace = CastSpace.new()
	space.setup([], [])
	_actor = Actor.new()
	if not _actor.setup_creature(0, StringName(request.cast), _manifest.cast[request.cast], space, 1729):
		_error = "CAPTURE_PLACEHOLDER_REFUSED"
		_finish()
		return
	root.add_child(_actor)
	_skeleton = _actor.get("_skeleton") as Skeleton3D
	_player = _actor.animation_player()
	_configured = false


func _configure_case() -> void:
	"""Resolve every remapped animation target and actual skin before starting sampled motion."""
	var request: Dictionary = _cases[_case_index]
	if _skeleton == null or _player == null or _skeleton.get_bone_count() > MAX_BONES:
		_error = "CAPTURE_SKELETON_MISSING"
	else:
		_error = _animation_error(StringName("cast/" + request.clip))
	if _error == "":
		_error = _cache_body()
	if _error == "":
		_error = _configure_attachments(request)
	if _error != "":
		_finish()
		return
	_begin_case(request)


func _animation_error(clip: StringName) -> String:
	"""Check the body's actual imported animation paths rather than assuming same-named rigs remap."""
	if not _player.has_animation(clip):
		return "CAPTURE_CLIP_NOT_IMPORTED"
	var animation: Animation = _player.get_animation(clip)
	var animation_root: Node = _player.get_node_or_null(_player.root_node)
	if animation_root == null or animation.length <= 0.0 or animation.length * SAMPLE_HZ > MAX_STEPS:
		return "CAPTURE_ANIMATION_CAPACITY"
	for track: int in animation.get_track_count():
		var path: NodePath = animation.track_get_path(track)
		var target: Node = animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
		if target == null:
			return "CAPTURE_TRACK_NODE_MISSING"
		if animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			if not target is Skeleton3D or path.get_subname_count() != 1 \
					or (target as Skeleton3D).find_bone(path.get_subname(0)) < 0:
				return "CAPTURE_TRACK_BONE_MISSING"
	return ""


func _cache_body() -> String:
	"""Cache all imported vertices and positive skin influences, refusing unsupported blend shapes."""
	_body.clear()
	var nodes: Array[Node] = _actor.get_node("Body").find_children("*", "MeshInstance3D", true, false)
	if nodes.is_empty() or nodes.size() > MAX_MESHES:
		return "CAPTURE_MESH_CAPACITY"
	var total: int = 0
	for node: Node in nodes:
		var part: Dictionary = _mesh_data(node as MeshInstance3D)
		if part.has("error"):
			return part.error
		total += int(part.vertices)
		if total > MAX_VERTICES:
			return "CAPTURE_VERTEX_CAPACITY"
		_body.append(part)
	return ""


func _mesh_data(instance: MeshInstance3D) -> Dictionary:
	"""Read engine-imported arrays and Skin name/index mapping; never use an undeformed AABB."""
	if not instance.mesh is ArrayMesh or instance.mesh.get_blend_shape_count() != 0:
		return {"error": "CAPTURE_BLEND_SHAPES_UNSUPPORTED"}
	var surfaces: Array[Dictionary] = []
	var count: int = 0
	if instance.mesh.get_surface_count() > MAX_MESHES:
		return {"error": "CAPTURE_MESH_CAPACITY"}
	for surface: int in instance.mesh.get_surface_count():
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var refusal: String = _weights_error(positions.size(), weights, bones, instance.skin)
		if refusal != "":
			return {"error": refusal}
		count += positions.size()
		if count > MAX_VERTICES:
			return {"error": "CAPTURE_VERTEX_CAPACITY"}
		surfaces.append({"positions": positions, "weights": weights, "bones": bones})
	var binds: Dictionary = _skin_data(instance)
	if binds.has("error"):
		return binds
	return {"node": instance, "surfaces": surfaces, "vertices": count, "binds": binds}


static func _weights_error(count: int, weights: PackedFloat32Array, bones: PackedInt32Array, skin: Skin) -> String:
	"""Honor all four or eight imported influences and refuse zero/negative/nonfinite or absent binds."""
	if count < 1 or count > MAX_VERTICES or weights.size() != bones.size():
		return "CAPTURE_SKIN_FORMAT"
	if weights.is_empty():
		return "" if skin == null else "CAPTURE_SKIN_FORMAT"
	if skin == null or weights.size() not in [count * 4, count * 8]:
		return "CAPTURE_SKIN_FORMAT"
	@warning_ignore("integer_division") var stride: int = weights.size() / count
	for vertex: int in count:
		var sum: float = 0.0
		for influence: int in stride:
			var at: int = vertex * stride + influence
			if not is_finite(weights[at]) or weights[at] < 0.0 or bones[at] < 0 or bones[at] >= skin.get_bind_count():
				return "CAPTURE_SKIN_INFLUENCE"
			sum += weights[at]
		if sum <= 0.0:
			return "CAPTURE_SKIN_INFLUENCE"
	return ""


func _skin_data(instance: MeshInstance3D) -> Dictionary:
	"""Resolve Skin binds exactly as the engine does: a named bind wins over a numerical fallback."""
	if instance.skin == null:
		return {"indices": PackedInt32Array(), "poses": []}
	var skeleton: Skeleton3D = instance.get_node_or_null(instance.skeleton) as Skeleton3D
	if skeleton != _skeleton or instance.skin.get_bind_count() > MAX_BONES:
		return {"error": "CAPTURE_SKIN_SKELETON"}
	var indices: PackedInt32Array = PackedInt32Array()
	var poses: Array[Transform3D] = []
	for bind: int in instance.skin.get_bind_count():
		var named: StringName = instance.skin.get_bind_name(bind)
		var index: int = skeleton.find_bone(named) if named != &"" else instance.skin.get_bind_bone(bind)
		if index < 0 or index >= skeleton.get_bone_count():
			return {"error": "CAPTURE_SKIN_BONE_MISSING"}
		indices.append(index)
		poses.append(instance.skin.get_bind_pose(bind))
	return {"indices": indices, "poses": poses}


func _configure_attachments(request: Dictionary) -> String:
	"""Use actual generated meshes and demo fitting; no highpoly proxy or fallback boxes enter evidence."""
	_items.clear()
	var total: int = 0
	if _tunnel_ext == null and request.attachments.has("mole_pick"):
		_tunnel_ext = load("res://demo/tunnel/tunnel_ext.gd") as GDScript
	for key: String in request.attachments:
		if _skeleton.find_bone("LeftHand") < 0 or _skeleton.find_bone("RightHand") < 0:
			return "CAPTURE_ATTACHMENT_BONE_MISSING"
		if key != "log" and not _props.is_staged(StringName(key)):
			return "CAPTURE_ATTACHMENT_NOT_IMPORTED"
		var item: Dictionary = _attachment_data(key)
		if item.has("error"):
			return item.error
		total += int(item.vertices)
		if total > MAX_VERTICES:
			return "CAPTURE_ATTACHMENT_CAPACITY"
		_items.append(item)
	return ""


func _attachment_data(key: String) -> Dictionary:
	"""Bind the real load and fitting function, then retain bounded immutable surface arrays."""
	var fit: Transform3D = Transform3D.IDENTITY
	var mesh: Mesh = null
	if key == "log":
		var log_node: MeshInstance3D = _actor.get("_load") as MeshInstance3D
		if log_node == null:
			return {"error": "CAPTURE_LOAD_BINDING_MISSING"}
		mesh = log_node.mesh
	elif key == "mole_pick":
		mesh = _props.mesh_of(StringName(key))
		fit = _tunnel_ext.call("pick_fit", _props)
	else:
		mesh = _props.mesh_of(StringName(key))
		fit = _goods.hand_fit(Farm.ITEM_PROP.find(StringName(key)))
	var data: Dictionary = _attachment_mesh_data(mesh)
	if data.has("error"):
		return data
	data.merge({"key": key, "mesh": mesh, "fit": fit, "bounds": []})
	return data


static func _attachment_mesh_data(mesh: Mesh) -> Dictionary:
	"""Static held geometry cannot silently inherit an undeformed skin or unbounded vertex workload."""
	if not (mesh is ArrayMesh or mesh is PrimitiveMesh) or mesh.get_surface_count() < 1 \
			or mesh.get_surface_count() > MAX_MESHES:
		return {"error": "CAPTURE_ATTACHMENT_CAPACITY"}
	if mesh is ArrayMesh and mesh.get_blend_shape_count() != 0:
		return {"error": "CAPTURE_ATTACHMENT_BLEND_SHAPES_UNSUPPORTED"}
	var surfaces: Array[PackedVector3Array] = []
	var count: int = 0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_WEIGHTS] != null and not arrays[Mesh.ARRAY_WEIGHTS].is_empty():
			return {"error": "CAPTURE_ATTACHMENT_SKIN_UNSUPPORTED"}
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += points.size()
		if points.is_empty() or count > MAX_VERTICES:
			return {"error": "CAPTURE_ATTACHMENT_CAPACITY"}
		surfaces.append(points)
	return {"surfaces": surfaces, "vertices": count}


func _begin_case(request: Dictionary) -> void:
	"""Pin capture axes and retained scenario inputs; scheduled poses remain explicitly non-authoritative."""
	var clip: StringName = StringName("cast/" + request.clip)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	_player.play(clip)
	_player.seek(0.0, true)
	_steps = ceili(_player.get_animation(clip).length * SAMPLE_HZ) + 1
	_step = -WARM_STEPS
	_pending = false
	_await_palette = false
	_configured = true
	_row = {"id": request.id, "cast": request.cast, "species": request.species,
		"life_stage": request.life_stage, "clip": request.clip, "scenario": request.scenario,
		"production_qualified": false, "status": "SAMPLED_RUNTIME_ONLY", "bounds_m": [],
		"samples": 0, "bones": _skeleton.get_bone_count(), "body_parts": _body.size(),
		"tracks_resolved": _player.get_animation(clip).get_track_count(),
		"skin_engine_matrix_checks": 0, "skin_engine_matrix_max_error_m": null,
		"deformed_vertex_max_displacement_m": 0.0, "bone_names": _bone_names(),
		"tail_live": _actor.has_live_tail(), "tail_refusal": str(_actor.tail_refusal),
		"attachments": [], "raw_stoop_drop_m": _modifier_drop(request),
		"basis": "demo local +Z forward; simulation -Z conversion not bound",
		"root_motion": "fixed origin, explicit pitch/turn schedule; not actual path traversal"}
	_begin_observations(clip)


func _begin_observations(clip: StringName) -> void:
	"""Keep expected temporal/palette coverage visible; positive totals alone can hide a frozen clip."""
	_row["clip_duration_s"] = _player.get_animation(clip).length
	_row["clip_loop_mode"] = _player.get_animation(clip).loop_mode
	_row["expected_sample_count"] = _steps
	_row["clip_positions_s"] = []
	_row["bone_pose_max_change_from_first"] = 0.0
	_row["expected_palette_checks_per_sample"] = 0
	_row["sample_boundary"] = "restart exact source clip at zero after warm-up; reset transient not qualified"
	for part: Dictionary in _body:
		_row.expected_palette_checks_per_sample += part.binds.indices.size()


func _bone_names() -> Array[String]:
	"""Retain the exact imported bone mapping so one rig cannot silently borrow another's names."""
	var names: Array[String] = []
	for bone: int in _skeleton.get_bone_count():
		names.append(String(_skeleton.get_bone_name(bone)))
	return names


func _modifier_drop(request: Dictionary) -> float:
	"""Measure the actual demo's standard-bore pose request without adopting it as a new clearance rule."""
	if request.scenario == "plain" or request.scenario == "turn":
		return 0.0
	var drop: float = Tunnel.to_m(Tunnel.stoop_drop_u(Tunnel.to_u(_actor.height_m), Tunnel.BORE_CROWNS_U[Tunnel.BORE_STANDARD]))
	if request.clip == String(Actor.CLIP_CROUCH):
		drop = maxf(0.0, drop - float(_actor.get("_crouch_drop")))
	return drop


func _step_pose() -> void:
	"""Advance the real animation and modifier chain by a fixed measured time step."""
	var request: Dictionary = _cases[_case_index]
	var pitch: float = atan2(float(Tunnel.RAMP_GRADE_RISE), float(Tunnel.RAMP_GRADE_RUN))
	if request.scenario == "ramp_up":
		pitch = -pitch
	elif request.scenario != "ramp_down":
		pitch = 0.0
	_actor.rotation = Vector3(pitch, float(maxi(0, _step)) / float(maxi(1, _steps - 1)) * PI if request.scenario == "turn" else 0.0, 0.0)
	if _actor.stoop() != null:
		_actor.stoop().set_pose(_modifier_drop(request), -pitch * Actor.LEAN_BACK_SHARE)
	if _step == 0:
		_restart_clip(_player, StringName("cast/" + request.clip))
	else:
		_player.advance(1.0 / SAMPLE_HZ)
	_pending = true
	_skeleton.advance(1.0 / SAMPLE_HZ)


static func _restart_clip(player: AnimationPlayer, clip: StringName) -> void:
	"""A non-looping clip may finish during warm-up; play and seek explicitly before recording pose zero."""
	player.play(clip)
	player.seek(0.0, true)
	player.advance(0.0)


func _on_skeleton_updated() -> void:
	"""Sample final post-modifier bone poses before Skeleton3D restores its animation input."""
	if not _pending or _finished:
		return
	_pending = false
	_await_palette = true
	_parity.clear()
	if _step >= 0:
		_capture_pose()
	_step += 1
	call_deferred("_after_palette")


func _after_palette() -> void:
	"""Skeleton signals precede renderer palette upload; compare stored final poses after that upload."""
	for entry: Dictionary in _parity:
		_compare_engine_skin(entry.instance, entry.transforms)
	_parity.clear()
	_await_palette = false
	if _error != "":
		_finish()
	elif _step >= _steps:
		_end_case()


func _capture_pose() -> void:
	"""Evaluate every imported body vertex with the actual final skin matrices and instance transform."""
	_row.clip_positions_s.append(_player.current_animation_position)
	var bounds: Array = _row.bounds_m
	for part: Dictionary in _body:
		var transforms: Array[Transform3D] = []
		for bind: int in part.binds.indices.size():
			transforms.append(_skeleton.get_bone_global_pose(part.binds.indices[bind]) * part.binds.poses[bind])
		_observe_motion(part, transforms)
		var instance: MeshInstance3D = part.node
		_parity.append({"instance": instance, "transforms": transforms})
		for surface: Dictionary in part.surfaces:
			for vertex: int in surface.positions.size():
				var point: Vector3 = _skin_point(surface, vertex, transforms)
				_row.deformed_vertex_max_displacement_m = maxf(_row.deformed_vertex_max_displacement_m,
					point.distance_to(surface.positions[vertex]))
				if not _include(bounds, instance.global_transform * point):
					_error = "CAPTURE_NONFINITE_VERTEX"
	_row.bounds_m = bounds
	_row.samples += 1
	_capture_items()


func _observe_motion(part: Dictionary, transforms: Array[Transform3D]) -> void:
	"""Observe actual post-modifier pose changes separately from static bind-pose displacement."""
	if not part.has("initial_matrices"):
		part["initial_matrices"] = transforms.duplicate()
	for index: int in transforms.size():
		_row.bone_pose_max_change_from_first = maxf(_row.bone_pose_max_change_from_first,
			_matrix_error(transforms[index], part.initial_matrices[index]))


func _compare_engine_skin(instance: MeshInstance3D, transforms: Array[Transform3D]) -> void:
	"""When the renderer stores skin matrices, compare every bind to the actual engine palette."""
	var reference: SkinReference = instance.get_skin_reference()
	if reference == null or transforms.is_empty():
		return
	var rid: RID = reference.get_skeleton()
	if not rid.is_valid() or RenderingServer.skeleton_get_bone_count(rid) != transforms.size():
		return
	for bind: int in transforms.size():
		var actual: Transform3D = RenderingServer.skeleton_bone_get_transform(rid, bind)
		if _row.skin_engine_matrix_max_error_m == null:
			_row.skin_engine_matrix_max_error_m = 0.0
		_row.skin_engine_matrix_max_error_m = maxf(_row.skin_engine_matrix_max_error_m,
			_matrix_error(actual, transforms[bind]))
		_row.skin_engine_matrix_checks += 1
	if _row.skin_engine_matrix_max_error_m != 0.0:
		_error = "CAPTURE_ENGINE_MATRIX_MISMATCH"


static func _matrix_error(actual: Transform3D, expected: Transform3D) -> float:
	"""Exact observed API palette parity is distinct from a GPU or continuous-position residual proof."""
	if not actual.is_finite() or not expected.is_finite():
		return INF
	var error: float = 0.0
	for point: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		error = maxf(error, (actual * point).distance_to(expected * point))
	return error


static func _skin_point(surface: Dictionary, vertex: int, matrices: Array[Transform3D]) -> Vector3:
	"""Match the engine's weighted affine sum, retaining eight influences and source weight sums."""
	var point: Vector3 = surface.positions[vertex]
	if matrices.is_empty():
		return point
	@warning_ignore("integer_division") var stride: int = surface.weights.size() / surface.positions.size()
	var result: Vector3 = Vector3.ZERO
	for influence: int in stride:
		var at: int = vertex * stride + influence
		result += (matrices[surface.bones[at]] * point) * surface.weights[at]
	return result


func _capture_items() -> void:
	"""Place every configured load with the actual actor helper, then measure all its visible vertices."""
	for item: Dictionary in _items:
		var instance: MeshInstance3D = _item_instance(item)
		if instance == null or not instance.visible:
			_error = "CAPTURE_ATTACHMENT_HIDDEN"
			return
		var bounds: Array = item.bounds
		if instance.mesh != item.mesh:
			_error = "CAPTURE_ATTACHMENT_MESH_CHANGED"
			return
		for points: PackedVector3Array in item.surfaces:
			for point: Vector3 in points:
				if not _include(bounds, instance.global_transform * point):
					_error = "CAPTURE_NONFINITE_ATTACHMENT"
		item.bounds = bounds


func _item_instance(item: Dictionary) -> MeshInstance3D:
	"""Invoke the existing hand placement; synthetic scheduling never supplies a production gear/cargo ref."""
	_actor.brain.clip = StringName(_cases[_case_index].clip)
	_actor.brain.set("_clip_time", Actor.CROSSFADE_S + 1.0)
	_actor.brain.carrying = item.key != "mole_pick"
	if item.key == "mole_pick":
		_actor.brain.state = Actor.BrainScript.State.DIG
		_actor.set_tool(item.mesh, item.fit)
		_actor.call("_place_tool")
		return _actor.get("_tool") as MeshInstance3D
	if item.key == "log":
		_actor.set("_holding", false)
		_actor.call("_place_load")
		return _actor.get("_load") as MeshInstance3D
	_actor.hold(item.mesh, item.fit)
	_actor.call("_place_load")
	return _actor.get("_held") as MeshInstance3D


static func _include(bounds: Array, point: Vector3) -> bool:
	"""A float presentation measurement, with no claimed continuous or numerical safety margin."""
	if not point.is_finite():
		return false
	if bounds.is_empty():
		bounds.append_array([point.x, point.y, point.z, point.x, point.y, point.z])
	for axis: int in 3:
		bounds[axis] = minf(bounds[axis], point[axis])
		bounds[axis + 3] = maxf(bounds[axis + 3], point[axis])
	return true


func _end_case() -> void:
	"""Detach all callbacks and free one real actor before the next variant can begin."""
	_configured = false
	_row["skin_engine_parity"] = "MEASURED" if _row.skin_engine_matrix_checks > 0 else "RENDERER_PALETTE_UNAVAILABLE"
	for item: Dictionary in _items:
		var combined: Array = _row.bounds_m.duplicate()
		_include(combined, Vector3(item.bounds[0], item.bounds[1], item.bounds[2]))
		_include(combined, Vector3(item.bounds[3], item.bounds[4], item.bounds[5]))
		_row.attachments.append({"key": item.key, "bounds_m": item.bounds, "body_and_attachment_bounds_m": combined,
			"gear_lot_ref": null, "cargo_lot_ref": null, "cargo_quantity_milli": null})
	_report.cases.append(_row)
	print("capture: %s %d sampled pose(s), %d attachment(s)" % [_row.id, _row.samples, _row.attachments.size()])
	_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
	_body.clear()
	_items.clear()
	_actor.free()
	_actor = null
	_skeleton = null
	_player = null


func _finish() -> void:
	"""Write truthful evidence or refusal, never an accepted movement envelope."""
	if _finished:
		return
	_finished = true
	if _actor != null:
		_body.clear()
		_items.clear()
		_actor.free()
		_actor = null
	_report["error"] = _error
	_report["production_qualified"] = false
	_report["qualified_profile_count"] = 0
	if _error != "":
		_report["status"] = "REFUSED"
	if _output_exists():
		printerr("CAPTURE_OUTPUT_EXISTS")
		quit(2)
		return
	var file: FileAccess = FileAccess.open(_out, FileAccess.WRITE)
	if file == null:
		printerr("CAPTURE_OUTPUT_UNWRITABLE")
		quit(2)
		return
	file.store_string(JSON.stringify(_report, "  ") + "\n")
	file.close()
	print("capture: %d runtime case(s), 0 qualified; %s" % [_report.get("cases", []).size(), _error if _error != "" else "complete"])
	quit(2 if _error != "" else 0)


func _self_checks() -> Dictionary:
	"""Small synthetic adversarial checks; their dimensions are never used for production content."""
	var checks: Dictionary = {}
	var skin: Skin = Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	var eight: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 1])
	var bones: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var surface: Dictionary = {"positions": PackedVector3Array([Vector3(1, 2, 3)]), "weights": eight, "bones": bones}
	var matrices: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(4, 5, 6))]
	checks["eighth_influence"] = _skin_point(surface, 0, matrices) == Vector3(5, 7, 9)
	checks["eight_supported"] = _weights_error(1, eight, bones, skin) == ""
	eight[7] = -1
	checks["negative_refused"] = _weights_error(1, eight, bones, skin) == "CAPTURE_SKIN_INFLUENCE"
	eight[7] = NAN
	checks["nonfinite_refused"] = _weights_error(1, eight, bones, skin) == "CAPTURE_SKIN_INFLUENCE"
	eight[7] = 0
	checks["zero_sum_refused"] = _weights_error(1, eight, bones, skin) == "CAPTURE_SKIN_INFLUENCE"
	eight[7] = 1
	bones[7] = 1
	checks["missing_bind_refused"] = _weights_error(1, eight, bones, skin) == "CAPTURE_SKIN_INFLUENCE"
	checks["missing_state_refused"] = not _attachment_compatible("mole_pick", "walk")
	checks["no_unknown_prop_fallback"] = not _attachment_compatible("item_missing", "carry_heavy_object_walk")
	checks["nonfinite_bounds_refused"] = not _include([], Vector3(INF, 0, 0))
	checks["matrix_mismatch_detected"] = _matrix_error(Transform3D.IDENTITY, matrices[0]) > 0.0
	checks["matrix_identity_exact"] = _matrix_error(matrices[0], matrices[0]) == 0.0
	checks["missing_attachment_mesh_refused"] = _attachment_mesh_data(null).get("error") == "CAPTURE_ATTACHMENT_CAPACITY"
	checks.merge(_mesh_self_checks())
	checks.merge(_timeline_self_checks())
	return {"synthetic": true, "checks": checks, "status": "SELF_TEST_ONLY"}


func _timeline_self_checks() -> Dictionary:
	"""A short non-looping synthetic clip must move again after a warm-up longer than its duration."""
	var holder: Node3D = Node3D.new()
	var target: Node3D = Node3D.new()
	target.name = "Target"
	holder.add_child(target)
	var player: AnimationPlayer = AnimationPlayer.new()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	holder.add_child(player)
	var animation: Animation = Animation.new()
	animation.length = 0.5
	animation.loop_mode = Animation.LOOP_NONE
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(0, NodePath("Target:position"))
	animation.track_insert_key(0, 0.0, Vector3.ZERO)
	animation.track_insert_key(0, 0.5, Vector3.RIGHT)
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(&"short", animation)
	player.add_animation_library(&"", library)
	root.add_child(holder)
	player.play(&"short")
	player.advance(float(WARM_STEPS) / SAMPLE_HZ)
	var checks: Dictionary = {"short_clip_finished_during_warmup": target.position.x == 1.0}
	_restart_clip(player, &"short")
	checks["sample_zero_restarted"] = player.current_animation_position == 0.0 and target.position.x == 0.0
	player.advance(0.25)
	checks["nonloop_motion_recorded"] = player.current_animation_position > 0.0 and target.position.x > 0.0 and target.position.x < 1.0
	holder.free()
	return checks


static func _mesh_self_checks() -> Dictionary:
	"""Keep static prop workload and unsupported skin refusals executable without production assets."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = PackedVector3Array()
	vertices.resize(MAX_VERTICES + 1)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var oversized: ArrayMesh = ArrayMesh.new()
	oversized.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	var checks: Dictionary = {"attachment_capacity_refused":
		_attachment_mesh_data(oversized).get("error") == "CAPTURE_ATTACHMENT_CAPACITY"}
	var log_mesh: CylinderMesh = CylinderMesh.new()
	var log_data: Dictionary = _attachment_mesh_data(log_mesh)
	checks["actual_log_mesh_type_supported"] = not log_data.has("error") and int(log_data.get("vertices", 0)) > 0
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0])
	var skinned: ArrayMesh = ArrayMesh.new()
	skinned.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	checks["attachment_skin_refused"] = _attachment_mesh_data(skinned).get("error") == "CAPTURE_ATTACHMENT_SKIN_UNSUPPORTED"
	return checks
