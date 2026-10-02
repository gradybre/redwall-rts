extends HBoxContainer
## A bed's ROTATION in the farm panel (decision 0886; farm_sowing.gd): the three-entry cycle the tending policy "Sow empty
## beds in season" sows it by, and the crop it sows next, with "Rotation ▸" stepping to the next cycle its soil can follow.
## Shown for a laid bed while its readout shows. DEMO UI in the woodland skin. It only shows and asks: a press emits
## `step_requested`, and demo_farm.gd acts.

const SowingScript := preload("res://demo/farm/farm_sowing.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

signal step_requested

const TIP: String = "The next rotation this bed's soil can follow, from its first crop. A crop you choose with Plant… is always sown instead."

var _sowing: SowingScript = null
var _line: Label = null
var _step: Button = null


func _init() -> void:
	"""Built at once, hidden; filled by `refresh`."""
	name = "RotationBox"
	visible = false
	add_theme_constant_override(&"separation", 6)
	_line = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_line)
	_step = FarmUi.button("Rotation ▸", FarmUi.SMALL_PX)
	_step.tooltip_text = TIP
	_step.pressed.connect(func() -> void: step_requested.emit())
	add_child(_step)


func bind(sowing: SowingScript) -> void:
	"""Show these rotations."""
	_sowing = sowing


func refresh(bed: int) -> void:
	"""Rewrite the line for `bed` (hidden with no rotations bound or no bed)."""
	visible = _sowing != null and Catalog.is_bed(bed)
	if visible:
		_line.text = "Rotation: " + _sowing.rotation_words(bed)


func line() -> String:
	"""The rotation line as shown (checks)."""
	return _line.text


func step_button() -> Button:
	"""'Rotation ▸' (checks)."""
	return _step
