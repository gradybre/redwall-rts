extends RefCounted
## The playtest log's BREADCRUMBS: a fixed ring of the last CAPACITY notable events (decision 0562). DEMO
## DIAGNOSTICS.
##
## WHAT IS ONE. A scene or view change, a panel opened, an order given, a speed change, a notice raised, a tester's
## mark, an error, a freeze. Never a frame: the sources call `record` only when something changed.
##
## NO ALLOCATION PER EVENT. The ring is six columns sized once in `_init` -- real time, game tick, kind, two ints
## and a StringName tag -- and `record` overwrites one slot of each. A tag is always an existing StringName (a
## constant, or a Node's name), so storing it only takes a reference. Text is made only when a line is read
## (`line`), which the log does in batches at most once a second, or when it dumps the ring after a freeze.
##
## THREADS. The error logger and the freeze watch call in from other threads, so every read and write holds
## the ring's own mutex. Locking allocates nothing.
##
## PRIVACY. A breadcrumb holds codes, counts and the names of the game's own nodes: never typed text, a file
## path or anything about the player.

const CAPACITY: int = 64

const KIND_SCENE: int = 0
const KIND_VIEW: int = 1
const KIND_PANEL: int = 2
const KIND_ORDER: int = 3
const KIND_SPEED: int = 4
const KIND_NOTICE: int = 5
const KIND_MARK: int = 6
const KIND_ERROR: int = 7
const KIND_FREEZE: int = 8
const KIND_CLOCK: int = 9
const KIND_NAMES: Array[String] = ["scene", "view", "panel", "order", "time", "notice", "MARK", "error", "freeze",
	"clock"]
## The words for a few kinds' first int (`a`); any other kind prints its ints as they are. An order's `a` is how
## many residents were selected; a notice's is its source * 2 + its level.
const SPEED_WORDS: Array[String] = ["paused", "1x", "2x", "", "4x"]
## GameManager.GameState, in order.
const STATE_WORDS: Array[String] = ["boot", "playing", "paused"]
## The right column's panels (demo_detail_zone.gd PANEL_*); -1 is collapsed.
const PANEL_WORDS: Array[String] = ["Farm", "Tunnels", "Woods", "Water"]
const OPEN_WORDS: Array[String] = ["closed", "opened"]
const ON_WORDS: Array[String] = ["off", "on"]
const ERROR_WORDS: Array[String] = ["error", "warning", "script error", "shader error", "printerr"]
const NOTICE_LEVEL_WORDS: Array[String] = ["note", "warning"]
## The notice feed's sources (demo_notices.gd SOURCE_NAMES), so a notice's `a` reads as its source.
const NOTICE_SOURCES: Array[String] = ["Farm", "Tunnels", "Weather", "Threat", "Crew", "Woods", "Water", "Village"]

var _usec: PackedInt64Array = PackedInt64Array()
var _tick: PackedInt64Array = PackedInt64Array()
var _kind: PackedByteArray = PackedByteArray()
var _a: PackedInt32Array = PackedInt32Array()
var _b: PackedInt32Array = PackedInt32Array()
var _tag: Array[StringName] = []
## Events recorded since the start (the newest's serial is `_total - 1`).
var _total: int = 0
## The serial `drain_into` reads from next.
var _drained: int = 0
## Real time zero for the lines (the session's start).
var _origin_usec: int = 0
## The game tick `record_now` stamps (the session sets it each frame; an int write).
var now_tick: int = 0
var _mutex: Mutex = Mutex.new()


func _init(origin_usec: int = 0) -> void:
	"""Size every column once."""
	_origin_usec = origin_usec
	_usec.resize(CAPACITY)
	_tick.resize(CAPACITY)
	_kind.resize(CAPACITY)
	_a.resize(CAPACITY)
	_b.resize(CAPACITY)
	_tag.resize(CAPACITY)
	_tag.fill(&"")


func record(kind: int, tag: StringName, a: int, b: int, usec: int, tick: int) -> void:
	"""Overwrite the oldest slot with one event (KIND_*) at real time `usec` and game tick `tick`."""
	_mutex.lock()
	var slot: int = _total % CAPACITY
	_usec[slot] = usec
	_tick[slot] = tick
	_kind[slot] = kind
	_a[slot] = a
	_b[slot] = b
	_tag[slot] = tag
	_total += 1
	_mutex.unlock()


func record_now(kind: int, tag: StringName, a: int, b: int) -> void:
	"""`record` at the real time now and the game tick last set (`now_tick`)."""
	record(kind, tag, a, b, Time.get_ticks_usec(), now_tick)


