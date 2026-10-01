extends RefCounted
## THE FIRST-VILLAGE GUIDE'S PROGRESS (decision 0481; review F49, P7, UX-017): which of the four objectives is current,
## whether its card is teaching (TRY), confirming what just happened (CONFIRM) or the guide is complete, and whether
## the player has hidden it. Pure logic: the facts (guide_facts.gd) say what happened, this says what to show.
##
## ONE AT A TIME. The current objective is the first not yet done, in order: meet a villager, bring in a harvest,
## serve the first supper, ready the village for the frost. An objective is DONE exactly when its fact is latched --
## no button, no timer completes one. When the current one is done its card CONFIRMS it (the real figures) for
## CONFIRM_S seconds of UNPAUSED time, or until Next; one already done when it came up is confirmed "Already done:"
## for ALREADY_S. Paused, a confirmation waits (P7: "Pause does not complete steps or lose guidance").
##
## SKIP AND REOPEN (REQ-SET-168). `hide_guide` hides the card; `reopen` shows it again at the first objective not done.
## Neither touches the facts, the village or its stores: skipping grants nothing and loses nothing. Hidden, the guide
## keeps up silently -- done objectives are passed without confirmations -- so reopening lands on what is left.
##
## COMPLETE. Past the fourth, the guide is complete: `take_completion()` answers true once, and the owner writes the
## chronicle entry that acknowledges the community (demo_guide.gd).

const FactsScript := preload("res://demo/guide/guide_facts.gd")

const STEP_MEET: int = 0
const STEP_HARVEST: int = 1
const STEP_SUPPER: int = 2
const STEP_SEASON: int = 3
const STEP_COUNT: int = 4
const PHASE_TRY: int = 0
const PHASE_CONFIRM: int = 1
const PHASE_COMPLETE: int = 2
## Seconds of unpaused time a confirmation stays before the next objective (Next goes at once).
const CONFIRM_S: float = 10.0
const ALREADY_S: float = 5.0

var current: int = STEP_MEET
var phase: int = PHASE_TRY
var hidden: bool = false
## Whether the confirmation shown is for an objective that was done before its card came up.
var already: bool = false
var confirm_left_s: float = 0.0
## Bumped on every change the card shows.
var revision: int = 0

var _arrived: bool = true
var _completion_pending: bool = false


static func is_done(step: int, facts: FactsScript) -> bool:
	"""Whether objective `step` has its real outcome (see the header)."""
	match step:
		STEP_MEET: return facts.met
		STEP_HARVEST: return facts.harvested_milli > 0
		STEP_SUPPER: return facts.supper_eaten
		STEP_SEASON: return facts.choice != FactsScript.CHOICE_NONE
	return false


func done_count(facts: FactsScript) -> int:
	"""How many of the four objectives are done (whatever the order they happened in)."""
	var n: int = 0
	for step: int in STEP_COUNT:
		if is_done(step, facts):
			n += 1
	return n


func update(facts: FactsScript, unpaused_s: float) -> void:
	"""One look: confirm the current objective when it is done, count a confirmation down by the unpaused time since
	the last look, and move on. Hidden, done objectives are passed silently."""
	if phase == PHASE_COMPLETE:
		return
	if hidden:
		_pass_done(facts)
		return
	if phase == PHASE_CONFIRM:
		confirm_left_s -= maxf(unpaused_s, 0.0)
		if confirm_left_s <= 0.0:
			next()
		return
	if is_done(current, facts):
		phase = PHASE_CONFIRM
		already = _arrived
		confirm_left_s = ALREADY_S if already else CONFIRM_S
		revision += 1
	_arrived = false


func next() -> void:
	"""Past the confirmation (Next, or its time ran out): on to the next objective, or complete."""
	if phase != PHASE_CONFIRM:
		return
	_advance()


func _advance() -> void:
	"""The next objective (it 'arrives': done already, its confirmation says so), or complete after the fourth."""
	current += 1
	already = false
	_arrived = true
	phase = PHASE_TRY
	if current >= STEP_COUNT:
		current = STEP_COUNT
		phase = PHASE_COMPLETE
		_completion_pending = true
	revision += 1


func _pass_done(facts: FactsScript) -> void:
	"""Hidden: move past every done objective, no confirmations."""
	if phase == PHASE_CONFIRM:
		phase = PHASE_TRY
	while phase != PHASE_COMPLETE and is_done(current, facts):
		_advance()
	_arrived = true


func hide_guide() -> void:
	"""Skip: hide the card (nothing else changes)."""
	if not hidden:
		hidden = true
		revision += 1


func reopen() -> void:
	"""Show the card again where the guide stands."""
	if hidden:
		hidden = false
		_arrived = true
		revision += 1


func is_complete() -> bool:
	"""Whether all four objectives are done and confirmed."""
	return phase == PHASE_COMPLETE


func take_completion() -> bool:
	"""True once, when the guide has just completed (the owner writes the chronicle)."""
	var pending: bool = _completion_pending
	_completion_pending = false
	return pending
