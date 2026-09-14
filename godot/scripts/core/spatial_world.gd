extends RefCounted
## ARCH-PATH-001 ground map: the baseline settlement surface as static integer navigation cells,
## plus the ground half of the shared location identity frozen by task 05.1a.
##
## ---------------------------------------------------------------------------------------
## WHAT A GROUND LOCATION IS, AND WHAT IT IS NOT (READY_07 1.2, first bullet).
##
## A ground location ID here is a BASELINE CELL INDEX qualified by a declared domain, a declared
## layer and the world/map revision it was minted against. It is NOT a universal multi-level
## location. Two different floors, a submerged column and a canopy branch can all sit above the
## same X/Z, so `cell` alone names a destination only inside `(DOMAIN_GROUND, LAYER_SURFACE)`.
## Every public API in this slice therefore carries the whole `Location` record -- domain, layer,
## revision, cell AND the generation-safe owner of the contact -- and no API in this slice accepts
## a bare X/Z pair as a destination. SET-MOVE-001 2's dynamic Location/Connection directory kinds
## are the eventual shared boundary; this module keeps the same field shape deliberately, so the
## later domains extend it instead of replacing it.
##
## BLOCKER, NAMED NOT INVENTED: domains other than DOMAIN_GROUND and layers other than
## LAYER_SURFACE refuse with `DOMAIN_NOT_CONTRACTED` / `LAYER_NOT_CONTRACTED`. Their finite depth,
## elevation and cell budgets are MOVE-G01 parameter-pack outputs (READY_07 1.3) and are not
## guessed here. One floor is not a substitute for multilevel scope.
##
## ---------------------------------------------------------------------------------------
## CLEARANCE IS AN INPUT, NOT A CONSTANT THIS MODULE OWNS.
##
## `_clearance[cell]` is pure map geometry: the side of the largest all-passable square whose
## north-west corner is that cell, in half-metre cells. A route asks `cell_passes_clearance(cell,
## clearance_class)` with a clearance class the CALLER supplies. This module publishes no body,
## posture or gear clearance number, because READY_07 1.2 is explicit that exact production
## body/gear clearances are a profile decision that neither the 1.0 m mouse anchor nor a size-speed
## category determines. Reference routing with a synthetic clearance class is unblocked; ordinary
## resident travel cannot be declared correct until starter profiles and contact clearances are
## specified, and nothing here may be published into an active gameplay catalog as if it were one.
##
## ---------------------------------------------------------------------------------------
## THE CONTACT SCHEMA IS A SCHEMA, NOT A CATALOG OF DESTINATIONS.
##
## `Contact` below is the movement half of the 2026-09-11 ruling's starter contact manifest: a work
## cell, a separate approach cell a body actually stands on, one generation-checked owner, and the
## owner's destination revision. What this module supplies is the RECORD SHAPE and its refusals.
## The exact supported footprint and contact envelope -- how far an approach may be from its work
## point, whether a footprint spans cells, which side of a building offers one -- is the contact
## owner's value and is NOT invented here. No adjacency rule is imposed for that reason.
##
## ---------------------------------------------------------------------------------------
## MEMORY. The five columns below ARE systems_architecture.md 2.3's "Static navigation map",
## 262144 x 14 bytes = 3670016: walkability/layer bytes plus terrain/height/clearance i32. No
## second world, no shadow copy, and no `resize()` outside `_init()`.

const IntMath := preload("res://scripts/core/int_math.gd")
const WorldInit := preload("res://scripts/core/world_init.gd")

# --- geometry, ARCH-PATH-001 --------------------------------------------------------------------

## "Navigation cells are 1/2 m, producing 512x512=262144 cells; cell ID=`z*512+x`."
const CELLS_X: int = 512
const CELLS_Z: int = 512
const CELL_COUNT: int = CELLS_X * CELLS_Z

## Positions are int32 in 1/1024 m units (GDD 4.2), so a half-metre cell is 512 units wide.
const CELL_SIZE_UNITS: int = 512
const CELL_CENTRE_OFFSET_UNITS: int = 256

## world_init.gd's exterior tiles are 2 m, so one tile covers exactly 4x4 navigation cells.
const CELLS_PER_TILE: int = 4

## ARCH-PATH-003: "Macro cells contain 16x16 navigation cells".
const MACRO_CELLS: int = 16
const MACROS_X: int = CELLS_X / MACRO_CELLS
const MACROS_Z: int = CELLS_Z / MACRO_CELLS
const MACRO_COUNT: int = MACROS_X * MACROS_Z
const CELLS_PER_MACRO: int = MACRO_CELLS * MACRO_CELLS

