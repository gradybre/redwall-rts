extends RefCounted
## THE FIRST-VILLAGE GUIDE'S WORDS, in one place (decision 0481; review F49, P7, UX-017). Every line the objective card
## shows is here, so the decision record can quote them for Brendan's review and a change of wording is one edit.
## Data only: guide_steps.gd chooses which line applies, and fills its blanks from the village's real state.
##
## Each objective has a TITLE, a TEACH line (what it is and why it matters to the village -- its economic reason), and a
## CONFIRM line said once its real outcome has happened. The TRY lines -- the current cause or blocker and the next
## legal action -- are chosen live (guide_steps.gd), from the lines below.

const STEP_TITLES: Array[String] = [
	"Meet a villager",
	"Bring in a harvest",
	"Serve the first supper",
	"Ready the village for the frost",
]
const STEP_TEACH: Array[String] = [
	"Every resident has a trade, needs and work of its own. Selecting one shows what it is doing, what it can do and how well fed it is.",
	"Food only counts once it is in store. A ripe bed is cut, carried and shelved; nothing is credited from afar.",
	"The cook makes supper from 15:00 and calls everyone at 17:00. It needs roots or grain, water in the butt and a little wood.",
	"A frost is coming. Choose one way to be ready -- a bridge over the stream, a dry tunnel route, or fields made safe.",
]
const STEP_CONFIRM: Array[String] = [
	"%s is selected. The Demo party panel (left) shows what it is doing, its skills and what you can order it to do.",
	"%s of %s came into store. The Pantry (K) shows every lot and when it spoils.",
	"%s. The village ate what it grew.",
	"%s",
]
## STEP 4's three ways, by CHOICE_*: the choice, and the confirmation for the one that was done.
const CHOICE_TITLES: Array[String] = ["A bridge", "A dry tunnel route", "Fields made safe"]
const CHOICE_TEACH: Array[String] = [
	"Build a bridge at a site and see someone cross it: loaded crews never swim, and a bridge is the dry way over.",
	"Dig a tunnel from one side to another and see someone walk it: rain and snow do not slow walkers below.",
	"Drain, raise, bank or cover a bed that has a crop: a covered bed keeps 4 °C warmer through a frost night.",
]
const CHOICE_CONFIRM: Array[String] = [
	"%s walked across the new bridge: the stream no longer splits the village.",
	"%s walked through the tunnel dry-shod: the village has a way that weather does not slow.",
	"The %s is ready for the frost (%s): its crop keeps its health.",
]

## The cause / blocker lines (STATE) and the next legal actions (NEXT), by situation.
const NOBODY_SELECTED: String = "Nobody is selected yet."
const NEXT_SELECT: String = "Click the resident under the brass marker, or open Residents (L) and click a row."
const ALL_INDOORS: String = "Everyone is indoors or below ground just now."
const NEXT_SELECT_LIST: String = "Open Residents (L) and click a row to select a resident."

const RIPE_BED: String = "The %s is ripe."
const NEXT_HARVEST: String = "Select a resident and right-click the bed, or click the bed and press Harvest."
const HARVEST_UNDER_WAY: String = "Under way: %s is harvesting the %s."
const DELIVERY_UNDER_WAY: String = "Under way: %s is carrying %s of %s to store."
const NEXT_WAIT_DELIVERY: String = "It counts once it is shelved. Speed time up (2x, 4x) to see it sooner."
const STORE_FULL: String = "No store has room for the harvest: the crop stands uncut."
const NEXT_MAKE_ROOM: String = "Open the Pantry (K): compost spoiled food, or rack a root cellar (Dig tool, C)."
const NOT_RIPE_YET: String = "Nothing is ripe yet: the %s ripens in about %d h."
const NEXT_WAIT_RIPE: String = "Speed time up (2x, 4x), or plant an empty bed meanwhile."
const STALLED: String = "The %s has stopped growing: %s."
const NEXT_FIX_STALL: String = "Click the bed: its Needs line says what to do (Drain a waterlogged bed, Water a dry one)."
const NOTHING_GROWING: String = "No crop is growing in any bed."
const NEXT_PLANT: String = "Click %s and press Plant…; radish ripens soonest."
const BEDS_LOST: String = "Every crop is withered or blighted."
const NEXT_CLEAR: String = "Click %s and press Clear, then plant it again."

