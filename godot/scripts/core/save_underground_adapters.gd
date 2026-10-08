extends RefCounted
## Section 6 adapters for the underground Session's owners (ADR 1228).
##
## Each adapter exposes `capture(block)`, `validate(block)` and `apply(block)` returning a
## `SaveHeader.Refusal`, as `save_section_auxiliary.gd`'s registry requires, and is bound to the
## settlement save's `World`. An owner exists only once the Session's composition reached its
## prefix (`MIN_PREFIX`); a world without it writes the canonical empty block, and a load requires
## the block empty exactly where the re-mounted target has no such owner.
##
##   * `WireAdapter` -- one owner's own versioned wire (Locations, Routes, WorldRoutes, Contacts,
##     Placements, Workpieces) as a length and a bounded image. Locations, Routes and WorldRoutes
##     take the Session's cold lease; Placements and Workpieces stream through one staging file.
##   * `DeclaredAdapter` -- an owner whose `save_columns()`/`restore_columns()`/`columns_valid()`
##     move its registry columns (excavation sites, their funding, the Router).
##   * `SpatialAdapter` -- Inventory's spatial endpoint arena.
##   * `MountAdapter` -- the mount record; the orchestrator re-mounts from it before section 4.
##   * `EntryAdapter` -- ADR 1218's entry progress record; the orchestrator restores it last.
##
## A capture an owner refuses (an operation open across the boundary) is SAVE_BUSY naming the
## owner's own code (DEC-055 Q5).
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveUnderground := preload("res://scripts/core/save_underground_adapters.gd")
const SaveAux := preload("res://scripts/core/save_aux_adapters.gd")
const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const Section := preload("res://scripts/core/save_section_auxiliary.gd")
const Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const InstalledGeometry := preload("res://scripts/core/save_installed_geometry.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BUSY: StringName = &"SAVE_BUSY"
const REFUSE_UNSUPPORTED: StringName = &"SAVE_UNSUPPORTED_STATE"
const REFUSE_RESTORE: StringName = &"SAVE_UNDERGROUND_RESTORE_REFUSED"
const REFUSE_MOUNT: StringName = &"SAVE_UNDERGROUND_MOUNT"
## The composition prefix at which each owner exists (ADR 1146/1184 composer steps).
const MIN_PREFIX: Dictionary = {
	"excavation_inventory": 4, "excavation_sites": 4, "modular_projects": 4, "inventory": 4,
	"underground_locations": 4, "underground_routes": 8, "underground_world_routes": 8,
	"underground_connector_contacts": 17, "underground_connector_placements": 17,
	"underground_connector_workpieces": 17,
}
## The prefixes a saved Session may hold: mounted, then after each of the four composer steps.
const SAVED_PREFIXES: Array[int] = [0, 4, 8, 9, 17]
## One staging file per streamed owner, overwritten by each capture or restore and then removed.
const STAGING_DIRECTORY: String = "user://save_staging"


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


static func present(world: SaveWorld.World, key: String) -> bool:
	"""Whether the mounted Session's composition has created `key`'s owner."""
	return world.session != null and world.session._operations_prefix >= int(MIN_PREFIX[key])


static func shape_refusal(block: Section.Block, key: String) -> SaveHeader.Refusal:
	"""The block is `key`'s and well shaped."""
	if block == null or Schema.OWNER_KEYS[block.owner] != key:
		return _no(SaveAux.REFUSE_OWNER_STATE, "a '%s' block is required" % key)
	var detail: String = block.shape_detail()
	return _ok() if detail == "" else _no(SaveAux.REFUSE_OWNER_STATE, detail)


static func cross_audit_refusal(world: SaveWorld.World) -> SaveHeader.Refusal:
	"""After the underground group: the Placements' full audit, anchors included, against the now
	restored Locations (Placements restored first, before their anchors existed); then every installed
	part's geometry against the restored Space (`save_installed_geometry.gd`)."""
	if not present(world, "underground_connector_placements"):
		return _ok()
	var code: StringName = world.underground.placements.audit()
	if code == &"":
		code = InstalledGeometry.refusal(world.underground.placements)
	return _ok() if code == &"" else _no(REFUSE_RESTORE, "'underground_connector_placements' audit: %s" % code)


# --- wires ----------------------------------------------------------------------------------------

static func capture_wire(o: RefCounted, key: String, out: PackedByteArray) -> StringName:
	"""One owner's own wire image into the empty `out`."""
	match key:
		"underground_connector_contacts": return o.contacts.capture_state_into(out)
		"underground_connector_placements": return _capture_placements(o, out)
		"underground_connector_workpieces": return _capture_workpieces(o, out)
	var cold: int = o.budget.acquire(Budget.COLD_BYTES)
	if cold == 0:
		return Budget.REFUSE_BUSY
	var code: StringName = &""
	match key:
		"underground_locations": code = o.locations.capture_state_into(cold, out)
		"underground_routes": code = o.routes.capture_state_into(cold, out)
		_: code = o.world_routes.capture_state_into(cold, out)
	o.budget.release(cold)
	return code


static func restore_wire(o: RefCounted, key: String, bytes: PackedByteArray) -> StringName:
	"""Hand one owner its saved wire; the owner proves it against the owners already restored."""
	match key:
		"underground_connector_contacts": return o.contacts.restore_state_bytes(bytes)
		"underground_connector_placements": return _restore_placements(o, bytes)
		"underground_connector_workpieces": return _restore_workpieces(o, bytes)
	var cold: int = o.budget.acquire(Budget.COLD_BYTES)
	if cold == 0:
		return Budget.REFUSE_BUSY
	var code: StringName = &""
	match key:
		"underground_locations": code = o.locations.restore_state_bytes(cold, bytes)
		"underground_routes": code = o.routes.restore_state_bytes(cold, bytes)
		_: code = o.world_routes.restore_state_bytes(cold, bytes)
	o.budget.release(cold)
	return code


static func _staging_path(key: String) -> String:
	"""The staging file for one streamed owner, with its directory created and no stale file left."""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STAGING_DIRECTORY))
	var path: String = "%s/%s.bin" % [STAGING_DIRECTORY, key]
	_remove(path)
	return path