# --- declared domain and layer space ------------------------------------------------------------

const DOMAIN_GROUND: int = 0
const DOMAIN_COUNT: int = 1
const LAYER_SURFACE: int = 0
const LAYER_COUNT: int = 1

# --- revisions ----------------------------------------------------------------------------------

## SET-MOVE-001 2 makes the topology revision a positive i64 that refuses exhaustion and never
## wraps. This baseline fixture carries the revision inside an int32-width identity record, so it
## refuses one step EARLIER than the eventual contract rather than wrapping into a revision that
## would silently revalidate every stale route. Widening the record to i64 is a MOVE-G02 output.
const FIRST_MAP_REVISION: int = 1
const MAX_MAP_REVISION: int = IntMath.INT32_MAX

const MIN_CLEARANCE_CLASS: int = 1
const MAX_CLEARANCE_CLASS: int = CELLS_X

# --- refusal codes ------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_CELL: StringName = &"INVALID_CELL"
const REFUSE_INVALID_COORD: StringName = &"INVALID_CELL_COORD"
const REFUSE_INVALID_POSITION: StringName = &"POSITION_OUT_OF_MAP"
const REFUSE_DOMAIN: StringName = &"DOMAIN_NOT_CONTRACTED"
const REFUSE_LAYER: StringName = &"LAYER_NOT_CONTRACTED"
const REFUSE_REVISION_EXHAUSTED: StringName = &"MAP_REVISION_EXHAUSTED"
const REFUSE_NULL_OWNER: StringName = &"LOCATION_OWNER_REQUIRED"
const REFUSE_CONTACT_REVISION: StringName = &"CONTACT_DESTINATION_REVISION_REQUIRED"
const REFUSE_CONTACT_APPROACH: StringName = &"CONTACT_APPROACH_NOT_WALKABLE"

## The first legal destination revision. Zero means "this contact named no destination state at
## all", which is how an empty building or an absent service store is kept out of the manifest --
## the ruling's "empty buildings or nonexistent service stores are not valid targets". The revision
## VALUE is the contact owner's; only its null is contracted here.
const FIRST_DESTINATION_REVISION: int = 1


class Location:
	extends RefCounted
	## One ground contact: spatial context plus the generation-safe entity that owns it.
	##
	## Caller-owned and reused, like `int_math.gd`'s IntResult, so a per-tick reader allocates
	## nothing. `owner_slot`/`owner_generation` are HALVES OF ONE EntityRef and must be compared
	## as a pair; comparing only the slot is the defect class this record exists to make visible.

	var domain: int = -1
	var layer: int = -1
	var revision: int = 0
	var cell: int = -1
	var owner_slot: int = -1
	var owner_generation: int = 0

	func clear() -> void:
		"""Return this record to the unbound state; `is_bound()` is false afterwards."""
		domain = -1
		layer = -1
		revision = 0
		cell = -1
		owner_slot = -1
		owner_generation = 0

	func is_bound() -> bool:
		"""True when this record names a domain, a layer and a cell. Says nothing about staleness."""
		return domain >= 0 and layer >= 0 and cell >= 0

	func owner_ref() -> Vector2i:
		"""The owning entity reference as GDD 4.1's `(slot, generation)` pair."""
		return Vector2i(owner_slot, owner_generation)

	func same_place_as(other: Location) -> bool:
		"""True when both records name the same domain, layer and cell. Ignores owner and revision."""
		return domain == other.domain and layer == other.layer and cell == other.cell


class Contact:
	extends RefCounted
	## One work or service destination: WHERE THE WORK IS and WHERE A BODY MUST STAND ARE TWO
	## DIFFERENT CELLS, plus the destination's own revision.
	##
	## The two locations are separate on purpose. A workbench, a store shelf or a well head occupies
	## a cell that navigation need not make walkable at all; the body stands on the approach cell.
	## Collapsing them is exactly SET-MOVE-001 MOVE-REQ-013's defect -- "being horizontally close
	## cannot satisfy a below-floor job" -- one level up.
	##
	## `destination_revision` is the CONTACT OWNER'S number, not this module's. It changes when the
	## thing being travelled to changes in a way that invalidates an admitted journey: a store
	## emptied, a service withdrawn, a building demolished and rebuilt on the same handle. Movement
	## records it at admission and refuses on mismatch; it never guesses what should bump it.
	##
	## NOT SETTLED HERE, AND DELIBERATELY NOT INVENTED: how far an approach cell may lie from its
	## work cell, whether a footprint spans several cells, and which approach a multi-sided building
	## offers. Those are the "exact supported footprint/contact envelopes" the 2026-09-11 movement
	## ruling assigns to the contact owner. This record therefore takes the approach cell as given
	## and checks only that it is a real, walkable ground cell -- no adjacency rule is imposed,
	## because imposing one would be choosing that envelope.

	var work: Location = Location.new()
	var approach: Location = Location.new()
	var destination_revision: int = 0

	func clear() -> void:
		"""Return this contact to the unbound state; `is_bound()` is false afterwards."""
		work.clear()
		approach.clear()
		destination_revision = 0

	func is_bound() -> bool:
		"""True when both endpoints name a place and the owner declared a destination revision."""
		return work.is_bound() and approach.is_bound() and destination_revision > 0

	func owner_ref() -> Vector2i:
		"""The owning entity reference; both endpoints always carry the same owner."""
		return work.owner_ref()


