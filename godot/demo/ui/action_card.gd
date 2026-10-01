extends RefCounted
## THE ACTION CARD: one shape for what any demo action will do, shown on its button before it is pressed. Decision
## 0332 (review group H: findings F33 and F44). Presentation only: a card is filled by the SAME function that decides
## the order -- each system's `decide`/`preview_into` (farm_crew.gd, forest_crew.gd, tunnel_actions.gd,
## room_fixtures.gd, demo_waterplay.gd) -- and is never consulted by the order itself, so the preview and the
## execution cannot disagree.
##
## WHAT A CARD SAYS, in this order (the review's formatting rule: warning, reason and the way out first):
##
##     Brace tunnel 3                                 the verb and its object
##     Can't now: the demo stores are short ...       only when refused: the exact refusal the order would say,
##     To fix: Woods ▸ Saw planks ...                 and how to put it right (a panel ▸ button where one does it)
##     Braced: no seep, no roof fall                  the result
##     Wood: have 40.0 U · need 2.0 U                 each cost, have / need, from the stores the HUD reads
##     Work: about 1.3 game hours, plus the walk      the work in game hours on the demo calendar
##     Who: Assign selected: Mouse keeper (nearest of 3)        the assignment (F44: the system's real rule)
##     Interrupts: Felling the oak — goes back to it after      what that resident stops, and whether it resumes
##     Needs: a finished tunnel; a resident who fits its bore   prerequisites
##
## THE WORK in game hours: every system's work runs on demo microseconds, the same microseconds the ONE calendar
## turns into hours (demo_calendar.gd HOUR_USEC), so a work time in demo microseconds is exactly that many game hours
## of the clock the HUD shows. Walking is not counted (it depends on the route); the card says so.
##
## THE SIZE. UI-SET-073 bounds a tooltip to 360 x 240 logical px. Godot's tooltip label does not wrap, so the card
## breaks its own lines at LINE_CHARS (about 340 px at the tooltip's type) and keeps to the lines above.
##
## UNITS are the stores' formatter (tunnel_stores.gd `units_text`, the HUD's), here and nowhere else in the card.
##
## THE LOOK. The demo panels sit outside the HUD's skinned theme, so a card's tooltip would draw in the engine's grey.
## `dress` gives a card's button a theme holding only the HUD skin's tooltip items (woodland_theme_patch.gd: the map
## piece, ink text) at TIP_PX: the button keeps its own look, and its tooltip is the HUD's.

const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## A card's work is unknown (no line is printed).
const NO_WORK: int = -1
## No resident is named (the job is queued, or refused).
const NOBODY: int = -1
## Where a card's lines break (see THE SIZE).
const LINE_CHARS: int = 46
const CANT: String = "Can't now: "
const FIX: String = "To fix: "
const WORK: String = "Work: "
const WHO: String = "Who: "
const NEEDS: String = "Needs: "
const WALK_NOTE: String = ", plus the walk"
## The card's type size (UI-SET-073's tooltip, the panels' body size).
const TIP_PX: int = 15
const TIP_MARGINS: PackedFloat32Array = [12.0, 9.0, 12.0, 10.0]

static var _tip_theme: Theme = null
## The HUD's effective scale S the tooltips are drawn at (scale_tooltips; decision 0391).
static var _tip_scale: float = 1.0

## The verb and its object ("Brace tunnel 3").
var verb: String = ""
## What the action does when it is done.
var result: String = ""
## Each cost: its name, what the stores hold, what the action takes (milli-U).
var cost_names: PackedStringArray = PackedStringArray()
var cost_have: PackedInt64Array = PackedInt64Array()
var cost_need: PackedInt64Array = PackedInt64Array()
## The work, in demo microseconds (NO_WORK: unknown), and anything said after it.
var work_usec: int = NO_WORK
var work_note: String = WALK_NOTE
## The assignment preview ("Assign selected: Mouse keeper (nearest of 3)"), and the resident named in it.
var who: String = ""
var worker: int = NOBODY
## What that resident will stop doing, and whether it goes back to it (demo_command.gd `interrupt_text`).
var interrupts: String = ""
var prerequisites: PackedStringArray = PackedStringArray()
## The refusal's code (the order's own), its words, and how to put it right. Empty `reason`: the action may be done.
var code: String = ""
var reason: String = ""
var fix: String = ""


