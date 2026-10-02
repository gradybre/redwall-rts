extends Node3D
## THE INFIRMARY DRAWN (decision 0623), composed from existing library models only -- nothing new staged, nothing paid:
## the library's `residence` building (a timbered cottage on a stone plinth; the world's own residence model) drawn at
## the lookdev envelope height of an INFIRMARY (assets/lookdev/lookdev_dimensions.gd: 5.5 m), with strings of herbs
## (`hanging_stores_strung`) and a `pantry_shelf` of remedies at its door, so it reads as the place of care. The library
## has no infirmary model of its own: an ART GAP, reported. Its materials' piles -- a plank stack, a heap of tunnel
## rubble, a sack pile for the cloth -- grow at its site with what is delivered. Placed, the body is pressed flat as its
## marked footprint; being built it rises with the work; built it stands whole and the piles are gone. Its name and
## progress hang over it. Redrawn only when the project changes (infirmary_project.gd `revision`). Presentation only.

const ProjectsScript := preload("res://demo/infirmary/infirmary_project.gd")
const Rules := preload("res://demo/infirmary/infirmary_rules.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const ManifestScript := preload("res://demo/demo_manifest.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const BODY_KEY: String = "residence"
const ENVELOPE_KEY: StringName = &"infirmary"
const PILE_KEYS: Array[StringName] = [&"plank_stack", &"tunnel_rubble", &"sack_pile"]
## The door's dressing: herb strings and a shelf of remedies, before its front (m, in its own frame).
const HERBS_KEY: StringName = &"hanging_stores_strung"
const SHELF_KEY: StringName = &"pantry_shelf"
const HERBS_AT: Vector3 = Vector3(-1.4, 0.0, 2.6)
const SHELF_AT: Vector3 = Vector3(1.4, 0.0, 2.55)
## The residence model's plinth is let into the ground (world_sizes.gd SINK_M's residence, scaled to this height).
const SINK_SHARE: float = 0.07
const MARKED_SCALE: float = 0.06
const BEGUN_SCALE: float = 0.15
const PILE_MIN: float = 0.35
const LABEL_LIFT_M: float = 6.2

static var _body_mesh: Mesh = null
static var _body_fit: Transform3D = Transform3D.IDENTITY

var _projects: ProjectsScript = null
var _props: PropsScript = null
var _seen: int = -1
var _body: Node3D = null
var _piles: Array[MeshInstance3D] = []
var _label: Label3D = null


static func body_node(props: PropsScript) -> Node3D:
	"""A new node drawing the infirmary's body and its door's dressing, base on y = 0, front +Z (the ghost's too)."""
	var root := Node3D.new()
	root.name = "InfirmaryBody"
	var shell := MeshInstance3D.new()
	_load_body()
	shell.mesh = _body_mesh
	shell.transform = _body_fit
	root.add_child(shell)
	if props != null:
		for pair: Array in [[HERBS_KEY, HERBS_AT], [SHELF_KEY, SHELF_AT]]:
			var part: MeshInstance3D = props.instance(pair[0])
			part.transform = Transform3D(Basis.IDENTITY, pair[1]) * part.transform
			root.add_child(part)
	return root


static func _load_body() -> void:
	"""The residence model, once, scaled to the infirmary's envelope height (a box when nothing is staged)."""
	if _body_mesh != null:
		return
	var height: float = Sizes.target_height_m(ENVELOPE_KEY)
	var row: Dictionary = (ManifestScript.load_manifest()["world"] as Dictionary).get(BODY_KEY, {})
	if row.is_empty() or not ResourceLoader.exists(String(row.get("path", ""))):
		var box := BoxMesh.new()
		box.size = Vector3(4.6, height, 4.0)
		_body_mesh = box
		_body_fit = Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))
		return
	var root: Node = (load(String(row["path"])) as PackedScene).instantiate()
	var found: Array = PropsScript.first_mesh(root, Transform3D.IDENTITY)
	root.free()
	var lo: Array = row["aabb_min"]
	var hi: Array = row["aabb_max"]
	var s: float = height / maxf(float(hi[1]) - float(lo[1]), 0.001)
	var centre := Vector3((float(lo[0]) + float(hi[0])) * 0.5, float(lo[1]), (float(lo[2]) + float(hi[2])) * 0.5)
	_body_mesh = found[0] if not found.is_empty() else BoxMesh.new()
	var sink := Vector3(0.0, -height * SINK_SHARE, 0.0)
	_body_fit = Transform3D(Basis.from_scale(Vector3.ONE * s), -centre * s + sink) * (found[1] if not found.is_empty() \
		else Transform3D.IDENTITY)


