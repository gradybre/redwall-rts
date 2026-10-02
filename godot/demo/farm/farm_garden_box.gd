extends VBoxContainer
## A kitchen-garden site in the farm panel (review ECO-004 and #48, decision 0883; farm_garden.gd): for a site not laid
## out, what it is, what its place would cost in walking and "Lay out a bed here"; for a laid garden bed, its walking,
## who tends it and "Take up". DEMO UI in the woodland skin. It only shows and asks: a press emits `lay_out_requested` or
## `take_up_requested`, and demo_farm.gd acts.

const GardenScript := preload("res://demo/farm/farm_garden.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

signal lay_out_requested
signal take_up_requested

const SITE_TEXT: String = "A place for one small garden bed (a 2 m tile) in the kitchen garden, round the garden paths across the road from the kitchen. Laying it out is a designation — at once and free; the work is the sowing. The garden's beds share one plan (Planner ▸ Kitchen garden), its work shelf and the well."
const LAY_OUT_TIP: String = "Lay out a garden bed on this site: it can be sown at once (no cost; the shelf goes up with the garden's first bed)"
const COOK_ON: String = "Between meals (%02d:00–%02d:00) the cook tends it; otherwise anyone may."
const COOK_OFF: String = "Anyone free tends it (the cook's garden hours are off: Planner ▸ Kitchen garden)."

var _garden: GardenScript = null
var _sim: SimScript = null
var _about: Label = null
var _walk: Label = null
var _tends: Label = null
var _lay_out: Button = null
var _take_up: Button = null


func _init() -> void:
	"""Built at once, hidden; filled by `refresh`."""
	name = "GardenBox"
	visible = false
	add_theme_constant_override(&"separation", 4)
	_about = FarmUi.label(SITE_TEXT, FarmUi.SMALL_PX, Palette.UMBER)
	add_child(_about)
	_walk = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	add_child(_walk)
	_tends = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	add_child(_tends)
	_lay_out = FarmUi.button("Lay out a bed here")
	_lay_out.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lay_out.pressed.connect(func() -> void: lay_out_requested.emit())
	add_child(_lay_out)
	_take_up = FarmUi.button("Take up the bed")
	_take_up.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_take_up.pressed.connect(func() -> void: take_up_requested.emit())
	add_child(_take_up)


func bind(garden: GardenScript, sim: SimScript) -> void:
	"""Show this garden over this farm."""
	_garden = garden
	_sim = sim


func refresh(bed: int) -> void:
	"""Rewrite the box for `bed` (hidden for a field bed, or with no garden bound)."""
	visible = _garden != null and Catalog.is_garden(bed)
	if not visible:
		return
	var laid: bool = _sim.is_laid(bed)
	_about.visible = not laid
	_walk.text = "Walking: %s" % _garden.walking_text(bed)
	_tends.visible = laid
	_tends.text = COOK_ON % [GardenScript.WINDOW_FROM_HOUR, GardenScript.WINDOW_TO_HOUR] if _garden.cook_tends else COOK_OFF
	_lay_out.visible = not laid
	FarmUi.set_card(_lay_out, true, LAY_OUT_TIP)
	_take_up.visible = laid
	var code: StringName = _sim.take_up_refusal(bed)
	FarmUi.set_card(_take_up, code == SimScript.REFUSE_NONE, "Take the bed up: the site is bare again (its soil keeps its history)"
		if code == SimScript.REFUSE_NONE else "Can't take it up: %s — %s" % [FarmCard.reason_words(code), FarmCard.fix_for(code)])


func lay_out_button() -> Button:
	"""'Lay out a bed here' (checks)."""
	return _lay_out


func take_up_button() -> Button:
	"""'Take up the bed' (checks)."""
	return _take_up


func walk_line() -> String:
	"""The walking line as shown (checks)."""
	return _walk.text
