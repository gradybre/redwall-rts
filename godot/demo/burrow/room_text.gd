extends RefCounted
## A room's fit-out in words, for the "Tunnels & burrows (demo)" panel (tunnel_ext.gd, tunnel_panel.gd `show_room`).
## Decision 0210. Presentation only; nothing here decides anything.
##
## A HOME: its comfort (room_fixtures.gd COMFORT) with its word, who sleeps in it and whether its hearth burns (a
## large bed, decision 0211, is a bed the palette offers beside the burrow bed, in the same alcoves). A
## CELLAR: what it holds of its racks' capacity, and the cool rule's verdict with its spoilage. Then the palette, a
## row a kind -- how many are in, how many are planned, of how many places, and the cost -- and the suggested layout
## with what it would cost now. `answer` is what a fit-out button said.

const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")

const NO_STORE: String = "No store yet: give it a shelf, a rack, a bin or hanging stores"
## A fit-out button's action: "fit:add:<kind>", "fit:take:<kind>", "fit:suggest" (tunnel_panel.gd).
const FIT_PREFIX: String = "fit:"
const FIT_ADD: String = "add"
const FIT_TAKE: String = "take"
const FIT_SUGGEST: String = "suggest"


static func name_of(graph: RefCounted, r: int) -> String:
	"""A room's name: "Burrow home 1", "Root cellar 2"."""
	return "%s %d" % [RoomsScript.NAMES[graph.rooms.template[r]], r + 1]


static func title(graph: RefCounted, r: int) -> String:
	"""The panel's heading for a room: its name and, a home, its comfort's word; a cellar, whether it is cool."""
	var fit: FixturesScript = graph.fit
	if graph.rooms.template[r] == RoomsScript.TEMPLATE_HOME:
		return "%s — %s" % [name_of(graph, r), FixturesScript.comfort_word(fit.comfort(graph, r))]
	return "%s — %s" % [name_of(graph, r), "cool" if fit.is_cool(graph, r) else "not cool"]


static func body(graph: RefCounted, r: int, night: RefCounted, stored: Callable) -> String:
	"""The panel's lines for a room (see the header)."""
	if graph.rooms.template[r] == RoomsScript.TEMPLATE_HOME:
		return _home_body(graph, r, night)
	return _cellar_body(graph, r, int(stored.call(r)) if stored.is_valid() else 0)


static func _home_body(graph: RefCounted, r: int, night: RefCounted) -> String:
	"""A home's comfort, sleepers and hearth."""
	var fit: FixturesScript = graph.fit
	var comfort := fit.comfort(graph, r)
	var lines := PackedStringArray()
	lines.append("Comfort %d of %d (%s): beds, a hearth, a rug, a table and a lantern make it cozy" % [comfort,
		FixturesScript.MAX_COMFORT, FixturesScript.comfort_word(comfort)])
	var sleepers: String = night.sleepers_of(r)
	lines.append("Its beds are for: %s" % (sleepers if not sleepers.is_empty() else "nobody yet (no beds in)"))
	if fit.has_hearth(graph, r):
		lines.append("Hearth: %s" % ("lit, smoke from the chimney" if night.hearth_burns() else "cold until evening"))
	return "\n".join(lines)


static func _cellar_body(graph: RefCounted, r: int, stored_u: int) -> String:
	"""A cellar's store and the cool rule."""
	var fit: FixturesScript = graph.fit
	var capacity := fit.capacity_u(graph, r)
	if capacity <= 0:
		return NO_STORE
	var cool := fit.cool(graph, r)
	var spoil := RoomsScript.CELLAR_SPOILAGE_PERMILLE if cool == FixturesScript.COOL_YES else RoomsScript.WARM_CELLAR_SPOILAGE_PERMILLE
	return "Holds %d of %d U\n%s (food ages at %d per mille)" % [stored_u, capacity, _first_up(FixturesScript.COOL_WORDS[cool]),
		spoil]


static func _first_up(text: String) -> String:
	"""`text` with its first letter capital."""
	return text.left(1).to_upper() + text.substr(1)


