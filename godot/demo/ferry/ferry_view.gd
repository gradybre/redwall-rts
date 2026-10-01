extends Node3D
## The ferry's drawing (decision 0437): its two stages (the staged jetty model, as the boathouse jetty is drawn), the
## wood stacked at each stage, the wood aboard the ferry boat, the far copse's windfall piles and a load set down where
## its carrier was called away. The boat itself is the boat core's (boat_view.gd), and a carrier walks with the carry
## clip's own log. Presentation only: it reads ferry.gd and writes nothing. Every node is made once; a frame only moves,
## shows or hides them (no allocation per frame), and only when the ferry's revision moved.

const FerryScript := preload("res://demo/ferry/ferry.gd")
const Rules := preload("res://demo/ferry/ferry_rules.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const JETTY_KEY: StringName = &"jetty"
const LOG_KEY: StringName = &"bridge_log"
## A windfall pile: a short stock log, smaller with less wood (the woods' own deadfall is a world piece; this is a
## props-table model, drawn without the world).
const PILE_KEY: StringName = &"bridge_log"
## The jetty model's base below the datum (water_dressing.gd's boathouse jetty: its deck 0.22 m above the water).
const JETTY_BASE_Y_M: float = -1.29
## Logs drawn on a stack (one a unit, at most), aboard, and set-down loads.
const STACK_LOGS: int = 6
const ABOARD_LOGS: int = 4
const LOAD_POOL: int = 3
## A windfall pile is drawn at this share of the stock log, bigger with more wood.
const PILE_SHARE_MIN: float = 0.8
const PILE_SHARE_MAX: float = 1.15
const MILLI_PER_U: int = 1000

var _ferry: FerryScript = null
var _props: PropsScript = null
var _stacks: Array[Array] = [[], []]
var _aboard: Array[MeshInstance3D] = []
var _piles: Array[MeshInstance3D] = []
var _loads: Array[MeshInstance3D] = []
var _seen: int = -1
var _boat_seen: Vector2 = Vector2.INF


func configure(ferry: FerryScript, props: PropsScript) -> void:
	"""Draw `ferry` with `props`' models (a fresh, unstaged table when none)."""
	name = "FerryView"
	_ferry = ferry
	_props = props if props != null else PropsScript.new()
	for stage: int in 2:
		_add_jetty(FerryScript.STAGE_JETTY[stage])
		for k: int in STACK_LOGS:
			_stacks[stage].append(_hidden(LOG_KEY))
	for k: int in ABOARD_LOGS:
		_aboard.append(_hidden(LOG_KEY))
	for k: int in Rules.COPSE_SPOTS.size():
		_piles.append(_hidden(PILE_KEY))
	for k: int in LOAD_POOL:
		_loads.append(_hidden(LOG_KEY))
	refresh()


func _add_jetty(jetty: int) -> void:
	"""A stage's jetty: the model halfway between its land end and its deck end, running out over the water."""
	var land: Vector2 = Routes.jetty_land_m(jetty)
	var out: Vector2 = Routes.jetty_end_m(jetty) - land
	var mid: Vector2 = land + out * 0.5
	var piece: MeshInstance3D = _props.instance(JETTY_KEY)
	piece.name = "Ferry_%s" % Routes.JETTY_NAMES[jetty].replace(" ", "_")
	piece.transform = Transform3D(Basis(Vector3.UP, atan2(-out.y, out.x)), Vector3(mid.x, JETTY_BASE_Y_M, mid.y)) \
		* _props.fit_of(JETTY_KEY)
	add_child(piece)


func _hidden(key: StringName) -> MeshInstance3D:
	"""One pooled model, hidden until wanted."""
	var piece: MeshInstance3D = _props.instance(key)
	piece.visible = false
	add_child(piece)
	return piece


func refresh() -> void:
	"""Follow the ferry: its stacks, the cargo aboard (it moves with the boat), the copse and set-down loads."""
	if _ferry == null:
		return
	var boat_at: Vector2 = _ferry.fleet.position_m(Routes.FERRY_BOAT) if _ferry.fleet != null else Vector2.ZERO
	if _ferry.revision == _seen and boat_at == _boat_seen:
		return
	_seen = _ferry.revision
	_boat_seen = boat_at
	_draw_stack(FerryScript.NEAR, _ferry.near_stack_milli)
	_draw_stack(FerryScript.FAR, _ferry.far_stack_milli)
	_draw_aboard(boat_at)
	_draw_piles()
	_draw_loads()


func _draw_stack(stage: int, milli: int) -> void:
	"""A stage's stack: a log a unit (rounded up), two to a layer."""
	var at: Vector2 = _ferry.stack_at(stage)
	var logs: Array = _stacks[stage]
	@warning_ignore("integer_division") var shown: int = mini((milli + MILLI_PER_U - 1) / MILLI_PER_U, STACK_LOGS)
	for k: int in logs.size():
		var piece: MeshInstance3D = logs[k]
		piece.visible = k < shown
		if k < shown:
			@warning_ignore("integer_division") var layer: int = k / 2
			var offset := Vector3(0.0, 0.12 + 0.16 * float(layer), (float(k % 2) - 0.5) * 0.22)
			piece.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y) + offset) * _props.fit_of(LOG_KEY)


