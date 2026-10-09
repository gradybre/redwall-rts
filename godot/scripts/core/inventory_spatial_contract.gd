extends RefCounted
## Typed location attestation borrowed by the actual Inventory owner.
## This seam carries no goods, positions, room identity or second transaction journal.
## Every callback is side-effect-free: it may read its exact bound owners but never mutate
## Inventory, close/reset its caller's transaction or replace catalog/provider bindings.

const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_AUTHORITY: StringName = &"INVENTORY_SPATIAL_AUTHORITY_UNBOUND"


func exact_binding(_inventory: RefCounted, _world: Vector2i) -> bool:
	"""Require the actual Inventory object, live World and connected location owner; base denies."""
	return false


func world_ref() -> Vector2i:
	"""Return the actual live Directory World generation, never a numeric stand-in."""
	return NULL_REF


func storage_endpoint_refusal(_location: Vector2i) -> StringName:
	"""Prove current dry supported contained storage geometry for the full location generation."""
	return REFUSE_AUTHORITY


func location_revision(_location: Vector2i) -> int:
	"""Return a positive immutable location-payload revision, or zero for stale/unavailable identity."""
	return 0


func same_storage_cell(_first: Vector2i, _second: Vector2i) -> bool:
	"""Compare live World, full floor-section ref and exact 2m placement cell, never only X/Z."""
	return false
