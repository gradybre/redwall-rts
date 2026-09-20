# --- SAVE-GEAR-R01 v2: exact Gear owner columns -----------------------------------------------
#
# APPEND-ONLY FRAGMENT for `godot/scripts/core/gear.gd`. It carries no `extends`, no `preload`
# and no redefinition of anything already declared above it: the parent appends this block
# verbatim at the end of that file.
#
# WHAT IT IS FOR. `begin_restore()`/`restore_row()`/`finish_restore()` publish rows one at a
# time and cannot carry the `equipped` byte at all, so a world saved with twelve equipped tools
# comes back with twelve unequipped ones. These four entry points move all twelve canonical
# columns as one image instead, preserving bare row identity, the equipped flag and the stale
# generations a coordinator still has to reconcile. The legacy route is left exactly as it is.
#
# WHAT IT DELIBERATELY DOES NOT CLAIM. Every check here is STRUCTURAL. Exact catalog
# membership, per-kind cap/manufacture validity, equipped-tool subtype, lot item/quantity, owner
# liveness/kind/mirror, the equipment biconditional, claim liveness and Work bindings are full
# coordinator gates that run BEFORE a settlement resumes. A well-formed image is not a playable
# world, and nothing below should be read as saying otherwise.
#
# TWO GATES ARE STRONGER THAN THE EXISTING CODEC, ON PURPOSE. A reference pair must be exactly
# (-1, 0) or exactly a live-shaped pair -- no half-null -- and a claim slot must be below 8192,
# which is the domain `claim_for_job()` already admits, while the codec bounds the same column
# at 352418. Neither side is changed here and such a value is never clamped, masked, normalised
# or remapped: it fails loading pending the separate job-generation integration ruling.
#
# NO NEW PERSISTENT STATE. `_last_column_refusal` is the one new owner field, category 3, and it
# is the ONLY field either operation writes on a refusal. No borrowed reference is bound, no
# collaborator is called, `audit()` is not invoked, no hot mutator is replayed and
# `_refill_heap_ascending()` -- which rewrites LIVE state -- is never reached from here.

## Category 3 refusal codes for the two bulk column operations. First failing gate wins.
const REFUSE_COLUMN_GEAR_SHAPE: StringName = &"COLUMN_GEAR_SHAPE"
const REFUSE_COLUMN_GEAR_RESTORING: StringName = &"COLUMN_GEAR_RESTORING"
const REFUSE_COLUMN_GEAR_DEFINITIONS: StringName = &"COLUMN_GEAR_DEFINITIONS"
const REFUSE_COLUMN_GEAR_OCCUPANCY: StringName = &"COLUMN_GEAR_OCCUPANCY"
const REFUSE_COLUMN_GEAR_BLANK: StringName = &"COLUMN_GEAR_BLANK"
const REFUSE_COLUMN_GEAR_REF: StringName = &"COLUMN_GEAR_REF"
const REFUSE_COLUMN_GEAR_ITEM: StringName = &"COLUMN_GEAR_ITEM"
const REFUSE_COLUMN_GEAR_DURABILITY: StringName = &"COLUMN_GEAR_DURABILITY"
const REFUSE_COLUMN_GEAR_MANUFACTURE: StringName = &"COLUMN_GEAR_MANUFACTURE"
const REFUSE_COLUMN_GEAR_DUPLICATE_LOT: StringName = &"COLUMN_GEAR_DUPLICATE_LOT"
const REFUSE_COLUMN_GEAR_BINDING: StringName = &"COLUMN_GEAR_BINDING"
const REFUSE_COLUMN_GEAR_SOURCE_CACHE: StringName = &"COLUMN_GEAR_SOURCE_CACHE"
const REFUSE_COLUMN_GEAR_SOURCE_DERIVED: StringName = &"COLUMN_GEAR_SOURCE_DERIVED"


