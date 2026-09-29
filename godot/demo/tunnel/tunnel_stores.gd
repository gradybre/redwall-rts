extends RefCounted
## The demo's own stores for its tunnel works. Decision 0196 (live demo). Presentation only.
##
## THE HUD'S WOOD AND STONE ARE THE SIMULATION'S (UIManager reads EconomySystem.stock_units), and the
## demo never writes into the simulation -- so bracing and lanterns are paid from THIS stock, shown
## in the tunnel panel and labelled as the demo's. Quantities are integer milli-U (AGENTS.md:
## quantity_milli). It starts at START_WOOD_MILLI_U and START_STONE_MILLI_U (demo values) and gains
## stone from rock quanta dug (tunnel_ground.gd).
##
## FINDS. Every find dug up (tunnel_finds.gd) is tallied here by kind; relics also advance the story
## notices. A refused spend changes nothing (no partial debit).

const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")

const START_WOOD_MILLI_U: int = 40000
const START_STONE_MILLI_U: int = 20000

var wood_milli_u: int = START_WOOD_MILLI_U
var stone_milli_u: int = START_STONE_MILLI_U
## Per find kind (FindsScript.FIND_*): how many have been dug up.
var finds: PackedInt32Array = PackedInt32Array()
## Bumped on every change, so the panel redraws only when something changed.
var revision: int = 0


func _init() -> void:
	"""Size the finds tally once."""
	finds.resize(FindsScript.KIND_COUNT)


func can_pay(wood: int, stone: int) -> bool:
	"""Whether the stock holds this much wood and stone (milli-U)."""
	return wood >= 0 and stone >= 0 and wood_milli_u >= wood and stone_milli_u >= stone


func pay(wood: int, stone: int) -> bool:
	"""Take this much wood and stone (milli-U) from the stock -- all of it, or (false) none."""
	if not can_pay(wood, stone):
		return false
	wood_milli_u -= wood
	stone_milli_u -= stone
	revision += 1
	return true


func add_stone(milli_u: int) -> void:
	"""Stone dug out of rock comes into the stock."""
	if milli_u <= 0:
		return
	stone_milli_u += milli_u
	revision += 1


func add_find(kind: int) -> void:
	"""Tally one find of this kind (FindsScript.FIND_*)."""
	finds[kind] += 1
	revision += 1


static func units_text(milli_u: int) -> String:
	"""Milli-U as the panel shows it: whole units and one decimal, floored ("12.5 U")."""
	return "%d.%d U" % [milli_u / 1000, (milli_u % 1000) / 100]


func stock_line() -> String:
	"""The panel's stores line."""
	return "Demo stores: wood %s · stone %s" % [units_text(wood_milli_u), units_text(stone_milli_u)]


func finds_line() -> String:
	"""The panel's finds tally -- and, once a relic has turned up, the latest relic's story."""
	var line := "Finds: %d flint · %d clay · %s · %s" % [finds[FindsScript.FIND_FLINT], finds[FindsScript.FIND_CLAY],
		counted(finds[FindsScript.FIND_ROOT_STORE], "root store", "root stores"),
		counted(finds[FindsScript.FIND_RELIC], "relic", "relics")]
	if finds[FindsScript.FIND_RELIC] == 0:
		return line
	return line + "\n" + FindsScript.relic_story(finds[FindsScript.FIND_RELIC])


static func counted(n: int, one: String, many: String) -> String:
	"""e.g. "1 relic", "2 relics"."""
	return "%d %s" % [n, one if n == 1 else many]
