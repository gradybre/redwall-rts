extends RefCounted
## The garden leat as the player runs it: the weir's sluice setting, what each setting does to the zone's beds (the
## PREVIEW, shown before a change), the order that changes it, and the leat in a flood. Decision 0441 (review
## ECO-006). Presentation-side control of a demo rule: nothing here writes into the running settlement.
##
## ONE DECISION, TWO READERS. `preview_into` fills a Preview for any setting from the same reads the midnight uses:
## each zone bed's service (weir_sluice.gd SERVICE_TABLE), its band now, the LEAT'S OWN SHARE at the next midnight
## (farm_sim.gd `leat_delta` on the bed's moisture now -- the midnight works it on the moisture the day left, before
## the weather, so the share agrees unless a job or a flood changes the bed first; the night's weather and the loam's
## natural drainage above the band's top then come on top of it, so a bed near its top keeps less than the share)
## and, while a flood runs, what the flood would do as it passes (`flood_surge`). The sluice's card (`card_into`) and
## its order (`set_sluice`) read the same refusal, so the card and the answer to pressing agree (decision 0332).
##
## THE ORDER is done at once: the sluice wheel on the weir is turned without a resident walking there (a demo
## simplification, recorded in 0441). It costs nothing. The service changes for the next midnight; the panel says so.
##
## FLOODS (demo/events/demo_events.gd KIND_FLOOD, `follow_flood` once a frame). While a flood runs and the sluice is
## not closed, an incident (FLOOD_KEY, a WARNING) says which beds the flood will waterlog or wet when it passes, and
## how to stop it: close the sluice. Closing it in time resolves the incident. When the flood passes with the sluice
## still open, each watered bed takes its `apply_flood_surge` at once, the feed says so, and the incident resolves --
## the waterlogged beds then raise the farm's own wet incidents (farm_alerts.gd), answered by Drain.
##
## TUNNELS AND THE LEAT. A tunnel's drainage and irrigation (farm_tunnels.gd) are unchanged; the leat adds a service
## on top (farm_sim.gd `day_delta`): a bed the leat waters (normal or wet) takes the leat's water instead of a
## tunnel's and is not drained that day; a bed it leaves dry keeps whatever its tunnels, ditch and raising do. So a
## travel tunnel never changes because of the sluice, and closing the sluice puts every zone bed back exactly as the
## tunnels alone would have it.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Sluice := preload("res://demo/water/weir_sluice.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const FLOOD_KEY: String = "leat:flood"
const REFUSE_NONE: String = ""
const REFUSE_SAME: String = "SLUICE_ALREADY_SET"
const REFUSE_UNKNOWN: String = "NO_SUCH_SETTING"
const SAME_WORDS: String = "the sluice is already %s"
const UNKNOWN_WORDS: String = "there is no such sluice setting"
const WHO_TEXT: String = "the sluice wheel on the weir (no one walks there: demo)"
const WHEN_TEXT: String = "At once, no cost; the beds' water changes at the next midnight."
const NEEDS_TEXT: String = "the weir (it stands across the stream)"

## What one setting would do to the zone, bed by bed (a reused object; `preview_into` fills it).
class Preview extends RefCounted:
	var setting: int = Sluice.SLUICE_CLOSED
	## Per zone bed, in leat order: the bed row, its service now and with `setting`, its band now
	## (farm_sim.gd BAND_*), what the leat adds at the next midnight before the weather (moisture points, signed) and
	## what a flood passing now would add.
	var beds: PackedInt32Array = PackedInt32Array()
	var service_now: PackedInt32Array = PackedInt32Array()
	var service_after: PackedInt32Array = PackedInt32Array()
	var band_now: PackedInt32Array = PackedInt32Array()
	var nudge: PackedInt32Array = PackedInt32Array()
	var flood_rise: PackedInt32Array = PackedInt32Array()
	## Per zone bed, its band were a flood to pass now with `setting` (its band now when no flood runs).
	var flood_band: PackedInt32Array = PackedInt32Array()
	## Whether a flood is running now (the flood line is said only then).
	var flooding: bool = false
	var text: String = ""

	func size() -> int:
		"""How many beds the preview covers (the zone's)."""
		return beds.size()