class GearColumns:
	"""A caller-owned image of the twelve canonical gear columns at one row capacity.

	WIRE ORDER, and the order the adapter's ordinals 0..11 name: occupied, lot_slot,
	lot_generation, item_id, durability, durability_cap, owner_slot, owner_generation,
	manufacture_recipe, equipped, claim_job_slot, claim_job_generation.

	NO BORROWED REFERENCE, NO CACHE, NO DERIVED ARRAY lives here: the free heap, the three
	counts and the five compiled catalog ids are all rebuilt by the owner on restore, so this
	record cannot carry a stale copy of any of them.

	`row_capacity` RECORDS THE REQUESTED METADATA UNCHANGED while the arrays are allocated from
	a separate local clamped length. That separation is deliberate: a malformed request stays
	visible in the metadata and is refused COLUMN_GEAR_SHAPE by whichever operation sees it,
	rather than being silently rounded into a capacity the caller never asked for.
	"""
	var row_capacity: int = 0
	var occupied: PackedByteArray = PackedByteArray()
	var lot_slot: PackedInt32Array = PackedInt32Array()
	var lot_generation: PackedInt32Array = PackedInt32Array()
	var item_id: PackedInt32Array = PackedInt32Array()
	var durability: PackedInt32Array = PackedInt32Array()
	var durability_cap: PackedInt32Array = PackedInt32Array()
	var owner_slot: PackedInt32Array = PackedInt32Array()
	var owner_generation: PackedInt32Array = PackedInt32Array()
	var manufacture_recipe: PackedInt32Array = PackedInt32Array()
	var equipped: PackedByteArray = PackedByteArray()
	var claim_job_slot: PackedInt32Array = PackedInt32Array()
	var claim_job_generation: PackedInt32Array = PackedInt32Array()

	func _init(p_row_capacity: int = ROW_CAPACITY) -> void:
		"""Record the requested capacity and allocate every column at the clamped length.

		The canonical blank is exactly what `clear()` writes: slots and item id -1, every
		generation 0, durability, cap, manufacture and both flags 0.
		"""
		row_capacity = p_row_capacity
		var length: int = clampi(p_row_capacity, 1, ROW_CAPACITY)
		occupied.resize(length)
		occupied.fill(0)
		equipped.resize(length)
		equipped.fill(0)
		lot_slot.resize(length)
		lot_slot.fill(NULL_SLOT)
		item_id.resize(length)
		item_id.fill(-1)
		owner_slot.resize(length)
		owner_slot.fill(NULL_SLOT)
		claim_job_slot.resize(length)
		claim_job_slot.fill(NULL_SLOT)
		lot_generation.resize(length)
		lot_generation.fill(NULL_GENERATION)
		owner_generation.resize(length)
		owner_generation.fill(NULL_GENERATION)
		claim_job_generation.resize(length)
		claim_job_generation.fill(NULL_GENERATION)
		durability.resize(length)
		durability.fill(0)
		durability_cap.resize(length)
		durability_cap.fill(0)
		manufacture_recipe.resize(length)
		manufacture_recipe.fill(MANUFACTURE_BASIC)


class GearColumnTally:
	"""The tiny native-count result of one column validation pass. Three ints, no rows."""
	var active_rows: int = 0
	var equipped_rows: int = 0
	var free_rows: int = 0


## The one owner field either bulk operation writes on a refusal. Category 3, transient, and
## cleared by a successful operation. It is NOT a busy flag and NOT part of the canonical image.
var _last_column_refusal: StringName = REFUSE_NONE


# --- Public owner API -------------------------------------------------------------------------

func last_column_refusal() -> StringName:
	"""The code of the most recent bulk column refusal, or REFUSE_NONE after a success."""
	return _last_column_refusal


func canonical_detail() -> String:
	"""The contracted echo of `last_column_refusal()` as a String, for a Refusal's detail.

	Deliberately a code echo and nothing more: this API promises no field or row diagnostic,
	so no caller can come to depend on one that later moves.
	"""
	return String(_last_column_refusal)


