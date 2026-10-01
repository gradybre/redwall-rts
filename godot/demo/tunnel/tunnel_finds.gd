extends RefCounted
## What turns up while digging. Decision 0196 (live demo). Presentation only: finds are a demo tally
## (tunnel_stores.gd) and a notice; nothing enters the simulation's inventory.
##
## ONE ROLL PER PHYSICAL CUBIC METRE, SEEDED AND DETERMINISTIC. When a quantum's cut completes, the
## metre it lies in -- its whole-metre cell (tunnel_ground.gd) and the LAYER it was cut in (the bore,
## the widening round it, a room's cell) -- is rolled once: an integer hash of (cell, layer, SEED) taken
## mod 10000 against the ground's table below. The same metre always yields the same find, and a
## metre already rolled (dug again after a collapse, or crossed by a second tunnel) yields nothing
## more (`claim`). This is not a hazard roll: it decides only a keepsake.
##
## THE TABLE (per 10000 cut metres, by ground; DEMO values):
##            flint  clay  root store  relic
##   loam       600   300         500     60
##   clay       300  2500         200     60
##   sand       900   100         300     60
##   rock      2500     0           0    100
##
## Relics tell a short story (RELIC_STORIES): original Redwall-flavoured text written for this demo,
## not quoted from any book. The Foremole's lines on a find are in light mole dialect, likewise
## original (decision 0196: light dialect, DEC-017).

const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")

const FIND_NONE: int = 0
const FIND_FLINT: int = 1
const FIND_CLAY: int = 2
const FIND_ROOT_STORE: int = 3
const FIND_RELIC: int = 4
const KIND_COUNT: int = 5

const LAYER_BORE: int = 0
const LAYER_WIDEN: int = 1
const LAYER_CHAMBER: int = 2
const LAYERS: int = 3

const SEED: int = 7043
const ROLL_RANGE: int = 10000
## Per ground (LOAM, CLAY, SAND, ROCK), four cumulative ceilings: flint, clay, root store, relic.
const TABLE: Array[int] = [
	600, 900, 1400, 1460,
	300, 2800, 3000, 3060,
	900, 1000, 1300, 1360,
	2500, 2500, 2500, 2600,
]
const FINDS_PER_GROUND: int = 4
const FIND_NAMES: Array[String] = ["nothing", "a flint", "a lump of good clay", "an old root store", "a relic"]
const FOREMOLE_ON_FIND: Array[String] = [
	"",
	"Hurr, a gurt flint! That'll strike a spark on a cold night, zurr.",
	"Good sticky clay, this 'un. Fit for pots an' patchin', burr aye.",
	"Oho! Some ole beast's root store, forgotted long since. Still smells o' turnip.",
	"",
]
const RELIC_STORIES: Array[String] = [
	"A relic! A copper bell no bigger than an acorn, green with age. Old ones say such bells hung at the gate of a woodland abbey, rung to call travellers in from the rain.",
	"A relic! A pewter spoon, its handle worked with twining ivy and the words FOR THE FEAST. Somebeast set a good table here, long before the village had a name.",
	"A relic! A slate scratched with a little map: a stream, three stones and a star. The stream on it runs somewhere else now, and nobeast knows where the star meant.",
	"A relic! A bone whistle carved like a wren. Blown softly it gives one clear note, and the Foremole swears the hedge-birds answer it.",
	"A relic! A clay beaker with a spout like a sparrow's beak, still smelling faintly of elderflower. Someone brewed cordial down here in summers long gone.",
	"A relic! An iron key as long as a mouse's paw, its bow worked into a knot of oak leaves. Whatever door it opened rotted to loam long ago, but the Foremole pockets it all the same.",
	"A relic! A folded scrap of banner, faded blue and rust, stitched round with acorns and oak leaves. Somebeast carried it proudly once, then folded it away down here where no rain could reach it.",
]
## The library model each relic is shown as (demo/props/demo_props.gd), by story; &"" for a relic
## with no model of its own (its icon is a roundel, and nothing is drawn where it was found).
const RELIC_MODEL: Array[StringName] = [&"relic_bell", &"", &"", &"", &"", &"relic_key", &"relic_banner"]
## The model of each find (FIND_*) that is not a relic; the root store is an old basket.
const FIND_MODEL: Array[StringName] = [&"", &"find_flint", &"find_clay", &"basket", &""]

## Per layer, one bit per ground cell: already rolled.
var _claimed: Array[PackedByteArray] = []


func _init(cell_count: int = 0) -> void:
	"""One claimed-bit column per layer, for `cell_count` ground cells, allocated once."""
	for layer in LAYERS:
		var bits := PackedByteArray()
		bits.resize(cell_count)
		_claimed.append(bits)


static func roll(cell: int, layer: int) -> int:
	"""The seeded roll for a cell and layer, in [0, ROLL_RANGE)."""
	var h := ((cell * 2654435761) ^ (layer * 40503) ^ (SEED * 2246822519)) & 0x7FFFFFFF
	h = ((h ^ (h >> 15)) * 2246822519) & 0x7FFFFFFF
	h = h ^ (h >> 13)
	return h % ROLL_RANGE


static func find_for(roll_value: int, ground: int) -> int:
	"""FIND_*: what a roll yields in this ground (see THE TABLE)."""
	for k in FINDS_PER_GROUND:
		if roll_value < TABLE[ground * FINDS_PER_GROUND + k]:
			return FIND_FLINT + k
	return FIND_NONE


func claim(cell: int, layer: int) -> bool:
	"""Take a cell's roll in a layer: true the first time only (see ONE ROLL PER PHYSICAL CUBIC METRE)."""
	if cell < 0 or cell >= _claimed[layer].size() or _claimed[layer][cell] == 1:
		return false
	_claimed[layer][cell] = 1
	return true


func dig(cell: int, layer: int, ground: int) -> int:
	"""A metre cut in `cell` and `layer` through `ground`: FIND_* it yields (FIND_NONE if nothing, or if
	that metre was rolled before)."""
	if not claim(cell, layer):
		return FIND_NONE
	return find_for(roll(cell, layer), ground)


static func model_of(kind: int, relic_number: int) -> StringName:
	"""The model a find is shown as: its kind's, or for a relic its story's (&"": none)."""
	if kind == FIND_RELIC:
		return RELIC_MODEL[(relic_number - 1) % RELIC_MODEL.size()]
	return FIND_MODEL[kind]


static func relic_story(relic_number: int) -> String:
	"""The story told by the `relic_number`-th relic found (1 for the first), cycling."""
	return RELIC_STORIES[(relic_number - 1) % RELIC_STORIES.size()]


static func find_line(kind: int) -> String:
	"""What the Foremole says on a find (a relic's story is told separately)."""
	return FOREMOLE_ON_FIND[kind]
