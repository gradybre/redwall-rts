extends RefCounted
## The words of a route estimate, a group's fit and a project's materials, for the Water and Tunnels panels and the
## Routes layer. Decision 0461 (review P5). Presentation only: every figure is read from its owner (the estimate,
## the network's fit, the stores, the bridge crew), and the uncertainty is always said.
##
## TIMES are walking time on the demo calendar (action_card.gd `hours_text`: game minutes, or hours to the tenth),
## from the router's cost at the walker's pace (route_estimator.gd `pace_m_s`). An estimate still being worked on says
## CALCULATING, never a number; a trip with no way says so; "after" is compared only when both are known.
##
## FIT is said by body and load, never by species (the review's "species-neutral"): a bore's clear width and height,
## and for a group each member by name with its own verdict (MOVE-REQ-012: one member fitting is never the group's).

const EstimatorScript := preload("res://demo/routes/route_estimator.gd")
const ReasonsScript := preload("res://demo/routes/route_reasons.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

const CALCULATING: String = "calculating…"
const NO_WAY: String = "no way"
const NO_TRIPS: String = "no work trip passes near it yet"
const ESTIMATE_NOTE: String = ("Estimate: the demo's routing at today's weather and today's lines at the tunnel mouths — "
	+ "walking time only, no turns or anyone in the way. Movement rules are not final (MOVE-G01–05).")
const BRIDGE_WHO: String = "Who can use it: anyone, carrying or not — a deck needs no swimming"
const FITS: String = "fits, carrying too"
const FITS_UNLOADED: String = "fits, but not with a load (load too wide)"
const TOO_BIG: String = "too big for this bore"
const USEC_PER_S: float = 1000000.0


static func time_text(cost_m: float, pace_m_s: float) -> String:
	"""A route's cost as walking time on the calendar ("about 40 game minutes"); NO_WAY with no route."""
	var seconds: float = EstimatorScript.seconds_of(cost_m, pace_m_s)
	if seconds == INF:
		return NO_WAY
	return CardScript.hours_text(roundi(seconds * USEC_PER_S))


static func short_time_text(cost_m: float, pace_m_s: float) -> String:
	"""A route's walking time, short, for a map label: "13 game min", "1.4 game h" (rounded up); NO_WAY with none."""
	var seconds: float = EstimatorScript.seconds_of(cost_m, pace_m_s)
	if seconds == INF:
		return NO_WAY
	var usec: int = roundi(seconds * USEC_PER_S)
	var minutes: int = (usec * 60 + CalendarScript.HOUR_USEC - 1) / CalendarScript.HOUR_USEC
	if minutes < 60:
		return "%d game min" % maxi(minutes, 1)
	var tenths: int = (usec * 10 + CalendarScript.HOUR_USEC - 1) / CalendarScript.HOUR_USEC
	return "%d.%d game h" % [tenths / 10, tenths % 10]


static func trip_line(estimate: EstimatorScript, k: int, pace_m_s: float) -> String:
	"""Trip `k` now and after: "the store to the farm: now about 2.1 game hours, after about 50 game minutes (60%
	quicker)"; CALCULATING until both are known; "no quicker" when the proposal does not shorten it."""
	var name: String = estimate.trip_names[k]
	if not estimate.trip_known(k):
		return "%s: %s" % [name, CALCULATING]
	var before: String = time_text(estimate.before_m[k], pace_m_s)
	if estimate.proposal == EstimatorScript.PROPOSE_NONE:
		return "%s: %s" % [name, before]
	var after: String = time_text(estimate.after_m[k], pace_m_s)
	var saving: float = estimate.saving_m(k)
	if saving == INF:
		return "%s: now %s, after %s (a way where there was none)" % [name, before, after]
	var percent: int = floori(saving * 100.0 / estimate.before_m[k]) if saving > 0.0 else 0
	if percent <= 0:
		return "%s: %s — no quicker this way" % [name, before]
	return "%s: now %s, after %s (%d%% quicker)" % [name, before, after, percent]


static func benefit_lines(estimate: EstimatorScript, pace_m_s: float, who: String) -> PackedStringArray:
	"""The estimate as lines: a heading naming whose trips (`who`), a line a trip, and the note on what it is."""
	var lines := PackedStringArray()
	var state: String = CALCULATING if estimate.is_calculating() else ""
	lines.append("Benefit (estimate, %s)%s" % [who, "" if state.is_empty() else ": " + state])
	for k: int in estimate.trip_count:
		lines.append("  " + trip_line(estimate, k, pace_m_s))
	if estimate.trip_count == 0:
		lines.append("  " + NO_TRIPS)
	if estimate.proposal != EstimatorScript.PROPOSE_NONE and not estimate.proposal_ok:
		lines.append("  The network has no room to take this piece as laid")
	lines.append(ESTIMATE_NOTE)
	return lines


static func bore_who(bore_class: int, fitting: int, fitting_loaded: int, total: int) -> String:
	"""Who a bore of `bore_class` takes, by body ("up to 1.0 m across, 1.2 m tall standing") and how many here."""
	var across: float = Rules.to_m(Rules.BORE_WIDTHS_U[bore_class])
	var tall: float = Rules.to_m(Rules.BORE_HEIGHTS_U[bore_class]) * float(Rules.PERMILLE) / float(Rules.STOOP_PERMILLE)
	return "Who can use it: bodies up to %.1f m across and %.1f m tall (stooping), a load across the body included — %d of the %d here fit it, %d of them carrying too" % [
		across, tall, fitting, total, fitting_loaded]


static func member_lines(graph: GraphScript, members: PackedInt32Array, bore_class: int, carrying: bool,
		name_of: Callable) -> PackedStringArray:
	"""Each member's own verdict for a bore of `bore_class` (carrying, when `carrying`): "Mouse keeper: fits, carrying
	too" -- never the first member's for the rest (see FIT)."""
	var lines := PackedStringArray()
	for who: int in members:
		var why: int = ReasonsScript.fit_reason(graph, who, bore_class, carrying)
		var verdict: String = FITS if why == ReasonsScript.NONE else (FITS_UNLOADED if why == ReasonsScript.LOAD_TOO_WIDE else TOO_BIG)
		lines.append("%s: %s" % [String(name_of.call(who)), verdict])
	return lines


static func fit_counts(graph: GraphScript, residents: int, bore_class: int) -> Vector2i:
	"""How many of the first `residents` fit a bore of `bore_class` at all (x), and carrying (y)."""
	var out := Vector2i.ZERO
	for who: int in residents:
		out.x += 1 if graph.fit_class_refusal(who, bore_class, false) == Rules.FIT_OK else 0
		out.y += 1 if graph.fit_class_refusal(who, bore_class, true) == Rules.FIT_OK else 0
	return out