static func palette_rows(graph: RefCounted, r: int) -> Array[Dictionary]:
	"""The palette for a room: a row a kind its places take -- {"kind", "text", "add", "take"}: its words, and whether
	one more can be planned (an empty place) or one taken out (one planned or in)."""
	var fit: FixturesScript = graph.fit
	var template: int = graph.rooms.template[r]
	var rows: Array[Dictionary] = []
	for kind: int in FixturesScript.palette(template):
		var places := _places_of(template, kind)
		var planned := fit.count(graph, r, kind, FixturesScript.PLANNED)
		var done := fit.count(graph, r, kind, FixturesScript.INSTALLED)
		var text := "%s: %d of %d in" % [_first_up(RoomsScript.FIXTURE_NAMES[kind]), done, places]
		if planned > done:
			text += ", %d coming" % (planned - done)
		rows.append({"kind": kind, "text": "%s · %s" % [text, FixturesScript.cost_text(kind)],
			"add": fit.has_room_for(graph, r, kind), "take": planned > 0})
	return rows


static func _places_of(template: int, kind: int) -> int:
	"""How many places of a template take a `kind` (a home's bed alcoves take a burrow bed or a large bed)."""
	var n := 0
	for f in RoomsScript.fixture_count(template):
		n += 1 if FixturesScript.accepts(template, f, kind) else 0
	return n


static func suggest_text(graph: RefCounted, r: int) -> String:
	"""The suggested layout's button: what it would cost now; or, every place taken, that the rest is on its way, or
	that the room is fitted out."""
	var cost: Vector3i = graph.fit.missing_cost(graph, r)
	if cost != Vector3i.ZERO:
		return "Suggested layout (%s)" % FixturesScript.amounts_text(cost.x, cost.y, cost.z)
	var fit: FixturesScript = graph.fit
	for f in RoomsScript.fixture_count(graph.rooms.template[r]):
		if fit.phase_of(graph, r, f) == FixturesScript.PLANNED:
			return "Everything ordered: being put in"
	return "Fitted out"


static func answer(graph: RefCounted, r: int, parts: PackedStringArray, code: int, stores: RefCounted,
		stored: Callable) -> String:
	"""What a fit-out button said: what was done, or why not (the refusal's words)."""
	if code == FixturesScript.REFUSE_NONE:
		return _done_text(graph, r, parts)
	return "Can't: " + FixturesScript.refusal_text(code, _refusal_words(graph, r, parts, code, stores, stored))


static func _done_text(graph: RefCounted, r: int, parts: PackedStringArray) -> String:
	"""What a button did, in words."""
	if parts[1] == FIT_SUGGEST:
		return "%s: the suggested layout is planned -- residents will put it in" % name_of(graph, r)
	var kind := int(parts[2])
	if parts[1] == FIT_ADD:
		return "%s: a %s planned (%s paid) -- a resident will put it in" % [name_of(graph, r), RoomsScript.FIXTURE_NAMES[kind],
			FixturesScript.cost_text(kind)]
	return "%s: a %s taken out (%s back in the stores)" % [name_of(graph, r), RoomsScript.FIXTURE_NAMES[kind],
		FixturesScript.cost_text(kind)]


static func _refusal_words(graph: RefCounted, r: int, parts: PackedStringArray, code: int, stores: RefCounted,
		stored: Callable) -> Array:
	"""The words a refusal's text is filled with (room_fixtures.gd REASONS)."""
	var room := name_of(graph, r)
	var kind_name: String = RoomsScript.FIXTURE_NAMES[int(parts[2])] if parts.size() > 2 else "fixture"
	match code:
		FixturesScript.REFUSE_NOT_HERE:
			return [kind_name, RoomsScript.NAMES[graph.rooms.template[r]].to_lower()]
		FixturesScript.REFUSE_FULL:
			return [kind_name, room]
		FixturesScript.REFUSE_SHORT:
			var suggest := parts[1] == FIT_SUGGEST
			var cost: Vector3i = graph.fit.missing_cost(graph, r)
			var needs := FixturesScript.amounts_text(cost.x, cost.y, cost.z) if suggest else FixturesScript.cost_text(int(parts[2]))
			return ["the " + ("suggested layout" if suggest else kind_name), needs, stores.holdings_text()]
		FixturesScript.REFUSE_NONE_TO_TAKE:
			return [room, kind_name]
		FixturesScript.REFUSE_HOLDS_FOOD:
			return [room, int(stored.call(r)) if stored.is_valid() else 0]
		FixturesScript.REFUSE_NO_NOOK:
			return [room, nook_words(graph.fit.nook_refused)]
	return [room]


static func nook_words(reason: int) -> String:
	"""Why a large bed's nook may not be dug, in words (underground_rooms.gd NOOK_REASONS; NOOK_TAKEN: its alcoves)."""
	if reason == FixturesScript.NOOK_TAKEN:
		return "the alcoves a nook can open from (the back and by the door) are taken"
	return RoomsScript.NOOK_REASONS[reason]