var setting: int = Sluice.OPENING_SLUICE
## Bumped by every change a reader could see (a setting, a flood starting or passing).
var revision: int = 0
## Whether a flood is running (as last followed).
var flooding: bool = false

var _sim: SimScript = null
var _incidents: IncidentsScript = null
var _notices: NoticesScript = null
var _preview: Preview = Preview.new()
var _scratch: Preview = Preview.new()


func configure(sim: SimScript, incidents: IncidentsScript = null, notices: NoticesScript = null) -> void:
	"""Run the leat over `sim`, raising its flood incident in `incidents` and its lines in `notices` (either may be
	null in checks). The zone's service is written at once."""
	_sim = sim
	_incidents = incidents
	_notices = notices
	push()


func push() -> void:
	"""Write every bed's leat service for the setting now into the farm (the midnight applies it)."""
	if _sim == null:
		return
	for bed: int in Catalog.BED_COUNT:
		_sim.set_leat_service(bed, Sluice.service_for(setting, bed))


# --- the order and its card ------------------------------------------------------------------------------

func refusal(to: int) -> String:
	"""Why the sluice cannot be set to `to` now (REFUSE_NONE: it can)."""
	if not Sluice.is_sluice(to):
		return REFUSE_UNKNOWN
	if to == setting:
		return REFUSE_SAME
	return REFUSE_NONE


func set_sluice(to: int) -> String:
	"""THE ORDER: set the sluice to `to` (see THE ORDER). Returns the answer the panel shows: what changed, or why
	not -- the card's own words."""
	var code: String = refusal(to)
	if code != REFUSE_NONE:
		return "Can't: " + refusal_words(code)
	setting = to
	push()
	revision += 1
	if flooding:
		_flood_check()
	preview_into(setting, _scratch)
	return preview_text(_scratch, "Sluice now %s" % Sluice.SLUICE_NAMES[setting].to_lower())


func refusal_words(code: String) -> String:
	"""A refusal code in words."""
	if code == REFUSE_SAME:
		return SAME_WORDS % Sluice.SLUICE_NAMES[setting].to_lower()
	if code == REFUSE_UNKNOWN:
		return UNKNOWN_WORDS
	return ""


func card_into(card: CardScript, to: int) -> CardScript:
	"""Setting `to`'s action card: the verb, the preview as the result (at once and free: no Work or cost line), who
	turns it, and -- when refused -- the order's own refusal. Returns `card`."""
	card.reset("Sluice: %s" % (Sluice.SLUICE_VERBS[to] if Sluice.is_sluice(to) else "?"))
	card.prerequisites.append(NEEDS_TEXT)
	var code: String = refusal(to)
	if code != REFUSE_NONE:
		card.refuse(code, refusal_words(code), "choose another setting" if code == REFUSE_SAME else "")
		return card
	preview_into(to, _scratch)
	card.result = _scratch.text + " " + WHEN_TEXT
	card.who = WHO_TEXT
	return card


# --- the preview ---------------------------------------------------------------------------------------

func preview() -> Preview:
	"""The preview of the setting now (filled afresh)."""
	return preview_into(setting, _preview)


