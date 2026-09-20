extends "res://test/framework/test_case.gd"
## Independent functional evidence for EQUIPMENT-LIFETIME-R01v1 (ADR 0187).
##
## Exercises the candidate `inventory.gd` equipment-authority WeakRef repair through only its
## published public API: bind/unbind, `has_equipment_authority()`, the four equipped gates
## (detach/attach preflight and live), `audit()`, `state_bytes()`, `begin()`/`abort()` and
## `clear()`, plus the real Gear/Inventory/Residents bind API `gear.gd` publishes. Every test
## double below is local and independent of other suites' private classes. No production file
## is touched by this suite; only the existing public surface is called.

const InventoryScript := preload("res://scripts/core/inventory.gd")
const GearScript := preload("res://scripts/core/gear.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")

const ITEM_TOOL: int = 0
const CATEGORY_GEAR: int = 4
const TOOL_MASS: int = 1000
const PROVENANCE_ORDINARY: int = 0
const OWNER: Vector2i = Vector2i(5, 1)
const BIG_MASS: int = 100000000

var _inv: InventoryScript = null


func before_each() -> void:
	"""A fresh 8-container, 32-lot inventory with one registered tool item."""
	_inv = InventoryScript.new(8, 32)
	var registered: InventoryScript.OpResult = _inv.register_item(ITEM_TOOL, TOOL_MASS, CATEGORY_GEAR)
	assert_true(registered.ok, "fixture item registration must succeed: %s" % registered.error)


func _stopped(ref: Vector2i) -> bool:
	"""True when `ref` is the null ref: a scenario must stop rather than act on it."""
	return ref == InventoryScript.NULL_REF


func _container() -> Vector2i:
	"""Create an accept-everything container and assert it, returning its ref."""
	var made: InventoryScript.OpResult = _inv.create_container(OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true)
	assert_true(made.ok, "fixture container creation must succeed: %s" % made.error)
	return made.ref


func _tool_lot(box: Vector2i) -> Vector2i:
	"""Create one indivisible tool lot in `box`, assert it, and return its ref."""
	var made: InventoryScript.OpResult = _inv.create_lot(box, ITEM_TOOL, 1000, 0,
		PROVENANCE_ORDINARY, 0, 0, 0)
	assert_true(made.ok, "fixture lot creation must succeed: %s" % made.error)
	return made.ref


func _equip(authority: Object, box: Vector2i) -> Vector2i:
	"""Attest for and detach one fresh tool lot while `authority` is live.

	Returns NULL_REF if the underlying create or detach refused, so a caller can never
	mistake a failed fixture for a genuinely equipped lot.
	"""
	var lot: Vector2i = _tool_lot(box)
	if _stopped(lot):
		return InventoryScript.NULL_REF
	authority.attest(lot)
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_true(detached.ok, "fixture equip must succeed: %s" % detached.error)
	if not detached.ok:
		return InventoryScript.NULL_REF
	return lot


func _bind_real_triple() -> Dictionary:
	"""Construct one real Inventory/Gear/Residents triple via the production bind API.

	Returns an empty Dictionary when the bind itself refused, so a scenario built on a
	genuine setup failure cannot be mistaken for a lifetime witness that never ran.
	"""
	var inventory: InventoryScript = InventoryScript.new()
	var residents: ResidentsScript = ResidentsScript.new()
	var gear: GearScript = GearScript.new()
	var bound: InventoryScript.OpResult = gear.bind_equipment(inventory, residents.directory(), residents)
	assert_true(bound.ok, "real triple must bind: %s" % bound.error)
	if not bound.ok:
		return {}
	return {"inventory": inventory, "gear": gear, "residents": residents}


# --- Local, independent test doubles -----------------------------------------------------

