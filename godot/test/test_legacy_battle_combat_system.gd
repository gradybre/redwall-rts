extends "res://test/framework/test_case.gd"
## LEGACY BATTLE-LAYER PROTOTYPE SUITE. NOT A RELEASE SETTLEMENT SUITE.
##
## Coverage for damage resolution, healing and death cleanup in
## `scripts/legacy_battle/combat_system.gd`. Nine of these ten methods are the original nine,
## byte-unchanged in body: ARCH-MIG-006 step 7 separates this module from the settlement build,
## it does not retire the proof that it works. The tenth is the regression guard below.
##
## ---------------------------------------------------------------------------------------
## WHY IT STILL RUNS IN THE MAIN SUITE. `run_tests.gd` discovers `test_*.gd` DIRECTLY UNDER
## `res://test` and does not recurse, so a `test/legacy/` subdirectory would have silently
## stopped running these nine tests and left the module unverified while it sits waiting for the
## battle layer. Untested retained code is worse than deleted code. The separation is therefore
## carried by the FILE NAME, which is what the runner prints as the suite heading, by the
## module's own directory, and by the header on both files -- not by hiding it from the runner.
##
## THE SETTLEMENT COUNTERPARTS OF THESE SEMANTICS LIVE IN `test_settlement_system.gd`, under
## "health, death and unknown references". Health, status, death and the refusals for an unknown
## or dead row are `scripts/core/needs.gd`'s, reached through SettlementSystem. Two semantics
## here have no settlement counterpart and are battle-layer only, deliberately not ported: the
## rejection of a non-positive DAMAGE amount (the settlement models no damage), and
## `health_fraction()`'s float divide (settlement health is an integer 0-100).

const CombatSystemScript := preload("res://scripts/legacy_battle/combat_system.gd")
const EntityManagerScript := preload("res://scripts/systems/entity_manager.gd")
const HealthComponentScript := preload("res://scripts/components/health_component.gd")

## Prefix every autoload path is checked against: nothing under it may be autoloaded again.
const LEGACY_DIRECTORY: String = "res://scripts/legacy_battle/"
## The autoload key this module was registered under until ARCH-MIG-006 step 7 removed it.
const RETIRED_AUTOLOAD_SETTING: String = "autoload/CombatSystem"
const AUTOLOAD_PREFIX: String = "autoload/"

var _entities: EntityManagerScript = null
var _combat: CombatSystemScript = null
var _deaths: Array[int] = []


func before_each() -> void:
	"""Build an entity manager and a combat system bound to it."""
	_entities = EntityManagerScript.new()
	_combat = CombatSystemScript.new()
	_combat.set_entity_manager(_entities)
	_deaths = []
	_combat.entity_died.connect(_on_entity_died)


func after_each() -> void:
	"""Free both systems built for the test."""
	if _combat != null:
		_combat.free()
		_combat = null
	if _entities != null:
		_entities.free()
		_entities = null


func test_damage_reduces_health() -> void:
	"""A non-lethal hit lowers health and reports that nothing died."""
	var entity_id: int = _spawn_fighter(100)
	assert_false(_combat.apply_damage(entity_id, 30), "the entity survived")
	assert_equal(_combat.get_health(entity_id), 70, "health was reduced")
	assert_true(_entities.is_alive(entity_id), "the entity is still alive")


func test_lethal_damage_destroys_the_entity() -> void:
	"""Damage past zero kills the entity and clears it from the manager."""
	var entity_id: int = _spawn_fighter(20)
	assert_true(_combat.apply_damage(entity_id, 25), "the killing blow is reported")
	assert_false(_entities.is_alive(entity_id), "the entity was destroyed")
	assert_equal(_deaths.size(), 1, "death was signalled once")
	assert_equal(_deaths[0], entity_id, "the right entity died")