func column_inventory_matches(inventory: Inventory) -> bool:
	"""PURE identity predicate: true only for a nonnull argument this store is not bound against.

	True when `inventory` is nonnull AND this store is either unbound or bound to exactly that
	object. It writes nothing, binds nothing and ATTESTS NOTHING: an unbound store cannot prove
	world association, so a coordinator still owns that check.
	"""
	if inventory == null:
		return false
	return _inventory == null or _inventory == inventory


func copy_gear_columns_into(out: GearColumns, definitions: ItemDefinitions) -> bool:
	"""Duplicate the twelve live columns into `out`, or refuse having written nothing to it.

	GATE ORDER, fixed: total shape of the caller's record and of this store's own live arrays;
	the restore window; the catalog; every occupancy and equipped flag; every row; duplicate lot
	slots; the equipment binding; the five source cache ids; and this store's three counts and
	free heap. Only then are the twelve columns duplicated across.

	The source caches are READ and never rewritten, and `capture_item_ids()` is not called.
	"""
	var shape: StringName = _gear_columns_shape_refusal(out)
	if shape != REFUSE_NONE:
		return _refuse_gear_columns(shape)
	var live: StringName = _gear_live_shape_refusal()
	if live != REFUSE_NONE:
		return _refuse_gear_columns(live)
	if _restoring:
		return _refuse_gear_columns(REFUSE_COLUMN_GEAR_RESTORING)
	if definitions == null or not definitions.is_loaded():
		return _refuse_gear_columns(REFUSE_COLUMN_GEAR_DEFINITIONS)
	var staged_tool: int = definitions.compiled_id(KEY_TOOL)
	var staged_net: int = definitions.compiled_id(KEY_NET)
	var staged_trap: int = definitions.compiled_id(KEY_TRAP)
	var staged_ice_kit: int = definitions.compiled_id(KEY_ICE_KIT)
	var staged_outfit: int = definitions.compiled_id(KEY_OUTFIT_TIER2)
	var tally: GearColumnTally = GearColumnTally.new()
	var payload: StringName = _gear_column_payload_refusal(_row_capacity, _occupied, _lot_slot,
		_lot_generation, _item_id, _durability, _durability_cap, _owner_slot, _owner_generation,
		_manufacture_recipe, _equipped, _claim_job_slot, _claim_job_generation, tally)
	if payload != REFUSE_NONE:
		return _refuse_gear_columns(payload)
	if tally.equipped_rows > 0 and not is_equipment_bound():
		return _refuse_gear_columns(REFUSE_COLUMN_GEAR_BINDING)
	var cache: StringName = _gear_source_cache_refusal(tally.active_rows, staged_tool, staged_net,
		staged_trap, staged_ice_kit, staged_outfit)
	if cache != REFUSE_NONE:
		return _refuse_gear_columns(cache)
	var derived: StringName = _gear_source_derived_refusal(tally)
	if derived != REFUSE_NONE:
		return _refuse_gear_columns(derived)
	_publish_gear_capture(out)
	_last_column_refusal = REFUSE_NONE
	return true