class StubAuthority extends RefCounted:
	"""A live RefCounted authority: attests only for lots explicitly told to it."""
	var attested: Dictionary = {}

	func attest(lot_ref: Vector2i) -> void:
		"""Start attesting for one lot."""
		attested[lot_ref] = true

	func withdraw(lot_ref: Vector2i) -> void:
		"""Stop attesting for one lot."""
		attested.erase(lot_ref)

	func is_equipped_record(lot_ref: Vector2i) -> bool:
		"""The duck-typed attestation method `inventory.gd` calls."""
		return attested.has(lot_ref)


class NodeAuthority extends Node:
	"""A live Node authority, released by an explicit `.free()` rather than a dropped refcount."""
	var attested: Dictionary = {}

	func attest(lot_ref: Vector2i) -> void:
		"""Start attesting for one lot."""
		attested[lot_ref] = true

	func is_equipped_record(lot_ref: Vector2i) -> bool:
		"""The duck-typed attestation method `inventory.gd` calls."""
		return attested.has(lot_ref)


class MissingMethodAuthority extends RefCounted:
	"""Publishes no attestation method at all: bind time must refuse it."""
	var unrelated: int = 0


class ReentrantAuthority extends RefCounted:
	"""Attests honestly, but tries to mutate the inventory from inside its own callback."""
	var inventory: Variant = null
	var lot_ref: Vector2i = Vector2i(-1, 0)
	var reentry_error: StringName = &"NOT_ATTEMPTED"

	func is_equipped_record(p_lot_ref: Vector2i) -> bool:
		"""Attest, but try to sink the very lot being validated on the way through."""
		reentry_error = inventory.sink_lot_quantity(lot_ref, 1).error
		return p_lot_ref == lot_ref


class SelfDroppingAuthority extends RefCounted:
	"""Proves per-call strong acquisition: drops the caller's only external strong owner from
	inside its own attestation callback, relying on `inventory.gd`'s own strong local to keep
	it alive for the rest of that one call. The transient array/self cycle this needs is broken
	by the callback itself before the call returns; nothing outlives the test."""
	var holder: Array = []
	var attested: Dictionary = {}

	func attest(lot_ref: Vector2i) -> void:
		"""Start attesting for one lot."""
		attested[lot_ref] = true

	func is_equipped_record(lot_ref: Vector2i) -> bool:
		"""Drop the only external strong reference to this object, then answer honestly."""
		holder.clear()
		return attested.has(lot_ref)


# --- Binding basics -------------------------------------------------------------------------

func test_an_object_without_the_method_is_refused_at_bind_time() -> void:
	"""The invalid-authority refusal happens at bind, not at the first detach."""
	var bound: InventoryScript.OpResult = _inv.set_equipment_authority(MissingMethodAuthority.new())
	assert_false(bound.ok, "an object that cannot attest cannot be bound")
	assert_equal(bound.error, InventoryScript.REFUSE_INVALID_EQUIPMENT_AUTHORITY, "named")
	assert_false(_inv.has_equipment_authority(), "so nothing is bound")


func test_a_failed_bind_preserves_the_previous_live_binding() -> void:
	"""Ruling: failed binding preserves the previous binding."""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var good: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(good).ok, "the good authority binds")
	var refused: InventoryScript.OpResult = _inv.set_equipment_authority(MissingMethodAuthority.new())
	assert_false(refused.ok, "the invalid replacement refuses")
	assert_true(_inv.has_equipment_authority(), "the old binding survives the refusal")
	var lot: Vector2i = _equip(good, box)
	if _stopped(lot):
		return
	assert_true(_inv.is_lot_equipped(lot), "and the surviving authority still equips lots")


func test_clear_preserves_the_equipment_authority_binding() -> void:
	"""The binding is wiring, not simulation state, and survives `clear()`."""
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	_inv.clear()
	assert_true(_inv.has_equipment_authority(), "the binding survives the clear")
	var reregistered: InventoryScript.OpResult = _inv.register_item(ITEM_TOOL, TOOL_MASS, CATEGORY_GEAR)
	assert_true(reregistered.ok, "item must be re-registered after clear: %s" % reregistered.error)
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var lot: Vector2i = _equip(authority, box)
	if _stopped(lot):
		return
	assert_true(_inv.is_lot_equipped(lot), "and still enforces against the rebuilt store")


