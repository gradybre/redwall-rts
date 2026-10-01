extends RefCounted
## The weir's sluice and the garden leat it feeds: which beds it serves and how, as a small table. Decision 0441
## (review ECO-006: bounded, discrete water service zones; no hydrology). Pure rules, integers only.
##
## THE SLUICE is a player control with three settings -- CLOSED, HALF, OPEN -- never a flow rate.
## THE LEAT is the garden's feeder: from the sluice on the weir's west bay it runs as a short open channel into
## the bank and then in a covered stone culvert under the village to an inlet at the garden's north-east corner,
## and along the beds' east column. Its zone is ZONE_BEDS, nothing else: Bed 2, Bed 4 and Bed 6 (the east
## column, `farm_catalog.gd BED_IDS` 1, 3 and 5), in the order the water reaches them.
## THE SERVICE each zone bed gets is one of three discrete states, read straight from SERVICE_TABLE:
##
##   sluice     Bed 2    Bed 4    Bed 6
##   Closed     dry      dry      dry
##   Half       normal   normal   dry
##   Open       wet      wet      normal
##
## A bed outside the zone is SERVICE_NONE whatever the sluice does. What each state does to a bed's moisture is
## farm_sim.gd's (`leat_delta` within `day_delta`, through the existing moisture model); what a flood does with the leat open is
## farm_sim.gd's `flood_surge`. Nothing here simulates water.

const SLUICE_CLOSED: int = 0
const SLUICE_HALF: int = 1
const SLUICE_OPEN: int = 2
const SLUICE_COUNT: int = 3
const SLUICE_NAMES: Array[String] = ["Closed", "Half open", "Open"]
## The verbs on the sluice's buttons.
const SLUICE_VERBS: Array[String] = ["Close", "Half", "Open"]
## The sluice as the demo opens: closed, so the garden's opening history (decision 0205's tuned spring) is unchanged.
const OPENING_SLUICE: int = SLUICE_CLOSED

const SERVICE_NONE: int = 0
const SERVICE_DRY: int = 1
const SERVICE_NORMAL: int = 2
const SERVICE_WET: int = 3
const SERVICE_NAMES: Array[String] = ["not served", "dry", "normal", "wet"]

## The zone: bed rows (farm_catalog.gd), in the order the leat reaches them.
const ZONE_BEDS: PackedInt32Array = [1, 3, 5]
## SERVICE_TABLE[sluice * ZONE_SIZE + k]: the service zone bed k gets (see the header).
const ZONE_SIZE: int = 3
const SERVICE_TABLE: PackedInt32Array = [
	SERVICE_DRY, SERVICE_DRY, SERVICE_DRY,
	SERVICE_NORMAL, SERVICE_NORMAL, SERVICE_DRY,
	SERVICE_WET, SERVICE_WET, SERVICE_NORMAL,
]
## How full the leat runs at each setting, per mille (presentation: the gate's lift and the channel's water).
const FLOW_PERMILLE: PackedInt32Array = [0, 500, 1000]


static func is_sluice(setting: int) -> bool:
	"""Whether `setting` is one of SLUICE_*."""
	return setting >= SLUICE_CLOSED and setting < SLUICE_COUNT


static func zone_index(bed: int) -> int:
	"""Where `bed` is along the leat (0 first), or -1 when the leat does not serve it."""
	for k: int in ZONE_SIZE:
		if ZONE_BEDS[k] == bed:
			return k
	return -1


static func in_zone(bed: int) -> bool:
	"""Whether the leat serves `bed`."""
	return zone_index(bed) >= 0


static func service_for(setting: int, bed: int) -> int:
	"""SERVICE_*: what bed `bed` gets with the sluice at `setting` (NONE outside the zone or for no setting)."""
	var k: int = zone_index(bed)
	if k < 0 or not is_sluice(setting):
		return SERVICE_NONE
	return SERVICE_TABLE[setting * ZONE_SIZE + k]


static func is_watering(service: int) -> bool:
	"""Whether a service brings water (normal or wet): what a flood can ride down the leat."""
	return service == SERVICE_NORMAL or service == SERVICE_WET


static func bed_word(bed: int) -> String:
	"""'Bed 4' (the panels' own numbering: row + 1)."""
	return "Bed %d" % (bed + 1)


static func list_words(beds: PackedInt32Array) -> String:
	"""'Bed 2', 'Bed 2 and Bed 4', 'Bed 2, Bed 4 and Bed 6'."""
	var words := PackedStringArray()
	for bed: int in beds:
		words.append(bed_word(bed))
	if words.size() <= 1:
		return "".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + words[words.size() - 1]