func total() -> int:
	"""Events recorded since the start (more than CAPACITY once the ring has wrapped)."""
	_mutex.lock()
	var count: int = _total
	_mutex.unlock()
	return count


func size() -> int:
	"""Events held now (at most CAPACITY)."""
	return mini(total(), CAPACITY)


func oldest_serial() -> int:
	"""The serial of the oldest event still held (0 until the ring wraps)."""
	return maxi(0, total() - CAPACITY)


func kind_of(serial: int) -> int:
	"""Event `serial`'s kind, or -1 when it is no longer (or not yet) held."""
	_mutex.lock()
	var held: bool = serial >= maxi(0, _total - CAPACITY) and serial < _total
	var kind: int = _kind[serial % CAPACITY] if held else -1
	_mutex.unlock()
	return kind


func line(serial: int) -> String:
	"""Event `serial` as one log line ('' when it is no longer held): '+12.345s tick 450  panel DemoMenu opened'."""
	_mutex.lock()
	if serial < maxi(0, _total - CAPACITY) or serial >= _total:
		_mutex.unlock()
		return ""
	var slot: int = serial % CAPACITY
	var text: String = "+%.3fs tick %d  %s %s" % [float(_usec[slot] - _origin_usec) / 1000000.0, _tick[slot],
		KIND_NAMES[_kind[slot]], describe(_kind[slot], _tag[slot], _a[slot], _b[slot])]
	_mutex.unlock()
	return text


func drain_into(out: PackedStringArray) -> int:
	"""Append every event not yet drained -- except those the log writes as lines of their own (`written_alone`) --
	to `out`, oldest first, and mark them drained. Safe from any thread. Returns how many were appended."""
	_mutex.lock()
	var from: int = maxi(_drained, maxi(0, _total - CAPACITY))
	var end: int = _total
	_drained = end
	var added: int = 0
	for k: int in range(from, end):
		if not written_alone(_kind[k % CAPACITY]):
			out.append(line(k))
			added += 1
	_mutex.unlock()
	return added


static func written_alone(kind: int) -> bool:
	"""Whether a kind's event has its own fuller line in the log (an error, a mark, a freeze), so a drain skips it;
	a dump after a freeze or a mark still lists it."""
	return kind == KIND_ERROR or kind == KIND_MARK or kind == KIND_FREEZE


func lines_from(serial: int, out: PackedStringArray) -> int:
	"""Append every event from `serial` on (or from the oldest held) to `out`; returns the next serial to read."""
	var end: int = total()
	for k: int in range(maxi(serial, maxi(0, end - CAPACITY)), end):
		out.append(line(k))
	return end


func last_lines(most: int, out: PackedStringArray) -> void:
	"""Append the newest `most` events, oldest first."""
	lines_from(maxi(0, total() - most), out)


static func describe(kind: int, tag: StringName, a: int, b: int) -> String:
	"""An event's words after its kind: 'DemoMenu opened', '2x', 'accepted, 3 selected'."""
	match kind:
		KIND_SCENE:
			return String(tag)
		KIND_VIEW:
			return "%s %s" % [tag, _word(ON_WORDS, a)] if tag == &"underground" else "%s %d" % [tag, a]
		KIND_PANEL:
			if tag == &"right_column":
				return "right column %s" % (_word(PANEL_WORDS, a) if a >= 0 else "collapsed")
			return "%s %s" % [tag, _word(OPEN_WORDS, a)]
		KIND_SPEED:
			return "%s %s" % [tag, _word(SPEED_WORDS if tag == &"speed" else STATE_WORDS, a)]
		KIND_ORDER:
			return "%s, %d selected" % [tag, a]
		KIND_NOTICE:
			return "%s %s" % [_word(NOTICE_SOURCES, a >> 1), _word(NOTICE_LEVEL_WORDS, a & 1)]
		KIND_MARK:
			return "#%d: the tester marked a problem here" % a
		KIND_ERROR:
			return "%s #%d" % [_word(ERROR_WORDS, a), b]
		KIND_FREEZE:
			return "%s %d ms" % [tag, a]
	if a == 0 and b == 0:
		return String(tag)
	return "%s %d %d" % [tag, a, b] if b != 0 else "%s %d" % [tag, a]


static func _word(words: Array[String], k: int) -> String:
	"""`words[k]`, or the number itself outside them."""
	return words[k] if k >= 0 and k < words.size() and not words[k].is_empty() else str(k)
