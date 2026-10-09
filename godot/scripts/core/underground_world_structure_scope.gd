extends "res://scripts/core/underground_phase_structure.gd".Scope
## Cycle-free actual World/Level binding for natural structural observations. No work permission.

const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const REFUSE_BINDING: StringName = &"WORLD_STRUCTURE_SCOPE_BINDING"
const REFUSE_BUSY: StringName = &"WORLD_STRUCTURE_SCOPE_REENTRY"

var _provider: WeakRef = null
var _levels: Levels = null
var _budget: Budget = null
var _domain: Space.Domain = null
var _level_revision: int = 0
var _reading: bool = false
var _poisoned: bool = false


func configure(provider: WorldBindings, levels: Levels, budget: Budget) -> StringName:
	"""Bind the actual immutable Level catalog and shared World once, at real quiescence."""
	if _reading:
		_poisoned = true
		return REFUSE_BUSY
	if _provider != null or provider == null or levels == null or budget == null \
			or not budget.is_quiescent():
		return REFUSE_BINDING
	_reading = true
	_poisoned = false
	var owner: Owner = provider.space_owner()
	var domain: Space.Domain = owner.domain_copy() if owner != null else null
	var revision: int = levels.content_revision()
	var code: StringName = _configuration_refusal(provider, levels, budget, domain, revision)
	if code == &"" and not _poisoned:
		_provider = weakref(provider)
		_levels = levels
		_budget = budget
		_domain = domain
		_level_revision = revision
	_reading = false
	return REFUSE_BUSY if _poisoned else code


func _configuration_refusal(provider: WorldBindings, levels: Levels, budget: Budget,
		domain: Space.Domain, revision: int) -> StringName:
	"""A matching numeric World or level height never substitutes for the actual Directory and catalog."""
	var owner: Owner = provider.space_owner()
	if domain == null or owner == null or owner.has_prepared() or not budget.is_quiescent() \
			or revision < 1 or provider.binding_refusal() != &"" or not provider.is_bound_budget(budget):
		return REFUSE_BINDING
	var sources: Owner.CoreSources = provider.sources()
	if sources == null or sources.construction_owner() == null \
			or not budget.is_quiescent() \
			or not levels.binding_matches(domain, sources.directory(), Space.VERSION):
		return REFUSE_BINDING
	var sites: Sites = sources.construction_owner().excavation_authority() as Sites
	if sites == null or sites.construction_owner() != sources.construction_owner() \
			or sites.initialization_refusal() != &"" or provider.terrain_owner() == null:
		return REFUSE_BINDING
	return &"" if not _poisoned and budget.is_quiescent() and not owner.has_prepared() \
		and provider.binding_refusal() == &"" and levels.content_revision() == revision else REFUSE_BINDING


func phase_world_owner() -> RefCounted:
	"""Return only the once-bound borrowed composer identity, never a structural approval."""
	return _actual_provider()


func exact_binding(owner: Owner, terrain: Terrain, levels: Levels, sites: Sites,
		budget: Budget) -> bool:
	"""Attest exact objects under a guarded callback lifetime; a nested query invalidates the outer one."""
	if _reading:
		_poisoned = true
		return false
	_reading = true
	_poisoned = false
	var provider: WorldBindings = _actual_provider()
	var token: int = provider.retained_cold_token() if provider != null else 0
	var code: StringName = _actual_binding_refusal(provider, token)
	if code == &"" and (owner == null or terrain == null or sites == null \
			or provider.space_owner() != owner or provider.terrain_owner() != terrain \
			or levels != _levels or budget != _budget \
			or provider.sources().construction_owner().excavation_authority() != sites):
		code = REFUSE_BINDING
	if code == &"":
		code = _actual_binding_refusal(provider, token)
	var result: bool = code == &"" and not _poisoned
	_reading = false
	return result


func phase_refusal(token: int, site: Vector2i, operation: int, stage: int,
		room: Vector2i) -> StringName:
	"""Read the actual retained operation/stage/Site/Room/Project/revision before and after owner callbacks."""
	if _reading:
		_poisoned = true
		return REFUSE_BUSY
	_reading = true
	_poisoned = false
	var provider: WorldBindings = _actual_provider()
	var code: StringName = provider.cold_phase_refusal(token, site, operation, stage, room) \
		if provider != null else REFUSE_BINDING
	if code == &"":
		code = _actual_binding_refusal(provider, token)
	if code == &"":
		code = provider.cold_phase_refusal(token, site, operation, stage, room)
	_reading = false
	return REFUSE_BUSY if _poisoned else code


func _actual_binding_refusal(provider: WorldBindings, token: int) -> StringName:
	"""Keep collaborators strongly borrowed for this call; source and level generations stay conjunctive."""
	if provider == null or _levels == null or _budget == null or _domain == null \
			or _poisoned or provider != _actual_provider() or provider.binding_refusal() != &"" \
			or not provider.is_bound_budget(_budget) or _levels.content_revision() != _level_revision:
		return REFUSE_BINDING
	var sources: Owner.CoreSources = provider.sources()
	if sources == null or sources.construction_owner() == null \
			or not _lease_current(provider, token) \
			or not _levels.binding_matches(_domain, sources.directory(), Space.VERSION):
		return REFUSE_BINDING
	var sites: Sites = sources.construction_owner().excavation_authority() as Sites
	if sites == null or sites.construction_owner() != sources.construction_owner() \
			or sites.initialization_refusal() != &"":
		return REFUSE_BINDING
	return &"" if not _poisoned and provider.binding_refusal() == &"" \
		and _levels.content_revision() == _level_revision and _lease_current(provider, token) else REFUSE_BINDING


func _lease_current(provider: WorldBindings, token: int) -> bool:
	"""Do not call virtual identity callbacks between this exact-token check and the Level allocation."""
	return _budget != null and provider != null and provider.retained_cold_token() == token \
		and ((_budget.is_quiescent() and token == 0) \
		or (token > 0 and _budget.covers(token, Budget.COLD_BYTES)))


func _actual_provider() -> WorldBindings:
	"""An expired configured World is unavailable and can never be replaced by a numerically equal World."""
	return _provider.get_ref() as WorldBindings if _provider != null else null
