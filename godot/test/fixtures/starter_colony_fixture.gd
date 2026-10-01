extends RefCounted
## Test-only starter colony: a standalone `buildings.gd` store with GDD §5.9's colony applied
## through the production `starter_colony.gd`, and the store binding read back from it.
##
## Decision 0533 made `inventory.gd` refuse an ownerless container and closed EconomySystem's
## stores until they are bound to real owners. A suite that exercises EconomySystem without a
## whole generated settlement gets those owners here: real Building rows of a real store, placed
## by the same production apply the settlement runs. Hold the fixture for as long as the economy
## uses the binding, so the store whose refs it names stays alive. No production source
## references this file; it lives only under `godot/test`.

const BuildingsScript := preload("res://scripts/core/buildings.gd")
const StarterStructuresScript := preload("res://scripts/core/starter_structures.gd")
const StarterColonyScript := preload("res://scripts/core/starter_colony.gd")
const MilestonesScript := preload("res://scripts/core/milestones.gd")

var buildings: BuildingsScript = BuildingsScript.new()
var plan: StarterStructuresScript.Plan = StarterStructuresScript.Plan.new()
var applied: StarterColonyScript.Applied = StarterColonyScript.Applied.new()
var binding: StarterColonyScript.StoreBinding = StarterColonyScript.StoreBinding.new()
## REFUSE_NONE when the colony stands and `binding` is complete; otherwise the first refusal.
var refusal: StringName = StarterColonyScript.REFUSE_NONE


func _init() -> void:
	"""Prepare the authored plan, apply it, and read the binding back from the live store."""
	var producer: StarterStructuresScript = StarterStructuresScript.new()
	if not producer.prepare_into(plan):
		refusal = producer.last_refusal()
		return
	refusal = StarterColonyScript.apply_into(buildings, plan, MilestonesScript.INITIAL_MASK, applied)
	if refusal == StarterColonyScript.REFUSE_NONE:
		refusal = StarterColonyScript.store_binding_into(buildings, plan, binding)
