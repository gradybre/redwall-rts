extends Node3D
## One demo resident on screen: its rigged body, its six clips on the body's own AnimationPlayer,
## its live tail, and the wandering brain that moves it. Decision 0196. Presentation only.
##
## ---------------------------------------------------------------------------------------
## THE CLIPS. Each clip file is staged STRIPPED to skeleton + animation (tools/stage_demo_assets.py).
## Its track paths (`Armature/Skeleton3D:<bone>`) resolve unchanged from the body scene's root, so the
## body's AnimationPlayer plays all six from one AnimationLibrary. Every clip loops: the activities
## are held for whole loops (resident_brain.gd), so a loop always ends where the next begins.
##
## THE TAIL. `TailRig.attach()` needs the skeleton inside the tree (decision 0191), so it runs from
## `_ready()`. The mole and badger have no chain and are refused with REFUSE_NO_CHAIN -- expected,
## not an error. Nothing here may scale the body: the spring collides wrongly under a scaled skeleton
## (decisions 0192, 0194), and TailRig refuses one.
##
## THE LOAD. A carry trip holds a log between the hands: a bark-coloured cylinder laid from one hand
## to the other, placed on the skeleton's `skeleton_updated` so it sits on this frame's posed hands
## rather than last frame's. Presentation only; the brain decides when a trip carries.
##
## FACING. The models face +Z, so the node's yaw is the brain's yaw: local +Z points along travel.
## With no staged cast (CI, a fresh clone), a capsule with a nose stands in, with the same brain.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const TailRigScript := preload("res://scripts/presentation/tail_rig.gd")
const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")

const CROSSFADE_S: float = 0.25
const LIBRARY: StringName = &"cast"
const CLIPS: Array[StringName] = [&"idle", &"walk", &"collect_object", &"stand_and_drink", &"wave_one_hand",
	&"carry_heavy_object_walk"]
const RADIUS_PER_HEIGHT: float = 0.22
const MIN_RADIUS_M: float = 0.2
const MAX_RADIUS_M: float = 0.6
const PLACEHOLDER_HEIGHT_M: float = 1.0
const PLACEHOLDER_WALK_SPEED_M_S: float = 0.8
const PLACEHOLDER_CLIP_S: float = 3.0
const LOAD_RADIUS_PER_HEIGHT: float = 0.055
const LOAD_OVERHANG_PER_HEIGHT: float = 0.12
const LOAD_COLOUR: Color = Color(0.36, 0.25, 0.16)
const PLACEHOLDER_COLOURS: Array[Color] = [Color(0.72, 0.52, 0.36), Color(0.55, 0.62, 0.38),
	Color(0.47, 0.55, 0.7), Color(0.75, 0.66, 0.42), Color(0.62, 0.45, 0.58), Color(0.5, 0.5, 0.5)]

var brain: BrainScript = null
var creature_key: StringName = &""
var is_placeholder: bool = false
var tail_refusal: StringName = TailRigScript.REFUSE_NONE

var _player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _tail: TailRigScript = null
var _tail_tried: bool = false
var _playing: StringName = &""
var _library_names: Dictionary = {}
var _load: MeshInstance3D = null
var _load_length: float = 0.0
var _hand_left: int = -1
var _hand_right: int = -1
var _skeleton_to_actor: Transform3D = Transform3D.IDENTITY


