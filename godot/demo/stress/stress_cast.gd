extends RefCounted
## THE SCALE TEST'S STRESS CAST (decision 0561; docs/performance/2026-10-01-scale-test.md). DEMO-TEST ONLY.
##
## The live demo has nine residents; the target is 256 (REQ-SET-163). A stress run grows the cast to N by repeating the
## staged species-and-trade rows in order -- resident i is staged row i mod 9 -- so every extra resident is a real
## rigged actor on the same body, clips and walking speed as its row, with that row's trade: its CREATURE KEY is the
## row's own (`mouse_fieldworker`), so the crews, homes, roles, the kitchen and the night take it exactly as they take
## the original. Only its manifest key ("mouse_fieldworker__t012", the node's name) and its display name differ. The
## first nine are the authored residents, unchanged.
##
## NAMES come from a data-only, non-canon generator (stress_names.json, marked DEMO-TEST): first name + surname head +
## surname tail, picked by the cast index, so a run repeats exactly. They are never authored people: the person rows
## a clone's key reads (interest, evening line, dialect) are its original's.
##
## HOW A RUN ASKS FOR IT: `--stress-residents N` after `--` on the command line (the windowed demo or the harness,
## tools/scale_test/scale_test.gd), or `override_count` set by a script before the village is built (a test). Off --
## 0 -- by default: with neither, `expand` returns the manifest's cast untouched and the demo is the nine. A release
## export ignores both.
## With nothing staged (CI) the cast is N placeholders instead of the default six.

const NAMES_PATH: String = "res://demo/stress/stress_names.json"
const FLAG: String = "--stress-residents"
## The living population's cap (AGENTS.md): never model beyond it.
const MAX_RESIDENTS: int = 256
## A clone's manifest key: its row's key, this, and its three-digit cast index.
const CLONE_KEY: String = "%s__t%03d"
## The fields a clone's row carries over its original's.
const ROW_BASE: String = "stress_base"
const ROW_NAME: String = "stress_name"
const ROW_TEST: String = "demo_test"
## Strides through the surname lists, so neighbours' names differ in every part.
const HEAD_STRIDE: int = 7
const TAIL_STRIDE: int = 5

## A script's request (a test, the harness): -1 reads the command line instead.
static var override_count: int = -1


static func requested_count() -> int:
	"""The residents this run asks for (0: off -- the demo's own cast), clamped to the population cap. Never in a release
	export (the Windows demo): a test mode does not ship."""
	if not OS.is_debug_build():
		return 0
	if override_count >= 0:
		return mini(override_count, MAX_RESIDENTS)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size() - 1:
		if args[k] == FLAG:
			return clampi(args[k + 1].to_int(), 0, MAX_RESIDENTS)
	return 0


static func is_active() -> bool:
	"""Whether this run is a stress run."""
	return requested_count() > 0


static func placeholder_count(default_count: int) -> int:
	"""How many placeholders an unstaged cast spawns: the stress count when asked for, else `default_count`."""
	var asked: int = requested_count()
	return asked if asked > 0 else default_count


static func expand(cast: Dictionary, count: int) -> Dictionary:
	"""The manifest's cast grown (or cut) to `count` rows (see the top); `cast` itself when `count` is 0 or nothing is
	staged. Insertion order is cast order: the originals first, then the clones by index."""
	if count <= 0 or cast.is_empty():
		return cast
	var bases: Array = cast.keys()
	var names: Dictionary = _load_names()
	var out: Dictionary = {}
	for i: int in mini(count, MAX_RESIDENTS):
		var base: String = String(bases[i % bases.size()])
		if i < bases.size():
			out[base] = cast[base]
			continue
		var row: Dictionary = (cast[base] as Dictionary).duplicate()
		row[ROW_BASE] = base
		row[ROW_NAME] = name_for(i, names)
		row[ROW_TEST] = true
		out[CLONE_KEY % [base, i]] = row
	return out


static func creature_key_of(manifest_key: StringName, row: Dictionary) -> StringName:
	"""The creature key an actor is built with: a clone's original's, else the manifest key."""
	return StringName(String(row.get(ROW_BASE, String(manifest_key))))


static func display_name_of(row: Dictionary, fallback: String) -> String:
	"""A clone's generated name, else `fallback` (the authored person's)."""
	return String(row.get(ROW_NAME, fallback))


static func name_for(index: int, names: Dictionary) -> String:
	"""Cast index `index`'s generated name from the name lists (see NAMES); "Test resident N" with no lists."""
	var first: Array = names.get("first", [])
	var head: Array = names.get("surname_head", [])
	var tail: Array = names.get("surname_tail", [])
	if first.is_empty() or head.is_empty() or tail.is_empty():
		return "Test resident %d" % index
	return "%s %s%s" % [first[index % first.size()], head[(index * HEAD_STRIDE) % head.size()],
		tail[(index * TAIL_STRIDE) % tail.size()]]


static func _load_names() -> Dictionary:
	"""The name lists ({} when the file is missing or malformed: names fall back to "Test resident N")."""
	if not FileAccess.file_exists(NAMES_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}
