extends Node3D
## The scene-side driver of the resident crowd: it resolves the mesh once, binds the readers once,
## and turns the clock's integer sub-tick debt into the render alpha every frame.
##
## ---------------------------------------------------------------------------------------
## WHY THE ALPHA IS THE CLOCK'S DEBT AND NOT A HOST FLOAT. `sim_clock.gd` accumulates host time as
## INTEGER debt units and one tick costs `TICK_COST` = 1000000 of them; a tick runs when the debt
## reaches that and the remainder stays. That remainder IS the renderer's position between the two
## committed ticks, exactly, as an integer fraction of an integer -- so `transforms.gd` gets
## `numerator/denominator` and no `float` is ever computed on this side of the boundary. Reading
## `debt()` cannot change it: the only writers are `_accumulate_debt()`, `_drain_ticks()` and the
## two explicit discard paths, all inside the clock.
##
## THE CLOCK OBJECT IS FETCHED EVERY FRAME AND THE MANAGER IS NOT. `GameManager.start_game()`
## REPLACES the SimClock instance, so a cached clock would silently become a previous run's. The
## autoload itself is resolved once in `_ready()`, so no `get_node()` runs in `_process`.
##
## ---------------------------------------------------------------------------------------
## ATTACHMENT IS AN EXPLICIT CALL, NOT A SIGNAL AND NOT A GUESS. Godot readies children before
## parents, so this node's `_ready()` runs BEFORE `main.gd` generates the settlement and there is
## nobody to draw yet. `main.gd` calls `attach()` once the cohort exists. CLAUDE.md: "Signal
## connections: UI updates only -- game logic uses direct system calls", and a renderer binding to
## a store is not a UI update.
##
## ---------------------------------------------------------------------------------------
## THIS NODE WRITES NOTHING INTO THE SIMULATION. It calls `residents.directory()` to build the
## scaffold's private pose store, and `refresh_into()` on the crowd. Every other call it makes is
## a read. See `resident_crowd.gd` and `resident_pose_scaffold.gd` for what each of those may and
## may not touch.