static func _remove(path: String) -> void:
	"""Delete a staging file if it exists."""
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _capture_placements(o: RefCounted, out: PackedByteArray) -> StringName:
	"""Placements stream their banks to a file under the cold lease; the file becomes the image."""
	var path: String = _staging_path("underground_connector_placements")
	var cold: int = o.budget.acquire(Budget.COLD_BYTES)
	if cold == 0:
		return Budget.REFUSE_BUSY
	var code: StringName = o.placements.capture_file(path, cold)
	o.budget.release(cold)
	if code == &"":
		out.append_array(FileAccess.get_file_as_bytes(path))
	_remove(path)
	return code


static func _restore_placements(o: RefCounted, bytes: PackedByteArray) -> StringName:
	"""Write the image to the staging file and restore it against its own SHA-256."""
	var path: String = _staging_path("underground_connector_placements")
	var code: StringName = _write_staging(path, bytes)
	var cold: int = o.budget.acquire(Budget.COLD_BYTES) if code == &"" else 0
	if code == &"" and cold == 0:
		code = Budget.REFUSE_BUSY
	if code == &"":
		code = o.placements.restore_file(path, _sha256_hex(bytes), cold)
		o.budget.release(cold)
	_remove(path)
	return code


static func _capture_workpieces(o: RefCounted, out: PackedByteArray) -> StringName:
	"""Workpieces stream their rows to an open file; the file becomes the image."""
	var path: String = _staging_path("underground_connector_workpieces")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return REFUSE_RESTORE
	var code: StringName = o.workpieces.capture_into(file)
	file.close()
	if code == &"":
		out.append_array(FileAccess.get_file_as_bytes(path))
	_remove(path)
	return code


static func _restore_workpieces(o: RefCounted, bytes: PackedByteArray) -> StringName:
	"""Write the image to the staging file and let Workpieces read it back."""
	var path: String = _staging_path("underground_connector_workpieces")
	var code: StringName = _write_staging(path, bytes)
	if code == &"":
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		code = o.workpieces.restore_from(file) if file != null else REFUSE_RESTORE
		if file != null:
			file.close()
	_remove(path)
	return code