func restore_gear_columns(columns: GearColumns, definitions: ItemDefinitions) -> bool:
	"""Install an exact twelve-column image, or refuse having changed no live byte.

	The OLD payload and the old derived values are ignored entirely -- this is a whole-image
	install, not a merge -- but the store's own construction metadata and live array extents are
	still required to be valid, and the borrowed Inventory/Directory/Residents identities, the
	seed buffers and `_wear_math` are left exactly as they are.

	The free heap is prepared PRIVATELY here. `_refill_heap_ascending()` mutates live state and
	is never called: nothing may be written until every gate has passed.
	"""
	var shape: StringName = _gear_columns_shape_refusal(columns)
	if shape != REFUSE_NONE:
		return _refuse_gear_columns(shape)
	var live: StringName = _gear_live_shape_refusal()
	if live != REFUSE_NONE:
		return _refuse_gear_columns(live)
	if _restoring:
		return _refuse_gear_columns(REFUSE_COLUMN_GEAR_RESTORING)
	if definitions == null or not definitions.is_loaded():
		return _refuse_gear_columns(REFUSE_COLUMN_GEAR_DEFINITIONS)
	var staged_tool: int = definitions.compiled_id(KEY_TOOL)
	var staged_net: int = definitions.compiled_id(KEY_NET)
	var staged_trap: int = definitions.compiled_id(KEY_TRAP)
	var staged_ice_kit: int = definitions.compiled_id(KEY_ICE_KIT)
	var staged_outfit: int = definitions.compiled_id(KEY_OUTFIT_TIER2)
	var tally: GearColumnTally = GearColumnTally.new()
	var payload: StringName = _gear_column_payload_refusal(_row_capacity, columns.occupied,
		columns.lot_slot, columns.lot_generation, columns.item_id, columns.durability,
		columns.durability_cap, columns.owner_slot, columns.owner_generation,
		columns.manufacture_recipe, columns.equipped, columns.claim_job_slot,
		columns.claim_job_generation, tally)
	if payload != REFUSE_NONE:
		return _refuse_gear_columns(payload)
	if tally.equipped_rows > 0 and not is_equipment_bound():
		return _refuse_gear_columns(REFUSE_COLUMN_GEAR_BINDING)
	_publish_gear_restore(columns, tally, staged_tool, staged_net, staged_trap, staged_ice_kit,
		staged_outfit)
	_last_column_refusal = REFUSE_NONE
	return true


# --- Publication ------------------------------------------------------------------------------

func _publish_gear_capture(out: GearColumns) -> void:
	"""Duplicate all twelve live columns into the caller. Runs only after every gate passed.

	Each column is an independent duplicate, so the caller's record cannot alias a live column
	and a later mutation here cannot reach through into a staged save.
	"""
	out.occupied = _occupied.duplicate()
	out.lot_slot = _lot_slot.duplicate()
	out.lot_generation = _lot_generation.duplicate()
	out.item_id = _item_id.duplicate()
	out.durability = _durability.duplicate()
	out.durability_cap = _durability_cap.duplicate()
	out.owner_slot = _owner_slot.duplicate()
	out.owner_generation = _owner_generation.duplicate()
	out.manufacture_recipe = _manufacture_recipe.duplicate()
	out.equipped = _equipped.duplicate()
	out.claim_job_slot = _claim_job_slot.duplicate()
	out.claim_job_generation = _claim_job_generation.duplicate()


func _publish_gear_restore(columns: GearColumns, tally: GearColumnTally, staged_tool: int,
		staged_net: int, staged_trap: int, staged_ice_kit: int, staged_outfit: int) -> void:
	"""Stage privately, then publish arrays, heap, three counts and five ids in one run.

	Every fallible check is already behind us and every buffer below is built BEFORE the first
	live assignment, so there is no window in which half an image is visible. The twelve inputs
	are duplicated, so the caller's record stays independent of the live store afterwards.
	"""
	var heap: PackedInt32Array = PackedInt32Array()
	heap.resize(_row_capacity)
	heap.fill(NULL_ROW)
	var free_count: int = 0
	for row: int in range(_row_capacity):
		if columns.occupied[row] == 1:
			continue
		heap[free_count] = row
		free_count += 1
	var occupied: PackedByteArray = columns.occupied.duplicate()
	var equipped: PackedByteArray = columns.equipped.duplicate()
	var lot_slot: PackedInt32Array = columns.lot_slot.duplicate()
	var lot_generation: PackedInt32Array = columns.lot_generation.duplicate()
	var item_id: PackedInt32Array = columns.item_id.duplicate()
	var durability: PackedInt32Array = columns.durability.duplicate()
	var durability_cap: PackedInt32Array = columns.durability_cap.duplicate()
	var owner_slot: PackedInt32Array = columns.owner_slot.duplicate()
	var owner_generation: PackedInt32Array = columns.owner_generation.duplicate()
	var manufacture_recipe: PackedInt32Array = columns.manufacture_recipe.duplicate()
	var claim_job_slot: PackedInt32Array = columns.claim_job_slot.duplicate()
	var claim_job_generation: PackedInt32Array = columns.claim_job_generation.duplicate()
	_occupied = occupied
	_equipped = equipped
	_lot_slot = lot_slot
	_lot_generation = lot_generation
	_item_id = item_id
	_durability = durability
	_durability_cap = durability_cap
	_owner_slot = owner_slot
	_owner_generation = owner_generation
	_manufacture_recipe = manufacture_recipe
	_claim_job_slot = claim_job_slot
	_claim_job_generation = claim_job_generation
	_free_heap = heap
	_active_count = tally.active_rows
	_free_count = free_count
	_equipped_count = tally.equipped_rows
	_id_tool = staged_tool
	_id_net = staged_net
	_id_trap = staged_trap
	_id_ice_kit = staged_ice_kit
	_id_outfit_tier2 = staged_outfit


