extends Node3D
## THE CELLAR BUILDINGS DRAWN (decision 0612), from existing library models only -- nothing new staged, nothing paid:
## the library's `cellar` building (a stone-fronted door in a turfed mound, demo/props/demo_props.gd BUILDINGS, drawn at
## its 2.0 m envelope), a plank stack for the wood delivered and a heap of tunnel rubble for the stone, at its site,
## each growing with what is there. Placed, the mound is pressed flat on the ground (its footprint marked out); being
## built it rises with the work; built it stands whole, and the piles are gone (built in). Its name and progress hang
## over it. Redrawn only when the cellars change (cellar_projects.gd `revision`). Presentation only.

const ProjectsScript := preload("res://demo/stores/cellar_projects.gd")
const Rules := preload("res://demo/stores/cellar_rules.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const BUILDING_KEY: StringName = &"cellar"
const PILE_KEYS: Array[StringName] = [&"plank_stack", &"tunnel_rubble"]
## How flat the mound lies while only its materials are being fetched, and how high it starts once building begins.
const MARKED_SCALE: float = 0.06
const BEGUN_SCALE: float = 0.15
## A pile's smallest drawn size once anything is delivered (of its full size).
const PILE_MIN: float = 0.35
const LABEL_LIFT_M: float = 3.2

var _projects: ProjectsScript = null
var _props: PropsScript = null
var _seen: int = -1
var _bodies: Array[MeshInstance3D] = []
var _piles: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []


func configure(projects: ProjectsScript, props: PropsScript) -> void:
	"""Draw these cellars with these props (null: placeholder boxes)."""
	name = "CellarView"
	_projects = projects
	_props = props
	for c: int in ProjectsScript.MAX_CELLARS:
		_bodies.append(_mesh_node(BUILDING_KEY))
		for m: int in Rules.MAT_COUNT:
			_piles.append(_mesh_node(PILE_KEYS[m]))
		_labels.append(_label())
	refresh()


func _mesh_node(key: StringName) -> MeshInstance3D:
	"""A hidden node drawing model `key` (a box without props)."""
	var node := MeshInstance3D.new()
	node.mesh = _props.mesh_of(key) if _props != null else BoxMesh.new()
	node.visible = false
	add_child(node)
	return node


func _label() -> Label3D:
	"""A hidden name over a cellar."""
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Palette.CREAM
	label.visible = false
	add_child(label)
	return label


func _process(_delta: float) -> void:
	"""Redraw when the cellars changed."""
	if _projects != null and _projects.revision != _seen:
		refresh()


func refresh() -> void:
	"""Draw every cellar as it stands now."""
	_seen = _projects.revision
	for c: int in ProjectsScript.MAX_CELLARS:
		_draw_cellar(c)


func _draw_cellar(c: int) -> void:
	"""One cellar: its body at its height for its state, its piles, its words."""
	var live: bool = _projects.state[c] != ProjectsScript.STATE_NONE
	_bodies[c].visible = live
	_labels[c].visible = live
	for m: int in Rules.MAT_COUNT:
		_draw_pile(c, m)
	if not live:
		return
	var turn := Basis(Vector3.UP, _projects.face[c])
	var height: float = body_scale(_projects, c)
	var place := Transform3D(turn.scaled(Vector3(1.0, height, 1.0)), Vector3(_projects.at[c].x, 0.0, _projects.at[c].y))
	_bodies[c].transform = place * _fit(BUILDING_KEY)
	_labels[c].position = Vector3(_projects.at[c].x, LABEL_LIFT_M * maxf(height, 0.5), _projects.at[c].y)
	_labels[c].text = label_text(_projects, c)


func _draw_pile(c: int, m: int) -> void:
	"""Cellar `c`'s pile of material `m` at its site, sized by what is there (none once built)."""
	var pile: MeshInstance3D = _piles[c * Rules.MAT_COUNT + m]
	var share: float = pile_scale(_projects, c, m)
	pile.visible = share > 0.0
	if share <= 0.0:
		return
	var at: Vector2 = _projects.site_of(c) + Vector2(0.0, 1.2 * (m - 0.5))
	pile.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * share), Vector3(at.x, 0.0, at.y)) * _fit(PILE_KEYS[m])


func _fit(key: StringName) -> Transform3D:
	"""How model `key` sits at its drawn size (the identity without props)."""
	return _props.fit_of(key) if _props != null else Transform3D.IDENTITY


static func body_scale(projects: ProjectsScript, c: int) -> float:
	"""How high the cellar stands, of its full height: flat while placed, rising with the work, whole when built."""
	match projects.state[c]:
		ProjectsScript.STATE_DELIVERING:
			return MARKED_SCALE
		ProjectsScript.STATE_BUILDING:
			return lerpf(BEGUN_SCALE, 1.0, float(projects.work_usec[c]) / float(Rules.work_usec()))
	return 1.0


static func pile_scale(projects: ProjectsScript, c: int, m: int) -> float:
	"""How big a pile is drawn, of its full size: 0 with nothing there or the cellar built or gone."""
	if not projects.is_active(c) or projects.delivered_milli(c, m) <= 0:
		return 0.0
	var share: float = float(projects.delivered_milli(c, m)) / float(Rules.cost_milli(m))
	return lerpf(PILE_MIN, 1.0, share)


static func label_text(projects: ProjectsScript, c: int) -> String:
	"""'Cellar 1' when built, else 'Cellar 1 · 45%'."""
	var title: String = Rules.LABEL % (c + 1)
	return title if projects.is_done(c) else "%s · %d%%" % [title, projects.percent(c)]


func body_of(c: int) -> MeshInstance3D:
	"""Cellar `c`'s drawn body (checks)."""
	return _bodies[c]


func pile_of(c: int, m: int) -> MeshInstance3D:
	"""Cellar `c`'s drawn pile of material `m` (checks)."""
	return _piles[c * Rules.MAT_COUNT + m]