func reset(p_verb: String) -> RefCounted:
	"""Empty the card for `p_verb` (a card is reused frame to frame). Returns itself."""
	verb = p_verb
	result = ""
	cost_names.clear()
	cost_have.clear()
	cost_need.clear()
	work_usec = NO_WORK
	work_note = WALK_NOTE
	who = ""
	worker = NOBODY
	interrupts = ""
	prerequisites.clear()
	code = ""
	reason = ""
	fix = ""
	return self


func add_cost(what: String, have_milli: int, need_milli: int) -> void:
	"""A cost row: `need_milli` of `what` from stores holding `have_milli`."""
	cost_names.append(what)
	cost_have.append(have_milli)
	cost_need.append(need_milli)


func refuse(p_code: String, words: String, how: String = "") -> void:
	"""The action is refused: the order's own code, the words it says, and the way to put it right."""
	code = p_code
	reason = words
	fix = how


func clear_refusal() -> void:
	"""The action may be done after all (a caller that knows better than the decision it read: Plant… opens a list)."""
	code = ""
	reason = ""
	fix = ""


func is_ok() -> bool:
	"""Whether the action may be ordered now."""
	return reason.is_empty()


func short_row() -> int:
	"""The first cost row the stores cannot meet (-1: none)."""
	for k: int in cost_need.size():
		if cost_have[k] < cost_need[k]:
			return k
	return -1


func text() -> String:
	"""The whole card, its lines broken at LINE_CHARS (see the header)."""
	var lines := PackedStringArray([verb])
	if not is_ok():
		lines.append(CANT + reason)
		if not fix.is_empty():
			lines.append(FIX + fix)
	if not result.is_empty():
		lines.append(result)
	for k: int in cost_names.size():
		lines.append(cost_line(k))
	if work_usec >= 0:
		lines.append(WORK + hours_text(work_usec) + work_note)
	if not who.is_empty():
		lines.append(WHO + who)
	if not interrupts.is_empty():
		lines.append(interrupts)
	if not prerequisites.is_empty():
		lines.append(NEEDS + "; ".join(prerequisites))
	return wrap_lines(lines)


func cost_line(k: int) -> String:
	"""Cost row `k`: "Planks: have 0.0 U · need 4.7 U"."""
	return "%s: have %s · need %s" % [cost_names[k], amount_text(cost_have[k]), need_text(cost_need[k])]


# --- THE COMMAND GRAMMAR (F44): one way, in every panel, of saying who an order goes to -------------------

static func assign_selected(name: String, free: int, selected: int) -> String:
	"""The order goes to a selected resident now: "Assign selected: Mouse keeper (nearest of 3)" -- "(nearest free of
	3 selected)" when some selected are busy with this kind of work, no parenthesis when it is the only one."""
	if selected <= 1:
		return "Assign selected: %s" % name
	if free >= selected:
		return "Assign selected: %s (nearest of %d)" % [name, selected]
	return "Assign selected: %s (nearest free of %d selected)" % [name, selected]


static func assign_first(name: String, selected: int, who_can: String) -> String:
	"""The order goes to the FIRST selected resident who can do it (the tunnels' rule): "Assign selected: Mouse keeper
	(first of 3 who fits the bore)"."""
	if selected <= 1:
		return "Assign selected: %s" % name
	return "Assign selected: %s (first of %d %s)" % [name, selected, who_can]


static func assign_village(name: String, why: String) -> String:
	"""The order goes to a resident the village's own rule picks, nobody selected being able to: "Assign Mole digger
	(the village's most skilled free digger)"."""
	return "Assign %s (%s)" % [name, why]


static func lead_with(lead: String, free: int, selected: int, helpers: int, helper_word: String) -> String:
	"""A lead from the selection and helpers from the rest: "Lead: Squirrel forester (nearest of 3) + 2 haulers"."""
	var head: String = assign_selected(lead, free, selected).replace("Assign selected: ", "Lead: ")
	if helpers <= 0:
		return head
	return "%s + %d %s" % [head, helpers, helper_word]