# --- static navigation map, systems_architecture.md 2.3 "Static navigation map" ------------------

var _walkable: PackedByteArray = PackedByteArray()
var _layer: PackedByteArray = PackedByteArray()
var _terrain: PackedInt32Array = PackedInt32Array()
var _height_units: PackedInt32Array = PackedInt32Array()
var _clearance: PackedInt32Array = PackedInt32Array()

var _map_revision: int = FIRST_MAP_REVISION
var _walkable_count: int = 0
var _clearance_dirty: bool = false
var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Allocate the five static map columns once and derive them from world_init.gd's terrain."""
	_walkable.resize(CELL_COUNT)
	_layer.resize(CELL_COUNT)
	_terrain.resize(CELL_COUNT)
	_height_units.resize(CELL_COUNT)
	_clearance.resize(CELL_COUNT)
	_layer.fill(LAYER_SURFACE)
	rebuild_static_legality()


func rebuild_static_legality() -> void:
	"""Rederive walkability, terrain, height and clearance from the authored terrain masks."""
	_fill_from_terrain()
	_recompute_clearance()


func _fill_from_terrain() -> void:
	"""Expand world_init.gd's 128x128 tile masks into the 512x512 cell columns, 4x4 cells a tile.

	Evaluated ONCE PER TILE rather than once per cell: the masks are tile-resolution, so a
	per-cell call would run the same predicates sixteen times for the same answer.
	"""
	var walkable_total: int = 0
	for tile_z: int in WorldInit.MAP_TILES_Z:
		for tile_x: int in WorldInit.MAP_TILES_X:
			var terrain: int = WorldInit.terrain_of(tile_x, tile_z)
			var height: int = WorldInit.elevation_y_units_of(tile_x, tile_z)
			var walkable: int = 1 if WorldInit.is_walkable(tile_x, tile_z) else 0
			walkable_total += walkable * CELLS_PER_TILE * CELLS_PER_TILE
			_fill_tile_block(tile_x, tile_z, walkable, terrain, height)
	_walkable_count = walkable_total


func _fill_tile_block(tile_x: int, tile_z: int, walkable: int, terrain: int, height: int) -> void:
	"""Write one tile's answers into the 4x4 navigation cells it covers."""
	var first_x: int = tile_x * CELLS_PER_TILE
	for offset_z: int in CELLS_PER_TILE:
		var row: int = (tile_z * CELLS_PER_TILE + offset_z) * CELLS_X + first_x
		for offset_x: int in CELLS_PER_TILE:
			var cell: int = row + offset_x
			_walkable[cell] = walkable
			_terrain[cell] = terrain
			_height_units[cell] = height


func _recompute_clearance() -> void:
	"""`_clearance[c]` = side of the largest all-passable square with `c` as its north-west corner.

	One reverse scan: a k-square at `c` exists exactly when `c` is passable and the three squares
	at east, south and south-east all reach k-1. Cells on the last row or column can only ever
	hold a 1-square. This is map geometry only -- see the header on why no profile value lives here.
	"""
	for cell: int in range(CELL_COUNT - 1, -1, -1):
		if _walkable[cell] == 0:
			_clearance[cell] = 0
			continue
		var x: int = cell % CELLS_X
		var z: int = cell / CELLS_X
		if x == CELLS_X - 1 or z == CELLS_Z - 1:
			_clearance[cell] = 1
			continue
		var east: int = _clearance[cell + 1]
		var south: int = _clearance[cell + CELLS_X]
		var south_east: int = _clearance[cell + CELLS_X + 1]
		var smallest: int = east if east < south else south
		if south_east < smallest:
			smallest = south_east
		_clearance[cell] = 1 + smallest


