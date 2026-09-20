extends SceneTree
## Isolated source feasibility: a normal owner can retain a stale pending reference.
const Planner := preload("res://scripts/core/job_planner.gd")
const Section := preload("res://scripts/core/save_section_job_indexes.gd")

func _init() -> void:
	var planner: Planner = Planner.new()
	var plot: int = planner.farming().create_plot_at_tile(100, 0, 1).value
	assert(planner.farming().plant(plot, 3, 1, 0, 1).ok)
	assert(planner.farming().begin_growing(plot).ok)
	assert(planner.reconcile_plot(plot, 600).ok)
	var job: Vector2i = planner.service_job_of(plot, 0)
	assert(planner.jobs().destroy_job(planner.directory().get_typed_row(job)).ok)
	var record: Section.Record = Section.Record.new()
	for field: int in Section.FIELD_COUNT:
		var value: Variant = planner.get(String(Section.FIELD_KEYS[field]))
		var bytes: PackedByteArray
		if value is int:
			bytes = PackedInt32Array([value]).to_byte_array()
		elif value is PackedByteArray:
			bytes = value.duplicate()
		else:
			bytes = value.to_byte_array()
		record.assign_column(field, bytes)
	var valid = Section.record_refusal(record)
	print("pending=", planner.pending_service_count(), " ref=", job,
		" resolves=", planner.directory().is_valid(job), " structural_refusal=", valid.code)
	assert(planner.pending_service_count() == 1)
	assert(not planner.directory().is_valid(job))
	assert(valid.is_ok())
	assert(planner.reconcile_plot(plot, 600).ok)
	print("natural_reconcile_new_ref=", planner.service_job_of(plot, 0),
		" pending=", planner.pending_service_count())
	assert(planner.service_job_of(plot, 0) != job)
	assert(planner.pending_service_count() == 1)
	quit(0)
