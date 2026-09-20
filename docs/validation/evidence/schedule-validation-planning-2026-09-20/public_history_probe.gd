extends SceneTree
const Needs := preload("res://scripts/core/needs.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
func _initialize() -> void:
	"""Observe history retention through public APIs without reading private owner columns."""
	var needs: Needs = Needs.new()
	assert(needs.spawn(0,Needs.SIZE_MEDIUM).ok)
	var columns: Needs.Columns = Needs.Columns.new()
	assert(needs.copy_columns_into(columns))
	columns.need_value[Needs.NEED_REST] = 9500
	columns.need_value[Needs.NEED_HUNGER] = 8000
	assert(needs.restore_columns(columns))
	var schedule: Schedule = Schedule.new(needs)
	var template: Variant = schedule.default_template_id()
	assert(template.ok)
	assert(schedule.spawn(0,template.value).ok)
	var unresolved: Variant = schedule.current_activity_of(0)
	assert(not unresolved.ok)
	assert(schedule.sleep_satisfied_of(0).value == 0)
	assert(schedule.resolve(0,22,false).value == Schedule.ACTIVITY_ANYTHING)
	assert(schedule.sleep_satisfied_of(0).value == 1)
	assert(schedule.set_hour_activity(0,22,Schedule.ACTIVITY_WORK).ok)
	var edited: Dictionary = {"hour":schedule.hour_activity_of(0,22).value,
		"current":schedule.current_activity_of(0).value,"sleep":schedule.sleep_satisfied_of(0).value}
	assert(edited.hour == Schedule.ACTIVITY_WORK and edited.current == Schedule.ACTIVITY_ANYTHING and edited.sleep == 1)
	assert(schedule.resolve(0,18,false).value == Schedule.ACTIVITY_SOCIAL)
	var flexible: Variant = schedule.template_id_of(&"flexible")
	assert(flexible.ok and schedule.assign_template(0,flexible.value).ok)
	var reassigned: Dictionary = {"hour":schedule.hour_activity_of(0,18).value,
		"current":schedule.current_activity_of(0).value,"sleep":schedule.sleep_satisfied_of(0).value}
	assert(reassigned.hour == Schedule.ACTIVITY_ANYTHING and reassigned.current == Schedule.ACTIVITY_SOCIAL and reassigned.sleep == 0)
	assert(not schedule.resolve(0,24,false).ok)
	assert(schedule.current_activity_of(0).value == Schedule.ACTIVITY_SOCIAL)
	print("SCHEDULE_HISTORY_PROBE "+JSON.stringify({"edited_latched":edited,"reassigned_resolved":reassigned,"invalid_hour_preserves_current":true}))
	quit(0)
