extends SceneTree
const Fishing := preload("res://scripts/core/fishing.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
var assertions: int = 0
var failures: int = 0
func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:
	_run()
	print("Fishing public probe: %d assertion(s), %d failure(s)" % [assertions,failures])
	quit(0 if failures == 0 else 1)
func _run() -> void:
	var fish: Fishing = Fishing.new()
	var capacities: Array[int] = [3100000,2200000,2100000]
	var efforts: Array[int] = [6,6,4]
	for habitat_type: int in 3:
		var created: Fishing.OpResult = fish.create_habitat(habitat_type,Fishing.NULL_REF,PackedInt32Array([2147483647,2147483646,2147483645]),2147483647,3,2147483647)
		check(created.ok,"arbitrary nonnegative species IDs and full i32 scalar histories")
		if not created.ok: continue
		var ref: Vector2i = created.ref
		var slot: int = created.value
		check(fish.habitat_capacity_milli_of(slot).value == capacities[habitat_type],"type capacity")
		check(fish.effort_slots_of(slot).value == efforts[habitat_type],"type effort")
		check(fish.pollution_of(slot).value == 2147483647,"full pollution")
		check(fish.protected_fraction_of(slot).value == 2147483647,"full protected fraction")
		for index: int in 3:
			var row: int = slot*3+index
			check(fish.stock_habitat_ref_of(row) == ref,"owner-major stock link")
			check(fish.species_id_of(row).value == 2147483647-index,"species item ID is not table index")
			check(fish.population_milli_of(row).value == fish.stock_capacity_milli_of(row).value*8/10,"initial 80 percent")
			check(not fish.is_restocking(row),"initial clear latch")
		check(fish.destroy_habitat(ref).ok,"destroy habitat")
		for index: int in 3: check(not fish.is_stock_present(slot*3+index),"destroy all three stocks")
		check(not fish.pollution_of(slot).ok,"inactive reader refuses; private retained bytes not claimed")
	fish.clear()
	var made: Fishing.OpResult = fish.create_habitat(0,Fishing.NULL_REF,PackedInt32Array([4,8,12]),0,0,0)
	check(made.ok,"coast fixture")
	var ref: Vector2i = made.ref
	var slot: int = made.value
	var row: int = slot*3
	check(fish.set_closed(ref,0,true).ok and fish.is_closed_flag(row),"public non-mussel event bit")
	check(not fish.harvest(ref,0,1,0,1).ok,"event closure blocks")
	check(fish.set_closed(ref,0,false).ok,"event reopened")
	check(fish.harvest(ref,0,77500,0,1).ok,"whole habitat quota from one stock")
	check(fish.harvested_today_milli_of(row).value == 77500,"quota stored")
	check(not fish.harvest(ref,1,1,0,1).ok,"second species shares quota")
	fish.reset_harvested_today()
	check(fish.harvested_today_milli_of(row).value == 0,"daily reset")
	check(fish.set_intensive_harvest(ref,true).ok,"explicit intensive policy")
	# Exact 30 percent reached from above retains false; one below enters true.
	for step: int in 30:
		var population: int = fish.population_milli_of(row).value
		if population <= 360000: break
		fish.reset_harvested_today()
		check(fish.harvest(ref,0,mini(77500,population-360000),0,1).ok,"deplete to exact30")
	check(fish.population_milli_of(row).value == 360000 and not fish.is_restocking(row),"30 percent retains false")
	fish.reset_harvested_today()
	check(fish.harvest(ref,0,1,0,1).ok and fish.is_restocking(row),"below30 enters true")
	check(fish.recover_stock(row,0,1).ok,"recover from below30")
	var recovered: int = fish.population_milli_of(row).value
	check(recovered > 360000 and recovered < 480000 and fish.is_restocking(row),"interior band retains true")
	for step: int in 20:
		if fish.population_milli_of(row).value > 480000: break
		check(fish.recover_stock(row,0,1).ok,"recover through band")
	check(fish.population_milli_of(row).value > 480000 and not fish.is_restocking(row),"above40 clears")
	fish.reset_harvested_today()
	check(fish.harvest(ref,0,fish.population_milli_of(row).value-480000,0,1).ok,"return to exact40")
	check(fish.population_milli_of(row).value == 480000 and not fish.is_restocking(row),"40 retains false")
	for step: int in 30:
		var population: int = fish.population_milli_of(row).value
		if population <= 120000: break
		fish.reset_harvested_today()
		check(fish.harvest(ref,0,mini(77500,population-120000),0,1).ok,"deplete to hard floor")
	check(fish.population_milli_of(row).value == 120000 and fish.is_restocking(row),"hard10 percent floor attained")
	fish.reset_harvested_today()
	check(not fish.harvest(ref,0,1,0,1).ok,"one below hard floor refused")
	check(fish.population_milli_of(row).value == 120000 and fish.harvested_today_milli_of(row).value == 0,"floor refusal atomic")
	check(fish.destroy_habitat(ref).ok,"destroy after retained policy/history")
	fish.clear()
	fish = null
	# Zone references may retain different generations of the same global slot.
	var directory: Directory = Directory.new()
	var linked: Fishing = Fishing.new(directory)
	var zone_a: Vector2i = directory.create(Directory.KIND_HARVEST_ZONE)
	var a: Fishing.OpResult = linked.create_habitat(0,zone_a,PackedInt32Array([1,2,3]),0,0,0)
	check(a.ok,"first basin binding")
	check(directory.destroy(zone_a),"destroy basin only")
	var zone_b: Vector2i = directory.create(Directory.KIND_HARVEST_ZONE)
	check(zone_b.x == zone_a.x and zone_b.y > zone_a.y,"same zone slot new generation")
	var b: Fishing.OpResult = linked.create_habitat(1,zone_b,PackedInt32Array([1,2,3]),0,0,0)
	check(b.ok,"new generation can bind another habitat")
	check(linked.habitat_zone_ref_of(a.value) == zone_a and linked.habitat_zone_ref_of(b.value) == zone_b,"stale and current zone pairs coexist")
	linked.clear()
	linked = null
	directory = null