const SUPPER_SERVING: String = "Supper is on the table until 19:00: the residents are eating."
const SUPPER_PLANNED: String = "Supper is planned: %s for the village. It is cooked from 15:00 and called at 17:00 (now %02d:00)."
const NEXT_SUPPER_WAIT: String = "Watch it in the Pantry's Kitchen tab (K). Speed time up (2x, 4x) to reach the evening sooner."
const SUPPER_CANT: String = "Can't now: %s."
const NEXT_SUPPER_FIX: String = "To fix: %s."
const SUPPER_MISSED: String = "Supper, day %d: nobody ate. The next supper is tomorrow at 17:00."

const FROST_AHEAD: String = "Frost comes on the night into %s (in about %d h)."
const FROST_TONIGHT: String = "Frost is due tonight, 02:00 to 05:59."
const FROST_NONE: String = "No frost is forecast this year: any of the three still readies the village."
const NEXT_CHOOSE: String = "Do any one of the three; each line says where it stands."
const BRIDGE_NONE: String = "No bridge yet: the Water panel's site has the costs and Build."
const BRIDGE_READY: String = "No bridge yet: a %s can be built at %s now."
const BRIDGE_SHORT: String = "No bridge yet: %s"
const BRIDGE_BUILDING: String = "%s: being built, %d%%."
const BRIDGE_OPEN: String = "%s is open: waiting for someone to walk across it."
const TUNNEL_NONE: String = "No tunnel yet: press B with a mouse, mole or squirrel selected and drag at least 8 m."
const TUNNEL_DIGGING: String = "A tunnel is being dug: %d%%."
const TUNNEL_OPEN: String = "%d tunnel(s) open: waiting for someone to walk through one."
const FIELD_NONE: String = "No bed is readied yet: a bed with a crop can be raised or banked now (tunnel earth)."
const FIELD_COVER: String = "Cover is open now: click a bed with a crop and press Cover."
const FIELD_WET: String = "The %s is wet: click it and press Drain."

## The card's frame.
const CARD_TITLE: String = "Guide %d of %d · %s"
const CARD_DONE_TITLE: String = "Guide · done"
const ALREADY_DONE: String = "Already done: "
const COMPLETE_TITLE: String = "The first village stands"
const COMPLETE_TEXT: String = "You met a villager, brought in a harvest, fed the village its supper and readied it for the frost. The village is yours now: carry on as you like. (The Hearth Charter, the village's long-term goal, is beyond this demo.)"
const CHRONICLE_COMPLETE: String = "The first village stands: a harvest brought in, a supper served, and the village readied for the frost (%s)."
const SHOW_ME: String = "Show me"
const HELP: String = "Help"
const HIDE: String = "Hide guide"
const NEXT: String = "Next ▸"
const CLOSE: String = "Close"
const SHOW_TIP: String = "Centre the camera on the brass marker (and open its panel)"
const HELP_TIP: String = "How-to for this step, in the village guide (O)"
const HIDE_TIP: String = "Hide the guide. Reopen it from the game menu or Objectives (O). Nothing is granted or lost."
const NEXT_TIP: String = "On to the next objective"

## The game menu's guide row and the Objectives command.
const MENU_ROW: String = "First-village guide: %s"
const MENU_STEP: String = "objective %d of %d (%s)"
const MENU_HIDDEN: String = "hidden, at objective %d of %d"
const MENU_DONE: String = "complete"
const SKIP_TEXT: String = "Skip guide"
const REOPEN_TEXT: String = "Reopen guide"
const WINDOW_TEXT: String = "Village guide (O)"
const PRACTICE_TEXT: String = "Practice stories"
const OBJECTIVES_TOOLTIP: String = "Village guide: the first-village objectives, your projects, the field guide, help and practice stories"
