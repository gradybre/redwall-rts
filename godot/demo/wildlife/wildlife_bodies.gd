extends RefCounted
## THE WILDLIFE'S BODIES. Decision 1631 (feature #11). Presentation only: made once, when the wildlife is configured --
## a pooled body per animal, never one made or freed while the village runs.
##
## STAGED, each is the art pass 2 model (decision 0951; gitignored, staged by tools/stage_art_passes.py into
## godot/demo/assets/wildlife/<key>.glb): skinned, its clips glTF animations, exported at DEC-047's sizes in metres with
## its origin at its feet (robin, frog) or its body's centre (the robin in flight, the butterfly; the trout's at the
## water surface). Godot imports glTF animations without looping (art_pass2_mapping.md), so LOOPED's clips are set to
## loop here, once, on the shared imported Animation.
##
## NOT STAGED (CI, a fresh clone), each is a STAND-IN of the same size and colour -- a small rounded body, no clips --
## so the wildlife still runs, places and counts exactly the same, and the suites see it.
##
## KEEPING THE COST DOWN. Every mesh in a body is culled past VIEW_RANGE_M (`visibility_range_end`): a robin is a few
## pixels at that distance. The butterflies cast no shadow (a 0.36 m wing's shadow is noise at the village camera).

const Rules := preload("res://demo/wildlife/wildlife_rules.gd")

const DIR: String = "res://demo/assets/wildlife/%s.glb"
## Per kind (Rules order) the staged model's key; the robin's flight is its own model (its folded wings cannot flap).
const KEYS: Array[StringName] = [&"wild_songbird", &"wild_butterfly", &"wild_frog", &"wild_trout_leaping"]
const FLIGHT_KEY: StringName = &"wild_songbird_flight"
const LOOPED: Array[StringName] = [&"idle", &"flap", &"glide", &"rest", &"swim"]
const VIEW_RANGE_M: float = 55.0
## The stand-ins' sizes (length, height, width; metres, DEC-047's lengths) and colours.
const STAND_IN_SIZE: Array[Vector3] = [Vector3(0.45, 0.3, 0.18), Vector3(0.12, 0.05, 0.36), Vector3(0.4, 0.16, 0.22),
	Vector3(0.8, 0.16, 0.12)]
const STAND_IN_COLOUR: Array[Color] = [Color(0.55, 0.35, 0.22), Color(0.72, 0.2, 0.12), Color(0.36, 0.45, 0.2),
	Color(0.5, 0.45, 0.32)]

var _scenes: Dictionary = {}
var _stand_ins: Dictionary = {}


static func path_of(key: StringName) -> String:
	"""Where a key's staged model is."""
	return DIR % key


static func is_staged(key: StringName) -> bool:
	"""Whether a key's model is staged (else its stand-in is drawn)."""
	return ResourceLoader.exists(path_of(key))


func make(key: StringName, kind: int, shadow: bool) -> Node3D:
	"""One body for `key` (its stand-in, sized for `kind`, when not staged), its meshes culled and shadowed as above."""
	var body: Node3D = _staged_body(key)
	if body == null:
		body = _stand_in(key, kind)
	for node: Node in body.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = VIEW_RANGE_M
		if not shadow:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.visible = false
	return body


func _staged_body(key: StringName) -> Node3D:
	"""An instance of the staged model, its clips' loops set (null when not staged)."""
	if not _scenes.has(key):
		_scenes[key] = load(path_of(key)) as PackedScene if is_staged(key) else null
	var scene: PackedScene = _scenes[key]
	if scene == null:
		return null
	var body := scene.instantiate() as Node3D
	var player: AnimationPlayer = player_of(body)
	if player != null:
		set_loops(player)
	return body


static func player_of(body: Node) -> AnimationPlayer:
	"""A body's AnimationPlayer (null: a stand-in)."""
	var found: Array[Node] = body.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


static func set_loops(player: AnimationPlayer) -> void:
	"""Loop the clips that loop (LOOPED); the hop, the peck and the leap play once."""
	for clip: StringName in player.get_animation_list():
		var animation: Animation = player.get_animation(clip)
		var loop: Animation.LoopMode = Animation.LOOP_LINEAR if LOOPED.has(clip) else Animation.LOOP_NONE
		if animation.loop_mode != loop:
			animation.loop_mode = loop


func _stand_in(key: StringName, kind: int) -> Node3D:
	"""A rounded stand-in the animal's size and colour, its feet at the origin (or its middle, as its model's)."""
	if not _stand_ins.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 8
		mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.albedo_color = STAND_IN_COLOUR[kind]
		mesh.material = material
		_stand_ins[key] = mesh
	var holder := Node3D.new()
	var shape := MeshInstance3D.new()
	shape.mesh = _stand_ins[key]
	var size: Vector3 = STAND_IN_SIZE[kind]
	var centred: bool = key == FLIGHT_KEY or kind == Rules.BUTTERFLY or kind == Rules.TROUT
	shape.transform = Transform3D(Basis.from_scale(Vector3(size.z, size.y, size.x)), Vector3.UP * (0.0 if centred else size.y * 0.5))
	holder.add_child(shape)
	return holder


func staged_count() -> int:
	"""How many of the five models are staged (a check)."""
	var n: int = 1 if is_staged(FLIGHT_KEY) else 0
	for key: StringName in KEYS:
		n += 1 if is_staged(key) else 0
	return n