func test_never_bound_and_explicit_unbind_both_refuse_no_equipment_authority() -> void:
	"""Never-bound and explicitly-unbound share the same NO_EQUIPMENT_AUTHORITY refusal."""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var lot: Vector2i = _tool_lot(box)
	if _stopped(lot):
		return
	var never: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_equal(never.error, InventoryScript.REFUSE_NO_EQUIPMENT_AUTHORITY, "never-bound")
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	assert_true(_inv.set_equipment_authority(null).ok, "unbinds with nothing equipped")
	var unbound: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_equal(unbound.error, InventoryScript.REFUSE_NO_EQUIPMENT_AUTHORITY, "explicit unbind")


func test_binding_refuses_while_a_transaction_is_open_and_preserves_the_prior_authority() -> void:
	"""set_equipment_authority refuses both a replacement and an unbind mid-transaction,
	leaving the original binding fully in force once the transaction is rolled back.
	"""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var original: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(original).ok, "binds")
	var lot: Vector2i = _tool_lot(box)
	if _stopped(lot):
		return
	original.attest(lot)
	var candidate: StubAuthority = StubAuthority.new()
	assert_true(_inv.begin().ok, "opens a transaction")
	var before: PackedByteArray = _inv.state_bytes()
	var replace: InventoryScript.OpResult = _inv.set_equipment_authority(candidate)
	assert_false(replace.ok, "a replacement bind refuses mid-transaction")
	assert_equal(replace.error, InventoryScript.REFUSE_TRANSACTION_OPEN, "named")
	var unbind: InventoryScript.OpResult = _inv.set_equipment_authority(null)
	assert_false(unbind.ok, "an unbind refuses mid-transaction too")
	assert_equal(unbind.error, InventoryScript.REFUSE_TRANSACTION_OPEN, "named")
	assert_equal(_inv.state_bytes(), before, "neither refused bind wrote a byte")
	_inv.abort()
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_true(detached.ok, "the original authority still attests: %s" % detached.error)


# --- Expiry: the four equipped gates ---------------------------------------------------------

func _assert_four_gates_refuse_invalid(detach_target: Vector2i, equipped_lot: Vector2i,
		box: Vector2i) -> void:
	"""Shared assertion body: every one of the four gates refuses, writing nothing."""
	var code: StringName = InventoryScript.REFUSE_INVALID_EQUIPMENT_AUTHORITY
	var before: PackedByteArray = _inv.state_bytes()
	var pre_detach: InventoryScript.OpResult = _inv.preflight_detach_to_equipment(detach_target)
	assert_false(pre_detach.ok, "detach preflight must not succeed")
	assert_equal(pre_detach.error, code, "detach preflight")
	assert_equal(_inv.state_bytes(), before, "preflight detach wrote nothing")
	var detach: InventoryScript.OpResult = _inv.detach_lot_to_equipment(detach_target)
	assert_false(detach.ok, "detach must not succeed")
	assert_equal(detach.error, code, "detach")
	assert_equal(_inv.state_bytes(), before, "detach wrote nothing")
	var pre_attach: InventoryScript.OpResult = _inv.preflight_attach_equipped_lot(
		equipped_lot, box, false)
	assert_false(pre_attach.ok, "attach preflight must not succeed")
	assert_equal(pre_attach.error, code, "attach preflight")
	assert_equal(_inv.state_bytes(), before, "preflight attach wrote nothing")
	var attach: InventoryScript.OpResult = _inv.attach_equipped_lot(equipped_lot, box, false)
	assert_false(attach.ok, "attach must not succeed")
	assert_equal(attach.error, code, "attach")
	assert_equal(_inv.state_bytes(), before, "attach wrote nothing")


