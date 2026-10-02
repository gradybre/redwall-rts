extends Node3D
## One demo resident on screen: its rigged body, its six clips on the body's own AnimationPlayer,
## its live tail, and the wandering brain that moves it. Decision 0196. Presentation only.
##
## ---------------------------------------------------------------------------------------
## THE CLIPS. Each clip file is staged STRIPPED to skeleton + animation (tools/stage_demo_assets.py).
## Its track paths (`Armature/Skeleton3D:<bone>`) resolve unchanged from the body scene's root, so the
## body's AnimationPlayer plays them all from one AnimationLibrary. Every clip loops but the dig swing (see CROUCHING
## AND STRIKING): the activities are held for whole loops (resident_brain.gd), so a loop always ends where the next
## begins.
##
## THE TAIL. `TailRig.attach()` needs the skeleton inside the tree (decision 0191), so it runs from
## `_ready()`. The mole and badger have no chain and are refused with REFUSE_NO_CHAIN -- expected,
## not an error. Nothing here may scale the body: the spring collides wrongly under a scaled skeleton
## (decisions 0192, 0194), and TailRig refuses one.
##
## THE LOAD. A carry trip holds a log between the hands: a bark-coloured cylinder laid from one hand
## to the other, placed on the skeleton's `skeleton_updated` so it sits on this frame's posed hands
## rather than last frame's. A trip carrying a HARVEST holds that item's own model instead (`hold()`,
## demo/farm/farm_carry_view.gd), centred between the hands and facing the way the carrier walks.
## A mole digging holds its pick (`set_tool()`) in its right hand; a resident felling a tree holds the
## woods' axe there (`set_work_tool()`, demo/forestry/) for as long as the work lasts. Presentation
## only; the brain decides when a trip carries, and the farm and the woods what.
##
## UNDERGROUND (demo/tunnel/; decision 0206). In a tunnel the actor stands on the bore floor (the brain's
## `ground_y_m`) on the UNDERGROUND render layer, so only the U view draws it; on the surface it is on
## the SURFACE layer, and a small cream MARKER on the level's floor (UNDERGROUND_MARKS) shows the U view
## where it stands. Going down or coming up rewrites its meshes' layers once (demo_layers.gd); a view
## switch touches nothing here -- no fade, no material. The tail's floor follows the ground it stands on.
##
## TIME. The cast steps each actor with the demo clock (demo_clock.gd): the brain by the frame's demo
## time, in sub-steps, and the AnimationPlayer at the clip's speed times the game's -- so a paused
## game holds every resident in its pose rather than walking in place, and 2x / 4x play faster.
##
## IN THE WATER (demo/waterplay/). The water clips -- swim, tread_water and, for the otters, dive --
## are authored against a waterline at the root (decision 0203), so a swimmer stands at the water's
## surface (the brain's `ground_y_m`). While the brain is `in_water` the tail is in water mode
## (`TailRig.set_water(true, back)`: pulled back along the body, not down) with its floor far below,
## and back on land it is pulled down again onto the ground it stands on. The back direction is
## refreshed only when the heading has turned WATER_TAIL_TURN_RAD.
##
## IN A BORE (decision 0207). A resident below stoops to clear its bore's drawn crown (cast/stoop_modifier.gd,
## tunnel_rules.gd `stoop_drop_u`): moles upright, mice a little, squirrels more, otters, the beaver and
## the badger as far as they can -- eased in and out over STOOP_EASE_S of demo time, so a paused game
## holds the pose. On a ramp the node pitches with the slope (the brain's `pitch`), so the feet meet it,
## and the spine leans half of that back into the slope.
##
## CROUCHING AND STRIKING (decision 0371, the underground revamp's P7; review F17). Where the bore makes a resident stoop
## (`stoop_target_m` at least CROUCH_FROM_M) its WALK plays as the staged crouch walk (Meshy 524
## `Cautious_Crouch_Walk_Forward`, decision 0204), at the pace the walk would have -- the ground speed the brain moves it
## at over the crouch's own recorded speed (the clip's stride_rate()) -- and the procedural stoop adds only what the
## crouch's own lowered head (the cast row's `crouch.head_drop_m`) leaves to clear. A mole, upright in every bore, walks.
## A carrier keeps its carry walk (the stoop bends it). A digger at an underground face with the staged swing (Meshy 128
## `Heavy_Hammer_Swing`, the mole digger and the badger quarryman) swings it ONCE PER STRIKE, not looped
## (strike_clock.gd: one swing a quantum cut, timed so its blow lands as the cut does), standing between swings and
## blended back out of each over BLEND_BACK_S. Neither changes the brain: what it moves, the actor only plays.
##
## IN A CUTTING (decision 0371; review F16). A tunnel's ramp is an open cutting down to where its bore goes under the
## ground (tunnel_mouth.gd): a resident walking it is drawn on the surface layer too, so the surface view sees it go down
## into the ground under the arch (or to a burrow home's door) rather than vanish at the mouth.
##
## ASLEEP (decision 0210). While the brain is `lying` the body is laid on the surface it names (`lie_top_y_m`: a
## mattress, a floor): with the staged sleep clip (Meshy's Sleep_Normally, staged as sleep_normally) the body is lifted
## so its LOWEST point -- the clip's own measure, tools/stage_demo_assets.py `sleep_row`, taken from its skinned
## vertices -- rests on it. Grounding seats a clip by its legs, so a lying torso would sink up to 19.5 cm into the
## mattress (decision 0204); this seats it by its body instead. With no sleep clip (the beaver, a placeholder) the body
## is laid back procedurally: tipped onto its back, head toward -Z, lifted by LIE_BACK_LIFT of its height. The tail's
## floor is the mattress. While the brain is `indoors` (asleep in the hall) nothing is drawn.
##
## FACING. The models face +Z, so the node's yaw is the brain's yaw: local +Z points along travel.
## With no staged cast (CI, a fresh clone), a capsule with a nose stands in, with the same brain.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const TailRigScript := preload("res://scripts/presentation/tail_rig.gd")
const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const StoopScript := preload("res://demo/cast/stoop_modifier.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const StrikeClockScript := preload("res://demo/cast/strike_clock.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const PeopleBook := preload("res://demo/people/people_book.gd")

const CROSSFADE_S: float = 0.25
const LIBRARY: StringName = &"cast"
const CLIPS: Array[StringName] = [&"idle", &"walk", &"collect_object", &"stand_and_drink", &"wave_one_hand",
	&"carry_heavy_object_walk", &"pull_radish", &"swim", &"tread_water", &"dive", &"sleep_normally",
	&"cautious_crouch_walk_forward", &"heavy_hammer_swing"]
## The crouch walk and the dig swing (see CROUCHING AND STRIKING): the walk crouches where the stoop is at least
## CROUCH_FROM_M; a swing blends back to the stance over BLEND_BACK_S. The swing plays once, never looped.
const CLIP_CROUCH: StringName = &"cautious_crouch_walk_forward"
const CLIP_SWING: StringName = &"heavy_hammer_swing"
const CROUCH_FROM_M: float = 0.05
const BLEND_BACK_S: float = 0.4
## The procedural lie-down (see ASLEEP): the body tipped back this far about its X axis (on its back, head toward
## -Z) and lifted by this share of its height (half a lying body's depth).
const LIE_BACK_RAD: float = -PI * 0.5
const LIE_BACK_LIFT: float = 0.14
const RADIUS_PER_HEIGHT: float = 0.22
const MIN_RADIUS_M: float = 0.2
const MAX_RADIUS_M: float = 0.6
const PLACEHOLDER_HEIGHT_M: float = 1.0
const PLACEHOLDER_WALK_SPEED_M_S: float = 0.8
## Every creature walks at WALK_PACE times the gait speed recorded on its walk clip, the clip played that
## much faster so the feet keep their ground (decision 0205: the playtest found everyone too slow).
const WALK_PACE: float = 1.4
const PLACEHOLDER_CLIP_S: float = 3.0
const LOAD_RADIUS_PER_HEIGHT: float = 0.055
const LOAD_OVERHANG_PER_HEIGHT: float = 0.12
const LOAD_COLOUR: Color = Color(0.36, 0.25, 0.16)
## A held harvest sits this far (per metre of height) before the hands' midpoint, out of the chest:
## the carry clip holds its hands wide, as round a log.
const HOLD_FORWARD_PER_HEIGHT: float = 0.07
## In the water, the tail's floor lies this far below the body, and its pull is re-aimed after a turn
## of this much.
const WATER_FLOOR_BELOW_M: float = 4.0
const WATER_TAIL_TURN_RAD: float = 0.15
## The stoop eases in (and out) over this much demo time (design §6: 0.3 s).
const STOOP_EASE_S: float = 0.3
## The spine takes back this share of a ramp's pitch (the body leans into the slope by the rest).
const LEAN_BACK_SHARE: float = 0.5
## The U view's marker for a resident on the surface: a cream disc in a dark edge, on the level's floor,
## drawn over the cap (no depth test), MARKER_RADIUS_M across.
const MARKER_RADIUS_M: float = 0.24
const MARKER_EDGE_M: float = 0.05
const MARKER_COLOUR: Color = Color(0.96, 0.91, 0.78)
const MARKER_EDGE_COLOUR: Color = Color(0.16, 0.12, 0.09)
const PLACEHOLDER_COLOURS: Array[Color] = [Color(0.72, 0.52, 0.36), Color(0.55, 0.62, 0.38),
	Color(0.47, 0.55, 0.7), Color(0.75, 0.66, 0.42), Color(0.62, 0.45, 0.58), Color(0.5, 0.5, 0.5)]

## Distinct chip colours for the demo party panel, one per cast slot (repeating past eight).
const CHIP_COLOURS: Array[Color] = [Color("#B76545"), Color("#466647"), Color("#4F6E8F"), Color("#D99743"),
	Color("#7E5A86"), Color("#8A8D84"), Color("#91613E"), Color("#3F7F7A")]

var brain: BrainScript = null
var creature_key: StringName = &""
## For the demo's select-and-command layer: its name, species, height (the picking capsule) and panel chip colour. The
## name is the person's own (demo/people/demo_people.json, decision 0491: "Wenna Tallowby"), or, for a key with no
## person (a placeholder), the key's label ("Placeholder 3"). Every surface names a resident through it.
var display_name: String = ""
var species: String = ""
var height_m: float = PLACEHOLDER_HEIGHT_M
var chip_colour: Color = CHIP_COLOURS[0]
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
## The model held in place of the log on a harvest carry (hidden unless holding), and its fit.
var _held: MeshInstance3D = null
var _held_fit: Transform3D = Transform3D.IDENTITY
var _holding: bool = false
## A tool in the right hand while the brain digs (the mole's pick), and its fit to the hand.
var _tool: MeshInstance3D = null
var _tool_fit: Transform3D = Transform3D.IDENTITY
## A work tool held while a job wants it (the woods' axe), whatever the brain's state.
var _work_tool: MeshInstance3D = null
var _work_tool_fit: Transform3D = Transform3D.IDENTITY
var _hand_bone: int = -1
var _hand_left: int = -1
var _hand_right: int = -1
var _skeleton_to_actor: Transform3D = Transform3D.IDENTITY
## The level the meshes were last put on (0 the surface, else the level underground; -1: not yet), and on which
## layer.
var _below: int = -1
var _layers: int = Layers.SURFACE
## The U view's marker for this resident on the levels it is not on (top level: placed in the world).
var _marker: Node3D = null
var _floor_y: float = 0.0
## The tail's water mode as last set, and the heading its pull was last aimed along.
var _tail_in_water: bool = false
var _tail_yaw: float = 0.0
## The stoop (null for a placeholder or another rig), how far into it the ease is (0..1) and the drop it
## eases toward (m).
var _stoop: StoopScript = null
var _stoop_ease: float = 0.0
var _stoop_drop: float = 0.0
## The sleep clip's lowest body point over the clip, from the ground it was seated on (m; negative: it sinks), and
## whether this creature lies by the clip or procedurally (see ASLEEP).
var _sleep_floor_m: float = 0.0
var _lies_by_clip: bool = false
## The crouch walk's recorded ground speed (m/s; 0: no crouch clip) and how much lower it carries the head than the
## walk (m); the swing's strikes (null: no swing clip). See CROUCHING AND STRIKING.
var _crouch_speed: float = 0.0
var _crouch_drop: float = 0.0
var _strike: StrikeClockScript = null
## Whether the body is drawn on the surface too, walking an open cutting (see IN A CUTTING).
var _in_cut: bool = false


func setup_creature(index: int, key: StringName, row: Dictionary, space: CastSpaceScript, seed_value: int) -> bool:
	"""Build a real creature from its manifest row. Returns false (and builds a placeholder, keeping
	the manifest key, its person's name and its species, and taking cast slot `index`'s colour) if its body cannot be
	loaded."""
	var body_path := String(row.get("body", ""))
	var scene: PackedScene = load(body_path) as PackedScene if ResourceLoader.exists(body_path) else null
	if scene == null:
		push_warning("demo cast: %s has no loadable body; using a placeholder" % key)
		setup_placeholder(index, space, seed_value)
		creature_key = key
		display_name = name_for(key)
		var kind: String = PeopleBook.species_of(key)
		if not kind.is_empty():
			species = kind.capitalize()
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
	_describe(index, key, String(row.get("species", key.split("_")[0])), height)
	_build_stoop(height)
	_make_brain(space, float(row.get("walk_speed_m_s", PLACEHOLDER_WALK_SPEED_M_S)), body_radius(height), seed_value, lengths)
	brain.set_carry_motion(motion)
	_read_sleep(row.get("sleep", {}), height)
	_read_crouch_and_dig(row)
	if brain.can_carry() and _skeleton != null:
		_build_load(height)
	return true


func _read_sleep(sleep: Dictionary, height: float) -> void:
	"""How this creature lies (see ASLEEP): the staged sleep clip's measure -- its lowest body point and the middle of
	its lying body -- or, with none, the procedural lie-down's (its middle half its height toward -Z)."""
	var centre: Array = sleep.get("centre_m", [])
	_lies_by_clip = brain.has_clip(BrainScript.CLIP_SLEEP) and centre.size() == 2
	if _lies_by_clip:
		_sleep_floor_m = float(sleep.get("floor_y_m", 0.0))
		brain.lie_middle_m = Vector2(float(centre[0]), float(centre[1]))
	else:
		brain.lie_middle_m = Vector2(0.0, -height * 0.5)


func _read_crouch_and_dig(row: Dictionary) -> void:
	"""The crouch walk's speed and head drop, and the swing's length and blow, from the cast row (see CROUCHING AND
	STRIKING; tools/stage_demo_assets.py `crouch_row`, `dig_row`) -- only for a clip that is staged."""
	var crouch: Dictionary = row.get("crouch", {})
	if brain.has_clip(CLIP_CROUCH) and float(crouch.get("speed_m_s", 0.0)) > ClipRootMotionScript.MIN_SPEED_M_S:
		_crouch_speed = float(crouch["speed_m_s"])
		_crouch_drop = float(crouch.get("head_drop_m", 0.0))
	var dig: Dictionary = row.get("dig", {})
	if brain.has_clip(CLIP_SWING):
		_strike = StrikeClockScript.new()
		_strike.swing_s = float(dig.get("length_s", _strike.swing_s))
		_strike.impact_s = float(dig.get("impact_s", _strike.impact_s))


func _notification(what: int) -> void:
	"""Freed: let the brain drop its jobs, which would otherwise keep their owners and this brain alive in a cycle
	(resident_brain.gd `drop_jobs`)."""
	if what == NOTIFICATION_PREDELETE and brain != null:
		brain.drop_jobs()


func _make_brain(space: CastSpaceScript, gait: float, radius: float, seed_value: int, lengths: Dictionary) -> void:
	"""The brain, walking at WALK_PACE times its walk clip's gait speed, the clip sped to match."""
	brain = BrainScript.new()
	brain.configure(space, gait * WALK_PACE, radius, seed_value, lengths)
	brain.set_gait_speed(gait)
	if _marker == null:
		_build_marker()


func setup_placeholder(index: int, space: CastSpaceScript, seed_value: int) -> void:
	"""A capsule with a nose on its +Z side, driven by the same brain at a nominal walk speed."""
	is_placeholder = true
	creature_key = StringName("placeholder_%d" % index)
	_describe(index, creature_key, "placeholder", PLACEHOLDER_HEIGHT_M)
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
		if clip != BrainScript.CLIP_SLEEP:
			lengths[clip] = PLACEHOLDER_CLIP_S
	_make_brain(space, PLACEHOLDER_WALK_SPEED_M_S, radius, seed_value, lengths)
	_read_sleep({}, PLACEHOLDER_HEIGHT_M)


func _describe(index: int, key: StringName, kind: String, height: float) -> void:
	"""The names, height and chip colour the command layer shows."""
	display_name = name_for(key)
	species = kind.capitalize()
	height_m = height
	chip_colour = CHIP_COLOURS[index % CHIP_COLOURS.size()]


static func friendly_name(key: StringName) -> String:
	"""`otter_boatwright` -> "Otter boatwright"; `placeholder_3` -> "Placeholder 3"."""
	var words := String(key).replace("_", " ").strip_edges()
	return words.left(1).to_upper() + words.substr(1)


static func name_for(key: StringName) -> String:
	"""A cast key's name: its person's (`mouse_keeper` -> "Wenna Tallowby"), else its label (`friendly_name`)."""
	var person: String = PeopleBook.name_of(key)
	return person if not person.is_empty() else friendly_name(key)


func role() -> String:
	"""This resident's trade, its role ("keeper"; "" for a placeholder)."""
	return PeopleBook.role_of(creature_key)


func name_with_role() -> String:
	"""'Wenna Tallowby (mouse keeper)' -- where the role helps; the name alone for a placeholder."""
	return PeopleBook.with_role(display_name, creature_key)


static func body_radius(height: float) -> float:
	"""The circle a creature of this height keeps clear around itself."""
	return clampf(height * RADIUS_PER_HEIGHT, MIN_RADIUS_M, MAX_RADIUS_M)


func place(at: Vector2, face_yaw: float, poi: int, slot: int) -> void:
	"""Stand at `at` (x, z) facing `face_yaw`, holding a POI slot (or -1, -1)."""
	brain.start_at(at, face_yaw, poi, slot)
	_apply_transform()
	_apply_clip(1)


func _ready() -> void:
	"""Inside the tree now: the tail can attach."""
	_attach_tail()


func advance(clock: DemoClockScript) -> void:
	"""Step the brain through this frame's demo time (none while paused) and draw where it says, the
	clip playing at the game's speed (see TIME)."""
	if brain == null:
		return
	for k in clock.steps():
		brain.step(clock.step_s(k))
	_apply_transform()
	_step_strike(clock.delta_s())
	ease_stoop(clock.delta_s())
	_apply_clip(clock.speed)
	if _skeleton == null and (_held != null or _tool != null or _work_tool != null):
		_place_load()


func _apply_transform() -> void:
	"""Stand on the ground -- or a bore's floor -- at the brain's position; local +Z along its yaw. Lying, laid on
	what it lies on (see ASLEEP)."""
	position.x = brain.position.x
	position.y = lie_y() if brain.lying else brain.ground_y_m
	position.z = brain.position.y
	rotation.y = brain.yaw
	rotation.x = LIE_BACK_RAD if brain.lying and not _lies_by_clip else brain.pitch
	visible = not brain.indoors
	_apply_view()
	if _tail == null:
		return
	if brain.in_water != _tail_in_water or (brain.in_water and absf(angle_difference(_tail_yaw, brain.yaw)) > WATER_TAIL_TURN_RAD):
		_apply_tail_water()
	var floor_y: float = brain.lie_top_y_m if brain.lying else brain.ground_y_m - (WATER_FLOOR_BELOW_M if brain.in_water else 0.0)
	if floor_y != _floor_y:
		_floor_y = floor_y
		_tail.set_floor(_floor_y)


func lie_y() -> float:
	"""Where the body's root stands while it lies (see ASLEEP): its lowest point on the mattress by the clip's measure,
	or the procedural lie-down's lift."""
	if _lies_by_clip:
		return brain.lie_top_y_m - _sleep_floor_m
	return brain.lie_top_y_m + height_m * LIE_BACK_LIFT


func lies_by_clip() -> bool:
	"""Whether this creature lies down by its staged sleep clip (else procedurally; checks)."""
	return _lies_by_clip


# --- the stoop ------------------------------------------------------------------------------

func _build_stoop(height: float) -> void:
	"""The stoop modifier, first on the skeleton (after the clip, before the tail's spring); none when the
	rig lacks the bones it bends."""
	if _skeleton == null:
		return
	var modifier := StoopScript.new()
	modifier.name = &"Stoop"
	if not modifier.setup(_skeleton, _relative_transform(_skeleton).basis, height):
		modifier.free()
		return
	_skeleton.add_child(modifier)
	_skeleton.move_child(modifier, 0)
	_stoop = modifier


func stoop_target_m() -> float:
	"""How far this resident lowers its head where it is now (m): its drop in the bore it is in, none on
	the surface (see IN A BORE)."""
	var bore := brain.bore_class() if brain != null else -1
	if bore < 0:
		return 0.0
	return TunnelRules.to_m(TunnelRules.stoop_drop_u(TunnelRules.to_u(height_m), TunnelRules.BORE_CROWNS_U[bore]))


func ease_stoop(delta_s: float) -> void:
	"""Ease the stoop toward where the resident is, over STOOP_EASE_S of demo time, and lean into a ramp."""
	var target := stoop_target_m()
	if _playing == CLIP_CROUCH:
		target = maxf(target - _crouch_drop, 0.0)
	if target > 0.0:
		_stoop_drop = target
	_stoop_ease = move_toward(_stoop_ease, 1.0 if target > 0.0 else 0.0, delta_s / STOOP_EASE_S)
	if _stoop != null:
		_stoop.set_pose(_stoop_drop * smoothstep(0.0, 1.0, _stoop_ease), -brain.pitch * LEAN_BACK_SHARE)


func stoop_now_m() -> float:
	"""How far the head is lowered now (m; checks)."""
	return _stoop_drop * smoothstep(0.0, 1.0, _stoop_ease)


func stoop() -> StoopScript:
	"""The stoop modifier (null when the rig has none; checks)."""
	return _stoop


func _apply_tail_water() -> void:
	"""The tail in or out of water mode, pulled back along the body's heading (see IN THE WATER)."""
	_tail_in_water = brain.in_water
	_tail_yaw = brain.yaw
	_tail.set_water(_tail_in_water, Vector3(-sin(brain.yaw), 0.0, -cos(brain.yaw)))


func tail_in_water() -> bool:
	"""Whether the live tail is in water mode now (checks)."""
	return _tail_in_water


func _apply_view() -> void:
	"""On the surface layer above ground, its level's underground layer in a bore (see UNDERGROUND; decision 0212:
	demo_layers.gd `body_mask`): rewritten only when that changes -- a layers write, never a fade or a material.
	The marker shows in the U view of every level the resident is not on (`marker_mask`), on the floor of the level
	shown, under the resident."""
	var level := brain.view_level()
	var in_cut := _walks_a_cutting()
	if level != _below or in_cut != _in_cut:
		_below = level
		_in_cut = in_cut
		_layers = Layers.body_mask(level) | (Layers.SURFACE if in_cut else 0)
		Layers.set_layers(self, _layers, _marker)
		if _marker != null:
			Layers.set_layers(_marker, Layers.marker_mask(level))
	if _marker != null:
		_marker.visible = not brain.indoors
		_marker.position = Vector3(brain.position.x, Layers.view_floor_y() + Layers.MARK_LIFT_M, brain.position.y)


func _walks_a_cutting() -> bool:
	"""Whether the resident walks an open cutting now (see IN A CUTTING): on the surface its bore is none."""
	var space := brain.space()
	return MouthScript.in_open_cutting(space.tunnels, space.resident_tunnel[brain.index], space.resident_along[brain.index])


func layers_now() -> int:
	"""The render layer this resident's body is on (checks)."""
	return _layers


func marker() -> Node3D:
	"""The U view's marker for this resident (null before setup; checks)."""
	return _marker


# --- the U view's marker ----------------------------------------------------------------------

static var _marker_mesh: CylinderMesh = null
static var _marker_materials: Array[StandardMaterial3D] = []


static func marker_mesh() -> CylinderMesh:
	"""The marker's unit disc (radius 1, flat), shared."""
	if _marker_mesh == null:
		_marker_mesh = CylinderMesh.new()
		_marker_mesh.top_radius = 1.0
		_marker_mesh.bottom_radius = 1.0
		_marker_mesh.height = 0.01
		_marker_mesh.radial_segments = 24
		_marker_mesh.rings = 1
	return _marker_mesh


static func marker_materials() -> Array[StandardMaterial3D]:
	"""The marker's two materials, shared: its dark edge, then its cream face drawn over it."""
	if _marker_materials.is_empty():
		for k: int in 2:
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = MARKER_EDGE_COLOUR if k == 0 else MARKER_COLOUR
			material.no_depth_test = true
			material.render_priority = 5 + k
			_marker_materials.append(material)
	return _marker_materials


static func register_marker(prewarm: PrewarmScript) -> void:
	"""What the marker draws, for the underground view's prewarm."""
	for material: StandardMaterial3D in marker_materials():
		prewarm.add_mesh(marker_mesh(), material)


func _build_marker() -> void:
	"""The marker: an edge disc and a face disc over it, on UNDERGROUND_MARKS, placed in the world."""
	_marker = Node3D.new()
	_marker.name = &"Marker"
	_marker.top_level = true
	for k: int in 2:
		var disc := MeshInstance3D.new()
		disc.mesh = marker_mesh()
		disc.material_override = marker_materials()[k]
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.layers = Layers.marker_mask(Rules.LEVEL_SURFACE)
		var radius: float = MARKER_RADIUS_M + (MARKER_EDGE_M if k == 0 else 0.0)
		disc.scale = Vector3(radius, 1.0, radius)
		_marker.add_child(disc)
	add_child(_marker)


func _adopt(part: VisualInstance3D) -> void:
	"""A part made after setup (a held good, a tool) goes on the layer the body is on now."""
	part.layers = _layers


func _apply_clip(game_speed: int) -> void:
	"""Crossfade to the clip to play when it changes (see CROUCHING AND STRIKING: the brain's, else the crouch or the
	swing in its place); follow its playback speed times the game's every frame (0 while paused: a frozen pose)."""
	if _player == null:
		return
	var want := played_clip()
	_player.speed_scale = played_rate(want) * float(game_speed)
	if want == _playing:
		return
	var blend := BLEND_BACK_S if _playing == CLIP_SWING else CROSSFADE_S
	_playing = want
	var full: StringName = _library_names.get(_playing, &"")
	if full != &"":
		_player.play(full, blend)


func played_clip() -> StringName:
	"""The clip to play now (see CROUCHING AND STRIKING)."""
	var striking := _striking()
	return choose_clip(brain.clip, striking, striking and _strike.swinging(), crouches())


static func choose_clip(brain_clip: StringName, striking: bool, swinging: bool, crouching: bool) -> StringName:
	"""The clip to play for the brain's `brain_clip`: at a face, the swing while one plays and the stance between; a
	walk where the resident crouches, the crouch walk; else the brain's own."""
	if striking:
		return CLIP_SWING if swinging else BrainScript.CLIP_IDLE
	if brain_clip == BrainScript.CLIP_WALK and crouching:
		return CLIP_CROUCH
	return brain_clip


func played_rate(clip: StringName) -> float:
	"""How fast `clip` plays before the game's speed: the crouch at the walk's ground speed over its own, a swing and
	the stance between at their own pace, else the brain's."""
	if clip == CLIP_CROUCH:
		return crouch_rate(brain.walk_speed, brain.clip_speed, brain.gait_rate(), _crouch_speed)
	if _striking():
		return 1.0
	return brain.clip_speed


static func crouch_rate(walk_speed: float, clip_speed: float, gait_rate: float, crouch_speed: float) -> float:
	"""The crouch walk's rate for a walk played at `clip_speed`: the walk clip plays at `gait_rate` (walk_speed over its
	gait speed: the brain's stride_rate()) times the bore's and slope's factor, so the ground speed is walk_speed times
	clip_speed over gait_rate -- and the crouch, recorded at `crouch_speed`, plays at that over it."""
	return walk_speed * clip_speed / maxf(gait_rate, 1e-4) / maxf(crouch_speed, 1e-4)


func crouches() -> bool:
	"""Whether this resident crouch-walks where it is: it has the crouch, and the bore makes it stoop."""
	return _crouch_speed > 0.0 and stoop_target_m() >= CROUCH_FROM_M


func _striking() -> bool:
	"""Whether this resident strikes at an underground face now (see CROUCHING AND STRIKING)."""
	return _strike != null and brain.state == BrainScript.State.DIG and brain.underground and brain.dig_tunnel >= 0


func _step_strike(delta_s: float) -> void:
	"""The strikes' clock on with the dig's cuts (forgotten off the face); a new swing restarts the clip."""
	if _strike == null:
		return
	if not _striking():
		_strike.reset()
		return
	if _strike.step(brain.space().tunnels.cut_count(brain.dig_tunnel), delta_s) and _playing == CLIP_SWING:
		_player.stop()
		_playing = &""


func strikes() -> StrikeClockScript:
	"""The swing's strikes (null without the swing clip; checks)."""
	return _strike


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
	_adopt(_load)
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
	"""Lay the log from hand to hand on this frame's pose, overhanging each hand a little -- or hold the
	harvest there. It shows only once the crossfade into the carry is over, so it never spans hands
	still swinging into place. (A placeholder, with no hands, holds before its chest.)"""
	_place_tool()
	var posed: bool = brain.clip == BrainScript.CLIP_CARRY and brain.clip_time() >= CROSSFADE_S
	var carrying: bool = brain.carrying and (is_placeholder or posed)
	if _held != null:
		_held.visible = carrying and _holding
	if _load != null:
		_load.visible = carrying and not _holding
	if not carrying or _skeleton == null or _hand_left < 0 or (_load == null and not _holding):
		return
	var left := _skeleton_to_actor * _skeleton.get_bone_global_pose(_hand_left).origin
	var right := _skeleton_to_actor * _skeleton.get_bone_global_pose(_hand_right).origin
	if _holding:
		var ahead := Vector3(0.0, 0.0, height_m * HOLD_FORWARD_PER_HEIGHT)
		_held.transform = Transform3D(Basis.IDENTITY, (left + right) * 0.5 + ahead) * _held_fit
		return
	var across := right - left
	var span := maxf(across.length(), 1e-3)
	var axis := across / span
	var side := Vector3.UP.cross(axis).normalized()
	_load.transform = Transform3D(Basis(axis.cross(side), axis * (span + _load_length), side), (left + right) * 0.5)


# --- held goods and tools --------------------------------------------------------------------

func hold(mesh: Mesh, fit: Transform3D) -> void:
	"""Carry this model between the hands on the carry walk, in place of the log (`fit` centres it on
	the hands' midpoint at its drawn size). A placeholder holds it before its chest."""
	if _held == null:
		_held = MeshInstance3D.new()
		_held.name = &"Held"
		_adopt(_held)
		add_child(_held)
		_listen_to_pose()
	_held.mesh = mesh
	_held_fit = fit
	_holding = true
	_held.visible = is_placeholder and brain.carrying
	if is_placeholder:
		_held.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, height_m * 0.55, body_radius(height_m) + 0.12)) * fit


