extends RefCounted
## THE DEMO CAST'S NAMES AND INTERESTS, read from ONE data file (demo_people.json). Decision 0491 (review group T, P6;
## Brendan's rulings of 2026-10-01). Presentation only.
##
## The demo's nine residents are an ORIGINAL community: each has a hand-written name, a personal interest, a way of
## speaking and an evening pastime (the file's own note says what each field is). Their trade stays a ROLE -- "Wenna
## Tallowby — mouse, keeper" -- read from the cast key (`mouse_keeper`: species "mouse", role "keeper"). Nothing here
## is the main game's naming system (GDD §5.3's fixed 32-entry catalogs), which is unchanged; a key with no row (a
## placeholder, a new cast member) keeps its key-derived label.
##
## DIALECT (DEC-017): a person's `dialect` words are appended only to that person's own SPOKEN lines (`spoken`), at
## most one a line and at most two words -- never to functional UI text, which callers build plainly from `name_of`
## and `role_of`.

const DEFAULT_PATH: String = "res://demo/people/demo_people.json"
## The most words a dialect tag may have (DEC-017's light dialect; Brendan's "at most one or two words a line").
const MAX_TAG_WORDS: int = 2

static var _rows: Dictionary = {}
static var _loaded_from: String = ""
static var _provenance: String = ""


static func load_from(path: String = DEFAULT_PATH) -> bool:
	"""Read the people file at `path` (once per path; a missing or malformed file leaves the book empty: every resident
	keeps its key-derived label). True when rows were read."""
	if _loaded_from == path:
		return not _rows.is_empty()
	_loaded_from = path
	_rows = {}
	_provenance = ""
	if not FileAccess.file_exists(path):
		push_warning("demo people: no file at %s; residents keep their trade labels" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("people") is Dictionary:
		push_warning("demo people: %s is not a people table" % path)
		return false
	_provenance = String((parsed as Dictionary).get("provenance", ""))
	var people: Dictionary = (parsed as Dictionary)["people"]
	for key: Variant in people:
		if people[key] is Dictionary and not String((people[key] as Dictionary).get("name", "")).is_empty():
			_rows[StringName(String(key))] = people[key]
	return not _rows.is_empty()


static func _row(key: StringName) -> Dictionary:
	"""Cast key `key`'s row ({} when it has none) -- from the file read last, the demo's own when none was."""
	if _loaded_from.is_empty():
		load_from()
	return _rows.get(key, {})


static func has_person(key: StringName) -> bool:
	"""Whether cast key `key` has a hand-written person."""
	return not _row(key).is_empty()


static func name_of(key: StringName) -> String:
	"""The person's name ("" when the key has none)."""
	return String(_row(key).get("name", ""))


static func first_name_of(key: StringName) -> String:
	"""The person's first name ("Wenna"; "" when the key has none)."""
	var full: String = name_of(key)
	return full.get_slice(" ", 0) if not full.is_empty() else ""


static func interest_of(key: StringName) -> String:
	"""The person's interest ("carves tiny animal figures for the windowsills"; "" when none)."""
	return String(_row(key).get("interest", ""))


static func speech_of(key: StringName) -> String:
	"""How the person talks ("plain, unhurried"; "" when none)."""
	return String(_row(key).get("speech", ""))


static func evening_of(key: StringName) -> String:
	"""What the person does of a free evening, after "is " ("" when none)."""
	return String(_row(key).get("evening", ""))


static func pleased_of(key: StringName) -> String:
	"""The person's line after a deed of theirs ("" when none) -- plain; `spoken` adds any dialect."""
	return String(_row(key).get("pleased", ""))


static func dialect_of(key: StringName) -> PackedStringArray:
	"""The person's own light dialect words (empty for nearly everyone); a tag longer than MAX_TAG_WORDS is dropped."""
	var out := PackedStringArray()
	for tag: Variant in _row(key).get("dialect", []):
		var words: String = String(tag).strip_edges()
		if not words.is_empty() and words.split(" ", false).size() <= MAX_TAG_WORDS:
			out.append(words)
	return out


static func provenance() -> String:
	"""The file's provenance note (decision 0491: original, not from the books)."""
	if _loaded_from.is_empty():
		load_from()
	return _provenance


static func species_of(key: StringName) -> String:
	"""A cast key's species, lower case: `otter_boatwright` -> "otter" ("" for a key without a trade)."""
	var text: String = String(key)
	if text.begins_with("placeholder") or not text.contains("_"):
		return ""
	return text.get_slice("_", 0)


static func role_of(key: StringName) -> String:
	"""A cast key's trade, its role: `otter_boatwright` -> "boatwright"; a placeholder has none ("")."""
	var text: String = String(key)
	if text.begins_with("placeholder") or not text.contains("_"):
		return ""
	return text.substr(text.find("_") + 1).replace("_", " ")


static func with_role(name: String, key: StringName) -> String:
	"""'Wenna Tallowby (mouse keeper)' -- a name with its species and role where the key has them; the name alone
	otherwise."""
	var role: String = role_of(key)
	return name if role.is_empty() else "%s (%s %s)" % [name, species_of(key), role]


static func spoken(key: StringName, line: String, turn: int = 0) -> String:
	"""`line` as cast key `key` says it: plain, or with ONE of its dialect words before the closing stop -- the
	`turn`'th, cycling ("A good day's work." -> "A good day's work, hurr."). A key without dialect says it plainly."""
	var tags: PackedStringArray = dialect_of(key)
	if tags.is_empty() or line.is_empty():
		return line
	var tag: String = tags[posmod(turn, tags.size())]
	var stop: String = line.right(1) if line.right(1) in [".", "!", "?"] else ""
	return "%s, %s%s" % [line.left(line.length() - stop.length()), tag, stop if not stop.is_empty() else "."]