func test_expired_refcounted_authority_refuses_all_four_gates_with_state_unchanged() -> void:
	"""All four equipped gates refuse INVALID_EQUIPMENT_AUTHORITY once the bound RefCounted
	authority has no other external owner and is released.
	"""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	var equipped_lot: Vector2i = _equip(authority, box)
	var detach_target: Vector2i = _tool_lot(box)
	if _stopped(equipped_lot) or _stopped(detach_target):
		return
	authority = null
	assert_false(_inv.has_equipment_authority(), "the released target is not live")
	_assert_four_gates_refuse_invalid(detach_target, equipped_lot, box)


func test_expired_node_authority_refuses_all_four_gates_after_explicit_free() -> void:
	"""The same four gates, for a Node authority released by an explicit `.free()`."""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var authority: NodeAuthority = NodeAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	var equipped_lot: Vector2i = _equip(authority, box)
	var detach_target: Vector2i = _tool_lot(box)
	if _stopped(equipped_lot) or _stopped(detach_target):
		authority.free()
		return
	authority.free()
	authority = null
	assert_false(_inv.has_equipment_authority(), "the freed Node is not live")
	_assert_four_gates_refuse_invalid(detach_target, equipped_lot, box)


# --- Audit, unbind-while-equipped, and replacement --------------------------------------------

func test_audit_refuses_orphan_lot_after_authority_expires_without_normalization() -> void:
	"""An equipped lot whose authority died is an orphan; audit refuses and changes nothing."""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	var lot: Vector2i = _equip(authority, box)
	if _stopped(lot):
		return
	authority = null
	var before: PackedByteArray = _inv.state_bytes()
	var audited: InventoryScript.OpResult = _inv.audit()
	assert_false(audited.ok, "an orphaned equipped lot fails audit")
	assert_equal(audited.error, InventoryScript.REFUSE_AUDIT_ORPHAN_LOT, "named")
	assert_equal(_inv.state_bytes(), before, "audit performed no automatic cleanup")
	assert_true(_inv.is_lot_equipped(lot), "the lot is still equipped, not unequipped")
	assert_equal(_inv.equipped_lot_count(), 1, "and still counted as equipment")


func test_explicit_unbind_refuses_with_live_equipped_lots_even_after_authority_expires() -> void:
	"""EQUIPPED_LOTS_LIVE is decided by the equipped count, not by the authority's liveness,
	and the refused unbind must not degrade the wrapper to the unbound state.
	"""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	var equipped: Vector2i = _equip(authority, box)
	if _stopped(equipped):
		return
	authority = null
	var unbind: InventoryScript.OpResult = _inv.set_equipment_authority(null)
	assert_false(unbind.ok, "an equipped lot still strands if the authority walks away")
	assert_equal(unbind.error, InventoryScript.REFUSE_EQUIPPED_LOTS_LIVE, "named explicitly")
	assert_false(_inv.has_equipment_authority(), "the wrapper still reports no live target")
	var probe: Vector2i = _tool_lot(box)
	if _stopped(probe):
		return
	var refused: InventoryScript.OpResult = _inv.preflight_detach_to_equipment(probe)
	assert_equal(refused.error, InventoryScript.REFUSE_INVALID_EQUIPMENT_AUTHORITY,
		"the wrapper is still bound-but-expired, not cleared to unbound")


func test_a_live_replacement_authority_restores_attestation_after_expiry() -> void:
	"""Binding a fresh live authority over an expired one restores full enforcement."""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var old: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(old).ok, "binds")
	var lot: Vector2i = _equip(old, box)
	if _stopped(lot):
		return
	old = null
	assert_equal(_inv.audit().error, InventoryScript.REFUSE_AUDIT_ORPHAN_LOT, "orphaned first")
	var fresh: StubAuthority = StubAuthority.new()
	fresh.attest(lot)
	assert_true(_inv.set_equipment_authority(fresh).ok, "the live replacement binds")
	assert_true(_inv.has_equipment_authority(), "and reports itself live")
	assert_true(_inv.audit().ok, "attestation from the replacement authority is accepted")
	fresh.withdraw(lot)
	assert_true(_inv.attach_equipped_lot(lot, box, false).ok, "and normal shelving still works")