func test_health_never_goes_negative() -> void:
	"""Overkill floors health at zero rather than wrapping past it."""
	var entity_id: int = _spawn_fighter(10)
	var health := _entities.get_component(entity_id, HealthComponentScript.COMPONENT_NAME) as HealthComponentScript
	_combat.apply_damage(entity_id, 999)
	assert_equal(health.current_health, 0, "health floored at zero")


func test_damage_requires_a_positive_amount() -> void:
	"""Zero and negative damage are rejected instead of healing the target."""
	var entity_id: int = _spawn_fighter(50)
	assert_false(_combat.apply_damage(entity_id, 0), "zero damage does nothing")
	assert_false(_combat.apply_damage(entity_id, -10), "negative damage does nothing")
	assert_equal(_combat.get_health(entity_id), 50, "health is unchanged")


func test_damage_without_health_component_is_ignored() -> void:
	"""An entity carrying no health data cannot be damaged."""
	var entity_id: int = _entities.create_entity()
	assert_false(_combat.apply_damage(entity_id, 10), "damage is refused")
	assert_true(_entities.is_alive(entity_id), "the entity is untouched")


func test_damage_to_unknown_entity_is_ignored() -> void:
	"""An id that was never created resolves to no target."""
	assert_false(_combat.apply_damage(9999, 10), "damage to a missing entity is refused")


func test_heal_restores_up_to_maximum() -> void:
	"""Healing tops out at the entity's maximum health."""
	var entity_id: int = _spawn_fighter(100)
	_combat.apply_damage(entity_id, 60)
	assert_true(_combat.heal(entity_id, 25), "healing applies")
	assert_equal(_combat.get_health(entity_id), 65, "health was restored")
	_combat.heal(entity_id, 500)
	assert_equal(_combat.get_health(entity_id), 100, "healing stops at maximum")


func test_dead_entities_cannot_be_healed() -> void:
	"""Once destroyed, an entity is not a valid heal target."""
	var entity_id: int = _spawn_fighter(10)
	_combat.apply_damage(entity_id, 10)
	assert_false(_combat.heal(entity_id, 50), "a destroyed entity cannot be healed")


func test_health_fraction_is_safe_at_zero_maximum() -> void:
	"""A component with no maximum reports zero rather than dividing by zero."""
	var health := HealthComponentScript.new()
	health.max_health = 0
	health.current_health = 0
	assert_almost_equal(health.health_fraction(), 0.0, "fraction is zero, not NaN")


# --- the separation itself (ARCH-MIG-006 step 7, decision 0006 row 9) --------------------------

func test_the_legacy_battle_module_is_not_registered_as_an_autoload() -> void:
	"""No autoload may point into the legacy directory: this is the regression guard for step 7.

	Re-adding `CombatSystem` to `project.godot`, or autoloading anything else out of
	`scripts/legacy_battle/`, fails here rather than quietly rejoining the settlement runtime.
	ProjectSettings is populated under `--script`, so the worker reads the real project file.
	"""
	assert_false(ProjectSettings.has_setting(RETIRED_AUTOLOAD_SETTING),
		"CombatSystem is no longer an autoload of the settlement build")
	var autoloads: int = 0
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = String(property["name"])
		if not setting.begins_with(AUTOLOAD_PREFIX):
			continue
		autoloads += 1
		var target: String = String(ProjectSettings.get_setting(setting))
		assert_false(target.contains(LEGACY_DIRECTORY),
			"%s does not autoload legacy battle code" % setting)
	assert_true(autoloads > 0, "the project does declare autoloads, so the scan was not vacuous")


func _spawn_fighter(health_points: int) -> int:
	"""Create an entity carrying a full health component."""
	var entity_id: int = _entities.create_entity()
	var health := HealthComponentScript.new()
	health.max_health = health_points
	health.current_health = health_points
	_entities.add_component(entity_id, health)
	return entity_id


func _on_entity_died(entity_id: int) -> void:
	"""Record a death signal for assertion."""
	_deaths.append(entity_id)
