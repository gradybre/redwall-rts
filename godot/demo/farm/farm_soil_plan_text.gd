extends RefCounted
## The soil plans' words (decision 0451, ECO-005): each plan as lines a column of the planner shows, every figure from
## farm_soil_plans.gd and said the bed panel's way (decision 0251: percentages, points, one `units_text`).

const Plans := preload("res://demo/farm/farm_soil_plans.gd")
const RecordText := preload("res://demo/farm/farm_record_text.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

const NONE: String = "—"


static func day_text(day: int) -> String:
	"""An absolute calendar day (1 = spring 1) as the HUD names it."""
	return RecordText.day_name(day - 1)


static func steps_line(plan: Plans.Plan) -> String:
	"""What the plan does, in order."""
	match plan.kind:
		Plans.PLAN_COMPOST:
			return "Compost on %s (%s), then %s" % [day_text(plan.start_day), Text.units_text(
				Plans.FarmingScript.COMPOST_MILLI_PER_TILE), _sow_words(plan)]
		Plans.PLAN_LEGUME:
			var sow: String = _sow_words(plan)
			return "%s%s, then rest it to %s" % [sow.left(1).to_upper(), sow.substr(1), day_text(plan.end_day)]
	return "Rest it from %s to %s; nothing is sown" % [day_text(plan.start_day), day_text(plan.end_day)]


static func _sow_words(plan: Plans.Plan) -> String:
	"""'sow carrot on Spring 3' or 'no planting window for carrot this season'."""
	if not Catalog.is_item(plan.crop):
		return "nothing to sow"
	var name: String = Catalog.ITEM_LABELS[plan.crop].to_lower()
	if plan.sow_day == Plans.NO_DAY:
		return "no planting window for %s this season" % name
	return "sow %s on %s" % [name, day_text(plan.sow_day)]


static func harvest_line(plan: Plans.Plan) -> String:
	"""'This season: carrot, about 5.4 U, ≈ Spring 8' or 'This season: no harvest'."""
	if plan.harvest_day == Plans.NO_DAY:
		return "This season: no harvest"
	var when: String = day_text(plan.harvest_day)
	var late: String = " (after this season)" if plan.harvest_day > plan.end_day else ""
	return "This season: %s, about %s, ≈ %s%s" % [Catalog.ITEM_LABELS[plan.crop].to_lower(),
		Text.units_text(plan.harvest_milli), when, late]


static func soil_line(plan: Plans.Plan, fertility_now: int) -> String:
	"""'Soil at the season's end: fertility 74% (now 63%: +11 points)'."""
	return "Soil at the season's end: fertility %s (now %s: %s points)" % [Text.percent_text(plan.fertility_end),
		Text.percent_text(fertility_now), Text.points_text(plan.fertility_end - fertility_now, true)]


static func next_line(plan: Plans.Plan) -> String:
	"""What the next crop would then yield: 'Then carrot: about 5.7 U' (the compost plan's harvest is its next crop)."""
	if not Catalog.is_item(plan.next_crop):
		return "Then: no crop suits this soil"
	var name: String = Catalog.ITEM_LABELS[plan.next_crop].to_lower()
	if plan.kind == Plans.PLAN_COMPOST:
		return "Next %s: about %s (this season's harvest)" % [name, Text.units_text(plan.next_milli)] \
			if plan.harvest_day != Plans.NO_DAY else "Next %s: not this season" % name
	return "Then %s, sown after it: about %s" % [name, Text.units_text(plan.next_milli)]


static func staff_line(plan: Plans.Plan) -> String:
	"""'Staff time: about 29 game minutes (0.05 staff-days)' -- the action cards' time, and staff-days of 10 work hours."""
	if plan.work_usec <= 0:
		return "Staff time: none"
	var hundredths: int = Plans.staff_hundredths(plan.work_usec)
	return "Staff time: %s (%d.%02d staff-days)" % [CardScript.hours_text(plan.work_usec), hundredths / 100,
		hundredths % 100]


static func lines(plan: Plans.Plan, fertility_now: int) -> PackedStringArray:
	"""The plan's lines, top down: steps, this season's harvest, the soil after, the next crop, staff time."""
	return PackedStringArray([steps_line(plan), harvest_line(plan), soil_line(plan, fertility_now), next_line(plan),
		staff_line(plan)])


static func warning(plan: Plans.Plan) -> String:
	"""Why it cannot be done ('Can't now: ...') or what it lacks ('Needs: ...'); '' when nothing stands in its way."""
	if not plan.refusal.is_empty():
		return "Can't now: " + plan.refusal
	if not plan.needs.is_empty():
		return "Needs: " + plan.needs
	return ""


static func compared_for(next: int, start: Plans.Start) -> String:
	"""Whose next crop the plans compare and from when: 'Compared for the next carrot, from Spring 3' (an estimate when
	the bed is not empty yet)."""
	var name: String = Catalog.ITEM_LABELS[next].to_lower() if Catalog.is_item(next) else "crop"
	var from: String = ("≈ %s, once its crop is in" if start.estimated else "%s") % day_text(start.day)
	return "Compared for the next %s, from %s; one season (12 days). A crop ripens at a full growth rate here." % [name,
		from]