# --- geometry helpers ---------------------------------------------------------------------------

static func is_cell(cell: int) -> bool:
	"""True when `cell` is a legal cell index. A predicate, never a refusal channel."""
	return cell >= 0 and cell < CELL_COUNT


static func is_cell_coord(x: int, z: int) -> bool:
	"""True when `(x, z)` is inside the 512x512 cell grid."""
	return x >= 0 and x < CELLS_X and z >= 0 and z < CELLS_Z


static func cell_x_of(cell: int) -> int:
	"""The X coordinate of a cell index. Caller checks `is_cell()` first."""
	return cell % CELLS_X


static func cell_z_of(cell: int) -> int:
	"""The Z coordinate of a cell index. Caller checks `is_cell()` first."""
	return cell / CELLS_X


static func macro_of(cell: int) -> int:
	"""ARCH-PATH-003's macro cell containing `cell`. Caller checks `is_cell()` first."""
	return (cell / CELLS_X / MACRO_CELLS) * MACROS_X + (cell % CELLS_X) / MACRO_CELLS


static func macro_first_cell(macro_id: int) -> int:
	"""The north-west cell of a macro cell. Caller checks `0 <= macro_id < MACRO_COUNT` first."""
	return (macro_id / MACROS_X) * MACRO_CELLS * CELLS_X + (macro_id % MACROS_X) * MACRO_CELLS


static func cell_centre_x_units(cell: int) -> int:
	"""The X centre of a cell in GDD 4.2's 1/1024 m units. Caller checks `is_cell()` first."""
	return (cell % CELLS_X) * CELL_SIZE_UNITS + CELL_CENTRE_OFFSET_UNITS


static func cell_centre_z_units(cell: int) -> int:
	"""The Z centre of a cell in GDD 4.2's 1/1024 m units. Caller checks `is_cell()` first."""
	return (cell / CELLS_X) * CELL_SIZE_UNITS + CELL_CENTRE_OFFSET_UNITS


func cell_index_into(x: int, z: int, out: IntMath.IntResult) -> bool:
	"""ARCH-PATH-001's `cell ID = z*512+x`, refusing an out-of-grid coordinate explicitly."""
	if not is_cell_coord(x, z):
		_last_refusal = REFUSE_INVALID_COORD
		return out.refuse(REFUSE_INVALID_COORD)
	_last_refusal = REFUSE_NONE
	return out.succeed(z * CELLS_X + x)


func cell_of_position_into(x_units: int, z_units: int, out: IntMath.IntResult) -> bool:
	"""The cell containing an authoritative 1/1024 m position, refusing a position off the map."""
	if x_units < 0 or z_units < 0:
		_last_refusal = REFUSE_INVALID_POSITION
		return out.refuse(REFUSE_INVALID_POSITION)
	var x: int = x_units / CELL_SIZE_UNITS
	var z: int = z_units / CELL_SIZE_UNITS
	if not is_cell_coord(x, z):
		_last_refusal = REFUSE_INVALID_POSITION
		return out.refuse(REFUSE_INVALID_POSITION)
	_last_refusal = REFUSE_NONE
	return out.succeed(z * CELLS_X + x)


# --- static legality readers --------------------------------------------------------------------

func is_walkable_cell(cell: int) -> bool:
	"""True when the authored terrain makes this cell navigable at all. False for any bad index."""
	return is_cell(cell) and _walkable[cell] == 1


func is_ford_cell(cell: int) -> bool:
	"""True on GDD 5.1's natural ford -- river tiles z=48..51, walkable and NOT a fishing work tile.

	The ford is why the baseline map is one connected walkable component: the river x=76..78 cuts
	it in two everywhere else. `world_init.gd` owns both halves of that fact and is read, not
	copied: this asks it whether the tile under the cell is the ford.
	"""
	if not is_cell(cell):
		return false
	return WorldInit.is_ford(cell % CELLS_X / CELLS_PER_TILE, cell / CELLS_X / CELLS_PER_TILE)


func cell_passes_clearance(cell: int, clearance_class: int) -> bool:
	"""True when the map geometry at `cell` admits a body of the CALLER-SUPPLIED clearance class."""
	if not is_cell(cell) or clearance_class < MIN_CLEARANCE_CLASS:
		return false
	if _clearance_dirty:
		_ensure_clearance()
	return _clearance[cell] >= clearance_class


