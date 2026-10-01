extends Node3D
## The kitchen, drawn: steam over the cauldron while a batch cooks, the portions as bowls on the hall's table, and what
## the cook and the drawers carry. Decision 0381. Presentation only: it reads the kitchen (kitchen.gd) and writes
## nothing to it.
##
## NO PARTICLES. The warren's budget is 200 live particles and 198 of them are allocated (decision 0211); the steam is
## not taken from it. It is STEAM_PUFFS soft quads made once, rising and fading in a loop on the demo clock (paused,
## they hang; at 2x and 4x they rise faster), shown only while a batch is at the cauldron.
## THE BOWLS: one per portion out on the table, at most MAX_BOWLS drawn (made once, shown as the count changes).
## CARRIED: the cook carries the item it fetched (its own model, farm_goods.gd), the pot as a basket of bowls, and a
## drawer its water in a jar (demo_actor.gd `hold`); polled each frame, an actor touched only when that changes.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const Layers := preload("res://demo/demo_layers.gd")

const STEAM_PUFFS: int = 6
const STEAM_LIFE_S: float = 2.4
const STEAM_RISE_M_S: float = 0.55
const STEAM_FROM_M: float = 1.05
const STEAM_SIZE_M: float = 0.42
const STEAM_COLOUR: Color = Color(0.93, 0.93, 0.9, 0.55)
const MAX_BOWLS: int = 12
const TABLE_TOP_M: float = 0.625
const BOWL_COLOUR: Color = Color(0.55, 0.38, 0.22)
const POT_KEY: StringName = &"basket"
const WATER_KEY: StringName = &"clay_jars"

var _kitchen: KitchenScript = null
var _cast: DemoCastScript = null
var _clock: DemoClockScript = null
var _goods: GoodsScript = null
var _puffs: Array[MeshInstance3D] = []
var _bowls: Array[MeshInstance3D] = []
var _time_s: float = 0.0
var _held: PackedInt32Array = PackedInt32Array()
var _shown_bowls: int = -1


func configure(kitchen: KitchenScript, cast: DemoCastScript, clock: DemoClockScript, goods: GoodsScript) -> void:
	"""Draw this kitchen for this cast, on this clock, carrying these goods."""
	_kitchen = kitchen
	_cast = cast
	_clock = clock
	_goods = goods
	name = "KitchenView"
	_held.resize(cast.actor_count() if cast != null else 0)
	_held.fill(Catalog.NO_ITEM)
	_build_steam()
	_build_bowls()


func _build_steam() -> void:
	"""The steam's quads, over the cauldron, hidden."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = STEAM_COLOUR
	material.albedo_texture = _puff_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(STEAM_SIZE_M, STEAM_SIZE_M)
	for k: int in STEAM_PUFFS:
		var puff := MeshInstance3D.new()
		puff.mesh = quad
		puff.material_override = material.duplicate()
		puff.layers = Layers.SURFACE
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.visible = false
		add_child(puff)
		_puffs.append(puff)


static func _puff_texture() -> GradientTexture2D:
	"""A soft round puff: white fading to clear from the middle out."""
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _build_bowls() -> void:
	"""The bowls on the table, in two rows, hidden."""
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.075
	mesh.bottom_radius = 0.05
	mesh.height = 0.06
	var material := StandardMaterial3D.new()
	material.albedo_color = BOWL_COLOUR
	material.roughness = 0.8
	mesh.material = material
	var table: Vector2 = _kitchen.places.table
	for k: int in MAX_BOWLS:
		var bowl := MeshInstance3D.new()
		bowl.mesh = mesh
		bowl.layers = Layers.SURFACE
		var along: float = (float(k % 6) - 2.5) * 0.2
		var across: float = -0.12 if k < 6 else 0.12
		bowl.position = Vector3(table.x + along, TABLE_TOP_M + 0.03, table.y + across)
		bowl.visible = false
		add_child(bowl)
		_bowls.append(bowl)


func _process(_delta: float) -> void:
	"""Each frame: the steam, the bowls and what is carried."""
	refresh(_clock.frame_usec if _clock != null else 0)


func refresh(usec: int) -> void:
	"""Draw the kitchen as it is, `usec` of demo time on."""
	if _kitchen == null:
		return
	_time_s += float(usec) / 1000000.0
	_draw_steam(_kitchen.wip_key() != KitchenScript.FREE)
	var out: int = mini(_kitchen.store.at_table(), MAX_BOWLS)
	if out != _shown_bowls:
		_shown_bowls = out
		for k: int in MAX_BOWLS:
			_bowls[k].visible = k < out
	_draw_carried()


func _draw_steam(on: bool) -> void:
	"""The puffs rising and fading over the cauldron while a batch cooks."""
	var at: Vector2 = _kitchen.places.cauldron
	for k: int in STEAM_PUFFS:
		var puff: MeshInstance3D = _puffs[k]
		puff.visible = on
		if not on:
			continue
		var life: float = fposmod(_time_s + STEAM_LIFE_S * float(k) / float(STEAM_PUFFS), STEAM_LIFE_S) / STEAM_LIFE_S
		var drift := Vector2.from_angle(float(k) * 2.1) * 0.12 * life
		puff.position = Vector3(at.x + drift.x, STEAM_FROM_M + life * STEAM_RISE_M_S * STEAM_LIFE_S, at.y + drift.y)
		puff.scale = Vector3.ONE * (0.6 + life)
		(puff.material_override as StandardMaterial3D).albedo_color.a = STEAM_COLOUR.a * (1.0 - life)


func _draw_carried() -> void:
	"""Each carrier holds what the kitchen says it carries (see CARRIED)."""
	if _cast == null:
		return
	for who: int in _held.size():
		var item: int = _kitchen.carried_item(who)
		if item == _held[who]:
			continue
		var was: int = _held[who]
		_held[who] = item
		var actor := _cast.actor(who) as DemoActorScript
		if item == Catalog.NO_ITEM:
			if was != Catalog.NO_ITEM:
				actor.drop_held()
		else:
			_hold(actor, item)


func _hold(actor: DemoActorScript, item: int) -> void:
	"""Put `item` (or the pot, or water) in `actor`'s arms."""
	if item >= 0 and _goods.has_model(item):
		actor.hold(_goods.props.mesh_of(Catalog.ITEM_PROP[item]), _goods.hand_fit(item))
		return
	var key: StringName = WATER_KEY if item == KitchenScript.CARRY_WATER else POT_KEY
	var bound: AABB = _goods.props.drawn_bound(key)
	actor.hold(_goods.props.mesh_of(key), Transform3D(Basis.IDENTITY, -bound.get_center()) * _goods.props.fit_of(key))


func steam_shown() -> bool:
	"""Whether the steam shows (checks)."""
	return not _puffs.is_empty() and _puffs[0].visible


func bowls_shown() -> int:
	"""How many bowls are on the table (checks)."""
	var n: int = 0
	for bowl: MeshInstance3D in _bowls:
		n += 1 if bowl.visible else 0
	return n


func held_item(who: int) -> int:
	"""What resident `who` is drawn carrying (checks)."""
	return _held[who]
