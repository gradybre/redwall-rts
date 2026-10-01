extends RefCounted
## THE DEMO'S ONE STORES: its wood, stone, planks and finds. Decision 0196 (live demo). Presentation
## only. Made once by demo_services.gd and shared by the tunnel works and the woods.
##
## THE TOP BAR SHOWS THIS STOCK. Its Wood, Stone and Planks cells read these three figures (the demo's HUD read
## model, demo/ui/demo_hud_model.gd, decision 0251) -- never written into the settlement simulation, whose
## own stock the demo does not run. Bracing and lanterns are paid from here. Quantities are integer milli-U
## (AGENTS.md: quantity_milli). It starts at START_WOOD_MILLI_U and START_STONE_MILLI_U (demo values),
## gains stone from rock quanta dug (tunnel_ground.gd), and gains WOOD from the woods
## (demo/forestry/): every log hauled to the log stack and every deadfall pile gathered.
##
## PLANKS (the stock the next step's bridges and boats build from): sawn at the sawhorse from this
## stock's wood (demo/forestry/), `plank_milli_u`. The API: `add_planks`, `can_pay_planks`,
## `pay_planks` -- all or nothing, like `pay` -- and `units_text` for the panels. `take_wood` is the
## sawyer's all-or-nothing draw on the wood.
##
## EARTH (decision 0401): the earth cleared off the tunnels' spoil heaps is kept here, by the open stockpile,
## `earth_milli_u` -- excavated earth, a plain material: never compost and never fertility (the adopted
## `excavated_earth` rule). Raising and banking a bed may fetch it back from here (farm_tunnels.gd EARTH). The API:
## `add_earth`, `take_earth` (all or nothing). It is not a top-bar figure; the panels' stores line shows it.
##
## THE FIT-OUT (demo/burrow/room_fixtures.gd, decision 0210) pays its fixtures with `pay_all` (wood, stone and planks,
## all or nothing) and takes a fixture's cost back with `refund`.
##
## FINDS. Every find dug up (tunnel_finds.gd) is tallied here by kind; relics also advance the story
## notices. A refused spend changes nothing (no partial debit).

const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")

const START_WOOD_MILLI_U: int = 40000
const START_STONE_MILLI_U: int = 20000

var wood_milli_u: int = START_WOOD_MILLI_U
var stone_milli_u: int = START_STONE_MILLI_U
var plank_milli_u: int = 0
## Earth kept by the stockpile (see EARTH), milli-U.
var earth_milli_u: int = 0
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


func pay_all(wood: int, stone: int, planks: int) -> bool:
	"""Take this much wood, stone and planks (milli-U) -- all of it, or (false) none (the rooms' fit-out, decision
	0210)."""
	if not can_pay(wood, stone) or not can_pay_planks(planks):
		return false
	wood_milli_u -= wood
	stone_milli_u -= stone
	plank_milli_u -= planks
	revision += 1
	return true


func refund(wood: int, stone: int, planks: int) -> void:
	"""Give wood, stone and planks (milli-U) back to the stock: a fixture taken out (decision 0210)."""
	add_wood(wood)
	add_stone(stone)
	add_planks(planks)


func holdings_text() -> String:
	"""What the stock holds, in whole units, for a refusal: "0 planks, 40 wood, 20 stone"."""
	return "%d planks, %d wood, %d stone" % [plank_milli_u / 1000, wood_milli_u / 1000, stone_milli_u / 1000]


func add_wood(milli_u: int) -> void:
	"""Wood from the woods comes into the stock (a hauled load, a gathered pile)."""
	if milli_u <= 0:
		return
	wood_milli_u += milli_u
	revision += 1


func take_wood(milli_u: int) -> bool:
	"""Take this much wood (milli-U) for sawing -- all of it, or (false) none."""
	if milli_u <= 0 or wood_milli_u < milli_u:
		return false
	wood_milli_u -= milli_u
	revision += 1
	return true


func add_planks(milli_u: int) -> void:
	"""Sawn planks come into the stock."""
	if milli_u <= 0:
		return
	plank_milli_u += milli_u
	revision += 1


func can_pay_planks(milli_u: int) -> bool:
	"""Whether the stock holds this many planks (milli-U)."""
	return milli_u >= 0 and plank_milli_u >= milli_u


func pay_planks(milli_u: int) -> bool:
	"""Take this many planks (milli-U) -- all of them, or (false) none."""
	if not can_pay_planks(milli_u):
		return false
	plank_milli_u -= milli_u
	revision += 1
	return true


func add_earth(milli_u: int) -> void:
	"""Earth carried off a spoil heap is kept here (see EARTH)."""
	if milli_u <= 0:
		return
	earth_milli_u += milli_u
	revision += 1


func take_earth(milli_u: int) -> bool:
	"""Take this much earth (milli-U) to raise or bank a bed -- all of it, or (false) none."""
	if milli_u <= 0 or earth_milli_u < milli_u:
		return false
	earth_milli_u -= milli_u
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
	"""The panels' stores line -- the same figures, in the same words, as the top bar's Wood, Stone and Planks -- and the
	earth kept by the stockpile, which the top bar does not show (see EARTH)."""
	return "Village stores: wood %s · stone %s · planks %s · earth %s" % [units_text(wood_milli_u),
		units_text(stone_milli_u), units_text(plank_milli_u), units_text(earth_milli_u)]


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