const IntMath := preload("res://scripts/core/int_math.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const ResidentCrowdScript := preload("res://scripts/presentation/resident_crowd.gd")
const PoseScaffoldScript := preload("res://scripts/presentation/resident_pose_scaffold.gd")

## Crowd doc 9.1's scale anchor: the reference model is a 1.0 m mouse, deliberately not biological.
## Only the FALLBACK box uses it; the shipped GLB is already normalised to that height.
const MOUSE_ANCHOR_HEIGHT_M: float = 1.0
const FALLBACK_BOX_SIZE: Vector3 = Vector3(0.4, MOUSE_ANCHOR_HEIGHT_M, 0.4)

const CROWD_MESH_PATH: String = "res://assets/units/species_mouse_body_a_lod0.glb"

## Which mesh the crowd is actually drawing, so a capture can never be read as the wrong asset.
const MESH_SOURCE_NONE: StringName = &"none"
const MESH_SOURCE_GLB: StringName = &"species_mouse_body_a_lod0.glb"
const MESH_SOURCE_FALLBACK: StringName = &"fallback_box"

const REFUSE_NONE: StringName = &""
const REFUSE_NO_CROWD: StringName = &"STAGE_NO_CROWD_CHILD"
const REFUSE_NO_RESIDENTS: StringName = &"STAGE_NO_RESIDENT_STORE"
const REFUSE_SCAFFOLD: StringName = &"STAGE_SCAFFOLD_REFUSED"
const REFUSE_BIND: StringName = &"STAGE_CROWD_BIND_REFUSED"

@onready var _crowd: ResidentCrowdScript = $ResidentCrowd as ResidentCrowdScript

var _time: GameManagerScript = null
var _scaffold: PoseScaffoldScript = null
var _mesh_source: StringName = MESH_SOURCE_NONE
var _attached: bool = false
var _last_refusal: StringName = REFUSE_NONE

## Caller-owned result, allocated once: `refresh_into()` fills it every frame and allocates nothing.
var _refresh_result: IntMath.IntResult = IntMath.IntResult.new()


func _ready() -> void:
	"""Resolve the autoload and the crowd child ONCE, and keep drawing while the game is paused."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	_time = GameManager as GameManagerScript
	if _crowd == null:
		_last_refusal = REFUSE_NO_CROWD
		push_error("ResidentStage has no ResidentCrowd child; residents will not be drawn.")


func attach(residents: ResidentsScript) -> bool:
	"""Bind the crowd to a live resident store and stand its cohort up. Called by `main.gd`.

	Refuses explicitly rather than leaving a half-bound crowd: an empty stage and a stage that
	failed to bind look identical on screen, and only one of them is a defect.
	"""
	if _crowd == null:
		return _refuse(REFUSE_NO_CROWD)
	if residents == null:
		return _refuse(REFUSE_NO_RESIDENTS)
	_scaffold = PoseScaffoldScript.new(residents)
	if not _scaffold.place_all():
		return _refuse(REFUSE_SCAFFOLD)
	if not _crowd.bind_stores(residents, _scaffold.transforms()):
		return _refuse(REFUSE_BIND)
	_crowd.set_crowd_mesh(_resolve_crowd_mesh())
	_attached = true
	_last_refusal = REFUSE_NONE
	return true


func detach() -> void:
	"""Drop the borrowed store and the scaffold without writing to either."""
	if _crowd != null:
		_crowd.unbind_stores()
	_scaffold = null
	_attached = false


func is_attached() -> bool:
	"""True while the crowd is bound to a resident store and drawing it."""
	return _attached


func _process(_delta: float) -> void:
	"""Redraw the crowd at the clock's current sub-tick position. Allocates nothing."""
	if not _attached:
		return
	_crowd.refresh_into(_alpha_numerator(), SimClockScript.TICK_COST, _refresh_result)


func _alpha_numerator() -> int:
	"""This frame's alpha numerator, read from the live clock. Zero when no clock is reachable."""
	if _time == null:
		return 0
	var clock: SimClockScript = _time.clock()
	if clock == null:
		return 0
	return alpha_numerator_of(clock.debt())


static func alpha_numerator_of(debt: int) -> int:
	"""Fold scheduler debt into a numerator over `TICK_COST`, in `0..TICK_COST`.

	A frame that is owed whole ticks it has not yet run holds debt above one tick; the remainder
	after those whole ticks is still the correct position between the last two committed ones.
	Negative debt is impossible -- `sim_clock.gd` refuses a negative elapsed time and never
	subtracts below zero -- but it is clamped rather than passed on, because a negative numerator
	would make `transforms.gd` refuse the whole frame over a number that cannot occur.
	"""
	if debt <= 0:
		return 0
	return debt % SimClockScript.TICK_COST


# --- the mesh ------------------------------------------------------------------------------------

func _resolve_crowd_mesh() -> Mesh:
	"""The authored crowd mesh, or an anchor-sized box when it cannot be loaded.

	A visible wrong-shaped resident beats an invisible correct one, but which one shipped must
	never be a guess: `mesh_source()` names it and the boot log prints it.
	"""
	var packed: PackedScene = load(CROWD_MESH_PATH) as PackedScene
	var mesh: Mesh = _mesh_from_packed(packed)
	if mesh != null:
		_mesh_source = MESH_SOURCE_GLB
		return mesh
	push_warning("Crowd mesh %s unusable; drawing the 1 m anchor box instead." % CROWD_MESH_PATH)
	_mesh_source = MESH_SOURCE_FALLBACK
	var box: BoxMesh = BoxMesh.new()
	box.size = FALLBACK_BOX_SIZE
	return box


func _mesh_from_packed(packed: PackedScene) -> Mesh:
	"""Extract the single surface mesh from an imported GLB, instancing it exactly once.

	One Node is created here and freed before returning. It happens at attach time, never in a
	frame: `_process()` touches no scene tree at all.
	"""
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	var found: MeshInstance3D = _first_mesh_instance(root)
	var mesh: Mesh = found.mesh if found != null else null
	root.free()
	return mesh


func _first_mesh_instance(node: Node) -> MeshInstance3D:
	"""Depth-first search for the first MeshInstance3D in an imported scene, or null."""
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _first_mesh_instance(child)
		if found != null:
			return found
	return null


# --- readers --------------------------------------------------------------------------------------

func crowd() -> ResidentCrowdScript:
	"""The MultiMesh crowd this stage drives, or null when the child is missing."""
	return _crowd


func scaffold() -> PoseScaffoldScript:
	"""The presentation-private pose scaffold; see its header for what it stands in for."""
	return _scaffold


func mesh_source() -> StringName:
	"""Which mesh the crowd drew with: the authored GLB, the fallback box, or none yet."""
	return _mesh_source


func drawn_count() -> int:
	"""Residents the crowd drew on the most recent frame. Zero when nothing is attached."""
	return 0 if _crowd == null else _crowd.drawn_count()


func last_refusal() -> StringName:
	"""Reason the most recent refused call refused; empty after a successful one."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false
