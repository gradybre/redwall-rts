extends Node3D
## The bridges drawn: every planned or open bridge as its staged models, growing with its stages, and
## the span the player is choosing. Decision 0196 (live demo). Presentation only; it reads bridges.gd.
##
## THE MODELS (staged by the asset pass, demo/props/demo_props.gd): a plank footbridge is the
## `bridge_plank` model, one or more segments laid end to end along the deck (each about as long as
## the model is wide times its proportions: SEGMENT_M), scaled to the deck's length and PLANK_WIDTH_M;
## a log bridge is one `bridge_log`, scaled to the deck; piers are `bridge_pier` posts standing on the
## bed. Built stage by stage: the piers rise out of the water with the piers stage, the beams (two
## timbers, or the log) reach across with the beams stage, and the deck appears from the near end with
## the deck stage. Unstaged, the props draw as boxes of the same size. Facing is not checked by any
## tool: the models are laid along their +X length, either way round, so they need no facing. While
## the deck stage is under way the deck is drawn as loose planks laid across the beams, PLANK_PITCH_M
## apart, as far as it has reached; the finished deck is the model (its own frame replaces the beams).
##
## THE SURVEY. While the player picks a span (a candidate, or two banks), a flat line shows it: sage
## when it may be built, clay when not.

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Look := preload("res://demo/world/world_look.gd")

const PLANK_KEY: StringName = &"bridge_plank"
const LOG_KEY: StringName = &"bridge_log"
const PIER_KEY: StringName = &"bridge_pier"
const PLANK_WIDTH_M: float = 1.35
const LOG_WIDTH_M: float = 0.8
const SEGMENT_M: float = 3.4
const BEAM_SIZE_M: float = 0.14
const BEAM_APART_M: float = 0.45
const PIER_HEIGHT_M: float = 1.6
const PIER_WIDTH_M: float = 0.32
const PLANK_PITCH_M: float = 0.3
const PLANK_BOARD: Vector3 = Vector3(0.22, 0.05, 1.2)
const SURVEY_LIFT_M: float = 0.3
const SURVEY_WIDTH_M: float = 0.18
const SURVEY_OK: Color = Color(0.55, 0.72, 0.45, 0.85)
const SURVEY_NO: Color = Color(0.75, 0.35, 0.25, 0.85)

var _bridges: BridgesScript = null
var _props: PropsScript = null
var _rows: Array[Node3D] = []
var _shown: PackedInt32Array = PackedInt32Array()
var _survey: MeshInstance3D = null
var _survey_material: StandardMaterial3D = null
var _beam_material: StandardMaterial3D = null
var _plank_mesh: BoxMesh = null


func configure(bridges: BridgesScript, props: PropsScript) -> void:
	"""Draw `bridges` with `props`' models."""
	name = "BridgeView"
	_bridges = bridges
	_props = props
	_shown.resize(BridgesScript.MAX_BRIDGES)
	_shown.fill(-1)
	for row: int in BridgesScript.MAX_BRIDGES:
		var holder := Node3D.new()
		holder.name = "Bridge%d" % row
		holder.visible = false
		add_child(holder)
		_rows.append(holder)
	_beam_material = StandardMaterial3D.new()
	_beam_material.albedo_color = Look.UMBER.lerp(Look.TIMBER, 0.45)
	_beam_material.roughness = 0.9
	_plank_mesh = BoxMesh.new()
	_plank_mesh.size = PLANK_BOARD
	_plank_mesh.material = _beam_material
	_build_survey()


func refresh() -> void:
	"""Redraw a bridge whose progress changed since it was last drawn (cheap when none did)."""
	for row: int in BridgesScript.MAX_BRIDGES:
		var key: int = -1 if _bridges.phase[row] == BridgesScript.PHASE_FREE else _bridges.percent(row) + 1000 * _bridges.generation[row]
		if key != _shown[row]:
			_shown[row] = key
			_draw(row)