func setup_creature(key: StringName, row: Dictionary, space: CastSpaceScript, seed: int) -> bool:
	"""Build a real creature from its manifest row. Returns false (and builds a placeholder) if its body
	cannot be loaded."""
	var body_path := String(row.get("body", ""))
	var scene: PackedScene = load(body_path) as PackedScene if ResourceLoader.exists(body_path) else null
	if scene == null:
		push_warning("demo cast: %s has no loadable body; using a placeholder" % key)
		setup_placeholder(0, space, seed)
		return false
	creature_key = key
	var body := scene.instantiate() as Node3D
	body.name = &"Body"
	add_child(body)
	_skeleton = _find_skeleton(body)
	_player = _find_player(body)
	if _player == null:
		_player = AnimationPlayer.new()
		body.add_child(_player)
	var motion := {}
	var lengths := _build_library(row.get("clips", {}), motion)
	var height := float(row.get("height_m", PLACEHOLDER_HEIGHT_M))
	brain = BrainScript.new()
	brain.configure(space, float(row.get("walk_speed_m_s", PLACEHOLDER_WALK_SPEED_M_S)), body_radius(height), seed, lengths)
	brain.set_carry_motion(motion)
	if brain.can_carry():
		_build_load(height)
	return true


func setup_placeholder(index: int, space: CastSpaceScript, seed: int) -> void:
	"""A capsule with a nose on its +Z side, driven by the same brain at a nominal walk speed."""
	is_placeholder = true
	creature_key = StringName("placeholder_%d" % index)
	var material := StandardMaterial3D.new()
	material.albedo_color = PLACEHOLDER_COLOURS[index % PLACEHOLDER_COLOURS.size()]
	var radius := body_radius(PLACEHOLDER_HEIGHT_M)
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = PLACEHOLDER_HEIGHT_M
	_add_shape(capsule, material, Vector3(0.0, PLACEHOLDER_HEIGHT_M * 0.5, 0.0))
	var nose := BoxMesh.new()
	nose.size = Vector3(0.1, 0.1, 0.16)
	_add_shape(nose, material, Vector3(0.0, PLACEHOLDER_HEIGHT_M * 0.75, radius))
	var lengths := {}
	for clip in CLIPS:
		lengths[clip] = PLACEHOLDER_CLIP_S
	brain = BrainScript.new()
	brain.configure(space, PLACEHOLDER_WALK_SPEED_M_S, radius, seed, lengths)


static func body_radius(height_m: float) -> float:
	"""The circle a creature of this height keeps clear around itself."""
	return clampf(height_m * RADIUS_PER_HEIGHT, MIN_RADIUS_M, MAX_RADIUS_M)


func place(at: Vector2, face_yaw: float, poi: int, slot: int) -> void:
	"""Stand at `at` (x, z) facing `face_yaw`, holding a POI slot (or -1, -1)."""
	brain.start_at(at, face_yaw, poi, slot)
	_apply_transform()
	_apply_clip()


func _ready() -> void:
	"""Inside the tree now: the tail can attach."""
	_attach_tail()


func _process(delta: float) -> void:
	"""Advance the brain and draw where it says."""
	if brain == null:
		return
	brain.step(delta)
	_apply_transform()
	_apply_clip()


func _apply_transform() -> void:
	"""Stand on the ground at the brain's position; local +Z along its yaw."""
	position.x = brain.position.x
	position.y = 0.0
	position.z = brain.position.y
	rotation.y = brain.yaw


func _apply_clip() -> void:
	"""Crossfade to the brain's clip when it changes; follow its playback speed every frame."""
	if _player == null:
		return
	_player.speed_scale = brain.clip_speed
	if brain.clip == _playing:
		return
	_playing = brain.clip
	var full: StringName = _library_names.get(_playing, &"")
	if full != &"":
		_player.play(full, CROSSFADE_S)


func _attach_tail() -> void:
	"""Once, in the tree: the live tail with its floor on the flat ground. Untailed species are refused."""
	if _tail_tried or _skeleton == null or not is_inside_tree():
		return
	_tail_tried = true
	var rig := TailRigScript.new()
	tail_refusal = rig.attach(_skeleton)
	if tail_refusal == TailRigScript.REFUSE_NONE:
		rig.set_floor(0.0)
		_tail = rig
	elif tail_refusal != TailRigScript.REFUSE_NO_CHAIN:
		push_warning("demo cast: %s's tail was refused: %s" % [creature_key, tail_refusal])


