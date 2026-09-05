extends Node
## Damage resolution and death handling for entities carrying health data.
##
## Holds no entity state of its own: health lives in HealthComponent and
## lifetime in EntityManager.

const EntityManagerScript := preload("res://scripts/systems/entity_manager.gd")
const HealthComponentScript := preload("res://scripts/components/health_component.gd")

signal entity_health_changed(entity_id: int, remaining_health: int)
signal entity_died(entity_id: int)

var _entities: EntityManagerScript = null


func _ready() -> void:
	"""Bind to the EntityManager autoload and report readiness."""
	set_entity_manager(EntityManager)
	print("[CombatSystem] ready")


func set_entity_manager(manager: EntityManagerScript) -> void:
	"""Inject the entity manager this system resolves damage against."""
	_entities = manager


func apply_damage(entity_id: int, amount: int) -> bool:
	"""Deal damage to an entity. Returns true only when this hit killed it.

	entity_died is emitted before the entity is destroyed, so a listener can
	still read the corpse's components.
	"""
	var health := _get_health(entity_id)
	if health == null or amount <= 0 or health.is_dead():
		return false
	health.current_health = maxi(health.current_health - amount, 0)
	entity_health_changed.emit(entity_id, health.current_health)
	if not health.is_dead():
		return false
	entity_died.emit(entity_id)
	_entities.destroy_entity(entity_id)
	return true


func heal(entity_id: int, amount: int) -> bool:
	"""Restore health up to the entity's maximum. False when it cannot be healed."""
	var health := _get_health(entity_id)
	if health == null or amount <= 0 or health.is_dead():
		return false
	health.current_health = mini(health.current_health + amount, health.max_health)
	entity_health_changed.emit(entity_id, health.current_health)
	return true


func get_health(entity_id: int) -> int:
	"""Current health of an entity, or 0 when it has no health component."""
	var health := _get_health(entity_id)
	if health == null:
		return 0
	return health.current_health


func _get_health(entity_id: int) -> HealthComponentScript:
	"""Fetch an entity's health component, or null when unavailable."""
	if _entities == null:
		return null
	var component := _entities.get_component(entity_id, HealthComponentScript.COMPONENT_NAME)
	var health := component as HealthComponentScript
	if component != null and health == null:
		push_error("Entity %d stores a non-health component under the health key." % entity_id)
	return health
