extends SceneTree
## Read-only diagnostic of the existing planner's claimed derived dirty worklists.
## Private reads here compare the exact declared canonical projection; no runtime adapter.
const Planner = preload("res://scripts/core/job_planner.gd")
const Section = preload("res://scripts/core/save_section_job_indexes.gd")

func _initialize() -> void:
	var output: Array[Dictionary] = []
	for order: Array in [[0, 1], [1, 0], []]:
		var planner: Planner = Planner.new()
		for tile: int in [100, 101]:
			var made = planner.farming().create_plot_at_tile(tile, 0, 1)
			assert(made.ok)
			assert(planner.farming().plant(made.value, 3, 1, 0, 1).ok)
			assert(planner.farming().begin_growing(made.value).ok)
		for row: int in order:
			assert(planner.mark_plot_dirty(row).ok)
		var canonical: PackedByteArray = PackedByteArray()
		for key in Section.FIELD_KEYS:
			var column: Variant = planner.get(String(key))
			if column is PackedByteArray:
				canonical.append_array(column)
			else:
				canonical.append_array(column.to_byte_array())
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(canonical)
		var before: String = hash.finish().hex_encode()
		var ran = planner.run_tick(600)
		assert(ran.ok)
		var ids: Array[int] = []
		for row: int in [0, 1]:
			ids.append(planner.jobs().directory().get_persistent_id(planner.service_job_of(row, 0)))
		output.append({"dirty_mark_order":order,"section8_before_sha256":before,
			"canonical_bytes":canonical.size(),"created":ran.value,"plot_job_ids":ids})
	print("PLANNER_DIRTY_PROBE=" + JSON.stringify(output))
	assert(output[0]["section8_before_sha256"] == output[1]["section8_before_sha256"])
	assert(output[1]["section8_before_sha256"] == output[2]["section8_before_sha256"])
	assert(output[0]["plot_job_ids"] != output[1]["plot_job_ids"])
	assert(output[2]["created"] == 1 and output[0]["created"] == 2)
	quit(0)