func drop_held() -> void:
	"""Stop holding (the log comes back for an ordinary carry)."""
	_holding = false
	if _held != null:
		_held.visible = false


func holding() -> bool:
	"""Whether a model is held in place of the log."""
	return _holding


func held_mesh() -> Mesh:
	"""The held model's mesh (null: none; tests and the scripted check)."""
	return _held.mesh if _held != null and _holding else null


func set_tool(mesh: Mesh, fit: Transform3D) -> void:
	"""Hold this tool in the right hand while the brain digs (`fit`: the tool in the hand bone's frame)."""
	if _tool == null:
		_tool = MeshInstance3D.new()
		_tool.name = &"Tool"
		_tool.visible = false
		_adopt(_tool)
		add_child(_tool)
		_listen_to_pose()
	_tool.mesh = mesh
	_tool_fit = fit
	if _skeleton != null:
		_hand_bone = _skeleton.find_bone("RightHand")


func set_work_tool(mesh: Mesh, fit: Transform3D) -> void:
	"""Hold this tool in the right hand from now until `clear_work_tool()` (`fit`: in the hand bone's
	frame) -- the woods' axe while felling."""
	if _work_tool == null:
		_work_tool = MeshInstance3D.new()
		_work_tool.name = &"WorkTool"
		_adopt(_work_tool)
		add_child(_work_tool)
		_listen_to_pose()
	_work_tool.mesh = mesh
	_work_tool_fit = fit
	_work_tool.visible = true
	if _skeleton != null and _hand_bone < 0:
		_hand_bone = _skeleton.find_bone("RightHand")
	if _skeleton == null:
		_place_tool()


