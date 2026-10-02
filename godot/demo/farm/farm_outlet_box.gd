extends VBoxContainer
## A bed's TUNNEL OUTLET in the farm panel (review ECO-006, decision 0884; farm_sim.gd TUNNEL OUTLETS): what runs under
## the bed (a dry tunnel, one carrying the stream's water, or none), whether an outlet is fitted, the Fit outlet job
## (its action card is the panel's, farm_bed_panel.gd), and -- fitted -- its three settings, Shut, Drain and Feed, each
## button's tooltip saying what it would do to THIS bed (the affected-bed preview), the setting now pressed. Shown only
## for a bed with a tunnel under it or an outlet fitted. DEMO UI in the woodland skin. It only shows and asks: a press
## emits `fit_requested` or `outlet_chosen`, and demo_farm.gd acts.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

signal fit_requested
signal outlet_chosen(mode: int)

const TITLE: String = "Tunnel outlet"
const TRANSPORT_ONLY: String = "A tunnel is transport only: it changes nothing here until an outlet is fitted and set."
const EFFECTS: Array[String] = [
	"Shut: transport only — the bed keeps its own water, as if no tunnel ran under it",
	"Drain: the bed sheds into the dry tunnel under it, up to %d%% a day, down toward the low side of its range",
	"Feed: the stream's water in the tunnel pulls the bed toward the middle of its range, up to %d%% a day",
]
const DRAIN_NO_DRY: String = " — but no dry tunnel runs under it now: nothing drains"
const FEED_NO_WATER: String = " — but the tunnel under it carries no water now: nothing is fed"

var _sim: SimScript = null
var _facts: Label = null
var _state: Label = null
var _fit: Button = null
var _row: HBoxContainer = null
var _buttons: Array[Button] = []


func _init() -> void:
	"""Built at once, hidden; filled by `refresh`."""
	name = "OutletBox"
	visible = false
	add_theme_constant_override(&"separation", 4)
	add_child(FarmUi.label(TITLE, FarmUi.BODY_PX, Palette.INK, true))
	_facts = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	add_child(_facts)
	_state = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	add_child(_state)
	_fit = FarmUi.button("Fit outlet")
	_fit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fit.pressed.connect(func() -> void: fit_requested.emit())
	add_child(_fit)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 6)
	for mode: int in SimScript.OUTLET_NAMES.size():
		var made: Button = FarmUi.button(SimScript.OUTLET_NAMES[mode])
		made.toggle_mode = true
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		made.pressed.connect(func() -> void: outlet_chosen.emit(mode))
		_row.add_child(made)
		_buttons.append(made)
	add_child(_row)


func bind(sim: SimScript) -> void:
	"""Show this farm's outlets."""
	_sim = sim


static func wanted(sim: SimScript, bed: int) -> bool:
	"""Whether the box shows for a bed: laid, with a tunnel under it or an outlet fitted."""
	return sim.is_laid(bed) and (sim.has_outlet(bed) or sim.dry_tunnel_under(bed) or sim.wet_tunnel_under(bed))


func refresh(bed: int) -> void:
	"""Rewrite the facts, the state and the buttons for `bed` (hidden when it has nothing to show)."""
	visible = _sim != null and Catalog.is_bed(bed) and wanted(_sim, bed)
	if not visible:
		return
	_facts.text = "%s %s" % [facts_text(_sim, bed), TRANSPORT_ONLY]
	var fitted: bool = _sim.has_outlet(bed)
	_fit.visible = not fitted
	_row.visible = fitted
	_state.text = state_text(_sim, bed)
	for mode: int in _buttons.size():
		var current: bool = fitted and _sim.outlet_of(bed) == mode
		_buttons[mode].set_pressed_no_signal(current)
		FarmUi.set_card(_buttons[mode], not current, effect_text(_sim, bed, mode) + (" (set now)" if current else ""))


static func facts_text(sim: SimScript, bed: int) -> String:
	"""What runs under the bed: 'A dry tunnel runs under this bed.' / '... carrying the stream's water ...'."""
	if sim.wet_tunnel_under(bed) and sim.dry_tunnel_under(bed):
		return "A dry tunnel and one carrying the stream's water run under this bed."
	if sim.wet_tunnel_under(bed):
		return "A tunnel carrying the stream's water runs under this bed."
	if sim.dry_tunnel_under(bed):
		return "A dry tunnel runs under this bed."
	return "No finished tunnel runs under this bed now."


static func state_text(sim: SimScript, bed: int) -> String:
	"""'No outlet fitted (transport only)' or 'Outlet: Drain — draining the bed into the tunnel'."""
	if not sim.has_outlet(bed):
		return "No outlet fitted (transport only)"
	var mode: int = sim.outlet_of(bed)
	var doing: String = "transport only"
	if mode == SimScript.OUTLET_DRAIN:
		doing = "draining the bed into the tunnel" if sim.is_drained(bed) else "nothing: no dry tunnel under it"
	elif mode == SimScript.OUTLET_FEED:
		doing = "feeding the bed from the tunnel" if sim.is_irrigated(bed) else "nothing: no water in the tunnel"
	return "Outlet: %s — %s" % [SimScript.OUTLET_NAMES[mode], doing]


static func effect_text(sim: SimScript, bed: int, mode: int) -> String:
	"""What setting `mode` does to this bed (the affected-bed preview), with why it would do nothing now."""
	if mode == SimScript.OUTLET_DRAIN:
		@warning_ignore("integer_division") return EFFECTS[mode] % (SimScript.DRAIN_PER_DAY / 100) + ("" if sim.dry_tunnel_under(bed) else DRAIN_NO_DRY)
	if mode == SimScript.OUTLET_FEED:
		@warning_ignore("integer_division") return EFFECTS[mode] % (SimScript.IRRIGATE_PER_DAY / 100) + ("" if sim.wet_tunnel_under(bed) else FEED_NO_WATER)
	return EFFECTS[mode]


func fit_button() -> Button:
	"""The Fit outlet button (the panel fills its action card; checks)."""
	return _fit


func setting_button(mode: int) -> Button:
	"""Setting `mode`'s button (checks)."""
	return _buttons[mode]


func state_line() -> String:
	"""The state line as shown (checks)."""
	return _state.text