func clearance_into(cell: int, out: IntMath.IntResult) -> bool:
	"""The largest passable square side at `cell`, in half-metre cells, or an explicit refusal."""
	if not is_cell(cell):
		_last_refusal = REFUSE_INVALID_CELL
		return out.refuse(REFUSE_INVALID_CELL)
	_ensure_clearance()
	_last_refusal = REFUSE_NONE
	return out.succeed(_clearance[cell])


func terrain_into(cell: int, out: IntMath.IntResult) -> bool:
	"""The world_init.gd terrain ordinal under `cell`, or an explicit refusal."""
	if not is_cell(cell):
		_last_refusal = REFUSE_INVALID_CELL
		return out.refuse(REFUSE_INVALID_CELL)
	_last_refusal = REFUSE_NONE
	return out.succeed(_terrain[cell])


func height_units_into(cell: int, out: IntMath.IntResult) -> bool:
	"""The authored surface height under `cell` in 1/1024 m units, or an explicit refusal."""
	if not is_cell(cell):
		_last_refusal = REFUSE_INVALID_CELL
		return out.refuse(REFUSE_INVALID_CELL)
	_last_refusal = REFUSE_NONE
	return out.succeed(_height_units[cell])


func layer_of(cell: int) -> int:
	"""The declared layer of a cell, or -1 off the map. Every baseline cell is LAYER_SURFACE."""
	if not is_cell(cell):
		return -1
	return _layer[cell]


func walkable_cell_count() -> int:
	"""How many of the 262144 cells the authored terrain makes navigable."""
	return _walkable_count


func lowest_passable_cell_in_macro(macro_id: int, clearance_class: int) -> int:
	"""ARCH-PATH-003's canonical macro anchor: the LOWEST cell ID in the macro passing clearance.

	Returns -1 when the macro admits no such cell. That is an ABSENCE, not a failure code: the
	caller's next step -- an exact-start search -- is a legitimate outcome, not an error path.
	"""
	if macro_id < 0 or macro_id >= MACRO_COUNT or clearance_class < MIN_CLEARANCE_CLASS:
		return -1
	_ensure_clearance()
	var first: int = macro_first_cell(macro_id)
	for row: int in MACRO_CELLS:
		var base: int = first + row * CELLS_X
		for column: int in MACRO_CELLS:
			var cell: int = base + column
			if _walkable[cell] == 1 and _clearance[cell] >= clearance_class:
				return cell
	return -1


# --- ground location identity -------------------------------------------------------------------

func current_map_revision() -> int:
	"""The revision every location minted right now carries. Positive, monotonic, never wrapped."""
	return _map_revision


func bind_ground_location(out: Location, cell: int, owner: Vector2i) -> bool:
	"""Fill `out` with a ground contact at `cell` owned by `owner`, or refuse explicitly.

	The owner is mandatory and may not be the null reference: READY_07 1.2 requires public APIs to
	carry a generation-safe contact owner rather than assume an X/Z pair identifies a destination.
	Whether that owner is still LIVE is the directory's question, asked by `navigation.gd` at
	submit and again at service; this call only records the pair.
	"""
	if not is_cell(cell):
		_last_refusal = REFUSE_INVALID_CELL
		return false
	if owner.x < 0:
		_last_refusal = REFUSE_NULL_OWNER
		return false
	out.domain = DOMAIN_GROUND
	out.layer = LAYER_SURFACE
	out.revision = _map_revision
	out.cell = cell
	out.owner_slot = owner.x
	out.owner_generation = owner.y
	_last_refusal = REFUSE_NONE
	return true


func location_is_current(location: Location) -> bool:
	"""True when `location` still names a contracted, in-bounds ground cell at the CURRENT revision."""
	if location.domain != DOMAIN_GROUND or location.layer != LAYER_SURFACE:
		return false
	if location.revision != _map_revision:
		return false
	return is_cell(location.cell)


func bind_ground_contact(
	out: Contact, work_cell: int, approach_cell: int, owner: Vector2i, destination_revision: int
) -> bool:
	"""Fill `out` with a work/service destination, or refuse explicitly and leave it unbound.

	Every check runs before anything is written, so a refused bind never leaves a half-filled
	contact that a later `is_bound()` would accept. The approach cell must be walkable -- a contact
	a body cannot legally stand at is not a destination -- while the work cell need only exist,
	because building interiors and water work points are not required to be navigable ground.
	"""
	out.clear()
	if destination_revision < FIRST_DESTINATION_REVISION:
		_last_refusal = REFUSE_CONTACT_REVISION
		return false
	if not is_cell(work_cell) or not is_cell(approach_cell):
		_last_refusal = REFUSE_INVALID_CELL
		return false
	if not is_walkable_cell(approach_cell):
		_last_refusal = REFUSE_CONTACT_APPROACH
		return false
	if not bind_ground_location(out.work, work_cell, owner):
		out.clear()
		return false
	if not bind_ground_location(out.approach, approach_cell, owner):
		out.clear()
		return false
	out.destination_revision = destination_revision
	_last_refusal = REFUSE_NONE
	return true