func _build_load(height: float) -> void:
	"""The log a carrier holds, hidden until a carry trip; placed from the hands once they are posed."""
	_hand_left = _skeleton.find_bone("LeftHand")
	_hand_right = _skeleton.find_bone("RightHand")
	if _hand_left < 0 or _hand_right < 0:
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = height * LOAD_RADIUS_PER_HEIGHT
	trunk.bottom_radius = trunk.top_radius
	trunk.height = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = LOAD_COLOUR
	material.roughness = 0.9
	_load = MeshInstance3D.new()
	_load.mesh = trunk
	_load.material_override = material
	_load.visible = false
	add_child(_load)
	_load_length = height * LOAD_OVERHANG_PER_HEIGHT
	_skeleton_to_actor = _relative_transform(_skeleton)
	_skeleton.skeleton_updated.connect(_place_load)


func _relative_transform(node: Node3D) -> Transform3D:
	"""`node`'s transform in this actor's space, walking the parents (setup only; works out of tree)."""
	var xform := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != self:
		if at is Node3D:
			xform = (at as Node3D).transform * xform
		at = at.get_parent()
	return xform


func _place_load() -> void:
	"""Lay the log from hand to hand on this frame's pose, overhanging each hand a little. It shows only
	once the crossfade into the carry is over, so it never spans hands still swinging into place."""
	_load.visible = brain.carrying and brain.clip == BrainScript.CLIP_CARRY and brain.clip_time() >= CROSSFADE_S
	if not _load.visible:
		return
	var left := _skeleton_to_actor * _skeleton.get_bone_global_pose(_hand_left).origin
	var right := _skeleton_to_actor * _skeleton.get_bone_global_pose(_hand_right).origin
	var across := right - left
	var span := maxf(across.length(), 1e-3)
	var axis := across / span
	var side := Vector3.UP.cross(axis).normalized()
	_load.transform = Transform3D(Basis(axis.cross(side), axis * (span + _load_length), side), (left + right) * 0.5)


func has_live_tail() -> bool:
	"""Whether a tail spring is running on this resident."""
	return _tail != null


func animation_player() -> AnimationPlayer:
	"""The body's AnimationPlayer (null for a placeholder)."""
	return _player


func skeleton() -> Skeleton3D:
	"""The body's skeleton (null for a placeholder)."""
	return _skeleton


# --- building -------------------------------------------------------------------------------

func _build_library(paths: Dictionary, motion_out: Dictionary) -> Dictionary:
	"""Load each staged clip into one looping AnimationLibrary on the body's player. Returns
	{clip: length_s}; fills `motion_out` with the carry clip's recorded root motion."""
	var library := AnimationLibrary.new()
	var lengths := {}
	for clip in CLIPS:
		var path := String(paths.get(clip, ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var holder := (load(path) as PackedScene).instantiate()
		var source := _find_player(holder)
		if source != null and not source.get_animation_list().is_empty():
			var animation := source.get_animation(source.get_animation_list()[0])
			animation.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(clip, animation)
			lengths[clip] = animation.length
			_library_names[clip] = StringName("%s/%s" % [LIBRARY, clip])
			if clip == BrainScript.CLIP_CARRY and _find_skeleton(holder) != null:
				motion_out.merge(ClipRootMotionScript.read(_find_skeleton(holder)))
		holder.free()
	_player.add_animation_library(LIBRARY, library)
	return lengths


func _add_shape(mesh: Mesh, material: Material, at: Vector3) -> void:
	"""One placeholder part."""
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	add_child(part)


static func _find_skeleton(root: Node) -> Skeleton3D:
	"""The first Skeleton3D under `root` (setup only)."""
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found.front() as Skeleton3D if not found.is_empty() else null


static func _find_player(root: Node) -> AnimationPlayer:
	"""The first AnimationPlayer under `root` (setup only)."""
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return found.front() as AnimationPlayer if not found.is_empty() else null
