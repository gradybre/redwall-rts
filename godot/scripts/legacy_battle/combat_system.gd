extends Node
## LEGACY BATTLE-LAYER PROTOTYPE. NOT A SETTLEMENT SYSTEM. NOT AUTOLOADED. DO NOT CALL FROM
## `scripts/core/`, `scripts/systems/` OR ANY SETTLEMENT CODE.
##
## Damage resolution and death handling for entities carrying health data. It works and it is
## tested (`test/test_legacy_battle_combat_system.gd`), and it is kept for exactly that reason:
## the battle layer will need a damage model and this is a working head start. It is retired
## from the running settlement build.
##
## ---------------------------------------------------------------------------------------
## WHY IT IS HERE AND NOT IN `scripts/systems/`. Decision 0006 divergence row 9: "Not a
## settlement system. The settlement layer models `Injury` and healing, with no damage or attack
## model." This module was written before the GDD and was placed in the autoload list, where six
## months of readers would have taken it for part of the colony sim. ARCH-MIG-006 step 7 removes
## the autoload and moves the file out of `scripts/systems/` so the mistake cannot repeat: the
## directory, the file's own first line and the test file's name all say legacy, and
## `test_legacy_battle_combat_system.gd` FAILS if anything re-registers it as an autoload.
##
## ---------------------------------------------------------------------------------------
## WHAT OWNS HEALTH, STATUS AND DEATH IN THE SETTLEMENT: `scripts/core/needs.gd`.
##   health_of() / health_into()      integer health 0-100, one packed column per resident row
##   status_of() / status_into()      STATUS_ACTIVE..STATUS_DEAD, precedence-ordered
##   apply_health_event()             signed whole-point events: REQ-SET-173 treatment, and
##                                    instantaneous injury damage when Injury lands
##   tick_all()                       starvation, cold exposure and recovery integration, and
##                                    the REQ-SET-016 death record
## A settlement resident's death does NOT destroy its row -- the corpse's status becomes
## STATUS_DEAD and the row is retained. This module's `apply_damage()` destroys the entity
## outright, which is a battle-layer lifetime, not a settlement one.
##
## ---------------------------------------------------------------------------------------
## THIS FILE DOES NOT MEET THE GDD CONSTRAINTS AND MUST BE RE-DERIVED, NOT ADOPTED AS-IS, WHEN
## THE BATTLE LAYER IS BUILT:
##   * `HealthComponent` is one Resource per entity (array-of-structures). ARCH-MEM-001 requires
##     packed integer columns.
##   * `EntityManager` hands out monotonic int ids. The GDD requires
##     `EntityRef = (slot:int32, generation:int32)` with slot reuse and generation validation;
##     `scripts/core/entity_directory.gd` is the compliant allocator.
##   * `get_health()` answers 0 for an entity that has no health at all, and `apply_damage()`
##     answers false both for "survived" and for "no such target". Both are sentinels; the house
##     rule is explicit refusal with the reason in a result object.
##   * `HealthComponent.health_fraction()` returns a float. Authoritative state is integer only.
##
## Holds no entity state of its own: health lives in HealthComponent and
## lifetime in EntityManager.

const EntityManagerScript := preload("res://scripts/systems/entity_manager.gd")
const HealthComponentScript := preload("res://scripts/components/health_component.gd")

signal entity_health_changed(entity_id: int, remaining_health: int)
signal entity_died(entity_id: int)

var _entities: EntityManagerScript = null

# There is deliberately NO _ready(). It used to bind the EntityManager AUTOLOAD and print
# "[CombatSystem] ready" on every boot of the settlement build. That hook is what made a
# battle-layer prototype look like a running settlement system, so the collaborator is now
# injected explicitly by whoever instantiates this and by nobody else.


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
