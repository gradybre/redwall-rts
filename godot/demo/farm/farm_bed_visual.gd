extends Node3D
## One crop bed as drawn: soil and frame, the plants of whatever grows there at its stage, the soil's
## moisture sheen, sowing furrows, a label over it, a selection ring and the map-overlay disc.
## Decision 0196. Presentation only: `show_state()` is handed what to draw (farm_view.gd reads the
## sim); nothing here decides anything.
##
## The plants are the staged card atlases -- each item's own library plant (tools/make_demo_props.py),
## or the old atlas it borrows (tools/make_demo_crop_cards.py) -- in ONE MultiMesh per bed (plus one
## of top-down leaves where the atlas has them), laid out once per visual kind with a seed per bed,
## and only re-transformed and re-celled -- never re-allocated -- when the growth step changes.
## Scale, the cells a stage shows, tint, bleach, blotches, droop and slump come from farm_look.gd. A
## head plant (the lettuce) is drawn filled out and ripe as its close-up mesh instead, in one more
## MultiMesh laid out the same, tinted by one material per bed.

const Look := preload("res://demo/farm/farm_look.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const AssetsScript := preload("res://demo/farm/farm_assets.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CropCards := preload("res://demo/world/crop_cards.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")

## A library plant's top-down cell for each of its standing cells (full, side, thinned, sparse):
## the tops atlas has full, thinned and sparse.
const TOP_OF_CELL: Array[int] = [0, 0, 1, 2]
## Where the old roots atlas's tops lie, as a share of its card's height.
const OLD_TOP_LIFT: float = 0.55
const JITTER: float = 0.3
const SCALE_JITTER: Vector2 = Vector2(0.85, 1.1)
const FURROWS: int = 5
const FURROW_SIZE: Vector3 = Vector3(1.55, 0.012, 0.07)
const FURROW_COLOR: Color = Color(0.16, 0.11, 0.08)
const LABEL_HEIGHT_M: float = 1.5
const LABEL_PIXEL: float = 0.0042
const LABEL_FONT_PX: int = 44
## The overlay square over a bed, a little inside its 3 m frame.
const OVERLAY_SIZE_M: float = 2.8
## Tunnel spoil under a raised bed lifts it this far; a bank is an earth rim round a bed.
const RAISE_LIFT_M: float = 0.14
const RAISE_BASE: Vector3 = Vector3(3.15, 0.14, 3.15)
const BANK_BAR: Vector3 = Vector3(3.6, 0.22, 0.34)
const BANK_HALF_M: float = 1.72
const EARTH_COLOR: Color = Color(0.36, 0.27, 0.19)
## Straw laid over a covered bed for a frost night.
const STRAW_SIZE: Vector3 = Vector3(2.85, 0.04, 2.85)
const STRAW_COLOR: Color = Color(0.83, 0.7, 0.42, 0.88)
const STRAW_Y_M: float = 0.5
## The selection outline: a brass square just outside the bed frame, above it.
const OUTLINE_HALF_M: float = 1.6
const OUTLINE_BAR: Vector3 = Vector3(3.3, 0.05, 0.08)
const OUTLINE_Y_M: float = 0.32
## A growth change smaller than this (permille) keeps the plants as they stand.
const GROWTH_STEP: int = 25

var bed: int = 0
## The scale the plants were last drawn at (0: none drawn).
var shown_scale: float = 0.0
var label: Label3D = null
var ring: Node3D = null
var overlay: MeshInstance3D = null
var straw: MeshInstance3D = null
var raised_base: MeshInstance3D = null
var bank: Node3D = null

var _assets: AssetsScript = null
var _units: Node3D = null
var _base: Node3D = null
var _heads: Node3D = null
var _plants: MultiMeshInstance3D = null
var _tops: MultiMeshInstance3D = null
var _heads_mm: MultiMeshInstance3D = null
var _furrows: MultiMeshInstance3D = null
var _sheen: MeshInstance3D = null
var _card_material: Material = null
var _top_material: Material = null
var _kind: int = -1
var _layout: Array[Transform3D] = []
var _shown_key: int = -1
var _heads_item: int = Catalog.NO_ITEM
## The atlas cell each plant shows now (kept here: headless MultiMeshes keep no instance data).
var _cells_shown: PackedInt32Array = PackedInt32Array()


func build(p_bed: int, assets: AssetsScript) -> void:
	"""Build bed `p_bed`'s nodes at its place, bare."""
	bed = p_bed
	_assets = assets
	name = "FarmBed%d" % bed
	var at: Vector2 = Catalog.bed_centre_m(bed)
	position = Vector3(at.x, 0.0, at.y)
	_units = Node3D.new()
	_units.scale = Vector3.ONE * assets.bed_scale
	add_child(_units)
	_base = assets.make_bed()
	_units.add_child(_base)
	_build_marks()
	_furrows = _make_furrows()
	_units.add_child(_furrows)
	_sheen = _make_sheen()
	_units.add_child(_sheen)
	label = _make_label()
	add_child(label)
	_build_works()


func _build_works() -> void:
	"""What the player can do to the ground, each hidden until done: straw, a raised base, a bank."""
	straw = _box(STRAW_SIZE, STRAW_COLOR, STRAW_Y_M)
	straw.material_override = _flat_material(STRAW_COLOR)
	(straw.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	add_child(straw)
	raised_base = _box(RAISE_BASE, EARTH_COLOR, RAISE_BASE.y * 0.5)
	add_child(raised_base)
	bank = Node3D.new()
	bank.visible = false
	add_child(bank)
	for side: int in 4:
		var bar: MeshInstance3D = _box(BANK_BAR, EARTH_COLOR, BANK_BAR.y * 0.5)
		bar.visible = true
		var yaw: float = PI * 0.5 * side
		bar.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(sin(yaw), 0.0, cos(yaw)) * BANK_HALF_M + bar.position)
		bank.add_child(bar)


static func _box(size: Vector3, colour: Color, y: float) -> MeshInstance3D:
	"""A plain box standing at height `y` (hidden)."""
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = y
	instance.visible = false
	return instance


func show_works(covered: bool, raised: bool, banked: bool) -> void:
	"""Straw over a covered bed; a raised bed lifted onto its spoil; an earth bank round a banked one."""
	straw.visible = covered
	raised_base.visible = raised
	_units.position.y = RAISE_LIFT_M if raised else 0.0
	straw.position.y = STRAW_Y_M + _units.position.y
	bank.visible = banked


func _build_marks() -> void:
	"""The selection outline and the overlay disc, both hidden."""
	ring = _make_outline()
	add_child(ring)
	var square := PlaneMesh.new()
	square.size = Vector2(OVERLAY_SIZE_M, OVERLAY_SIZE_M)
	overlay = MeshInstance3D.new()
	overlay.mesh = square
	overlay.material_override = _flat_material(Color(0, 0, 0, 0))
	overlay.position.y = 0.42
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.visible = false
	add_child(overlay)


static func _make_outline() -> Node3D:
	"""Four brass bars round the bed (hidden)."""
	var outline := Node3D.new()
	outline.name = "Selected"
	outline.visible = false
	var bar := BoxMesh.new()
	bar.size = OUTLINE_BAR
	var material := _flat_material(MarksScript.SELECTED)
	for side: int in 4:
		var piece := MeshInstance3D.new()
		piece.mesh = bar
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var yaw: float = PI * 0.5 * side
		piece.transform = Transform3D(Basis(Vector3.UP, yaw),
			Vector3(sin(yaw), 0.0, cos(yaw)) * OUTLINE_HALF_M + Vector3(0.0, OUTLINE_Y_M, 0.0))
		outline.add_child(piece)
	return outline


static func _flat_material(colour: Color) -> StandardMaterial3D:
	"""An unshaded see-through material that draws over the plants."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.render_priority = 2
	return material


func _make_label() -> Label3D:
	"""The two-line label over the bed, always facing the camera and readable over the plants."""
	var text := Label3D.new()
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.no_depth_test = true
	text.pixel_size = LABEL_PIXEL
	text.font_size = LABEL_FONT_PX
	text.outline_size = 12
	text.outline_modulate = Color(0.08, 0.1, 0.08, 0.85)
	text.position.y = LABEL_HEIGHT_M
	text.render_priority = 3
	text.outline_render_priority = 2
	return text


func _make_furrows() -> MultiMeshInstance3D:
	"""FURROWS dark seed rows across the soil (shown while sowing)."""
	var box := BoxMesh.new()
	box.size = FURROW_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = FURROW_COLOR
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = FURROWS
	for k: int in FURROWS:
		var z: float = lerpf(-0.6, 0.6, float(k) / float(FURROWS - 1))
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(0.0, _assets.soil_y + 0.004, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Furrows"
	instance.multimesh = multimesh
	instance.visible = false
	return instance


func _make_sheen() -> MeshInstance3D:
	"""A flat film over the soil that shows how wet or dry it is."""
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (_assets.inner_half * 2.0)
	var instance := MeshInstance3D.new()
	instance.name = "Sheen"
	instance.mesh = plane
	var material := _flat_material(Color(0, 0, 0, 0))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 0.15
	material.render_priority = 0
	instance.material_override = material
	instance.position.y = _assets.soil_y + 0.006
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


# --- the state --------------------------------------------------------------------------------

func show_state(stage: int, item: int, growth: int, band: int, ripe_hours: int, title: String, status: String) -> void:
	"""Draw the bed at this stage (farm_look.gd decides the look)."""
	var heads: bool = Look.shows_heads(stage, item)
	_show_heads(heads, item)
	_furrows.visible = stage == SimScript.STAGE_SOWN
	var sheen_colour: Color = Look.sheen(band)
	(_sheen.material_override as StandardMaterial3D).albedo_color = sheen_colour
	_sheen.visible = sheen_colour.a > 0.0 and not heads
	_show_plants(stage, item, growth, heads)
	label.text = "%s\n%s" % [title, status]
	label.modulate = Look.urgency(stage, band, ripe_hours)


func _show_plants(stage: int, item: int, growth: int, heads: bool) -> void:
	"""Lay out (once per kind), cell, scale and colour the plants for the stage; none when bare or
	showing heads."""
	var scale_now: float = Look.plant_scale(stage, growth)
	var visible_now: bool = scale_now > 0.0 and not heads and Catalog.is_item(item)
	_show_parts(visible_now, false)
	if not visible_now:
		return
	var kind: int = Catalog.ITEM_VISUAL[item]
	if kind != _kind:
		_rebuild(kind)
	_show_parts(true, _heads_mm != null and Look.shows_head_mesh(stage, growth))
	_paint(stage, item, growth)
	var key: int = stage * 100000 + growth / GROWTH_STEP
	if key != _shown_key:
		_shown_key = key
		_assign_cells(stage, growth)
		_place(scale_now, Look.droop(stage), Look.limp(stage))


func _show_parts(on: bool, heads: bool) -> void:
	"""The cards (and tops), or the head meshes, or nothing."""
	if _plants != null:
		_plants.visible = on and not heads
	if _tops != null:
		_tops.visible = on and not heads
	if _heads_mm != null:
		_heads_mm.visible = on and heads


func showing_cards() -> bool:
	"""Whether the bed draws its plants as cards now (tests)."""
	return _plants != null and _plants.visible


func showing_head_meshes() -> bool:
	"""Whether the bed draws its plants as head meshes now (tests)."""
	return _heads_mm != null and _heads_mm.visible


func _paint(stage: int, item: int, growth: int) -> void:
	"""Tint, bleach and blotch the bed's card materials for the stage; tint the head meshes."""
	var tint: Vector3 = Look.plant_tint(stage, item, growth)
	if _heads_mm != null:
		(_heads_mm.material_override as BaseMaterial3D).albedo_color = Color(tint.x, tint.y, tint.z)
	for material: Material in [_card_material, _top_material]:
		if material != null:
			AssetsScript.set_tint(material, tint)
			AssetsScript.set_blight(material, Look.bleach(stage), Look.spots(stage))


func cells_for(stage: int, growth: int) -> PackedInt32Array:
	"""The atlas cells this bed's plants show at a stage: a library plant's stage subset
	(farm_look.gd stage_cells), or every cell of an old atlas's kind."""
	if Catalog.is_plant_kind(_kind):
		return PackedInt32Array(Look.stage_cells(stage, growth))
	return _assets.cells[_kind]


func _assign_cells(stage: int, growth: int) -> void:
	"""Give each plant (and its top) a cell of the stage's subset, spread by a per-bed stride."""
	var shown: PackedInt32Array = cells_for(stage, growth)
	var plant_kind: bool = Catalog.is_plant_kind(_kind)
	for i: int in _layout.size():
		var cell: int = shown[(i * 7 + bed) % shown.size()]
		_cells_shown[i] = cell
		_plants.multimesh.set_instance_custom_data(i, Color(float(cell), 0.0, 0.0, 0.0))
		if _tops != null:
			var top: int = TOP_OF_CELL[cell] if plant_kind else cell
			_tops.multimesh.set_instance_custom_data(i, Color(float(top), 0.0, 0.0, 0.0))


func _rebuild(kind: int) -> void:
	"""New plant MultiMeshes and a new layout for a visual kind (only when the kind changes)."""
	_assets.ensure_loaded(kind)
	_kind = kind
	_shown_key = -1
	for node: Node in [_plants, _tops, _heads_mm]:
		if node == null:
			continue
		_units.remove_child(node)
		node.queue_free()
	_layout = _layout_for(kind)
	_cells_shown.resize(_layout.size())
	_heads_mm = _head_node(kind)
	var cell: Vector2 = _assets.card_cell[kind]
	var mesh: ArrayMesh = CropCards.card_mesh(cell)
	_card_material = _assets.card_material(kind, Vector3.ONE)
	mesh.surface_set_material(0, _card_material)
	_plants = _multimesh(mesh, _layout.size(), "Plants")
	_units.add_child(_plants)
	_tops = null
	_top_material = null
	if _assets.top_texture[kind] != null:
		var top: ArrayMesh = CropCards.top_mesh(_assets.top_cell[kind])
		_top_material = _assets.top_material(kind, Vector3.ONE)
		top.surface_set_material(0, _top_material)
		_tops = _multimesh(top, _layout.size(), "Tops")
		_units.add_child(_tops)


func _head_node(kind: int) -> MultiMeshInstance3D:
	"""A head plant's mesh for every plant of the layout, with the bed's own tinted copy of its
	material; null when the kind has no staged head mesh."""
	var mesh: Mesh = _assets.head_mesh[kind]
	if mesh == null:
		return null
	var node: MultiMeshInstance3D = _multimesh(mesh, _layout.size(), "Heads")
	var source := mesh.surface_get_material(0) as BaseMaterial3D
	node.material_override = source.duplicate() if source != null else StandardMaterial3D.new()
	node.visible = false
	_units.add_child(node)
	return node


func _multimesh(mesh: Mesh, count: int, node_name: String) -> MultiMeshInstance3D:
	"""A MultiMesh of `count` plants, each showing the atlas cell in its custom data red (set by
	_assign_cells)."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


func _layout_for(kind: int) -> Array[Transform3D]:
	"""Where each plant stands (bed units) and its own yaw and size: a jittered grid, seeded by bed."""
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + bed * 31 + kind
	var grid: Vector2i = _assets.grid[kind]
	var span: float = (_assets.inner_half - 0.08) * 2.0
	var out: Array[Transform3D] = []
	for row: int in grid.x:
		for column: int in grid.y:
			var u: float = (column + 0.5 + rng.randf_range(-JITTER, JITTER)) / grid.y
			var v: float = (row + 0.5 + rng.randf_range(-JITTER, JITTER) * 0.5) / grid.x
			var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * rng.randf_range(SCALE_JITTER.x, SCALE_JITTER.y))
			out.append(Transform3D(basis, Vector3((u - 0.5) * span, _assets.soil_y - 0.01, (v - 0.5) * span)))
	return out


func _place(scale_now: float, lean: float, slump: float) -> void:
	"""Scale every plant (and its top) to the stage, drooping and slumping when withered."""
	shown_scale = scale_now
	var top_height: float = _assets.card_cell[_kind].y * top_lift(_kind) * slump
	var top_scale: float = scale_now * top_size(_kind)
	for i: int in _layout.size():
		_plants.multimesh.set_instance_transform(i, plant_transform(i, scale_now, lean, slump))
		if _heads_mm != null:
			_heads_mm.multimesh.set_instance_transform(i, plant_transform(i, scale_now, lean, slump) * _assets.head_fit[_kind])
		if _tops != null:
			var t: Transform3D = _layout[i]
			var up: Vector3 = t.origin + Vector3(0.0, top_height * scale_now, 0.0)
			_tops.multimesh.set_instance_transform(i, Transform3D(t.basis.scaled(Vector3.ONE * top_scale), up))


static func top_lift(kind: int) -> float:
	"""Where a kind's top card lies, as a share of its standing card's height (the old atlases: 0.55)."""
	return Catalog.PLANT_TOP_LIFT[kind - Catalog.VIS_PLANT_FIRST] if Catalog.is_plant_kind(kind) else OLD_TOP_LIFT


static func top_size(kind: int) -> float:
	"""How much larger than the standing cards a kind's top card is drawn (the old atlases: as large)."""
	return Catalog.PLANT_TOP_SCALE[kind - Catalog.VIS_PLANT_FIRST] if Catalog.is_plant_kind(kind) else 1.0


func plant_transform(i: int, scale_now: float, lean: float, slump: float = 1.0) -> Transform3D:
	"""Plant `i` at `scale_now` of its own size, leaning `lean` radians and keeping `slump` of its
	height (bed units)."""
	var t: Transform3D = _layout[i]
	var basis: Basis = (Basis(Vector3.RIGHT, lean) * t.basis).scaled(Vector3.ONE * scale_now)
	return Transform3D(Basis.from_scale(Vector3(1.0, slump, 1.0)) * basis, t.origin)


func _show_heads(on: bool, item: int) -> void:
	"""The staged cabbage heads in place of bed and plants for a ripe leaf crop, tinted per item."""
	_base.visible = not on or _assets.heads_scene == null
	if not on or _assets.heads_scene == null:
		if _heads != null:
			_heads.visible = false
		return
	if _heads == null:
		_heads = _assets.heads_scene.instantiate() as Node3D
		_heads.scale = Vector3.ONE * (_assets.heads_scale / _assets.bed_scale)
		_units.add_child(_heads)
	_heads.visible = true
	if item != _heads_item:
		_heads_item = item
		_tint_heads(Catalog.ITEM_TINT[item])


func _tint_heads(tint: Color) -> void:
	"""Tint the heads' own materials (duplicated per bed, once per item change)."""
	for node: Node in _heads.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var copy := source.duplicate() as BaseMaterial3D
			copy.albedo_color = source.albedo_color * tint
			mesh_instance.set_surface_override_material(surface, copy)


func set_selected(on: bool) -> void:
	"""Show the brass outline round a selected bed."""
	ring.visible = on


func show_overlay(colour: Color) -> void:
	"""Show the map-overlay disc in `colour` (alpha 0 hides it)."""
	overlay.visible = colour.a > 0.0
	(overlay.material_override as StandardMaterial3D).albedo_color = colour


func set_faded(alpha: float) -> void:
	"""Fade every drawn part (the tunnel tool's underground view)."""
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = alpha


func plant_count() -> int:
	"""How many plants the bed draws (0 with none laid out)."""
	return _layout.size() if _plants != null and _plants.visible else 0


func cell_shown(i: int) -> int:
	"""The atlas cell plant `i` shows (tests)."""
	return _cells_shown[i]


func visual_kind() -> int:
	"""The visual kind the bed's plants are laid out for (-1: none yet; tests)."""
	return _kind


func layout_scale(i: int) -> float:
	"""Plant `i`'s own size in the layout (its jitter; tests)."""
	return _layout[i].basis.get_scale().x