# --- Reentry and strong per-call acquisition ---------------------------------------------------

func test_reentry_during_detach_is_still_refused() -> void:
	"""A live authority that mutates the inventory from inside its own callback is refused."""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var authority: ReentrantAuthority = ReentrantAuthority.new()
	authority.inventory = _inv
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	var lot: Vector2i = _tool_lot(box)
	if _stopped(lot):
		return
	authority.lot_ref = lot
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_equal(authority.reentry_error, InventoryScript.REFUSE_ATTESTATION_REENTRY,
		"the re-entrant mutation was refused inside the attestation")
	assert_true(detached.ok, "and the honest attestation still completed: %s" % detached.error)


func test_a_strong_per_call_local_survives_the_authority_dropping_its_sole_external_owner() -> void:
	"""`_attests()` holds a strong local for the call; the authority may safely drop its own
	external owner from inside that same call without the call itself failing, and nothing
	survives once the call returns.
	"""
	var box: Vector2i = _container()
	if _stopped(box):
		return
	var authority: SelfDroppingAuthority = SelfDroppingAuthority.new()
	var holder_ref: Array = authority.holder
	holder_ref.append(authority)
	assert_true(_inv.set_equipment_authority(authority).ok, "binds")
	var lot: Vector2i = _tool_lot(box)
	if _stopped(lot):
		holder_ref.clear()
		return
	authority.attest(lot)
	var watch: WeakRef = weakref(authority)
	authority = null
	assert_not_null(watch.get_ref(), "the holder array keeps it alive before the call")
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_true(detached.ok, "the call completed despite the mid-call drop: %s" % detached.error)
	assert_equal(holder_ref.size(), 0, "the callback did drop the only external reference")
	assert_null(watch.get_ref(), "and nothing kept the authority alive once the call returned")


# --- Real Gear/Inventory/Residents ownership witnesses -----------------------------------------

func test_real_gear_inventory_residents_mutually_release_without_unbind() -> void:
	"""Dropping every external owner of the real bound triple at once releases all three,
	with no explicit unbind call -- the exact scenario the shutdown probe proves.
	"""
	var triple: Dictionary = _bind_real_triple()
	if triple.is_empty():
		return
	var wi: WeakRef = weakref(triple["inventory"])
	var wg: WeakRef = weakref(triple["gear"])
	var wr: WeakRef = weakref(triple["residents"])
	triple["inventory"] = null
	triple["gear"] = null
	triple["residents"] = null
	triple = {}
	assert_null(wi.get_ref(), "inventory released with no explicit unbind")
	assert_null(wg.get_ref(), "gear released")
	assert_null(wr.get_ref(), "residents released")


func test_real_gear_alone_retains_inventory_and_residents_until_gear_is_dropped() -> void:
	"""Gear alone keeps Inventory and Residents alive; only dropping Gear releases all three.
	"""
	var triple: Dictionary = _bind_real_triple()
	if triple.is_empty():
		return
	var wi: WeakRef = weakref(triple["inventory"])
	var wr: WeakRef = weakref(triple["residents"])
	var wg: WeakRef = weakref(triple["gear"])
	triple["inventory"] = null
	triple["residents"] = null
	assert_not_null(wi.get_ref(), "gear alone keeps inventory alive")
	assert_not_null(wr.get_ref(), "gear alone keeps residents alive")
	assert_not_null(wg.get_ref(), "gear itself is still externally owned here")
	triple["gear"] = null
	triple = {}
	assert_null(wi.get_ref(), "inventory releases once gear is dropped")
	assert_null(wr.get_ref(), "residents release once gear is dropped")
	assert_null(wg.get_ref(), "gear releases")