static func _write_staging(path: String, bytes: PackedByteArray) -> StringName:
	"""Write `bytes` as the whole staging file."""
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return REFUSE_RESTORE
	file.store_buffer(bytes)
	var ok: bool = file.get_error() == OK
	file.close()
	return &"" if ok else REFUSE_RESTORE


static func _sha256_hex(bytes: PackedByteArray) -> String:
	"""Lowercase hex SHA-256 of `bytes`."""
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


class WireAdapter:
	"""A length and the owner's own wire image; empty exactly where the owner does not exist."""
	var _world: SaveWorld.World = null
	var _key: String = ""

	func _init(p_world: SaveWorld.World, p_key: String) -> void:
		"""Bind the world and the owner key."""
		_world = p_world
		_key = p_key

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""The image, or the canonical empty block while the owner does not exist."""
		block.reset_to_empty()
		if not SaveUnderground.present(_world, _key):
			return SaveUnderground._ok()
		var bytes: PackedByteArray = PackedByteArray()
		var code: StringName = SaveUnderground.capture_wire(_world.underground, _key, bytes)
		if code != &"":
			return SaveUnderground._no(REFUSE_BUSY, "'%s' refused its capture: %s" % [_key, code])
		var length: SaveHeader.Refusal = block.set_scalar(0, bytes.size())
		return length if not length.is_ok() else block.set_u8_column(1, bytes)

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Shape, and the length equal to the image's element count."""
		var shape: SaveHeader.Refusal = SaveUnderground.shape_refusal(block, _key)
		if shape.is_ok() and block.scalar(0) != block.element_count(1):
			return SaveUnderground._no(SaveAux.REFUSE_OWNER_STATE, "'%s' length disagrees" % _key)
		return shape

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Restore the image into the re-mounted owner; an empty block only where none exists."""
		var exists: bool = SaveUnderground.present(_world, _key)
		if block.element_count(1) == 0 or not exists:
			return SaveUnderground._ok() if block.element_count(1) == 0 and not exists \
				else SaveUnderground._no(REFUSE_MOUNT, "'%s' disagrees with the mount record" % _key)
		var code: StringName = SaveUnderground.restore_wire(_world.underground, _key, block.u8_column(1))
		if code != &"":
			return SaveUnderground._no(REFUSE_RESTORE, "'%s': %s" % [_key, code])
		return SaveUnderground._ok()


class DeclaredAdapter:
	"""An owner's registry columns through its own column API; empty where it does not exist."""
	var _world: SaveWorld.World = null
	var _key: String = ""

	func _init(p_world: SaveWorld.World, p_key: String) -> void:
		"""Bind the world and the owner key."""
		_world = p_world
		_key = p_key

	func _store() -> Object:
		"""The live owner, or null while the composition has not created it."""
		if not SaveUnderground.present(_world, _key):
			return null
		match _key:
			"excavation_sites": return _world.underground.sites
			"excavation_inventory": return _world.underground.sites._funding
		return _world.underground.router

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""Every column, or the canonical empty block."""
		block.reset_to_empty()
		var store: Object = _store()
		return SaveAux.ColumnsAdapter.new(store, _key).capture(block) if store != null \
			else SaveUnderground._ok()

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner and shape; the columns are judged by the re-composed owner at apply."""
		return SaveUnderground.shape_refusal(block, _key)

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Install into the re-composed owner; an empty block only where none exists."""
		var store: Object = _store()
		if store == null or block.is_canonical_empty():
			return SaveUnderground._ok() if store == null and block.is_canonical_empty() \
				else SaveUnderground._no(REFUSE_MOUNT, "'%s' disagrees with the mount record" % _key)
		return SaveAux.ColumnsAdapter.new(store, _key).apply(block)


class SpatialAdapter:
	"""Inventory's spatial endpoint arena (`inventory` owner)."""
	var _world: SaveWorld.World = null

	func _init(p_world: SaveWorld.World) -> void:
		"""Bind the world."""
		_world = p_world

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""The eight columns; an unbound arena still holding an endpoint has no image."""
		var columns: Array = _world.inventory.save_spatial_columns()
		if columns.is_empty():
			return SaveUnderground._no(REFUSE_UNSUPPORTED, "inventory holds a spatial endpoint with no World")
		var refusals: Array = []
		for ordinal: int in columns.size():
			refusals.append(SaveAux._set_column(block, ordinal, columns[ordinal]))
		return SaveAux._first_refusal(refusals)

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner and shape."""
		return SaveUnderground.shape_refusal(block, "inventory")

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Install and audit the arena against the restored containers and Locations."""
		var code: StringName = _world.inventory.restore_spatial_columns(SaveAux._columns_of(block))
		return SaveUnderground._ok() if code == &"" else SaveUnderground._no(REFUSE_RESTORE, "inventory: %s" % code)


class MountAdapter:
	"""`underground_mount`: whether a Session is mounted, its prefix and its content's SHA-256."""
	var _world: SaveWorld.World = null

	func _init(p_world: SaveWorld.World) -> void:
		"""Bind the world."""
		_world = p_world

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""The record; a Session mid-composition or holding a failed prefix cannot be saved."""
		block.reset_to_empty()
		var session: RefCounted = _world.session
		if session == null:
			return SaveUnderground._ok()
		var settled: bool = (session._operations_state == 2 and session._operations_prefix > 0) \
			or (session._operations_state == 0 and session._operations_prefix == 0)
		if not settled or not SAVED_PREFIXES.has(session._operations_prefix) or session._busy:
			return SaveUnderground._no(REFUSE_BUSY, "the underground Session is mid-composition (state %d, prefix %d)"
				% [session._operations_state, session._operations_prefix])
		var refusals: Array = [block.set_scalar(0, 1), block.set_scalar(1, session._operations_prefix),
			block.set_u8_column(2, session._content.source_digest().hex_decode())]
		return SaveAux._first_refusal(refusals)

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Shape; an unmounted record is all zero; a mounted one names a saved prefix."""
		var shape: SaveHeader.Refusal = SaveUnderground.shape_refusal(block, "underground_mount")
		if not shape.is_ok():
			return shape
		var mounted: int = block.scalar(0)
		if (mounted == 0 and not block.is_canonical_empty()) or mounted > 1 \
				or (mounted == 1 and not SAVED_PREFIXES.has(block.scalar(1))):
			return SaveUnderground._no(SaveAux.REFUSE_OWNER_STATE, "the mount record is malformed")
		return shape

	func apply(_block: Section.Block) -> SaveHeader.Refusal:
		"""Nothing: the orchestrator re-mounted from this record before section 4."""
		return SaveUnderground._ok()


