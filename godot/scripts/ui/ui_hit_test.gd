extends RefCounted
## SET-UX-001 §1.2's world click-through rule, as a table a test can interrogate.
##
## §1.2: "World click-through rectangle is the viewport minus the ACTUAL VISIBLE INPUT
## RECTANGLES. A transparent full-screen Control must not block the center. Full-screen HUD
## roots and decorative graphics use MOUSE_FILTER_IGNORE; interactive controls consume
## `_gui_input` events. World commands use `_unhandled_input`, after UI handling. Visual z-order
## alone is insufficient to define interaction priority."
##
## Godot enforces the second half of that on its own -- an IGNORE control really does let the
## event through -- but nothing in the engine enforces the FIRST half, that a region which
## merely looks like a panel must not be registered as an input rectangle. That is a decision
## made control by control, and it is exactly the decision 04.4 says must not be got wrong:
## "Decorative UI must not consume world clicks."
##
## So the shell registers every region it draws HERE, each with an explicit `consumes` flag, and
## `world_receives()` answers the §1.2 question directly. A decorative region registered with
## `consumes = false` can never consume a point, whatever its rectangle, its layer or its
## registration order: `_consuming_region_at()` skips it before any geometry is compared.
## `test_ui_hit_test.gd` drives a full-screen decorative region over the whole viewport and
## asserts that a thousand world points still reach the world, which is UX-T04's own criterion.
##
## ---------------------------------------------------------------------------------------
## LAYERS COME FROM §3, NOT FROM DRAW ORDER. §3's table assigns explicit layers: 0 world, 10
## world overlays, 20 permanent HUD, 30 expansions, 40 workspaces, 50 quick menu, 60 tooltip,
## 80 modal, 90 victory/collapse, 100 announcer. A point inside two consuming regions belongs to
## the higher layer; equal layers are resolved by registration order, later last. The tooltip
## layer is registered non-consuming because §4 says UI-SET-073 is "IGNORE", and the announcer
## because §3 says it is "semantic and not a click block".
##
## The columns are sized once in `_init()` and never resized: `reset()` moves a count, it does
## not free memory, so rebuilding the region table every layout pass allocates nothing.

const IntMath := preload("res://scripts/core/int_math.gd")

# --- §3 layers --------------------------------------------------------------------------------

const LAYER_WORLD: int = 0
const LAYER_WORLD_OVERLAY: int = 10
const LAYER_PERMANENT_HUD: int = 20
const LAYER_EXPANSION: int = 30
const LAYER_WORKSPACE: int = 40
const LAYER_QUICK_MENU: int = 50
const LAYER_TOOLTIP: int = 60
const LAYER_MODAL: int = 80
const LAYER_END_STATE: int = 90
const LAYER_ANNOUNCER: int = 100

## §3's ten layers in ascending order, for validation and for the suite to walk.
const LAYERS: Array[int] = [
	LAYER_WORLD, LAYER_WORLD_OVERLAY, LAYER_PERMANENT_HUD, LAYER_EXPANSION, LAYER_WORKSPACE,
	LAYER_QUICK_MENU, LAYER_TOOLTIP, LAYER_MODAL, LAYER_END_STATE, LAYER_ANNOUNCER,
]

## Regions the table can hold at once. The shell registers one per visible element, and §4
## defines 103 elements in total, so this cannot be reached by a correct caller.
const REGION_CAPACITY: int = 256

const REFUSE_NONE: StringName = &""
const REFUSE_TABLE_FULL: StringName = &"UI_HIT_TABLE_FULL"
const REFUSE_UNKNOWN_LAYER: StringName = &"UI_UNKNOWN_HIT_LAYER"
const REFUSE_NEGATIVE_SIZE: StringName = &"UI_NEGATIVE_REGION_SIZE"
const REFUSE_NO_REGION: StringName = &"UI_NO_REGION_AT_POINT"
const REFUSE_INVALID_INDEX: StringName = &"UI_INVALID_REGION_INDEX"
const REFUSE_ELEMENT_ABSENT: StringName = &"UI_ELEMENT_HAS_NO_CONTROL"

## No SCRIM is up. §3 gives the scrim to layer 80 and above; layer 0 is the world, which cannot
## be a scrim, so this is not an in-band value.
const NO_SCRIM: int = -1

# --- packed region columns ----------------------------------------------------------------------

var _element_id: PackedInt32Array = PackedInt32Array()
var _layer: PackedInt32Array = PackedInt32Array()
var _consumes: PackedByteArray = PackedByteArray()
var _x: PackedFloat32Array = PackedFloat32Array()
var _y: PackedFloat32Array = PackedFloat32Array()
var _width: PackedFloat32Array = PackedFloat32Array()
var _height: PackedFloat32Array = PackedFloat32Array()

var _count: int = 0
var _last_refusal: StringName = REFUSE_NONE
## The layer of the open SCRIM, or NO_SCRIM. §3 layer 80: "SCRIM blocks background".
var _scrim_layer: int = NO_SCRIM


func _init() -> void:
	"""Size every region column once. Nothing after this point resizes one."""
	_element_id.resize(REGION_CAPACITY)
	_layer.resize(REGION_CAPACITY)
	_consumes.resize(REGION_CAPACITY)
	_x.resize(REGION_CAPACITY)
	_y.resize(REGION_CAPACITY)
	_width.resize(REGION_CAPACITY)
	_height.resize(REGION_CAPACITY)
	reset()


func reset() -> void:
	"""Drop every registered region and lower any scrim, without freeing a column."""
	_count = 0
	_scrim_layer = NO_SCRIM
	_last_refusal = REFUSE_NONE