func preview_into(to: int, out: Preview) -> Preview:
	"""What setting `to` does to each zone bed now (see ONE DECISION, TWO READERS), and its words. Returns `out`."""
	out.setting = to
	out.flooding = flooding
	for column: PackedInt32Array in [out.beds, out.service_now, out.service_after, out.band_now, out.nudge,
			out.flood_rise, out.flood_band]:
		column.resize(Sluice.ZONE_SIZE)
	for k: int in Sluice.ZONE_SIZE:
		var bed: int = Sluice.ZONE_BEDS[k]
		var after: int = Sluice.service_for(to, bed)
		out.beds[k] = bed
		out.service_now[k] = _sim.leat_service_of(bed)
		out.service_after[k] = after
		out.band_now[k] = _sim.band_of(bed)
		out.nudge[k] = SimScript.leat_delta(after, _sim.moisture_of(bed), _sim.band_min_of(bed), _sim.band_max_of(bed))
		out.flood_rise[k] = _sim.flood_surge(bed, after) if flooding else 0
		out.flood_band[k] = _sim.band_at(bed, _sim.moisture_of(bed) + out.flood_rise[k])
	out.text = preview_text(out)
	return out


static func preview_text(p: Preview, head: String = "") -> String:
	"""'Open: Bed 2 and Bed 4 go to wet, Bed 6 to normal. Bed 4 is already waterlogged.' -- then, in a flood, what
	the flood would do as it passes with this setting. `head` replaces the setting's name before the colon."""
	var parts := PackedStringArray()
	for service: int in [Sluice.SERVICE_WET, Sluice.SERVICE_NORMAL, Sluice.SERVICE_DRY]:
		var group: PackedInt32Array = _beds_where(p, service)
		if not group.is_empty():
			parts.append(_group_words(group, service, parts.is_empty()))
	var text: String = "%s: %s." % [head if not head.is_empty() else Sluice.SLUICE_NAMES[p.setting], ", ".join(parts)]
	var already: String = _already_text(p)
	if not already.is_empty():
		text += " " + already
	if p.flooding:
		text += " " + _flood_text(p)
	return text


static func _group_words(group: PackedInt32Array, service: int, first: bool) -> String:
	"""One group of beds and what it gets: 'Bed 2 and Bed 4 go to wet' first, then 'Bed 6 to normal'; for dry,
	'... get no leat water' first, then 'Bed 6 gets none'."""
	var many: bool = group.size() > 1
	var beds: String = Sluice.list_words(group)
	if service == Sluice.SERVICE_DRY:
		if first:
			return "%s %s no leat water" % [beds, "get" if many else "gets"]
		return "%s %s none" % [beds, "get" if many else "gets"]
	if first:
		return "%s %s %s" % [beds, "go to" if many else "goes to", Sluice.SERVICE_NAMES[service]]
	return "%s to %s" % [beds, Sluice.SERVICE_NAMES[service]]


static func _already_text(p: Preview) -> String:
	"""The warnings: a bed sent wetter that is already wet or waterlogged, one left dry that is already dry."""
	var said := PackedStringArray()
	for k: int in p.size():
		var band: int = p.band_now[k]
		var after: int = p.service_after[k]
		if after == Sluice.SERVICE_WET and band >= SimScript.BAND_WET:
			said.append("%s is already %s." % [Sluice.bed_word(p.beds[k]), SimScript.BAND_NAMES[band]])
		elif after == Sluice.SERVICE_DRY and band == SimScript.BAND_DRY:
			said.append("%s is already dry." % Sluice.bed_word(p.beds[k]))
	return " ".join(said)


static func _flood_text(p: Preview) -> String:
	"""In a flood: which beds it would leave waterlogged or wet as it passes with this setting, or that none is at
	risk."""
	var drowned: PackedInt32Array = _beds_after_flood(p, SimScript.BAND_WATERLOGGED)
	var wetted: PackedInt32Array = _beds_after_flood(p, SimScript.BAND_WET)
	if drowned.is_empty() and wetted.is_empty():
		return "Flood: no bed is at risk from the leat."
	var harm := PackedStringArray()
	if not drowned.is_empty():
		harm.append("waterlogs " + Sluice.list_words(drowned))
	if not wetted.is_empty():
		harm.append("wets " + Sluice.list_words(wetted))
	return "Flood: left like this, it %s as it passes." % " and ".join(harm)