func _draw(row: int) -> void:
	"""Rebuild bridge `row`'s drawing at its current progress."""
	var holder: Node3D = _rows[row]
	for child: Node in holder.get_children():
		child.queue_free()
	holder.visible = _bridges.phase[row] != BridgesScript.PHASE_FREE
	if not holder.visible:
		return
	_draw_piers(row, holder)
	if _bridges.kind[row] == Rules.KIND_LOG:
		_draw_log(row, holder)
	else:
		_draw_beams(row, holder)
		_draw_deck(row, holder)


func _draw_piers(row: int, holder: Node3D) -> void:
	"""Piers on the bed, risen by the piers stage's share."""
	var rise: float = float(_bridges.stage_permille(row, Rules.STAGE_PIERS)) / 1000.0
	if _bridges.piers[row] == 0 or rise <= 0.0:
		return
	var top: float = _bridges.deck_y_m(row, 0.5) - 0.05
	for at: Vector2 in _bridges.pier_points(row):
		var bound: AABB = _props.drawn_bound(PIER_KEY)
		var sy: float = PIER_HEIGHT_M / maxf(bound.size.y, 1e-3) * rise
		var sxz: float = PIER_WIDTH_M / maxf(maxf(bound.size.x, bound.size.z), 1e-3)
		var pier: MeshInstance3D = _props.instance(PIER_KEY)
		pier.transform = Transform3D(Basis.from_scale(Vector3(sxz, sy, sxz)), Vector3(at.x, top - PIER_HEIGHT_M, at.y)) * _props.fit_of(PIER_KEY)
		holder.add_child(pier)


func _draw_beams(row: int, holder: Node3D) -> void:
	"""Two timbers reaching from the near footing across the water, by the beams stage's share (until the
	deck is finished: the model carries its own)."""
	var share: float = float(_bridges.stage_permille(row, Rules.STAGE_BEAMS)) / 1000.0
	if share <= 0.0 or _bridges.stage_permille(row, Rules.STAGE_DECK) >= Rules.PERMILLE:
		return
	var a: Vector2 = _bridges.deck_end(row, false)
	var b: Vector2 = _bridges.deck_end(row, true)
	var along: Vector2 = (b - a).normalized()
	var across: Vector2 = along.orthogonal() * BEAM_APART_M
	for side: float in [-1.0, 1.0]:
		var from: Vector2 = a + across * side
		var to: Vector2 = from + (b - a) * share
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(BEAM_SIZE_M, BEAM_SIZE_M, from.distance_to(to))
		beam.mesh = box
		beam.material_override = _beam_material
		var y: float = _bridges.deck_y_m(row, share * 0.5) - 0.2
		beam.transform = Transform3D(Basis.looking_at(Vector3(to.x - from.x, 0.0, to.y - from.y), Vector3.UP), Vector3((from.x + to.x) * 0.5, y, (from.y + to.y) * 0.5))
		holder.add_child(beam)


func _draw_deck(row: int, holder: Node3D) -> void:
	"""Loose planks across the beams as far as the deck stage has reached; finished, the plank model's
	segments laid end to end along the deck."""
	var permille: int = _bridges.stage_permille(row, Rules.STAGE_DECK)
	if permille <= 0:
		return
	var length: float = _bridges.deck_end(row, false).distance_to(_bridges.deck_end(row, true))
	if permille < Rules.PERMILLE:
		_draw_planks(row, holder, length, float(permille) / 1000.0)
		return
	var count: int = maxi(1, roundi(length / SEGMENT_M))
	for k: int in count:
		holder.add_child(_segment(row, PLANK_KEY, float(k) / float(count), float(k + 1) / float(count), PLANK_WIDTH_M, BridgesScript.PLANK_HEIGHT_M))