static func is_layer(layer: int) -> bool:
	"""True for one of §3's ten explicit layers."""
	return LAYERS.has(layer)


func add_region(element_id: int, rect: Rect2, layer: int, consumes: bool) -> bool:
	"""Register one drawn region. `consumes` is §1.2's actual-visible-input-rectangle flag.

	A decorative region -- a full-screen HUD root, a shadow, a label that is not a control --
	registers with `consumes = false` and can never take a point away from the world.
	"""
	if _count >= REGION_CAPACITY:
		return _refuse(REFUSE_TABLE_FULL)
	if not is_layer(layer):
		return _refuse(REFUSE_UNKNOWN_LAYER)
	if rect.size.x < 0.0 or rect.size.y < 0.0:
		return _refuse(REFUSE_NEGATIVE_SIZE)
	_element_id[_count] = element_id
	_layer[_count] = layer
	_consumes[_count] = 1 if consumes else 0
	_x[_count] = rect.position.x
	_y[_count] = rect.position.y
	_width[_count] = rect.size.x
	_height[_count] = rect.size.y
	_count += 1
	_last_refusal = REFUSE_NONE
	return true


func _contains(index: int, point: Vector2) -> bool:
	"""True when a registered region's half-open rectangle contains `point`."""
	return point.x >= _x[index] and point.x < _x[index] + _width[index] \
		and point.y >= _y[index] and point.y < _y[index] + _height[index]


func _consuming_region_at(point: Vector2) -> int:
	"""Index of the topmost CONSUMING region under `point`, or -1 when the world gets it.

	The `-1` never leaves this file: every public caller turns it into an explicit boolean or a
	refusal, so no caller can mistake it for an element id.
	"""
	var best: int = -1
	for index: int in _count:
		if _consumes[index] == 0:
			continue
		if _layer[index] < _scrim_layer:
			continue
		if not _contains(index, point):
			continue
		if best == -1 or _layer[index] >= _layer[best]:
			best = index
	return best


func consumes_point(point: Vector2) -> bool:
	"""True when a visible interactive rectangle owns this point, so the world must not see it."""
	return _consuming_region_at(point) != -1


func world_receives(point: Vector2) -> bool:
	"""§1.2's click-through question: does this point reach the 3D world?

	False everywhere while a SCRIM is up. §3 gives layer 80 "SCRIM blocks background" and
	REQ-UX-003 forbids background selection or construction changes while a modal is open, so a
	click on bare world next to an open dialog is a click on the scrim, not an order.
	"""
	if _scrim_layer != NO_SCRIM:
		return false
	return _consuming_region_at(point) == -1


func raise_scrim(layer: int) -> bool:
	"""Put §3's SCRIM up at one layer. Every region below it stops receiving points."""
	if not is_layer(layer):
		return _refuse(REFUSE_UNKNOWN_LAYER)
	_scrim_layer = layer
	_last_refusal = REFUSE_NONE
	return true


func lower_scrim() -> void:
	"""Take the SCRIM down. The background becomes clickable again in the same layer order."""
	_scrim_layer = NO_SCRIM


func scrim_is_up() -> bool:
	"""True while a modal SCRIM is blocking the background."""
	return _scrim_layer != NO_SCRIM


func add_visible_region(element_id: int, rect: Rect2, layer: int, consumes: bool,
		creates_control: bool) -> bool:
	"""Register a region only for an element that has a Control, refusing when it has none.

	The refusal is the point. §4's Gate is evaluated before availability, and an element whose
	gate is unsatisfied has no Control at all -- so it must not be able to acquire an input
	rectangle by a caller that forgot, any more than it could acquire a tab stop. A hidden panel
	that still eats world clicks is the exact failure §1.2 calls "actual visible input
	rectangles" to prevent.
	"""
	if not creates_control:
		return _refuse(REFUSE_ELEMENT_ABSENT)
	return add_region(element_id, rect, layer, consumes)


func element_at(point: Vector2) -> IntMath.IntResult:
	"""The §4 element id that owns this point, or an explicit NO_REGION refusal.

	Refuses rather than returning 0 or -1: "no element here" is a different answer from "element
	number zero", and §4 has no element zero to confuse it with.
	"""
	var index: int = _consuming_region_at(point)
	if index == -1:
		_refuse(REFUSE_NO_REGION)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, _element_id[index])


func layer_at(point: Vector2) -> IntMath.IntResult:
	"""The §3 layer that owns this point, or an explicit NO_REGION refusal."""
	var index: int = _consuming_region_at(point)
	if index == -1:
		_refuse(REFUSE_NO_REGION)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, _layer[index])


func region_count() -> int:
	"""How many regions are registered, decorative ones included."""
	return _count


func consuming_count() -> int:
	"""How many registered regions are actual visible input rectangles."""
	var total: int = 0
	for index: int in _count:
		if _consumes[index] == 1:
			total += 1
	return total


func region_consumes(index: int) -> bool:
	"""Whether the region at a registration index consumes input. Refuses an invalid index."""
	if index < 0 or index >= _count:
		_refuse(REFUSE_INVALID_INDEX)
		return false
	_last_refusal = REFUSE_NONE
	return _consumes[index] == 1


func region_rect(index: int) -> Rect2:
	"""The registered rectangle at an index, or an empty Rect2 after an INVALID_INDEX refusal."""
	if index < 0 or index >= _count:
		_refuse(REFUSE_INVALID_INDEX)
		return Rect2()
	_last_refusal = REFUSE_NONE
	return Rect2(_x[index], _y[index], _width[index], _height[index])


func capacity() -> int:
	"""Regions the table can hold. Fixed at construction."""
	return REGION_CAPACITY


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
