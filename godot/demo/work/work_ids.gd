extends RefCounted
## The work board's shared words and numbers (decision 0411, review F22/F32/SOC-004). Presentation only: the demo's
## jobs are the demo's, never the simulation's.
##
## SOURCES are the job owners whose tasks the board lists (each one's board stays its own); ACTIVITIES are what a crew
## prefers and falls back to (GDD §5.3 eligibility is per job kind: a source maps each of its tasks to one); STATES are
## a task's phase in the Work screen's words, and PRIORITIES are REQ-SET-026's 0-4 (0 forbidden, 1 highest).

const SOURCE_FARM: int = 0
const SOURCE_WOODS: int = 1
const SOURCE_BRIDGES: int = 2
const SOURCE_TUNNELS: int = 3
const SOURCE_FIT_OUT: int = 4
const SOURCE_SPOIL: int = 5
## The kitchen's cook and water drawers (decision 0381's kitchen; demo/work/kitchen_work.gd): listed, never claimed.
const SOURCE_KITCHEN: int = 6
## The fishery: fishing trips' seats, traps' collections, the rack, the mill and the gear (water part B, decision 0431;
## demo/work/fishery_work.gd): claimed like the farm's.
const SOURCE_FISHERY: int = 7
## The ferry: gathering the far copse, hauling ferried wood, crewing a crossing (decision 0437; demo/work/ferry_work.gd):
## claimed like the farm's.
const SOURCE_FERRY: int = 8
## The food stores: surplus food carried from a warmer store into a cool cellar (decision 0611; demo/work/stores_work.gd):
## claimed like the farm's, as HAULING. (8 on its own lane; 9 since the batch 7 integration, decision 0902.)
const SOURCE_STORES: int = 9
## The hall's projects: its one tier-2 upgrade and its banners (decision 0771; demo/work/hall_work.gd). (8 on its own
## lane; 10 since the batch 7 integration, decision 0902.)
const SOURCE_HALL: int = 10
## The infirmary building's places: fetching its materials and building it (decision 0623; demo/work/care_work.gd):
## claimed like the farm's. (8 on its own lane; 11 since the batch 7 integration, decision 0902.)
const SOURCE_CARE: int = 11
## The foraging trips' seats: a forager walking to its spot in the woods, gathering, carrying the haul home (decision
## 0681; demo/work/forage_work.gd): claimed like the farm's, the Woods crew's work. (9 on its own lane; 12 since the
## batch 7 integration, decision 0902.)
const SOURCE_FORAGE: int = 12
const SOURCE_COUNT: int = 13
## What each source is called in the Projects view and the Cancel all scope.
const SOURCE_NAMES: Array[String] = ["Farm", "Woods", "Bridges", "Tunnels", "Rooms and fit-out", "Spoil heaps",
	"Kitchen", "Fishery and stations", "Ferry", "Food stores", "The hall", "Infirmary", "Foraging"]
## A queued walk (Shift+right-click on open ground): an order-list entry, never a board task.
const SOURCE_WALK: int = 13

const ACT_FARM: int = 0
const ACT_WOODS: int = 1
const ACT_HAUL: int = 2
const ACT_DIG: int = 3
const ACT_BUILD: int = 4
## Water part B (decision 0431): fishing (a trip's seat, a trap's collection) and the stations' craft (the rack, the
## mill, making and mending gear). No crew prefers them yet: everyone takes them at priority 4 unless the player moves
## them (work_crews.gd), and a boat's helm still needs FISH >= 1.
const ACT_FISH: int = 5
const ACT_CRAFT: int = 6
const ACT_COUNT: int = 7
const ACT_NAMES: Array[String] = ["Farm", "Woods", "Hauling", "Digging", "Building", "Fishing", "Crafting"]

const STATE_QUEUED: int = 0
const STATE_ASSIGNED: int = 1
const STATE_TRAVELLING: int = 2
const STATE_WORKING: int = 3
const STATE_HAULING: int = 4
const STATE_BLOCKED: int = 5
const STATE_PAUSED: int = 6
const STATE_COUNT: int = 7
const STATE_NAMES: Array[String] = ["Queued", "Assigned", "Travelling", "Working", "Hauling", "Blocked", "Paused"]

## REQ-SET-026's priorities.
const PRIORITY_FORBIDDEN: int = 0
const PRIORITY_HIGHEST: int = 1
const PRIORITY_HIGH: int = 2
const PRIORITY_NORMAL: int = 3
const PRIORITY_LOW: int = 4
const PRIORITY_NAMES: Array[String] = ["Forbidden", "Highest", "High", "Normal", "Low"]

## Why a resident cannot take a task -- ONE set of words for the Reassign picker, a group order's preview on the action
## cards and the owners' own refusals (decision 0411, review UX-001 and F44's remainder).
const OTHER_FARM_JOB: String = "has another farm job"
const OTHER_WOODS_JOB: String = "has another woods job"
const OTHER_BRIDGE: String = "builds another bridge"
const HELD: String = "held by the rescue"
const IN_WATER: String = "in the water"
const NOT_FITTING: String = "does not fit this tunnel's bore"
const NOT_A_DIGGER: String = "can't dig (its body fits no standard bore)"
const DIGGING: String = "is digging a tunnel"
const BELOW: String = "is below ground"

## The refusal words the board's own commands answer with (a source's own words are used where it has them).
const NOT_FOUND: String = "that task is no longer on the board"
const CARRYING: String = "%s is carrying the load — it finishes the delivery first"
const DELIVERY_GOES_ON: String = "a delivery always finishes: its load is already cut"
## An earth return (farm_jobs.gd KIND_RETURN_EARTH, decision 0401): a delivery of earth back to its heap or the stores.
const EARTH_GOES_BACK: String = "earth carried back always finishes: it goes back where it was dug"
const PAUSED_ALREADY: String = "it is paused already"


static func is_source(source: int) -> bool:
	"""Whether `source` names one of the board's sources."""
	return source >= 0 and source < SOURCE_COUNT


static func is_activity(activity: int) -> bool:
	"""Whether `activity` names one of the crews' activities."""
	return activity >= 0 and activity < ACT_COUNT


static func is_priority(priority: int) -> bool:
	"""Whether `priority` is one of REQ-SET-026's five."""
	return priority >= PRIORITY_FORBIDDEN and priority <= PRIORITY_LOW