func _draw_planks(row: int, holder: Node3D, length: float, share: float) -> void:
	"""Boards laid across the deck line every PLANK_PITCH_M from the near footing, `share` of the way."""
	var a: Vector2 = _bridges.deck_end(row, false)
	var along: Vector2 = (_bridges.deck_end(row, true) - a).normalized()
	var basis := Basis.looking_at(Vector3(along.orthogonal().x, 0.0, along.orthogonal().y), Vector3.UP)
	var boards: int = floori(length / PLANK_PITCH_M * share)
	for k: int in boards:
		var d: float = (float(k) + 0.5) * PLANK_PITCH_M
		var at: Vector2 = a + along * d
		var board := MeshInstance3D.new()
		board.mesh = _plank_mesh
		board.transform = Transform3D(basis, Vector3(at.x, _bridges.deck_y_m(row, d / length) - 0.03, at.y))
		holder.add_child(board)


func _draw_log(row: int, holder: Node3D) -> void:
	"""The log, drawn across once its beams ("log") stage is past the shaping."""
	var shaped: float = float(Rules.LOG_SHAPE_WU) / float(maxi(_bridges.stage_total_wu[row * Rules.STAGE_COUNT + Rules.STAGE_BEAMS], 1))
	var share: float = float(_bridges.stage_permille(row, Rules.STAGE_BEAMS)) / 1000.0
	var reach: float = clampf((share - shaped) / maxf(1.0 - shaped, 1e-3), 0.0, 1.0)
	if reach <= 0.0:
		return
	holder.add_child(_segment(row, LOG_KEY, 0.0, reach, LOG_WIDTH_M, BridgesScript.LOG_HEIGHT_M))


func _segment(row: int, key: StringName, t0: float, t1: float, width: float, height: float) -> MeshInstance3D:
	"""`key` stretched along the deck from share `t0` to `t1` of its length, `width` wide and `height`
	tall, standing on the footings' ground (its drawn base on the bank at each end)."""
	var a: Vector2 = _bridges.deck_end(row, false)
	var b: Vector2 = _bridges.deck_end(row, true)
	var from: Vector2 = a.lerp(b, t0)
	var to: Vector2 = a.lerp(b, t1)
	var bound: AABB = _props.drawn_bound(key)
	var scale := Vector3(from.distance_to(to) / maxf(bound.size.x, 1e-3), height / maxf(bound.size.y, 1e-3),
		width / maxf(bound.size.z, 1e-3))
	var along := Vector3((to - from).normalized().x, 0.0, (to - from).normalized().y)
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var ground: float = lerpf(_bridges.footing_y_a[row], _bridges.footing_y_b[row], (t0 + t1) * 0.5)
	var node: MeshInstance3D = _props.instance(key)
	node.transform = Transform3D(basis * Basis.from_scale(scale), Vector3((from.x + to.x) * 0.5, ground, (from.y + to.y) * 0.5)) * _props.fit_of(key)
	return node


# --- the survey ----------------------------------------------------------------------------------

func _build_survey() -> void:
	"""The survey line: a thin flat bar, hidden until shown."""
	_survey_material = StandardMaterial3D.new()
	_survey_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_survey_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_survey_material.no_depth_test = true
	_survey = MeshInstance3D.new()
	_survey.name = "Survey"
	_survey.mesh = BoxMesh.new()
	_survey.material_override = _survey_material
	_survey.visible = false
	_survey.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_survey)


func show_survey(a: Vector2, b: Vector2, ok: bool) -> void:
	"""Show the span a -> b being chosen: sage when it may be built, clay when not."""
	var length: float = maxf(a.distance_to(b), 0.05)
	(_survey.mesh as BoxMesh).size = Vector3(SURVEY_WIDTH_M, 0.04, length)
	_survey_material.albedo_color = SURVEY_OK if ok else SURVEY_NO
	var dir := Vector3(b.x - a.x, 0.0, b.y - a.y)
	_survey.transform = Transform3D(Basis.looking_at(dir if dir.length() > 1e-4 else Vector3.FORWARD, Vector3.UP),
		Vector3((a.x + b.x) * 0.5, SURVEY_LIFT_M, (a.y + b.y) * 0.5))
	_survey.visible = true


func hide_survey() -> void:
	"""Hide the survey line."""
	_survey.visible = false


func survey_shown() -> bool:
	"""Whether a survey line is shown (checks)."""
	return _survey.visible