func contact_is_current(contact: Contact) -> bool:
	"""True when both of a bound contact's endpoints still name cells at the CURRENT map revision.

	Says nothing about the owner being alive or the destination revision still being the admitted
	one. Those are two separate questions, asked by two separate callers, and merging them would
	hide which of the three went stale.
	"""
	if not contact.is_bound():
		return false
	return location_is_current(contact.work) and location_is_current(contact.approach)


func domain_is_contracted(domain: int) -> bool:
	"""True only for DOMAIN_GROUND. Every other domain waits on the MOVE-G01 parameter pack."""
	return domain == DOMAIN_GROUND


func layer_is_contracted(layer: int) -> bool:
	"""True only for LAYER_SURFACE. One floor is not a substitute for multilevel scope."""
	return layer == LAYER_SURFACE


func refuse_uncontracted(domain: int, layer: int) -> StringName:
	"""The refusal a caller must raise for an out-of-contract domain/layer, or REFUSE_NONE."""
	if not domain_is_contracted(domain):
		return REFUSE_DOMAIN
	if not layer_is_contracted(layer):
		return REFUSE_LAYER
	return REFUSE_NONE


# --- the one legality mutator this slice contracts -----------------------------------------------

func override_static_legality(cell: int, walkable: bool) -> bool:
	"""Force one cell's static legality and publish a NEW map revision, or refuse explicitly.

	SCOPE, STATED RATHER THAN IMPLIED: this is the baseline fixture's ONLY legality mutator. It is
	whole-map, immediate and non-transactional, so it is sufficient to exercise ARCH-PATH-005's
	revision invalidation and nothing more. The production edit path -- a bounded overlay on the
	committed topology, reserve, evaluate, stage, publish together at a tick boundary, with
	occupied-exit refusal -- is `topology_edits.gd` under task 05.6 and is NOT implemented here.
	Refusing revision exhaustion instead of wrapping is SET-MOVE-001 2's rule; see MAX_MAP_REVISION.
	"""
	if not is_cell(cell):
		_last_refusal = REFUSE_INVALID_CELL
		return false
	if _map_revision >= MAX_MAP_REVISION:
		_last_refusal = REFUSE_REVISION_EXHAUSTED
		return false
	var value: int = 1 if walkable else 0
	if _walkable[cell] != value:
		_walkable_count += 1 if walkable else -1
	_walkable[cell] = value
	_map_revision += 1
	_clearance_dirty = true
	_last_refusal = REFUSE_NONE
	return true


func _ensure_clearance() -> void:
	"""Rebuild the clearance column if a legality override has invalidated it.

	Deferred rather than immediate so that carving N cells costs ONE 262144-cell pass instead of N.
	The revision is still advanced by each override, so no route survives an edit it did not see;
	only the derived column is lazy, and no reader can observe the stale version.
	"""
	if not _clearance_dirty:
		return
	_clearance_dirty = false
	_recompute_clearance()


func last_refusal() -> StringName:
	"""The refusal code from the most recent refusing call, or REFUSE_NONE after a success."""
	return _last_refusal


# --- §1 WORLD block: capture, local validation, cross-check and restore --------------------------
#
# R-WORLD-S1-001 §6 S1-SPATIAL_WORLD. Section 1's `spatial_world` block is owner schema 1,
# primary_count 262144 and a 2621484-byte payload in this ordinal order: `_map_revision` as a
# ONE-ELEMENT i32 field, then `_walkable` and `_layer` as u8 cell columns and `_terrain` and
# `_height_units` as i32 cell columns. The primary count is the CELL extent even though the first
# field is a scalar; each field's own element count is what fixes its extent on the wire.
#
# EVERY CELL IS WRITTEN, INCLUDING THE BLOCKED ONES. A blocked cell is state, not absence.
#
# RESTORE MUST NOT REBUILD WALKABILITY FROM AUTHORED TERRAIN. `override_static_legality()` above
# legitimately changes a cell's legality and advances the revision, so the live map is NOT a
# function of `world_init.gd`'s authored masks and "equals the authored value" is not a valid
# load check. `restore_section_1_columns()` therefore installs the STORED columns and then
# rebuilds only what is genuinely derived from them -- `_walkable_count` and `_clearance` --
# rather than calling `rebuild_static_legality()`, which would overwrite stored legality with the
# authored answer and silently discard every edit the saved world had made.
#
# `_clearance` IS NOT PERSISTED AND MUST NOT BE. It is a pure function of `_walkable`, recomputed
# here by the same `_recompute_clearance()` the live store uses, so there is exactly one
# implementation of that geometry and a restored map cannot disagree with an edited one.
#
# THE REVISION DOMAIN STAYS i32. R-WORLD-S1-001 forbids widening it to i64 at this boundary;
# `MAX_MAP_REVISION` is already `IntMath.INT32_MAX` and exhaustion refuses rather than wrapping.