static func queue_for(crew: String, names: PackedStringArray, selected: int) -> String:
	"""The order waits for a routine crew: "Queue for the field crew: Mouse fieldworker or Squirrel gatherer, whoever
	is free first"; with nobody on that crew, says to select someone."""
	var head: String = "Queue for %s" % crew
	if selected > 0:
		head += " (no selected resident is free for it)"
	if names.is_empty():
		return head + ": nobody is on it — select residents to do it"
	return "%s: %s%s" % [head, " or ".join(names), ", whoever is free first" if names.size() > 1 else ""]


static func specialist(role: String, name: String, selected: int) -> String:
	"""The order waits for a specialist: "Queue for the bridgewright: Beaver bridgewright (specialist)"."""
	var head: String = "Queue for the %s" % role
	if selected > 0:
		head += " (no selected resident can take it)"
	if name.is_empty():
		return head + ": none in the village — select residents to do it"
	return "%s: %s (specialist)" % [head, name]


static func under_way(name: String) -> String:
	"""The same job is under way already: "Already under way: Mouse fieldworker is on it"."""
	return "Already under way: %s is on it" % name


static func dress(button: Control) -> void:
	"""Give `button` the card tooltip's theme (see THE LOOK), once."""
	if button.theme == null:
		button.theme = tooltip_theme()


static func tooltip_theme() -> Theme:
	"""The one theme holding the HUD skin's tooltip items (made once), at the tooltips' scale."""
	if _tip_theme == null:
		_tip_theme = Theme.new()
		_tip_theme.set_color(&"font_color", &"TooltipLabel", Palette.INK)
		_apply_tip_scale()
	return _tip_theme


static func scale_tooltips(scale: float) -> void:
	"""Draw every card's tooltip at the HUD's effective scale S (the interface scale included: demo_ui_scale.gd). A
	tooltip is a pop-up of the viewport, not a child of its panel's scaled frame, so it does not grow with the panel:
	its type and margins are scaled here instead (decision 0391, review F35)."""
	if is_equal_approx(scale, _tip_scale):
		return
	_tip_scale = scale
	if _tip_theme != null:
		_apply_tip_scale()


static func tip_px() -> int:
	"""The tooltips' type size now: TIP_PX at the HUD's scale."""
	return roundi(float(TIP_PX) * _tip_scale)


static func _apply_tip_scale() -> void:
	"""The theme's type size and panel margins at the current scale."""
	var margins := PackedFloat32Array()
	for margin: float in TIP_MARGINS:
		margins.append(margin * _tip_scale)
	_tip_theme.set_stylebox(&"panel", &"TooltipPanel", Styles.box(Styles.PIECE_MAP, margins))
	_tip_theme.set_font_size(&"font_size", &"TooltipLabel", tip_px())


static func amount_text(milli: int) -> String:
	"""A quantity as the HUD and the stores' panels print it ("4.7 U")."""
	return StoresScript.units_text(milli)


static func need_text(milli: int) -> String:
	"""A requirement, stated exactly: the HUD's tenths, or hundredths when it has them ("0.25 U" -- the floored tenth
	would understate what is needed)."""
	if milli % 100 == 0:
		return amount_text(milli)
	return "%d.%02d U" % [milli / 1000, (milli % 1000) / 10]


static func hours_text(usec: int) -> String:
	"""Demo microseconds as game hours on the demo calendar, to the tenth, rounded up (a sliver of work is never
	"0.0"): "about 2.4 game hours", "about 1 game hour"."""
	var tenths: int = (usec * 10 + CalendarScript.HOUR_USEC - 1) / CalendarScript.HOUR_USEC
	if tenths == 10:
		return "about 1 game hour"
	return "about %d.%d game hours" % [tenths / 10, tenths % 10]


static func wrap_lines(lines: PackedStringArray) -> String:
	"""Each line broken at word boundaries so none runs past LINE_CHARS; continuation lines indented."""
	var out := PackedStringArray()
	for line: String in lines:
		var rest: String = line
		var first: bool = true
		while rest.length() > LINE_CHARS:
			var cut: int = rest.rfind(" ", LINE_CHARS)
			if cut <= 0:
				cut = LINE_CHARS
			out.append(("" if first else "  ") + rest.left(cut))
			rest = rest.substr(cut).strip_edges(true, false)
			first = false
		out.append(("" if first else "  ") + rest)
	return "\n".join(out)