class EntryAdapter:
	"""`underground_entry_progress`: ADR 1218's runtime record. The hauler queue columns stay empty;
	ADR 1218 declared them hash-free because the record carries the queue."""
	var _world: SaveWorld.World = null

	func _init(p_world: SaveWorld.World) -> void:
		"""Bind the world."""
		_world = p_world

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""The runtime's record, or the canonical empty block before the first entry request."""
		block.reset_to_empty()
		if _world.entry == null:
			return SaveUnderground._ok()
		var bytes: PackedByteArray = PackedByteArray()
		var code: StringName = _world.entry.capture(bytes)
		if code != &"":
			return SaveUnderground._no(REFUSE_BUSY, "the entry runtime refused its capture: %s" % code)
		var length: SaveHeader.Refusal = block.set_scalar(0, bytes.size())
		return length if not length.is_ok() else block.set_u8_column(1, bytes)

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Shape, the record length, and no queue outside the record."""
		var shape: SaveHeader.Refusal = SaveUnderground.shape_refusal(block, "underground_entry_progress")
		if shape.is_ok() and (block.scalar(0) != block.element_count(1) or block.scalar(2) != 0
				or block.element_count(3) != 0):
			return SaveUnderground._no(SaveAux.REFUSE_OWNER_STATE, "the entry record is malformed")
		return shape

	func apply(_block: Section.Block) -> SaveHeader.Refusal:
		"""Nothing here: the orchestrator restores the record after every other section."""
		return SaveUnderground._ok()