# --- Shape gates ------------------------------------------------------------------------------

func _gear_columns_shape_refusal(columns: GearColumns) -> StringName:
	"""Total shape gate for a caller's record: null, metadata, R match and twelve extents.

	Runs BEFORE any indexing and before any derived staging is allocated, so a malformed record
	can neither read past a column nor make this store allocate.
	"""
	if columns == null:
		return REFUSE_COLUMN_GEAR_SHAPE
	if columns.row_capacity < 1 or columns.row_capacity > ROW_CAPACITY:
		return REFUSE_COLUMN_GEAR_SHAPE
	if columns.row_capacity != _row_capacity:
		return REFUSE_COLUMN_GEAR_SHAPE
	var rows: int = columns.row_capacity
	if columns.occupied.size() != rows or columns.equipped.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if columns.lot_slot.size() != rows or columns.lot_generation.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if columns.item_id.size() != rows or columns.manufacture_recipe.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if columns.durability.size() != rows or columns.durability_cap.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if columns.owner_slot.size() != rows or columns.owner_generation.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if columns.claim_job_slot.size() != rows or columns.claim_job_generation.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	return REFUSE_NONE


func _gear_live_shape_refusal() -> StringName:
	"""Total shape gate for THIS store: native R, twelve live columns and the free heap.

	The heap is included because capture indexes it, and a heap shorter than R would be indexed
	out of range by a corrupted free count before the count gate could report anything useful.
	"""
	if _row_capacity < 1 or _row_capacity > ROW_CAPACITY:
		return REFUSE_COLUMN_GEAR_SHAPE
	var rows: int = _row_capacity
	if _occupied.size() != rows or _equipped.size() != rows or _free_heap.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if _lot_slot.size() != rows or _lot_generation.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if _item_id.size() != rows or _manufacture_recipe.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if _durability.size() != rows or _durability_cap.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if _owner_slot.size() != rows or _owner_generation.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	if _claim_job_slot.size() != rows or _claim_job_generation.size() != rows:
		return REFUSE_COLUMN_GEAR_SHAPE
	return REFUSE_NONE


# --- Shared payload validation ------------------------------------------------------------------

