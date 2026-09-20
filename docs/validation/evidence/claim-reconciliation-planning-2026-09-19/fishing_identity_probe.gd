extends SceneTree
## Diagnostic witness only: exit 0 means the existing alias was reproduced, not fixed.
const Residents := preload("res://scripts/core/residents.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Fish := preload("res://scripts/core/fishing.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
func _initialize() -> void:
	var residents: Residents = Residents.new()
	var priorities: Priorities = Priorities.new()
	var schedule: Schedule = Schedule.new(residents.needs())
	var jobs: Jobs = Jobs.new(residents,priorities,schedule)
	var forage: Forage = Forage.new(null,jobs)
	var fish: Fish = Fish.new(null,forage,jobs)
	var job: Jobs.OpResult = jobs.create_job(2,0,0,100,10)
	var habitat: Fish.OpResult = fish.create_habitat(2,Directory.NULL_REF,PackedInt32Array([10,11,12]),0,0,0)
	var a: Vector2i = fish.directory().create(Directory.KIND_EXPEDITION)
	var row: int = fish.directory().get_typed_row(a)
	if not job.ok or not habitat.ok or not fish.reserve_effort_slots(a,job.ref,habitat.ref,2).ok:
		push_error("fixture admission failed");quit(2);return
	if not fish.directory().destroy(a):
		push_error("destroy failed");quit(2);return
	var zone: Forage.OpResult = forage.create_zone(2,1,1000,false,true)
	var b: Vector2i = fish.directory().create(Directory.KIND_EXPEDITION)
	var rebuilt: Vector2i = fish.effort_claim_expedition_ref_of(row)
	var purged: Fish.OpResult = fish.purge_stale_effort_claims()
	var aliased_release: Fish.OpResult = fish.release_effort_slots(b)
	var witnessed: bool = zone.ok and zone.ref.x == a.x and b.x != a.x and b.y == a.y and rebuilt == b and purged.ok and purged.value == 0 and aliased_release.ok
	print(JSON.stringify({"diagnostic_witness_only":true,"original_expedition":str(a),"replacement_zone":str(zone.ref),"new_expedition":str(b),"typed_row":row,"reconstructed_claim_owner":str(rebuilt),"purged_count":purged.value,"unrelated_expedition_can_release":aliased_release.ok,"alias_reproduced":witnessed}))
	quit(0 if witnessed else 1)