static func paint(node: Node, material: Material) -> void:
	"""Every mesh under `node` drawn in `material` (the ghost's brass or clay)."""
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = material


func configure(projects: ProjectsScript, props: PropsScript) -> void:
	"""Draw this infirmary with these props (null: placeholder boxes)."""
	name = "InfirmaryView"
	_projects = projects
	_props = props
	_body = body_node(props)
	_body.visible = false
	add_child(_body)
	for m: int in Rules.MAT_COUNT:
		var node := MeshInstance3D.new()
		node.mesh = props.mesh_of(PILE_KEYS[m]) if props != null else BoxMesh.new()
		node.visible = false
		add_child(node)
		_piles.append(node)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.pixel_size = 0.01
	_label.outline_size = 8
	_label.modulate = Palette.CREAM
	_label.visible = false
	add_child(_label)
	refresh()


func _process(_delta: float) -> void:
	"""Redraw when the project changed."""
	if _projects != null and _projects.revision != _seen:
		refresh()


func refresh() -> void:
	"""Draw the infirmary as it stands now."""
	_seen = _projects.revision
	var live: bool = _projects.state != ProjectsScript.STATE_NONE
	_body.visible = live
	_label.visible = live
	for m: int in Rules.MAT_COUNT:
		_draw_pile(m)
	if not live:
		return
	var height: float = body_scale(_projects)
	var turn := Basis(Vector3.UP, _projects.face).scaled(Vector3(1.0, height, 1.0))
	_body.transform = Transform3D(turn, Vector3(_projects.at.x, 0.0, _projects.at.y))
	_label.position = Vector3(_projects.at.x, LABEL_LIFT_M * maxf(height, 0.4), _projects.at.y)
	_label.text = label_text(_projects)


func _draw_pile(m: int) -> void:
	"""Its pile of material `m` at its site, sized by what is there (none once built)."""
	var pile: MeshInstance3D = _piles[m]
	var share: float = pile_scale(_projects, m)
	pile.visible = share > 0.0
	if share <= 0.0:
		return
	var at: Vector2 = _projects.site() + Vector2(0.0, 1.2 * (m - 1))
	var fit: Transform3D = _props.fit_of(PILE_KEYS[m]) if _props != null else Transform3D.IDENTITY
	pile.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * share), Vector3(at.x, 0.0, at.y)) * fit


static func body_scale(projects: ProjectsScript) -> float:
	"""How high it stands, of its full height: flat while placed, rising with the work, whole when built."""
	match projects.state:
		ProjectsScript.STATE_DELIVERING:
			return MARKED_SCALE
		ProjectsScript.STATE_BUILDING:
			return lerpf(BEGUN_SCALE, 1.0, float(projects.work_usec) / float(Rules.work_usec()))
	return 1.0


static func pile_scale(projects: ProjectsScript, m: int) -> float:
	"""How big a pile is drawn, of its full size: 0 with nothing there or the building built or gone."""
	if not projects.is_active() or projects.delivered[m] <= 0:
		return 0.0
	return lerpf(PILE_MIN, 1.0, float(projects.delivered[m]) / float(Rules.cost_milli(m)))


static func label_text(projects: ProjectsScript) -> String:
	"""'Infirmary' when built, else 'Infirmary · 45%'."""
	return Rules.LABEL if projects.is_done() else "%s · %d%%" % [Rules.LABEL, projects.percent()]


func body() -> Node3D:
	"""The drawn body (checks)."""
	return _body


func pile_of(m: int) -> MeshInstance3D:
	"""The drawn pile of material `m` (checks)."""
	return _piles[m]
