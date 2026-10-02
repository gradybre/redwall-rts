extends VBoxContainer
## The Pantry's KITCHEN tab (UI-SET-060 "Recipes and production"): who cooks, the next meals and what they take, the
## pot and the table, the water butt and the fuel, how the village is fed -- and the kitchen's orders, Cook and Draw
## water, each with its action card (decision 0332) from the kitchen's own decision (kitchen.gd `decide_meal`,
## `decide_draw`), so a button is pressable exactly when its order would be taken. Decision 0381. DEMO UI in the
## Pantry's woodland skin; it reads the kitchen and writes only through its orders.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const StoreScript := preload("res://demo/kitchen/meal_store.gd")
const FedScript := preload("res://demo/kitchen/nourishment.gd")

signal said(text: String)

const TITLE: String = "Kitchen"
const NOTE_PX: int = 14
## How many meals the tab lists, newest first.
const LAST_MEALS: int = 4
const TARGET_PX: float = 32.0
const KEEP_ON: String = "Keep water drawn: on"
const KEEP_OFF: String = "Keep water drawn: off"
const KEEP_TIP: String = "On: whoever is free draws the water the planned meals need. Off: only Draw water does."
const CANCEL_TIP: String = "Cancel the next meal: its food stays in store (a batch already cooking is half spoiled)"

var _kitchen: KitchenScript = null
var _members: Callable = Callable()
var _interrupt: Callable = Callable()
var _card: CardScript = CardScript.new()
var _cook_line: Label = null
var _shortage: Label = null
var _meals: Label = null
var _pot: Label = null
var _water: Label = null
var _village: Label = null
var _history: Label = null
## The dishes waiting for an ingredient the demo cannot produce yet, and why (decision 0603).
var _waiting: Label = null
var _cook: Button = null
var _draw: Button = null
var _keep: Button = null
var _cancel: Button = null


func configure(kitchen: KitchenScript, members: Callable, interrupt: Callable) -> void:
	"""Show this kitchen; `members() -> PackedInt32Array` is the selection, `interrupt(who) -> String` the cards'
	interrupts line."""
	_kitchen = kitchen
	_members = members
	_interrupt = interrupt
	name = "KitchenTab"
	add_theme_constant_override(&"separation", 6)
	_cook_line = _line(FarmUi.BODY_PX, Palette.INK)
	_shortage = _line(FarmUi.BODY_PX, Palette.CLAY)
	_meals = _line(FarmUi.BODY_PX, Palette.INK)
	_pot = _line(FarmUi.BODY_PX, Palette.INK)
	_water = _line(FarmUi.BODY_PX, Palette.INK)
	_village = _line(FarmUi.BODY_PX, Palette.INK)
	_history = _line(NOTE_PX, Palette.UMBER)
	add_child(_buttons())
	add_child(FarmUi.label(Words.tab_note(), NOTE_PX, Palette.UMBER))
	_waiting = _line(NOTE_PX, Palette.UMBER)


func _line(px: int, colour: Color) -> Label:
	"""A wrapping line, added."""
	var made: Label = FarmUi.label("", px, colour)
	add_child(made)
	return made


func _buttons() -> HFlowContainer:
	"""Cook, Draw water, Keep water drawn and Cancel."""
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 8)
	_cook = _button("Cook now", func() -> void: said.emit(_kitchen.order_cook(_selection())))
	_draw = _button("Draw water", func() -> void: said.emit(_kitchen.order_draw(_selection())))
	_keep = _button(KEEP_ON, func() -> void: _kitchen.set_keep_water(not _kitchen.keep_water))
	_cancel = _button("Cancel the next meal", func() -> void: said.emit(_kitchen.cancel_meal()))
	for made: Button in [_cook, _draw, _keep, _cancel]:
		row.add_child(made)
	return row


func _button(text: String, pressed: Callable) -> Button:
	"""A woodland button at the interactive floor's height."""
	var made: Button = FarmUi.button(text)
	made.custom_minimum_size.y = TARGET_PX
	made.pressed.connect(pressed)
	return made


func _selection() -> PackedInt32Array:
	"""Who is selected now."""
	return PackedInt32Array(_members.call()) if _members.is_valid() else PackedInt32Array()