## Section 1's owner key, schema version and declared primary row extent for this block.
const SECTION_1_OWNER_KEY: String = "spatial_world"
const SECTION_1_OWNER_SCHEMA_VERSION: int = 1
const SECTION_1_PRIMARY_COUNT: int = CELL_COUNT

## The baseline terrain domain, read from its owner rather than mirrored as a number here.
const TERRAIN_ID_COUNT: int = WorldInit.TERRAIN_COUNT

const COLUMN_REFUSE_NONE: StringName = &""
const COLUMN_REFUSE_SHAPE: StringName = &"S1_SPATIAL_COLUMN_SHAPE"
const COLUMN_REFUSE_REVISION: StringName = &"S1_SPATIAL_REVISION_RANGE"
const COLUMN_REFUSE_WALKABLE_FLAG: StringName = &"S1_SPATIAL_WALKABLE_FLAG"
const COLUMN_REFUSE_LAYER: StringName = &"S1_SPATIAL_LAYER_NOT_CONTRACTED"
const COLUMN_REFUSE_TERRAIN: StringName = &"S1_SPATIAL_TERRAIN_RANGE"
const COLUMN_REFUSE_HEIGHT: StringName = &"S1_SPATIAL_HEIGHT_RANGE"
const COLUMN_REFUSE_DERIVED: StringName = &"S1_SPATIAL_DERIVED_DISAGREES"

## Code and detail behind the most recent §1 column refusal. Both empty after an accepted call.
var _section_1_code: StringName = COLUMN_REFUSE_NONE
var _section_1_detail: String = ""


func section_1_code() -> StringName:
	"""The code of the last §1 column refusal, or COLUMN_REFUSE_NONE."""
	return _section_1_code


func section_1_detail() -> String:
	"""Human-readable detail behind the last §1 column refusal, or an empty string."""
	return _section_1_detail


func section_1_map_revision() -> int:
	"""The scalar this block's ordinal-0 field carries: the live map revision."""
	return _map_revision


func copy_section_1_columns_into(out_walkable: PackedByteArray, out_layer: PackedByteArray,
		out_terrain: PackedInt32Array, out_height_units: PackedInt32Array) -> bool:
	"""Snapshot the four saved cell columns into caller-owned buffers already CELL_COUNT long."""
	if not _section_1_sized(_walkable, _layer, _terrain, _height_units, "the live columns"):
		return false
	if not _section_1_sized(out_walkable, out_layer, out_terrain, out_height_units,
			"the destination buffers"):
		return false
	out_walkable.clear()
	out_walkable.append_array(_walkable)
	out_layer.clear()
	out_layer.append_array(_layer)
	out_terrain.clear()
	out_terrain.append_array(_terrain)
	out_height_units.clear()
	out_height_units.append_array(_height_units)
	_section_1_accept()
	return true


func _section_1_sized(walkable: PackedByteArray, layer: PackedByteArray,
		terrain: PackedInt32Array, height_units: PackedInt32Array, role: String) -> bool:
	"""True when all four cell columns are exactly CELL_COUNT long; records a detail when not."""
	if (walkable.size() == CELL_COUNT and layer.size() == CELL_COUNT
			and terrain.size() == CELL_COUNT and height_units.size() == CELL_COUNT):
		return true
	return _refuse_section_1(COLUMN_REFUSE_SHAPE, "%s are %d/%d/%d/%d entries, not %d each"
		% [role, walkable.size(), layer.size(), terrain.size(), height_units.size(), CELL_COUNT])


