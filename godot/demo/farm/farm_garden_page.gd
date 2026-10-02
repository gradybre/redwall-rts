extends VBoxContainer
## The seasonal planner's KITCHEN GARDEN tab (review ECO-004 and feature #48, decision 0883; farm_garden.gd): the four
## sites -- laid out or bare, what grows, the walking each place costs -- a round of the garden, the garden's ONE PLAN
## (its crop, stepped with ◀ ▶, and "Sow every empty garden bed"), and whether the cook tends it between meals. A site's
## row opens its panel on the map, where it is laid out or taken up. DEMO UI in the woodland skin.

const GardenScript := preload("res://demo/farm/farm_garden.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const TableScript := preload("res://demo/farm/farm_planner_table.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Roles := preload("res://demo/farm/farm_crop_roles.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")

## A site's row was pressed: open its panel (the planner closes and the camera goes there).
signal bed_wanted(bed: int)

const NOTE_PX: int = 14
const SITE_RATIOS: PackedFloat32Array = [0.9, 1.1, 1.2, 0.9, 0.9]
const SITE_TITLES: Array[String] = ["Site", "Bed", "Growing", "To the shelf", "To the well"]
const INTRO: String = "Lay out small garden beds on any of the four sites round the garden paths (click a row, or the site on the map). The beds share one plan, the work shelf and the well; where you put them only changes the walking."
const HERBS: String = "Herb beds are not offered yet: herbs are woodland forage in the rules, with no field-crop row to grow by."

var wide: Array[Label] = []

var _garden: GardenScript = null
var _sim: SimScript = null
var _sites: TableScript = null
var _round: Label = null
var _crop: Label = null
var _sow_all: Button = null
var _cook: Button = null
var _answer: Label = null
var _cells: PackedStringArray = PackedStringArray()


func _init() -> void:
	"""Built at once; filled by `refresh` once a garden is bound."""
	name = "KitchenGardenPage"
	add_theme_constant_override(&"separation", 6)
	_note(INTRO, Palette.UMBER)
	_sites = TableScript.new()
	_sites.configure(PackedStringArray(SITE_TITLES), SITE_RATIOS, true)
	_sites.row_pressed.connect(func(bed: int) -> void: bed_wanted.emit(bed))
	add_child(_sites)
	_round = _note("", Palette.INK)
	add_child(FarmUi.label("The garden's plan", FarmUi.BODY_PX, Palette.INK, true))
	add_child(_crop_row())
	_sow_all = FarmUi.button("Sow every empty garden bed", NOTE_PX)
	_sow_all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_sow_all.pressed.connect(sow_all)
	add_child(_sow_all)
	_cook = FarmUi.button("", NOTE_PX)
	_cook.toggle_mode = true
	_cook.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_cook.pressed.connect(func() -> void: toggle_cook())
	add_child(_cook)
	_answer = _note("", Palette.INK)
	_note(HERBS, Palette.UMBER)


func _crop_row() -> HBoxContainer:
	"""◀ the garden's crop ▶."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var back: Button = FarmUi.button("◀", NOTE_PX)
	back.tooltip_text = "The previous crop the garden's loam takes"
	back.pressed.connect(step_crop.bind(-1))
	row.add_child(back)
	_crop = FarmUi.label("", NOTE_PX, Palette.INK)
	_crop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_crop)
	var next: Button = FarmUi.button("▶", NOTE_PX)
	next.tooltip_text = "The next crop the garden's loam takes"
	next.pressed.connect(step_crop.bind(1))
	row.add_child(next)
	return row


func _note(text: String, colour: Color) -> Label:
	"""A full-width wrapping line (the planner widens it: `wide`)."""
	var line: Label = FarmUi.label(text, NOTE_PX, colour)
	add_child(line)
	wide.append(line)
	return line


func bind(garden: GardenScript, sim: SimScript) -> void:
	"""Show this garden over this farm."""
	_garden = garden
	_sim = sim
	refresh()


# --- the player's choices --------------------------------------------------------------------------------------------

func step_crop(by: int) -> void:
	"""Step the garden's crop through the ingredients the garden's loam takes (catalog order, wrapping)."""
	if _garden == null:
		return
	var item: int = _garden.plan_item
	for k: int in Catalog.ITEM_COUNT:
		item = posmod(item + by, Catalog.ITEM_COUNT) if item >= 0 else (0 if by > 0 else Catalog.ITEM_COUNT - 1)
		if loam_takes(item):
			break
	_garden.set_plan_item(item)
	refresh()


static func loam_takes(item: int) -> bool:
	"""Whether the garden's soil (every site is loam: farm_catalog.gd) takes the ingredient's §5.6 row."""
	return (FarmingScript.CROP_ALLOWED_SOILS[Catalog.crop_of(item)] & (1 << Catalog.BED_SOILS[Catalog.GARDEN_FIRST])) != 0


func sow_all() -> String:
	"""THE GROUP's one order (farm_garden.gd `sow_all`). Returns the answer shown."""
	var said: String = _garden.sow_all() if _garden != null else ""
	_answer.text = said
	refresh()
	return said


func toggle_cook() -> void:
	"""The cook's garden hours on or off (#48)."""
	if _garden != null:
		_garden.set_cook_tends(not _garden.cook_tends)
	refresh()


# --- filling ---------------------------------------------------------------------------------------------------------

func refresh() -> void:
	"""Rewrite the sites, the round, the plan and the cook's hours from the garden as it stands."""
	if _garden == null:
		return
	_sites.set_row_count(Catalog.GARDEN_SITES)
	for k: int in Catalog.GARDEN_SITES:
		var bed: int = Catalog.GARDEN_FIRST + k
		site_cells_into(_garden, _sim, bed, _cells)
		_sites.set_row(k, _cells, bed, Palette.INK if _sim.is_laid(bed) else Palette.UMBER, "Show %s on the map" % _cells[0])
	var laid: int = _garden.laid_beds().size()
	_round.text = "A round of the garden — every bed watered from the well and its harvest carried to the shelf: about %d m of walking for %d bed%s." % [
		_garden.round_metres(), laid, "" if laid == 1 else "s"] if laid > 0 else "No garden bed is laid out yet."
	var item: int = _garden.plan_item
	_crop.text = "Garden crop: %s" % ("%s — %s; sow in %s" % [Catalog.ITEM_LABELS[item], Roles.traits_text(item),
		Text.window_text(Catalog.crop_of(item))] if Catalog.is_item(item) else "none chosen (◀ ▶)")
	FarmUi.set_enabled(_sow_all, Catalog.is_item(item) and laid > 0,
		"Choose the garden's crop (◀ ▶) and lay out a bed first")
	_cook.set_pressed_no_signal(_garden.cook_tends)
	_cook.text = "The cook tends the garden between meals (%02d:00–%02d:00): %s" % [GardenScript.WINDOW_FROM_HOUR,
		GardenScript.WINDOW_TO_HOUR, "on" if _garden.cook_tends else "off"]


static func site_cells_into(garden: GardenScript, sim: SimScript, bed: int, out: PackedStringArray) -> void:
	"""A site's cells: its name, its bed (or bare), what grows, and its walking."""
	out.resize(SITE_TITLES.size())
	out[0] = GardenScript.SITE_TITLE % (bed - Catalog.GARDEN_FIRST + 1)
	var laid: bool = sim.is_laid(bed)
	out[1] = "Bed %d" % (bed + 1) if laid else "bare (lay out)"
	var item: int = sim.item_of(bed)
	out[2] = Catalog.ITEM_LABELS[item] if Catalog.is_item(item) else ("empty" if laid else "—")
	out[3] = "about %.1f m" % garden.shelf_metres(bed)
	out[4] = "about %.1f m" % garden.well_metres(bed)


func site_table() -> TableScript:
	"""The sites' table (checks)."""
	return _sites


func sow_all_button() -> Button:
	"""'Sow every empty garden bed' (checks)."""
	return _sow_all


func cook_button() -> Button:
	"""The cook's garden hours toggle (checks)."""
	return _cook


func crop_text() -> String:
	"""The garden crop line as shown (checks)."""
	return _crop.text