func _gear_column_payload_refusal(rows: int, occupied: PackedByteArray,
		lot_slot: PackedInt32Array, lot_generation: PackedInt32Array, item_id: PackedInt32Array,
		durability: PackedInt32Array, durability_cap: PackedInt32Array,
		owner_slot: PackedInt32Array, owner_generation: PackedInt32Array,
		manufacture_recipe: PackedInt32Array, equipped: PackedByteArray,
		claim_job_slot: PackedInt32Array, claim_job_generation: PackedInt32Array,
		tally: GearColumnTally) -> StringName:
	"""THE one validator both operations share, over twelve typed arrays and three counters.

	It allocates no second GearColumns, no Dictionary and no per-row object: the only buffer is
	the 16384-byte duplicate-lot bitmap, and it is allocated only once every per-row field has
	already passed. Both flag columns are checked across the whole extent FIRST, because a byte
	of 2 in `equipped` would otherwise decide a row's meaning before it was known to be legal.
	"""
	tally.active_rows = 0
	tally.equipped_rows = 0
	tally.free_rows = 0
	for row: int in range(rows):
		if occupied[row] > 1 or equipped[row] > 1:
			return REFUSE_COLUMN_GEAR_OCCUPANCY
	for row: int in range(rows):
		if occupied[row] == 0:
			var blank: StringName = _gear_blank_row_refusal(lot_slot[row], lot_generation[row],
				item_id[row], durability[row], durability_cap[row], owner_slot[row],
				owner_generation[row], manufacture_recipe[row], equipped[row],
				claim_job_slot[row], claim_job_generation[row])
			if blank != REFUSE_NONE:
				return blank
			continue
		var active: StringName = _gear_active_row_refusal(lot_slot[row], lot_generation[row],
			item_id[row], durability[row], durability_cap[row], owner_slot[row],
			owner_generation[row], manufacture_recipe[row], equipped[row], claim_job_slot[row],
			claim_job_generation[row])
		if active != REFUSE_NONE:
			return active
		tally.active_rows += 1
		tally.equipped_rows += equipped[row]
	tally.free_rows = rows - tally.active_rows
	return _gear_duplicate_lot_refusal(rows, occupied, lot_slot)


func _gear_blank_row_refusal(lot_s: int, lot_g: int, item: int, dur: int, cap: int, own_s: int,
		own_g: int, manufacture: int, equipped_flag: int, claim_s: int,
		claim_g: int) -> StringName:
	"""An inactive row must be the EXACT canonical blank `_blank_row()`/`clear()` writes.

	The four owners that blank on release leave no residue, so anything else in an inactive row
	is corruption rather than history -- and, left admitted, two observably identical worlds
	would capture to different bytes.
	"""
	if lot_s != NULL_SLOT or lot_g != NULL_GENERATION or item != -1:
		return REFUSE_COLUMN_GEAR_BLANK
	if dur != 0 or cap != 0 or manufacture != MANUFACTURE_BASIC or equipped_flag != 0:
		return REFUSE_COLUMN_GEAR_BLANK
	if own_s != NULL_SLOT or own_g != NULL_GENERATION:
		return REFUSE_COLUMN_GEAR_BLANK
	if claim_s != NULL_SLOT or claim_g != NULL_GENERATION:
		return REFUSE_COLUMN_GEAR_BLANK
	return REFUSE_NONE


func _gear_active_row_refusal(lot_s: int, lot_g: int, item: int, dur: int, cap: int, own_s: int,
		own_g: int, manufacture: int, equipped_flag: int, claim_s: int,
		claim_g: int) -> StringName:
	"""One occupied row's structural identities. NOT a liveness check of any kind.

	A reference pair is either EXACTLY null -- (-1, 0) -- or entirely well formed; a half-null
	pair is refused rather than repaired. Stale generations are preserved deliberately: whether
	an owner or a claim still resolves is a coordinator question, asked after loading.
	"""
	if lot_s < 0 or lot_s >= LOT_CAPACITY or lot_g <= NULL_GENERATION:
		return REFUSE_COLUMN_GEAR_REF
	var owner_null: bool = own_s == NULL_SLOT and own_g == NULL_GENERATION
	if not owner_null:
		if own_s < 0 or own_s >= EntityDirectory.DIRECTORY_CAPACITY or own_g <= NULL_GENERATION:
			return REFUSE_COLUMN_GEAR_REF
	if equipped_flag == 1 and owner_null:
		return REFUSE_COLUMN_GEAR_REF
	var claim_null: bool = claim_s == NULL_SLOT and claim_g == NULL_GENERATION
	if not claim_null:
		# Stronger than the codec's 352418 on purpose: this is the domain `claim_for_job()`
		# already admits, and neither bound is widened or rewritten here.
		if claim_s < 0 or claim_s >= JOB_CAPACITY or claim_g <= NULL_GENERATION:
			return REFUSE_COLUMN_GEAR_REF
	if item < 0:
		return REFUSE_COLUMN_GEAR_ITEM
	if cap < 0 or dur < 0 or dur > cap:
		return REFUSE_COLUMN_GEAR_DURABILITY
	if manufacture != MANUFACTURE_BASIC and manufacture != MANUFACTURE_IRON:
		return REFUSE_COLUMN_GEAR_MANUFACTURE
	return REFUSE_NONE


