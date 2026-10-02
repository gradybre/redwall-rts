extends RefCounted
## THE GROUP PANEL'S STATUSES, AS DATA (decision 0791). The group panel (group_panel.gd) has no code for any one status:
## it reads this registry, a row per status, and shows whichever rows the selected residents hold. A status is a ROW:
##
##     add(id, word, severity, query)      e.g.  add(&"hungry", "Hungry", SEVERITY_WARN, kitchen_is_hungry)
##
##   * `id`        a StringName naming it (a second `add` with the same id replaces the row, in place);
##   * `word`      what the panel says ("Hungry"): its line "Hungry ×2 — Tobit, Corra", a tile's tag, a tooltip;
##   * `severity`  SEVERITY_WARN (listed first, under "Needs attention", and named on the member's tile) or SEVERITY_NOTE
##                 (listed after, in umber);
##   * `query`     `query(actor_index: int) -> bool`: whether that resident has it NOW -- the owner's EXISTING query, read
##                 a few times a second, never per frame. It must not change anything.
##
## HOW A NEW STATUS APPEARS: its owner adds one row where it is wired (demo_village.gd), through the village's
## `group_select().statuses` -- e.g. the winter fuel's Chilled (`add(&"chilled", "Chilled", SEVERITY_WARN, is_chilled)`)
## or the infirmary's injuries (`add(&"injured", "Injured", SEVERITY_WARN, is_injured)`). Nothing in the group panel,
## the party panel or the single-resident card changes. Rows are shown in the order they were added, warnings first.
##
## The ROW `IDLE` is special only in that "Select idle" reads it: it is a NOTE row like any other, added by group_select.gd
## from the Work screen's own "available" (work_crews.gd `status_of`).

const SEVERITY_NOTE: int = 0
const SEVERITY_WARN: int = 1
## The row "Select idle" and the panel's idle line read.
const IDLE: StringName = &"idle"

## Bumped whenever a row is added or replaced (the panel re-reads its rows only then).
var revision: int = 0

var _ids: Array[StringName] = []
var _words: PackedStringArray = PackedStringArray()
var _severity: PackedInt32Array = PackedInt32Array()
var _queries: Array[Callable] = []


func add(id: StringName, word: String, severity: int, query: Callable) -> bool:
	"""Add (or, for a known `id`, replace in place) one status row (see the header). False, and nothing added, for an
	empty id or word, an unknown severity or an invalid query."""
	if id == &"" or word.is_empty() or not query.is_valid():
		return false
	if severity != SEVERITY_NOTE and severity != SEVERITY_WARN:
		return false
	var k: int = _ids.find(id)
	if k < 0:
		_ids.append(id)
		_words.append(word)
		_severity.append(severity)
		_queries.append(query)
	else:
		_words[k] = word
		_severity[k] = severity
		_queries[k] = query
	revision += 1
	return true


func count() -> int:
	"""How many rows there are."""
	return _ids.size()


func find(id: StringName) -> int:
	"""The row named `id`, or -1."""
	return _ids.find(id)


func id_of(k: int) -> StringName:
	"""Row `k`'s id (&"" for no such row)."""
	return _ids[k] if k >= 0 and k < _ids.size() else &""


func word_of(k: int) -> String:
	"""Row `k`'s word ("" for no such row)."""
	return _words[k] if k >= 0 and k < _words.size() else ""


func severity_of(k: int) -> int:
	"""Row `k`'s severity (SEVERITY_NOTE for no such row)."""
	return _severity[k] if k >= 0 and k < _severity.size() else SEVERITY_NOTE


func holds(k: int, who: int) -> bool:
	"""Whether resident `who` has row `k`'s status now (false for no such row)."""
	if k < 0 or k >= _queries.size() or not _queries[k].is_valid():
		return false
	return bool(_queries[k].call(who))


func members_into(k: int, members: PackedInt32Array, out: PackedInt32Array) -> int:
	"""Those of `members` who have row `k`'s status, in their order, into `out` (resized); how many."""
	out.resize(0)
	for who: int in members:
		if holds(k, who):
			out.append(who)
	return out.size()


func bits_of(who: int) -> int:
	"""Which rows resident `who` has, as bits (row k: bit k; the first 62 rows) -- the panel's change check."""
	var bits: int = 0
	for k: int in mini(_ids.size(), 62):
		if holds(k, who):
			bits |= 1 << k
	return bits


func shown_order() -> PackedInt32Array:
	"""The rows in the order the panel lists them: warnings first, then notes, each in the order added."""
	var order := PackedInt32Array()
	for severity: int in [SEVERITY_WARN, SEVERITY_NOTE]:
		for k: int in _ids.size():
			if _severity[k] == severity:
				order.append(k)
	return order


func first_warning(who: int) -> int:
	"""The first warning row (in the order added) resident `who` has, or -1."""
	for k: int in _ids.size():
		if _severity[k] == SEVERITY_WARN and holds(k, who):
			return k
	return -1
