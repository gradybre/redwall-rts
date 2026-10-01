extends RefCounted
## WHAT AN ORDER INTERRUPTS: the resident an action card names (demo/ui/action_card.gd) stops what it is doing --
## and does it go back to it afterwards? Decision 0331 (review F44). Pure: it reads a brain and asks the job owners,
## never changes either.
##
## The answer is the brain's own RESUMING rule (resident_brain.gd, decision 0205), read in the order the brain applies
## it when an order takes the resident:
##   * a TASK (a tunnel job, an install, a crew place, a sleep) is kept to come back to when the task says there is
##     something to come back to (`unfinished()` not null); a sleep is not kept, but at night the night routine sends
##     a free resident back to bed (night_routine.gd), so the card says so;
##   * a DIG is kept paused with its progress -- unless not one tick of its piece was dug, when the route is DROPPED
##     (underground_graph.gd `stop_digging`): the card warns of that;
##   * an outside job is its OWNER's: the farm's, the woods' and the spoil crew's keep it to come back to; a bridge
##     builder leaves the bridge waiting for a builder (bridge_crew.gd `_drop`). Each owner answers through a rule
##     (`(who: int) -> int`, demo_command.gd `add_resume_rule`) with one of the codes below, or NOT_MINE;
##   * a work spot (a player's right click on a POI) is let go, not kept;
##   * anything else -- wandering, holding where it was sent -- interrupts nothing.

const BrainScript := preload("res://demo/cast/resident_brain.gd")

## An owner's rule: not this owner's resident.
const NOT_MINE: int = -1
## Nothing held: wandering, holding, idle.
const FREE: int = 0
## Kept on the resident's resume list; taken up after the new work.
const RESUMES: int = 1
## Asleep (or night and free): the night routine sends it back to bed after.
const BACK_TO_BED: int = 2
## A task with nothing to come back to (a crew place, an errand).
const DROPS_TASK: int = 3
## A dig with not one tick dug: the route is dropped.
const DROPS_EMPTY_DIG: int = 4
## A player's work spot: let go.
const DROPS_SPOT: int = 5
## A bridge it was building: the bridge waits for a builder.
const DROPS_BRIDGE: int = 6
const WORDS: Array[String] = ["nothing to interrupt", "goes back to it after", "back to bed after",
	"won't go back to it (nothing to come back to)", "won't go back to it: nothing is dug yet, so the route is dropped",
	"won't go back to it (the work spot is let go)", "won't go back to it: the bridge waits for a builder"]
const FREE_HEAD: String = "Free now: "
const BUSY_HEAD: String = "Interrupts: "


static func resume_of(brain: BrainScript, rules: Array[Callable], who: int) -> int:
	"""What happens to resident `who`'s present work when an order takes it (one of the codes above)."""
	if brain.order == BrainScript.ORDER_TASK and brain.task != null:
		if brain.resting:
			return BACK_TO_BED
		return RESUMES if brain.task.unfinished() != null else DROPS_TASK
	if brain.order == BrainScript.ORDER_DIG:
		return RESUMES if _dug_any(brain) else DROPS_EMPTY_DIG
	for rule: Callable in rules:
		var said: int = int(rule.call(who))
		if said != NOT_MINE:
			return said
	if brain.order == BrainScript.ORDER_WORK:
		return DROPS_SPOT
	return BACK_TO_BED if brain.resting else FREE


static func _dug_any(brain: BrainScript) -> bool:
	"""Whether the piece the digger is digging has a tick dug (else stopping drops it)."""
	var network: RefCounted = brain.space().tunnels if brain.space() != null else null
	if network == null or brain.dig_tunnel < 0:
		return false
	var ticks := PackedInt32Array([0, 0])
	network.piece_ticks_into(network.piece[brain.dig_tunnel], ticks)
	return ticks[0] > 0


static func text(activity: String, resume: int) -> String:
	"""The card's line: "Interrupts: Felling the oak — goes back to it after", "Free now: wandering"."""
	if resume == FREE:
		return FREE_HEAD + activity
	return "%s%s — %s" % [BUSY_HEAD, activity, WORDS[resume]]