func _draw_aboard(boat_at: Vector2) -> void:
	"""The wood aboard, laid along the hull between the seats."""
	var yaw: float = _ferry.fleet.yaw(Routes.FERRY_BOAT) if _ferry.fleet != null else 0.0
	var facing := Basis(Vector3.UP, yaw + PI * 0.5)
	@warning_ignore("integer_division") var shown: int = mini((_ferry.aboard_milli + 2 * MILLI_PER_U - 1) / (2 * MILLI_PER_U), ABOARD_LOGS)
	for k: int in _aboard.size():
		_aboard[k].visible = k < shown
		if k < shown:
			var offset := Vector3(sin(yaw), 0.0, cos(yaw)) * (0.18 * float(k) - 0.27)
			_aboard[k].transform = Transform3D(facing, Vector3(boat_at.x, -0.12 + 0.05 * float(k % 2), boat_at.y) + offset) \
				* _props.fit_of(LOG_KEY)


func _draw_piles() -> void:
	"""Each lying windfall pile as a fallen log at its spot, sized by its wood."""
	for spot: int in _piles.size():
		var milli: int = _ferry.copse_milli[spot] if spot < _ferry.copse_milli.size() else 0
		_piles[spot].visible = milli > 0
		if milli <= 0:
			continue
		var share: float = lerpf(PILE_SHARE_MIN, PILE_SHARE_MAX, float(milli - Rules.PILE_MIN_MILLI) /
			float(Rules.PILE_MAX_MILLI - Rules.PILE_MIN_MILLI))
		var at: Vector2 = _ferry.copse_at[spot]
		var turn := Basis(Vector3.UP, float(spot) * 1.3) * Basis.from_scale(Vector3.ONE * share)
		_piles[spot].transform = Transform3D(turn, Vector3(at.x, 0.0, at.y)) * _props.fit_of(PILE_KEY)


func _draw_loads() -> void:
	"""A load set down where its carrier was called away shows as a log there."""
	var used: int = 0
	for j: int in FerryScript.MAX_JOBS:
		if used >= LOAD_POOL:
			break
		if _ferry.j_live[j] == 1 and _ferry.j_load[j] > 0 and _ferry.j_load_at[j].is_finite():
			var at: Vector2 = _ferry.j_load_at[j]
			_loads[used].transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.1, at.y)) * _props.fit_of(LOG_KEY)
			_loads[used].visible = true
			used += 1
	for k: int in range(used, LOAD_POOL):
		_loads[k].visible = false


func stack_shown(stage: int) -> int:
	"""How many logs a stage's stack shows (checks)."""
	var shown: int = 0
	for piece: MeshInstance3D in _stacks[stage]:
		shown += 1 if piece.visible else 0
	return shown


func piles_shown() -> int:
	"""How many windfall piles are drawn (checks)."""
	var shown: int = 0
	for piece: MeshInstance3D in _piles:
		shown += 1 if piece.visible else 0
	return shown
