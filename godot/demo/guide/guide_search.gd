extends RefCounted
## PLAIN-LANGUAGE SEARCH for the help page and the field guide (decision 0481; review P1's "Objectives / Help" row,
## UX-018). A query is split into words; each word is widened by the few everyday words players use for the demo's
## things (SYNONYMS: "eat" finds supper and the kitchen, "cross" finds bridges and fords); an entry matches when EVERY
## word of the query (or one of its widenings) is found in it, and ranks by where: its title (3), its keywords (2), its
## text (1). With no entry matching every word, the entries matching any word are offered, best first. An empty query
## lists everything in its own order. Pure, no allocation beyond the result.

const TITLE_WEIGHT: int = 3
const KEYWORD_WEIGHT: int = 2
const BODY_WEIGHT: int = 1
## Words too common to search by ("how do I cross the stream" searches "cross stream").
const STOP_WORDS: PackedStringArray = ["a", "an", "the", "to", "i", "do", "does", "how", "can", "my", "of", "is", "it",
	"in", "on", "for", "and", "or", "what", "me", "get", "with", "be", "are"]
## Everyday words -> the demo's words for the same thing.
const SYNONYMS: Dictionary = {
	"eat": "supper breakfast meal kitchen food fed", "food": "harvest pantry kitchen supper crop meal",
	"meal": "supper breakfast kitchen", "dinner": "supper", "cook": "kitchen supper porridge soup",
	"crop": "bed harvest plant", "field": "bed farm crop", "farm": "bed crop harvest plant",
	"cross": "bridge ford swim wade", "river": "stream water", "stream": "water bridge ford",
	"swim": "water wade dive", "wood": "woods fell saw planks log", "tree": "woods fell",
	"dig": "tunnel mole", "tunnel": "dig", "house": "burrow home bed", "sleep": "bed night burrow",
	"store": "pantry cellar stores", "storage": "pantry cellar store", "full": "room pantry store",
	"save": "save", "pause": "space speed time", "speed": "time pause", "time": "speed pause",
	"move": "order right", "select": "click resident", "who": "resident residents", "job": "work jobs task",
	"jobs": "work task", "waiting": "work blocked why", "frost": "cover cold", "cold": "frost cover",
	"wet": "drain waterlogged", "rain": "weather wet", "news": "history village", "goal": "objective guide project",
	"help": "guide", "keys": "controls key", "controls": "key", "map": "layer minimap", "rescue": "swim water",
}


## One searchable entry: its title, keywords and text, lower-cased once.
class Entry extends RefCounted:
	var title: String = ""
	var keywords: String = ""
	var body: String = ""

	func _init(p_title: String, p_keywords: String, p_body: String) -> void:
		"""Lower-case once, for matching."""
		title = p_title.to_lower()
		keywords = p_keywords.to_lower()
		body = p_body.to_lower()


static func words_of(query: String) -> PackedStringArray:
	"""The query's words, lower-cased, punctuation and STOP_WORDS dropped."""
	var cleaned: String = query.to_lower()
	for mark: String in [",", ".", "?", "!", ";", ":", "(", ")", "'", "\""]:
		cleaned = cleaned.replace(mark, " ")
	var out := PackedStringArray()
	for word: String in cleaned.split(" ", false):
		if not STOP_WORDS.has(word):
			out.append(word)
	return out


static func widen(word: String) -> PackedStringArray:
	"""A word and the demo's words for it."""
	var out := PackedStringArray([word])
	if word.length() > 3 and word.ends_with("s"):
		out.append(word.substr(0, word.length() - 1))
	if SYNONYMS.has(word):
		out.append_array(String(SYNONYMS[word]).split(" ", false))
	return out


static func score(entry: Entry, word: String) -> int:
	"""How well one query word (widened) matches `entry` (0: not at all)."""
	var best: int = 0
	for form: String in widen(word):
		if entry.title.contains(form):
			best = maxi(best, TITLE_WEIGHT)
		elif entry.keywords.contains(form):
			best = maxi(best, KEYWORD_WEIGHT)
		elif entry.body.contains(form):
			best = maxi(best, BODY_WEIGHT)
	return best


static func search(entries: Array[Entry], query: String) -> PackedInt32Array:
	"""The indices of `entries` matching `query`, best first (see the header); all of them for an empty query."""
	var words: PackedStringArray = words_of(query)
	var all := PackedInt32Array()
	for k: int in entries.size():
		all.append(k)
	if words.is_empty():
		return all
	var strict: PackedInt32Array = _ranked(entries, words, true)
	return strict if not strict.is_empty() else _ranked(entries, words, false)


static func _ranked(entries: Array[Entry], words: PackedStringArray, every: bool) -> PackedInt32Array:
	"""Entries matching every word (`every`) or any, ranked by total score, ties in their own order."""
	var scored: Array[Vector2i] = []
	for k: int in entries.size():
		var total: int = 0
		var missed: bool = false
		for word: String in words:
			var s: int = score(entries[k], word)
			total += s
			missed = missed or s == 0
		if total > 0 and not (every and missed):
			scored.append(Vector2i(-total, k))
	scored.sort()
	var out := PackedInt32Array()
	for pair: Vector2i in scored:
		out.append(pair.y)
	return out