func _gear_duplicate_lot_refusal(rows: int, occupied: PackedByteArray,
		lot_slot: PackedInt32Array) -> StringName:
	"""One gear record per lot SLOT, including two rows at different generations.

	A 16384-byte bitmap, one ascending pass: no quadratic scan, no Dictionary, no sort. The slot
	is compared rather than the whole reference because two rows sharing a slot mean one lot
	carries two instances, whatever their generations say.
	"""
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(LOT_CAPACITY)
	seen.fill(0)
	for row: int in range(rows):
		if occupied[row] == 0:
			continue
		var slot: int = lot_slot[row]
		if seen[slot] == 1:
			return REFUSE_COLUMN_GEAR_DUPLICATE_LOT
		seen[slot] = 1
	return REFUSE_NONE


# --- Capture-only source gates --------------------------------------------------------------------

func _gear_source_cache_refusal(active_rows: int, staged_tool: int, staged_net: int,
		staged_trap: int, staged_ice_kit: int, staged_outfit: int) -> StringName:
	"""The five bound catalog ids must describe the catalog this capture was handed.

	An empty store may also be entirely unbound -- all five -1 -- because nothing has needed the
	ids yet. A store holding rows must match exactly: a stale cache means the rows' item ids were
	interpreted against a different catalog, and a mixed cache is refused outright.
	"""
	if _id_tool == staged_tool and _id_net == staged_net and _id_trap == staged_trap \
			and _id_ice_kit == staged_ice_kit and _id_outfit_tier2 == staged_outfit:
		return REFUSE_NONE
	if active_rows == 0 and _id_tool == -1 and _id_net == -1 and _id_trap == -1 \
			and _id_ice_kit == -1 and _id_outfit_tier2 == -1:
		return REFUSE_NONE
	return REFUSE_COLUMN_GEAR_SOURCE_CACHE


func _gear_source_derived_refusal(tally: GearColumnTally) -> StringName:
	"""Re-derive the three counts and prove the free heap before capturing from this store.

	RANGES FIRST, then indexing: the free count is bounded before a single heap cell is read.
	The live prefix must be exactly the free set, with no duplicate and no occupied row, and it
	must satisfy the min-heap property. ANY valid permutation is admitted -- the lowest-index
	allocation order depends on the heap, not on a particular arrangement of it -- and the tail
	beyond the count is ignored, because it is stale garbage two identical worlds can differ in.
	"""
	if _active_count != tally.active_rows or _equipped_count != tally.equipped_rows:
		return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
	if _free_count != tally.free_rows:
		return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
	if _free_count < 0 or _free_count > _row_capacity:
		return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
	if _active_count < 0 or _active_count > _row_capacity:
		return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(_row_capacity)
	seen.fill(0)
	for index: int in range(_free_count):
		var row: int = _free_heap[index]
		if row < 0 or row >= _row_capacity:
			return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
		if _occupied[row] == 1 or seen[row] == 1:
			return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
		seen[row] = 1
	for index: int in range(_free_count):
		var left: int = index * 2 + 1
		if left < _free_count and _free_heap[index] > _free_heap[left]:
			return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
		var right: int = left + 1
		if right < _free_count and _free_heap[index] > _free_heap[right]:
			return REFUSE_COLUMN_GEAR_SOURCE_DERIVED
	return REFUSE_NONE


func _refuse_gear_columns(code: StringName) -> bool:
	"""Record a bulk column refusal and change nothing else. Always returns false.

	`_last_column_refusal` is the ONLY owner field a failed bulk operation writes: the twelve
	columns, the heap, the three counts, the five ids, the seed buffers, `_wear_math`, the three
	borrowed collaborators and `_restoring` are all exactly as they were.
	"""
	_last_column_refusal = code
	return false
