extends RefCounted
## THE SOWING POLICY'S ROTATIONS (Brendan's balance ruling E5, 2026-10-01, as relayed by the coordinator: 12-18 beds "plus
## a default sowing policy"; decision 0886). Which crop an empty bed is sown with when the tending policy "Sow empty beds
## in season" is on (farm_tending.gd POLICY_SOW), by GDD §5.6's rotation rule and R06-JOB-005's cycle contract. Pure
## per-bed columns over the farm; it orders nothing itself.
##
## THE ROTATION. GDD §5.6: "Crop rotation is chosen manually per field or through an explicit three-entry cycle; default
## cycle grain→beans→roots." Each bed has a three-entry cycle (a demo bed is one plot, a field of its own) and a cursor.
## The demo grows ingredients, so each §5.6 row in a cycle is one ingredient: grain = wheat, beans = pea, roots = carrot
## (any of a row's ingredients grows by the same numbers: decision 0881). A bed's soil may refuse a row (clay refuses
## roots, sand refuses grain and beans), so a bed STARTS on the cycle its soil can follow (ROTATION_FOR_SOIL): loam on
## the GDD's default, clay on grain → beans → grain, sand on roots only. The player steps a bed through the cycles its
## soil can follow (the bed panel's Rotation, `step_rotation`); a crop the player chose with Plant… always wins over the
## cycle -- the policy sows the player's choice and never another crop.
##
## THE CURSOR follows R06-JOB-005: it advances ONCE, when the cycle's crop has been in the bed and the bed is empty again
## (harvested or cleared: `observe`), never when an entry is merely refused; it never skips a blocked entry and never
## substitutes a crop. An entry whose sowing window is not open waits for it (said once a bed and entry: `wait_words`).

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")

const ROTATION_GDD: int = 0
const ROTATION_NO_ROOTS: int = 1
const ROTATION_ROOTS: int = 2
const ROTATION_COUNT: int = 3
const ENTRIES: int = 3
const ROTATION_NAMES: Array[String] = ["Grain → beans → roots", "Grain → beans → grain", "Roots only"]
## Each cycle's three ingredients (farm_catalog.gd ITEM_KEYS rows): wheat, pea, carrot | wheat, pea, barley | carrot,
## turnip, radish.
const ROTATION_ITEMS: PackedInt32Array = [13, 11, 2, 13, 11, 14, 2, 1, 0]
## The cycle a bed starts on, by its soil (loam, clay, sand).
const ROTATION_FOR_SOIL: PackedInt32Array = [ROTATION_GDD, ROTATION_NO_ROOTS, ROTATION_ROOTS]

## Per bed: its cycle (ROTATION_*), its cursor (0..2), whether the cursor's crop has been in the bed since the cursor last
## moved, and whether its wait for a window has been said.
var rotation: PackedInt32Array = PackedInt32Array()
var cursor: PackedInt32Array = PackedInt32Array()
var _in_bed: PackedByteArray = PackedByteArray()
var _said_wait: PackedByteArray = PackedByteArray()
## Bumped by every change a reader could see.
var revision: int = 0


func _init() -> void:
	"""Every bed on its soil's cycle, at the cycle's first entry."""
	rotation.resize(Catalog.BED_COUNT)
	cursor.resize(Catalog.BED_COUNT)
	_in_bed.resize(Catalog.BED_COUNT)
	_said_wait.resize(Catalog.BED_COUNT)
	for bed: int in Catalog.BED_COUNT:
		rotation[bed] = ROTATION_FOR_SOIL[Catalog.BED_SOILS[bed]]


static func item_at(cycle: int, entry: int) -> int:
	"""The ingredient of entry `entry` of cycle `cycle`."""
	return ROTATION_ITEMS[cycle * ENTRIES + entry]


func entry_item(bed: int) -> int:
	"""The ingredient the bed's cycle sows next."""
	return item_at(rotation[bed], cursor[bed])


static func follows(cycle: int, soil: int) -> bool:
	"""Whether a soil takes every crop of a cycle (§5.6 allowed soils)."""
	for entry: int in ENTRIES:
		var crop: int = Catalog.crop_of(item_at(cycle, entry))
		if (FarmingScript.CROP_ALLOWED_SOILS[crop] & (1 << soil)) == 0:
			return false
	return true


func step_rotation(bed: int) -> String:
	"""The bed's next cycle its soil can follow (wrapping), from its first entry. Returns the answer shown."""
	if not Catalog.is_bed(bed):
		return ""
	var soil: int = Catalog.BED_SOILS[bed]
	for k: int in range(1, ROTATION_COUNT + 1):
		var cycle: int = (rotation[bed] + k) % ROTATION_COUNT
		if follows(cycle, soil):
			rotation[bed] = cycle
			break
	cursor[bed] = 0
	_in_bed[bed] = 0
	_said_wait[bed] = 0
	revision += 1
	return "Bed %d's rotation: %s" % [bed + 1, rotation_words(bed)]


func crop_to_sow(sim: SimScript, bed: int) -> int:
	"""What the policy sows in `bed`: the player's own choice when there is one, else the cycle's entry."""
	var chosen: int = sim.chosen_of(bed)
	return chosen if Catalog.is_item(chosen) else entry_item(bed)


func observe(sim: SimScript, bed: int) -> void:
	"""Follow the bed (see THE CURSOR): the cycle's crop standing marks it; the bed empty again after it advances."""
	var stage: int = sim.stage_of(bed)
	if stage == SimScript.STAGE_EMPTY or stage == SimScript.STAGE_SITE:
		if _in_bed[bed] == 1:
			_in_bed[bed] = 0
			_said_wait[bed] = 0
			cursor[bed] = (cursor[bed] + 1) % ENTRIES
			revision += 1
		return
	if sim.item_of(bed) == entry_item(bed) and _in_bed[bed] == 0:
		_in_bed[bed] = 1


func wait_words(sim: SimScript, bed: int) -> String:
	"""Why the bed's crop is not sown now, said ONCE per bed and entry ('' when it can be, or it was said)."""
	if _said_wait[bed] == 1:
		return ""
	var item: int = crop_to_sow(sim, bed)
	var why: String = Text.pick_reason(sim, bed, item)
	if why.is_empty():
		return ""
	_said_wait[bed] = 1
	return "Bed %d's %s waits: %s" % [bed + 1, Catalog.ITEM_LABELS[item].to_lower(), why]


func rotation_words(bed: int) -> String:
	"""'Grain → beans → roots (wheat, pea, carrot) · next: wheat'."""
	var cycle: int = rotation[bed]
	return "%s (%s, %s, %s) · next: %s" % [ROTATION_NAMES[cycle], Catalog.ITEM_LABELS[item_at(cycle, 0)].to_lower(),
		Catalog.ITEM_LABELS[item_at(cycle, 1)].to_lower(), Catalog.ITEM_LABELS[item_at(cycle, 2)].to_lower(),
		Catalog.ITEM_LABELS[entry_item(bed)].to_lower()]