func refresh() -> void:
	"""Every line and both cards, as the kitchen is now."""
	if _kitchen == null:
		return
	_cook_line.text = cook_text()
	var d: KitchenScript.Decision = _kitchen.decide_meal(_selection())
	_shortage.visible = not d.ok() and d.code != KitchenScript.NOTHING_TO_COOK
	_shortage.text = Words.cant(d.reason, d.fix) if _shortage.visible else ""
	_meals.text = meals_text()
	_pot.text = pot_text()
	_water.text = water_text()
	_village.text = village_text()
	var meals: String = _kitchen.last_meals_text(LAST_MEALS)
	_history.text = "Last meals:\n" + meals if not meals.is_empty() else ""
	_waiting.text = _kitchen.waiting_text()
	_keep.text = KEEP_ON if _kitchen.keep_water else KEEP_OFF
	_keep.tooltip_text = KEEP_TIP
	FarmUi.set_enabled(_cancel, not _kitchen.planned_keys().is_empty(), Words.NOTHING_PLANNED)
	if _cancel.tooltip_text.is_empty():
		_cancel.tooltip_text = CANCEL_TIP
	_kitchen.preview_cook_into(_card, _selection())
	_show_card(_cook)
	_kitchen.preview_draw_into(_card, _selection())
	_show_card(_draw)


func _show_card(button: Button) -> void:
	"""`button`'s tooltip is the card; enabled exactly when the order would be taken."""
	if _card.worker >= 0 and _interrupt.is_valid():
		_card.interrupts = String(_interrupt.call(_card.worker))
	FarmUi.set_card(button, _card.is_ok(), _card.text())


func cook_text() -> String:
	"""'Cook: Mouse keeper (the village cook) — Cooking wild oat porridge for breakfast'."""
	var who: int = _kitchen.cook if _kitchen.cook >= 0 else _kitchen.designated
	if who < 0:
		return "Cook: nobody"
	var role: String = "the village cook" if who == _kitchen.designated else "standing in"
	var doing: String = _kitchen.doing_text(who) if _kitchen.role_of(who) != KitchenScript.ROLE_NONE else "not at the kitchen now"
	return "Cook: %s (%s) — %s" % [_kitchen.name_of(who), role, doing]


func meals_text() -> String:
	"""The planned meals, a line each, with how many residents like the dish (decision 0601)."""
	var lines := PackedStringArray()
	for key: int in _kitchen.planned_keys():
		var plan: PackedInt32Array = _kitchen.plan_of(key)
		var liked: int = _kitchen.fed.likers_of(plan[0])
		lines.append("%s — %s%s: %d of %d batches cooked, %d more with food reserved%s" % [Words.meal_title(key),
			Rules.DISH_NAMES[plan[0]], " (liked by %d)" % liked if liked > 0 else "", plan[2], plan[1], plan[3],
			" (one cooking)" if plan[4] > 0 else ""])
	if lines.is_empty():
		return "Next meals: none planned"
	return "Next meals:\n" + "\n".join(lines)


func pot_text() -> String:
	"""Portions in the pot and at the table, by dish: porridge and soup always, any other dish while it has some."""
	var store: StoreScript = _kitchen.store
	var parts := PackedStringArray()
	for dish: int in Rules.DISH_COUNT:
		var held: int = store.portions_of(dish)
		if held > 0 or dish == Rules.DISH_PORRIDGE or dish == Rules.DISH_SOUP:
			parts.append("%s %d" % [Rules.DISH_SHORT[dish], held])
	return "Portions: %d in the pot, %d at the table (%s)" % [store.in_pot(), store.at_table(), ", ".join(parts)]


func water_text() -> String:
	"""The butt, what is on its way, what the meals need; the fuel."""
	return "Water butt by the well: %s of %s (%s on its way; the planned meals need %s) · Fuel: wood %s (0.1 U a batch)" % [
		Words.units(_kitchen.stores.water_milli_u), Words.units(_kitchen.stores.WATER_CAP_MILLI_U),
		Words.units(_kitchen.water_on_the_way()), Words.units(_kitchen.water_needed()),
		Words.units(_kitchen.stores.wood_milli_u)]


func village_text() -> String:
	"""How the village is fed."""
	var fed: FedScript = _kitchen.fed
	return "The village: %d fed · %d peckish · %d hungry" % [fed.count_in(Rules.FED), fed.count_in(Rules.PECKISH),
		fed.count_in(Rules.HUNGRY)]


func cook_button() -> Button:
	"""The Cook now button (checks)."""
	return _cook


func draw_button() -> Button:
	"""The Draw water button (checks)."""
	return _draw


func keep_button() -> Button:
	"""The Keep water drawn toggle (checks)."""
	return _keep


func cancel_button() -> Button:
	"""The Cancel button (checks)."""
	return _cancel


func waiting_shown() -> String:
	"""The waiting dishes' lines as shown (checks)."""
	return _waiting.text


func history_text() -> String:
	"""The last meals' lines as shown."""
	return _history.text


func shortage_text() -> String:
	"""The refusal line shown (empty when none)."""
	return _shortage.text if _shortage.visible else ""