func clear_work_tool() -> void:
	"""Put the work tool away."""
	if _work_tool != null:
		_work_tool.visible = false


func work_tool_shown() -> bool:
	"""Whether a work tool is held now (tests and the scripted check)."""
	return _work_tool != null and _work_tool.visible


func tool_shown() -> bool:
	"""Whether the tool shows now (tests and the scripted check)."""
	return _tool != null and _tool.visible


func _place_tool() -> void:
	"""The tool in the right hand on this frame's pose, while digging; hidden otherwise. A work tool
	held for a job goes in the same hand."""
	if _work_tool != null and _work_tool.visible:
		_work_tool.transform = _in_right_hand(_work_tool_fit)
	if _tool == null:
		return
	_tool.visible = brain.state == BrainScript.State.DIG and (_hand_bone >= 0 or is_placeholder)
	if not _tool.visible:
		return
	_tool.transform = _in_right_hand(_tool_fit)


func _in_right_hand(fit: Transform3D) -> Transform3D:
	"""`fit` in the right hand bone's frame on this frame's pose, as the actor's local transform; a
	placeholder holds it at its side."""
	if _hand_bone >= 0 and _skeleton != null:
		return _skeleton_to_actor * _skeleton.get_bone_global_pose(_hand_bone) * fit
	return Transform3D(Basis.IDENTITY, Vector3(body_radius(height_m), height_m * 0.5, 0.2)) * fit


func _listen_to_pose() -> void:
	"""Place held things on every posed frame (a placeholder: every advance)."""
	if _skeleton == null:
		return
	_skeleton_to_actor = _relative_transform(_skeleton)
	if _hand_left < 0:
		_hand_left = _skeleton.find_bone("LeftHand")
		_hand_right = _skeleton.find_bone("RightHand")
	if not _skeleton.skeleton_updated.is_connected(_place_load):
		_skeleton.skeleton_updated.connect(_place_load)


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
			animation.loop_mode = Animation.LOOP_NONE if clip == CLIP_SWING else Animation.LOOP_LINEAR
			library.add_animation(clip, animation)
			lengths[clip] = animation.length
			_library_names[clip] = StringName("%s/%s" % [LIBRARY, clip])
			if clip == BrainScript.CLIP_CARRY and _skeleton != null and _find_skeleton(holder) != null:
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