func section_1_local_refusal(map_revision: int, walkable: PackedByteArray,
		layer: PackedByteArray, terrain: PackedInt32Array,
		height_units: PackedInt32Array) -> StringName:
	"""S1-SPATIAL_WORLD local domains over the scalar and all 262144 cells of each column."""
	if map_revision < FIRST_MAP_REVISION or map_revision > MAX_MAP_REVISION:
		_refuse_section_1(COLUMN_REFUSE_REVISION, "map revision %d outside %d..%d"
			% [map_revision, FIRST_MAP_REVISION, MAX_MAP_REVISION])
		return COLUMN_REFUSE_REVISION
	if not _section_1_sized(walkable, layer, terrain, height_units, "the columns"):
		return COLUMN_REFUSE_SHAPE
	for cell: int in CELL_COUNT:
		if walkable[cell] > 1:
			return _refuse_section_1_code(COLUMN_REFUSE_WALKABLE_FLAG,
				"cell %d walkable flag is %d, not 0 or 1" % [cell, walkable[cell]])
		if layer[cell] != LAYER_SURFACE:
			return _refuse_section_1_code(COLUMN_REFUSE_LAYER,
				"cell %d layer is %d; only %d is contracted" % [cell, layer[cell], LAYER_SURFACE])
		if terrain[cell] < 0 or terrain[cell] >= TERRAIN_ID_COUNT:
			return _refuse_section_1_code(COLUMN_REFUSE_TERRAIN,
				"cell %d terrain id %d outside 0..%d" % [cell, terrain[cell], TERRAIN_ID_COUNT - 1])
		if height_units[cell] < IntMath.INT32_MIN or height_units[cell] > IntMath.INT32_MAX:
			return _refuse_section_1_code(COLUMN_REFUSE_HEIGHT,
				"cell %d height %d is not an i32" % [cell, height_units[cell]])
	_section_1_accept()
	return COLUMN_REFUSE_NONE


func section_1_cross_check_refusal() -> StringName:
	"""The two DERIVED members must agree with the installed columns, cell for cell.

	This is not a save field check: `_walkable_count` and `_clearance` are rebuilt on restore, so
	what this proves is that the rebuild actually ran and produced the same answers the live store
	would. A restore that installed columns and forgot the rebuild fails here.
	"""
	var walkable_total: int = 0
	for cell: int in CELL_COUNT:
		walkable_total += _walkable[cell]
	if walkable_total != _walkable_count:
		return _refuse_section_1_code(COLUMN_REFUSE_DERIVED,
			"the column holds %d walkable cells against a count of %d"
				% [walkable_total, _walkable_count])
	if _clearance_dirty:
		return _refuse_section_1_code(COLUMN_REFUSE_DERIVED,
			"clearance is still marked dirty after a restore")
	for cell: int in CELL_COUNT:
		if _walkable[cell] == 0 and _clearance[cell] != 0:
			return _refuse_section_1_code(COLUMN_REFUSE_DERIVED,
				"blocked cell %d carries clearance %d" % [cell, _clearance[cell]])
		if _walkable[cell] == 1 and _clearance[cell] < MIN_CLEARANCE_CLASS:
			return _refuse_section_1_code(COLUMN_REFUSE_DERIVED,
				"passable cell %d carries clearance %d" % [cell, _clearance[cell]])
	_section_1_accept()
	return COLUMN_REFUSE_NONE


func restore_section_1_columns(map_revision: int, walkable: PackedByteArray,
		layer: PackedByteArray, terrain: PackedInt32Array,
		height_units: PackedInt32Array) -> bool:
	"""Install the validated stored map, then rebuild ONLY `_walkable_count` and `_clearance`."""
	if section_1_local_refusal(map_revision, walkable, layer, terrain,
			height_units) != COLUMN_REFUSE_NONE:
		return false
	_walkable = walkable.duplicate()
	_layer = layer.duplicate()
	_terrain = terrain.duplicate()
	_height_units = height_units.duplicate()
	_map_revision = map_revision
	var walkable_total: int = 0
	for cell: int in CELL_COUNT:
		walkable_total += _walkable[cell]
	_walkable_count = walkable_total
	_clearance_dirty = false
	_recompute_clearance()
	_section_1_accept()
	return true


func _section_1_accept() -> void:
	"""Clear the recorded §1 refusal, so a stale code cannot be read after an accepted call."""
	_section_1_code = COLUMN_REFUSE_NONE
	_section_1_detail = ""


func _refuse_section_1(code: StringName, detail: String) -> bool:
	"""Record one §1 column refusal and return false, so callers can `return` it."""
	_section_1_code = code
	_section_1_detail = "%s: %s" % [code, detail]
	return false


func _refuse_section_1_code(code: StringName, detail: String) -> StringName:
	"""Record one §1 column refusal and hand the code straight back to a `return`."""
	_section_1_code = code
	_section_1_detail = "%s: %s" % [code, detail]
	return code