static func _beds_where(p: Preview, service: int) -> PackedInt32Array:
	"""The zone beds whose service with the setting is `service`."""
	var out := PackedInt32Array()
	for k: int in p.size():
		if p.service_after[k] == service:
			out.append(p.beds[k])
	return out


static func _beds_after_flood(p: Preview, band: int) -> PackedInt32Array:
	"""The zone beds a flood passing now would raise into `band`."""
	var out := PackedInt32Array()
	for k: int in p.size():
		if p.flood_rise[k] > 0 and p.flood_band[k] == band:
			out.append(p.beds[k])
	return out


# --- floods --------------------------------------------------------------------------------------------

func follow_flood(active: bool) -> void:
	"""Once a frame: whether a flood is running (see FLOODS). Its start raises the incident when beds are at risk;
	its passing lands the surge on the watered beds."""
	if active == flooding:
		return
	flooding = active
	revision += 1
	if active:
		_flood_check()
	else:
		_flood_passed()


func at_risk() -> PackedInt32Array:
	"""The zone beds a flood passing now would raise (the setting now)."""
	preview_into(setting, _scratch)
	var out := PackedInt32Array()
	for k: int in _scratch.size():
		if _scratch.flood_rise[k] > 0:
			out.append(_scratch.beds[k])
	return out


func _flood_check() -> void:
	"""During a flood: raise the incident while beds are at risk (said in the feed once), its words kept current as the
	setting changes (no second warning), and resolve it once none is."""
	var risk: PackedInt32Array = at_risk()
	if _incidents == null:
		return
	if risk.is_empty():
		_incidents.update(FLOOD_KEY, IncidentsScript.STATE_RESOLVED, "Flood: the weir sluice is closed; the garden is safe.")
		return
	var text: String = "Flood at the weir with the sluice %s. %s To spare them, close it (Farm ▸ Sluice…)." % [
		Sluice.SLUICE_NAMES[setting].to_lower(), _flood_text(_scratch)]
	if _incidents.update(FLOOD_KEY, IncidentsScript.STATE_NEEDS_DECISION, text):
		return
	_incidents.report(FLOOD_KEY, NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, text,
		"Flood: sluice open", NoticesScript.TARGET_BED, risk[0])


func _flood_passed() -> void:
	"""The flood has gone by: the watered beds take their surge, the feed says what it did, the incident resolves."""
	var hit := PackedInt32Array()
	for k: int in Sluice.ZONE_SIZE:
		var bed: int = Sluice.ZONE_BEDS[k]
		if _sim.apply_flood_surge(bed) > 0:
			hit.append(bed)
	if _incidents != null:
		_incidents.resolve(FLOOD_KEY)
	if hit.is_empty() or _notices == null:
		return
	_notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING,
		"The flood ran down the open leat: %s now %s." % [Sluice.list_words(hit), _bands_words(hit)],
		"Flood ran down the leat", NoticesScript.TARGET_BED, hit[0])


func _bands_words(beds: PackedInt32Array) -> String:
	"""'waterlogged' or 'wet / waterlogged' -- each bed's band after the surge, in order."""
	var words := PackedStringArray()
	for bed: int in beds:
		words.append(SimScript.BAND_NAMES[_sim.band_of(bed)])
	return " / ".join(words)


# --- readouts ------------------------------------------------------------------------------------------

func service_line(bed: int) -> String:
	"""A bed's leat line for its panel: 'Garden leat: wet (sluice open)'; '' outside the zone."""
	if not Sluice.in_zone(bed):
		return ""
	var service: int = _sim.leat_service_of(bed)
	return "Garden leat: %s (sluice %s)" % [Sluice.SERVICE_NAMES[service], Sluice.SLUICE_NAMES[setting].to_lower()]


func flow_permille() -> int:
	"""How full the leat runs now (weir_sluice.gd FLOW_PERMILLE): the gate's lift and the channel's water."""
	return Sluice.FLOW_PERMILLE[setting]
