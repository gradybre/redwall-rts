extends RefCounted
## SAVE-CLAIM-CHECK-R01 v2 / decision 0168: the READ-ONLY section 7 resource claim checker.
##
## It compares the exact section 7 `fishing` and `forage` claim blocks with caller-owned immutable
## projections of saved section 4 state, a section 3 Directory record and section 1's next-PID
## cursor. It proves the CONSISTENCY OF THE VALUES SUPPLIED and nothing about their file origin.
##
## ## What this module is not
##
## It is not a loader, not a coordinator and not an activation. It performs no await, callback,
## dispatch, live store access, rebind, persistence I/O, tick, allocator admission or borrowed
## binding, and it never instantiates a live store or calls a store mutator. Preloading the
## owning scripts for their immutable constants and their pure static shape gates is exactly that:
## a script dependency, not a runtime read of a live world.
##
## It REPAIRS NOTHING. No amount is trimmed, no aggregate rebuilt, no ordering key refreshed, no
## quota reconciled, no claim purged or released. The legacy `validate`/`rebuild_effort_aggregates`
## /`rebuild_reservation_aggregates` helpers are deliberately never called: they mutate counts,
## scratch or canonical data, and so cannot validate the state they repair.
##
## SAVE-CLAIM-WORLD-BINDING owns the production projection from a complete decoded file, actual
## descriptor version checks, file/world identity and coordinator invocation before publication.
## That task remains a blocking dependency of final SAVE-CAPTURE/activation. This checker alone
## may never mark release_save_ready, SAVE-CAPTURE, SAVE-ORCHESTRATOR or first-playable complete.
## No opaque binding token is invented here: a made-up token would not prove common provenance.
##
## ## The projection interface
##
## `Components` is a deliberately bounded NEW interface, not a claim that the absent section 4
## codec already exposes one. It holds three caller-owned records, every array at its full
## compiled extent, with no variable-size admission, no Dictionary and no `Object.get` property
## access. There is no per-entity object. The omitted section 4/5 fields remain the full owner's
## structural/semantic validator's responsibility; this projection does not validate a complete
## owner record and does not pretend to.
##
##   * FishComponents     544 bytes
##   * ForageComponents  8960 bytes
##   * JobComponents   139264 bytes
##   * total value payload 148768 bytes of caller-owned cold scratch.
##
## ## Allocation bound
##
## One private `SaveSectionDirectory.Derived` costs 1409816 packed bytes; the two int64 total
## columns here cost 32*8 + 128*8 = 1280. The Directory validator also duplicates `_generation`
## and `_persistent_id` for sorting, 1409672 each; those are sequential function locals, but this
## call conservatively charges BOTH: 1409816 + 1280 + 2*1409672 = 4230440 private packed bytes,
## plus the caller's 148768 projection and the already-owned input records. That is a conservative
## bound, not measured RSS; native objects, `Array[int]` wrappers, Refusal objects and detail
## strings are separately unmeasured. There is no clone of the whole Directory record, no copy of
## the claim arrays, no second mutable world and no new resident budget. The validator's two
## permitted single-column copies are not the prohibited full-record clone.
##
## ## Refusal discipline
##
## Every supplied byte and all caller state is unchanged on success AND on refusal. A `Result` is
## new per call and is stored on no owner. On refusal every count is zero -- partial counts are
## never published -- and `owner`/`row_space`/`row` localize the FIRST offending claim or component
## row; a preflight refusal uses empty owner/row_space and row -1. Underlying Directory and codec
## refusals keep their EXACT code and detail.
##
## ## Stale is diagnostic, not a deferral list
##
## A dead owning Job/Expedition pair is preserved and counted. The exact retained claim is already
## the state the normal purge/release methods scan, so no new persistent deferral list or flag is
## introduced, and this checker must never call cleanup on load. Ensuring cleanup resumes in the
## same ordinary stage as an uninterrupted world belongs to WORLD-BINDING and normal gameplay
## integration.
##
## NO FLOAT. ARCH-AUTH-002; every value here is an integer, and every accumulation is checked.

const SaveSectionDirectory := preload("res://scripts/core/save_section_directory.gd")
const SaveSectionInventories := preload("res://scripts/core/save_section_inventories.gd")
const SaveResourceClaims := preload("res://scripts/core/save_resource_claims_restore.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

# --- identity constants, read from their owners rather than restated ---------------------------

const DIRECTORY_CAPACITY: int = EntityDirectoryScript.DIRECTORY_CAPACITY
const KIND_EXPEDITION: int = EntityDirectoryScript.KIND_EXPEDITION
const KIND_FISH_HABITAT: int = EntityDirectoryScript.KIND_FISH_HABITAT
const KIND_HARVEST_ZONE: int = EntityDirectoryScript.KIND_HARVEST_ZONE
const KIND_JOB: int = EntityDirectoryScript.KIND_JOB
const NULL_SLOT: int = EntityDirectoryScript.NULL_SLOT
const NULL_GENERATION: int = EntityDirectoryScript.NULL_GENERATION
const MAX_INT32: int = EntityDirectoryScript.MAX_INT32
const PERSISTENT_ID_MIN: int = EntityDirectoryScript.PERSISTENT_ID_MIN
const PERSISTENT_ID_EXHAUSTED: int = EntityDirectoryScript.PERSISTENT_ID_EXHAUSTED

## Habitat rows: `fishing.gd`'s own compiled habitat table, which is KIND_CAPACITY[fish_habitat].
const HABITAT_ROWS: int = FishingScript.FISH_HABITAT_CAPACITY
## Fishing claim rows, indexed by the owning Expedition's typed row, so this is also the
## Expedition typed-row capacity (KIND_CAPACITY[expedition]).
const FISHING_CLAIM_ROWS: int = FishingScript.FISHING_EFFORT_CLAIM_CAPACITY
const EXPEDITION_ROWS: int = FISHING_CLAIM_ROWS
## Forage claim rows, indexed by the owning Job's typed row, so this is also the Job typed-row
## capacity (KIND_CAPACITY[job]).
const FORAGE_CLAIM_ROWS: int = ForageScript.FORAGE_CLAIM_CAPACITY
const JOB_ROWS: int = FORAGE_CLAIM_ROWS
## Harvest zone rows use the owner's existing constant and are cross-checked against
## the Directory kind table in the extent gate; a drift refuses rather than mis-indexing.
const ZONE_ROWS: int = ForageScript.HARVEST_ZONE_CAPACITY
const PATCHES_PER_ZONE: int = ForageScript.PATCHES_PER_ZONE
const PATCH_ROWS: int = ZONE_ROWS * PATCHES_PER_ZONE

## The accepted owner quantity bounds, from the existing sources and not from guessed quota math.
## Forage: `forage.gd`'s MANUAL_QUOTA_MAX_MILLI under accepted SAVE-CLAIMS-R01 v2. Fishing: the
## largest entry of EFFORT_SLOTS_BY_TYPE, computed by `_max_effort_capacity()` with int locals.
const FORAGE_QUANTITY_MIN: int = 1
const FORAGE_QUANTITY_MAX: int = ForageScript.MANUAL_QUOTA_MAX_MILLI
const FISHING_QUANTITY_MIN: int = 1

# --- new checker-specific refusal codes ---------------------------------------------------------

const CLAIM_CHECK_NULL: StringName = &"CLAIM_CHECK_NULL"
const CLAIM_CHECK_SHAPE: StringName = &"CLAIM_CHECK_SHAPE"
const CLAIM_CHECK_CURSOR: StringName = &"CLAIM_CHECK_CURSOR"
const CLAIM_CHECK_COMPONENT: StringName = &"CLAIM_CHECK_COMPONENT"
const CLAIM_CHECK_IDENTITY: StringName = &"CLAIM_CHECK_IDENTITY"
const CLAIM_CHECK_FUTURE_REF: StringName = &"CLAIM_CHECK_FUTURE_REF"
const CLAIM_CHECK_ECOLOGY: StringName = &"CLAIM_CHECK_ECOLOGY"
const CLAIM_CHECK_PROVENANCE: StringName = &"CLAIM_CHECK_PROVENANCE"
const CLAIM_CHECK_QUANTITY: StringName = &"CLAIM_CHECK_QUANTITY"
const CLAIM_CHECK_OVERFLOW: StringName = &"CLAIM_CHECK_OVERFLOW"
const CLAIM_CHECK_TOTAL: StringName = &"CLAIM_CHECK_TOTAL"

## Owner and row-space spellings a refusal localizes itself with.
const OWNER_NONE: StringName = &""
const OWNER_FISHING: StringName = &"fishing"
const OWNER_FORAGE: StringName = &"forage"
const OWNER_JOBS: StringName = &"jobs"
const SPACE_NONE: StringName = &""
const SPACE_HABITAT: StringName = &"habitat"
const SPACE_ZONE: StringName = &"zone"
const SPACE_PATCH: StringName = &"patch"
const SPACE_JOB: StringName = &"job"
const SPACE_CLAIM: StringName = &"claim"
const SPACE_DIRECTORY_SLOT: StringName = &"directory_slot"
const NO_ROW: int = -1

## Classification of one saved owner (Job/Expedition) pair against the Directory slot it names.
const PAIR_FUTURE: int = 0
const PAIR_STALE: int = 1
const PAIR_LIVE: int = 2


class FishComponents:
	"""The saved per-habitat projection: occupancy, self reference and the effort ledger.

	There is no Expedition component and none is invented. `habitat_effort_slots` may retain a
	prior valid capacity on an inactive row after an ordinary `destroy_habitat()`, so 0..max is
	accepted there and nothing is normalized.
	"""
	var habitat_present: PackedByteArray = PackedByteArray()
	var habitat_ref_slot: PackedInt32Array = PackedInt32Array()
	var habitat_ref_generation: PackedInt32Array = PackedInt32Array()
	var habitat_effort_slots: PackedInt32Array = PackedInt32Array()
	var habitat_effort_used: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate the five cold buffers once and set the exact blank row."""
		habitat_present.resize(HABITAT_ROWS)
		habitat_ref_slot.resize(HABITAT_ROWS)
		habitat_ref_generation.resize(HABITAT_ROWS)
		habitat_effort_slots.resize(HABITAT_ROWS)
		habitat_effort_used.resize(HABITAT_ROWS)
		habitat_present.fill(0)
		habitat_ref_slot.fill(NULL_SLOT)
		habitat_ref_generation.fill(NULL_GENERATION)
		habitat_effort_slots.fill(0)
		habitat_effort_used.fill(0)


class ForageComponents:
	"""The saved per-zone and per-patch projection.

	A zone's basin pair need NOT resolve when the zone carries no active claim: ordinary basin
	deletion leaves surviving designations with a stale basin reference. A patch belongs to the
	zone at `row / PATCHES_PER_ZONE`; a zone may own one patch or any subset, and all five are
	never required.
	"""
	var zone_present: PackedByteArray = PackedByteArray()
	var zone_ref_slot: PackedInt32Array = PackedInt32Array()
	var zone_ref_generation: PackedInt32Array = PackedInt32Array()
	var zone_basin_slot: PackedInt32Array = PackedInt32Array()
	var zone_basin_generation: PackedInt32Array = PackedInt32Array()
	var zone_quota_reserved_milli: PackedInt64Array = PackedInt64Array()
	var patch_present: PackedByteArray = PackedByteArray()
	var patch_zone_slot: PackedInt32Array = PackedInt32Array()
	var patch_zone_generation: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate the nine cold buffers once and set the exact blank zone and patch rows."""
		zone_present.resize(ZONE_ROWS)
		zone_ref_slot.resize(ZONE_ROWS)
		zone_ref_generation.resize(ZONE_ROWS)
		zone_basin_slot.resize(ZONE_ROWS)
		zone_basin_generation.resize(ZONE_ROWS)
		zone_quota_reserved_milli.resize(ZONE_ROWS)
		patch_present.resize(PATCH_ROWS)
		patch_zone_slot.resize(PATCH_ROWS)
		patch_zone_generation.resize(PATCH_ROWS)
		zone_present.fill(0)
		zone_ref_slot.fill(NULL_SLOT)
		zone_ref_generation.fill(NULL_GENERATION)
		zone_basin_slot.fill(NULL_SLOT)
		zone_basin_generation.fill(NULL_GENERATION)
		zone_quota_reserved_milli.fill(0)
		patch_present.fill(0)
		patch_zone_slot.fill(NULL_SLOT)
		patch_zone_generation.fill(NULL_GENERATION)


class JobComponents:
	"""The saved per-Job projection: occupancy, self reference and the creation tick.

	A dead owner's tick cannot be re-derived, so a claim preserves its own nonnegative saved
	value rather than guessing it from a reused row.
	"""
	var job_present: PackedByteArray = PackedByteArray()
	var job_ref_slot: PackedInt32Array = PackedInt32Array()
	var job_ref_generation: PackedInt32Array = PackedInt32Array()
	var created_tick: PackedInt64Array = PackedInt64Array()

	func _init() -> void:
		"""Allocate the four cold buffers once and set the exact blank row."""
		job_present.resize(JOB_ROWS)
		job_ref_slot.resize(JOB_ROWS)
		job_ref_generation.resize(JOB_ROWS)
		created_tick.resize(JOB_ROWS)
		job_present.fill(0)
		job_ref_slot.fill(NULL_SLOT)
		job_ref_generation.fill(NULL_GENERATION)
		created_tick.fill(0)


class Components:
	"""The three caller-owned projection records. The constructor creates all three."""
	var fish: FishComponents = null
	var forage: ForageComponents = null
	var jobs: JobComponents = null

	func _init() -> void:
		"""Allocate the whole 148768-byte projection once."""
		fish = FishComponents.new()
		forage = ForageComponents.new()
		jobs = JobComponents.new()


class Result:
	"""One checker outcome. New per call, stored on no owner, never partially published.

	On success `code` is the existing empty StringName `SaveHeader.REFUSE_NONE`, detail is empty,
	owner/row_space are empty, row is -1, and all five counts are computed. On refusal the counts
	stay zero and owner/row_space/row localize the first offending claim or component row.
	"""
	var code: StringName = SaveHeader.REFUSE_NONE
	var detail: String = ""
	var owner: StringName = OWNER_NONE
	var row_space: StringName = SPACE_NONE
	var row: int = NO_ROW
	var fishing_count: int = 0
	var forage_count: int = 0
	var stale_fishing_expeditions: int = 0
	var stale_fishing_jobs: int = 0
	var stale_forage_jobs: int = 0

	func is_ok() -> bool:
		"""True when nothing refused."""
		return code == SaveHeader.REFUSE_NONE


class Sums:
	"""The two private int64 total columns and the five per-call counters.

	The 32 + 128 int64 cells are the 1280 packed bytes the allocation bound charges. Nothing else
	is cached: no per-kind prefix table, no second reverse map and no copy of a claim column.
	"""
	var habitat_total: PackedInt64Array = PackedInt64Array()
	var zone_total: PackedInt64Array = PackedInt64Array()
	var fishing_count: int = 0
	var forage_count: int = 0
	var stale_fishing_expeditions: int = 0
	var stale_fishing_jobs: int = 0
	var stale_forage_jobs: int = 0

	func _init() -> void:
		"""Allocate both total columns at zero."""
		habitat_total.resize(HABITAT_ROWS)
		zone_total.resize(ZONE_ROWS)
		habitat_total.fill(0)
		zone_total.fill(0)


# --- the one entry point -------------------------------------------------------------------------

static func validate(directory: SaveSectionDirectory.Record, next_persistent_id: int,
		fishing: SaveSectionInventories.OwnerRecord, forage: SaveSectionInventories.OwnerRecord,
		components: Components) -> Result:
	"""Check one saved world's resource claims against its saved Directory, cursor and components.

	The caller supplies the SAME validated file's records and must prevent mutation throughout
	this synchronous call. Deterministic gate order, first failure wins: null participants
	including the three component subrecords; every component array extent; section 7 block
	identity/shape for Fishing then Forage; Directory structure then the cursor; section 7 codec
	owner domains for Fishing then Forage; all component local domains, live mirrors and the
	reverse Directory walk; active Fishing rows ascending; active Forage rows ascending; all
	Fishing aggregate rows ascending; all Forage aggregate rows ascending.
	"""
	var out: Result = Result.new()
	if not _null_gate(directory, fishing, forage, components, out):
		return out
	if not _extent_gate(components, out):
		return out
	if not _block_shape_gate(fishing, forage, out):
		return out
	var private_derived: SaveSectionDirectory.Derived = SaveSectionDirectory.Derived.new()
	var rebuilt: SaveHeader.Refusal = SaveSectionDirectory.rebuild_into(directory, private_derived)
	if not rebuilt.is_ok():
		_refuse_preflight(out, rebuilt.code, rebuilt.detail)
		return out
	if not _cursor_gate(directory, next_persistent_id, out):
		return out
	var fishing_domain: SaveHeader.Refusal = SaveSectionInventories.owner_refusal(fishing)
	if not fishing_domain.is_ok():
		_refuse_preflight(out, fishing_domain.code, fishing_domain.detail)
		return out
	var forage_domain: SaveHeader.Refusal = SaveSectionInventories.owner_refusal(forage)
	if not forage_domain.is_ok():
		_refuse_preflight(out, forage_domain.code, forage_domain.detail)
		return out
	if not _component_gate(directory, private_derived, components, out):
		return out
	var sums: Sums = Sums.new()
	var math: IntMath.IntResult = IntMath.IntResult.new()
	if not _fishing_claim_gate(directory, private_derived, fishing, components, sums, math, out):
		return out
	if not _forage_claim_gate(directory, private_derived, forage, next_persistent_id, components,
			sums, math, out):
		return out
	if not _fishing_total_gate(components.fish, sums, out):
		return out
	if not _forage_total_gate(components.forage, sums, out):
		return out
	return _succeed(out, sums)


# --- refusal plumbing ------------------------------------------------------------------------------

static func _refuse(out: Result, code: StringName, detail: String, owner: StringName,
		row_space: StringName, row: int) -> bool:
	"""Localize one refusal and return false. Counts are left at zero, never partially published."""
	out.code = code
	out.detail = detail
	out.owner = owner
	out.row_space = row_space
	out.row = row
	return false


static func _refuse_preflight(out: Result, code: StringName, detail: String) -> bool:
	"""A preflight refusal: empty owner and row space, row -1, underlying code/detail preserved."""
	return _refuse(out, code, detail, OWNER_NONE, SPACE_NONE, NO_ROW)


static func _succeed(out: Result, sums: Sums) -> Result:
	"""Publish the five computed counts. Reached only when every gate passed."""
	out.code = SaveHeader.REFUSE_NONE
	out.detail = ""
	out.owner = OWNER_NONE
	out.row_space = SPACE_NONE
	out.row = NO_ROW
	out.fishing_count = sums.fishing_count
	out.forage_count = sums.forage_count
	out.stale_fishing_expeditions = sums.stale_fishing_expeditions
	out.stale_fishing_jobs = sums.stale_fishing_jobs
	out.stale_forage_jobs = sums.stale_forage_jobs
	return out


# --- gate 1: null participants ---------------------------------------------------------------------

static func _null_gate(directory: SaveSectionDirectory.Record,
		fishing: SaveSectionInventories.OwnerRecord, forage: SaveSectionInventories.OwnerRecord,
		components: Components, out: Result) -> bool:
	"""Refuse a missing participant, including each of the three component subrecords."""
	if directory == null:
		return _refuse_preflight(out, CLAIM_CHECK_NULL, "no section 3 Directory record was supplied")
	if fishing == null:
		return _refuse_preflight(out, CLAIM_CHECK_NULL, "no section 7 fishing claim block was supplied")
	if forage == null:
		return _refuse_preflight(out, CLAIM_CHECK_NULL, "no section 7 forage claim block was supplied")
	if components == null:
		return _refuse_preflight(out, CLAIM_CHECK_NULL, "no component projection was supplied")
	if components.fish == null:
		return _refuse_preflight(out, CLAIM_CHECK_NULL, "the projection carries no fish subrecord")
	if components.forage == null:
		return _refuse_preflight(out, CLAIM_CHECK_NULL, "the projection carries no forage subrecord")
	if components.jobs == null:
		return _refuse_preflight(out, CLAIM_CHECK_NULL, "the projection carries no jobs subrecord")
	return true


# --- gate 2: component extents ---------------------------------------------------------------------

static func _extent_gate(components: Components, out: Result) -> bool:
	"""Every projection column must hold its full compiled extent before anything indexes it.

	The three typed-row capacities are also compared with the Directory's own KIND_CAPACITY, so a
	build whose compiled capacities drifted from these projection extents refuses instead of
	silently checking the wrong rows.
	"""
	if not _extent_ok(out, "KIND_CAPACITY[fish_habitat]",
			EntityDirectoryScript.KIND_CAPACITY[KIND_FISH_HABITAT], HABITAT_ROWS):
		return false
	if not _extent_ok(out, "KIND_CAPACITY[harvest_zone]",
			EntityDirectoryScript.KIND_CAPACITY[KIND_HARVEST_ZONE], ZONE_ROWS):
		return false
	if not _extent_ok(out, "KIND_CAPACITY[job]",
			EntityDirectoryScript.KIND_CAPACITY[KIND_JOB], JOB_ROWS):
		return false
	if not _extent_ok(out, "KIND_CAPACITY[expedition]",
			EntityDirectoryScript.KIND_CAPACITY[KIND_EXPEDITION], EXPEDITION_ROWS):
		return false
	var fish: FishComponents = components.fish
	if not _extent_ok(out, "habitat_present", fish.habitat_present.size(), HABITAT_ROWS):
		return false
	if not _extent_ok(out, "habitat_ref_slot", fish.habitat_ref_slot.size(), HABITAT_ROWS):
		return false
	if not _extent_ok(out, "habitat_ref_generation", fish.habitat_ref_generation.size(),
			HABITAT_ROWS):
		return false
	if not _extent_ok(out, "habitat_effort_slots", fish.habitat_effort_slots.size(), HABITAT_ROWS):
		return false
	if not _extent_ok(out, "habitat_effort_used", fish.habitat_effort_used.size(), HABITAT_ROWS):
		return false
	var zones: ForageComponents = components.forage
	if not _extent_ok(out, "zone_present", zones.zone_present.size(), ZONE_ROWS):
		return false
	if not _extent_ok(out, "zone_ref_slot", zones.zone_ref_slot.size(), ZONE_ROWS):
		return false
	if not _extent_ok(out, "zone_ref_generation", zones.zone_ref_generation.size(), ZONE_ROWS):
		return false
	if not _extent_ok(out, "zone_basin_slot", zones.zone_basin_slot.size(), ZONE_ROWS):
		return false
	if not _extent_ok(out, "zone_basin_generation", zones.zone_basin_generation.size(), ZONE_ROWS):
		return false
	if not _extent_ok(out, "zone_quota_reserved_milli", zones.zone_quota_reserved_milli.size(),
			ZONE_ROWS):
		return false
	if not _extent_ok(out, "patch_present", zones.patch_present.size(), PATCH_ROWS):
		return false
	if not _extent_ok(out, "patch_zone_slot", zones.patch_zone_slot.size(), PATCH_ROWS):
		return false
	if not _extent_ok(out, "patch_zone_generation", zones.patch_zone_generation.size(), PATCH_ROWS):
		return false
	var jobs: JobComponents = components.jobs
	if not _extent_ok(out, "job_present", jobs.job_present.size(), JOB_ROWS):
		return false
	if not _extent_ok(out, "job_ref_slot", jobs.job_ref_slot.size(), JOB_ROWS):
		return false
	if not _extent_ok(out, "job_ref_generation", jobs.job_ref_generation.size(), JOB_ROWS):
		return false
	return _extent_ok(out, "created_tick", jobs.created_tick.size(), JOB_ROWS)


static func _extent_ok(out: Result, label: String, actual: int, expected: int) -> bool:
	"""One extent comparison; refuses with CLAIM_CHECK_SHAPE at empty owner/space and row -1."""
	if actual == expected:
		return true
	return _refuse_preflight(out, CLAIM_CHECK_SHAPE,
		"component extent '%s' is %d, not the compiled %d" % [label, actual, expected])


# --- gate 3: section 7 block identity and shape ------------------------------------------------------

static func _block_shape_gate(fishing: SaveSectionInventories.OwnerRecord,
		forage: SaveSectionInventories.OwnerRecord, out: Result) -> bool:
	"""Reuse the existing pure resource-adapter shape statics: fishing first, then forage.

	Those statics already check the declared owner, the fixed primary count, the absent child
	extents and every column length, so there is no duplicate gate and no helper move in this
	lane. Their SAVE_CLAIMS_BLOCK_SHAPE code and detail are preserved exactly.
	"""
	var fishing_shape: SaveHeader.Refusal = SaveResourceClaims.fishing_block_shape_refusal(fishing)
	if not fishing_shape.is_ok():
		return _refuse_preflight(out, fishing_shape.code, fishing_shape.detail)
	var forage_shape: SaveHeader.Refusal = SaveResourceClaims.forage_block_shape_refusal(forage)
	if not forage_shape.is_ok():
		return _refuse_preflight(out, forage_shape.code, forage_shape.detail)
	return true


# --- gate 4b: the next-PID cursor --------------------------------------------------------------------

static func _cursor_gate(directory: SaveSectionDirectory.Record, next_persistent_id: int,
		out: Result) -> bool:
	"""The existing identity contract: 1..2147483648, strictly above every live persistent ID.

	The terminal value means exhausted and is a legal saved cursor. Nothing is installed into any
	live store; this reads the supplied record only. Live slots are walked through the packed
	`find()` jump, so the cost is the number of live rows and not the whole capacity.
	"""
	if next_persistent_id < PERSISTENT_ID_MIN or next_persistent_id > PERSISTENT_ID_EXHAUSTED:
		return _refuse_preflight(out, CLAIM_CHECK_CURSOR,
			"next persistent id %d is outside %d..%d"
				% [next_persistent_id, PERSISTENT_ID_MIN, PERSISTENT_ID_EXHAUSTED])
	var slot: int = directory.active.find(1, 0)
	while slot >= 0:
		if directory.persistent_id[slot] >= next_persistent_id:
			return _refuse_preflight(out, CLAIM_CHECK_CURSOR,
				"live slot %d holds persistent id %d, not below the cursor %d"
					% [slot, directory.persistent_id[slot], next_persistent_id])
		slot = directory.active.find(1, slot + 1)
	return true


# --- the ARCH-ID-003 reference predicate --------------------------------------------------------------

static func _kind_base_of(kind: int) -> int:
	"""The prefix sum that partitions the rebuilt reverse map into per-kind arenas.

	Computed from the immutable KIND_CAPACITY with int locals on demand. No packed prefix cache
	is allocated: the sum is at most eighteen additions and is charged nothing.
	"""
	var base: int = 0
	for earlier: int in kind:
		base += EntityDirectoryScript.KIND_CAPACITY[earlier]
	return base


static func _live_typed_row(directory: SaveSectionDirectory.Record, owner_map: PackedInt32Array,
		base: int, capacity: int, slot: int, generation: int, kind: int) -> int:
	"""Resolve one saved pair, or -1. The SAME predicate every live reference uses.

	Bounds, active, generation, expected kind, typed range and reverse owner -- through the
	Directory's own rebuilt reverse map. An owner reference is never RECONSTRUCTED from a claim's
	typed row; the stored pair is what is resolved.
	"""
	if slot < 0 or slot >= DIRECTORY_CAPACITY:
		return NO_ROW
	if directory.active[slot] != 1:
		return NO_ROW
	if directory.generation[slot] != generation:
		return NO_ROW
	if directory.kind[slot] != kind:
		return NO_ROW
	var row: int = directory.typed_row[slot]
	if row < 0 or row >= capacity:
		return NO_ROW
	if owner_map[base + row] != slot:
		return NO_ROW
	return row


static func _pair_state(directory: SaveSectionDirectory.Record, slot: int, generation: int) -> int:
	"""Classify one saved owning Job/Expedition pair as future, stale or live.

	Structurally out-of-range slots and zero generations are already refused by the section 7
	codec domains, which run before this. A generation ABOVE the Directory slot's saved generation
	is impossible future provenance. Otherwise an inactive slot or an older generation is a
	legitimate dead owner -- Directory generations rise on allocation/reuse and never on destroy,
	so an inactive same-generation slot is dead too, including a terminal retired generation --
	and the slot's CURRENT kind is irrelevant to an older pair.
	"""
	var saved: int = directory.generation[slot]
	if generation > saved:
		return PAIR_FUTURE
	if generation < saved or directory.active[slot] != 1:
		return PAIR_STALE
	return PAIR_LIVE


static func _max_effort_capacity() -> int:
	"""The largest existing habitat effort capacity, read off EFFORT_SLOTS_BY_TYPE itself.

	[6, 6, 4] in COAST/LAKE/RIVER order, so 6. Derived by integer iteration over the constants
	every existing public habitat write already uses; this is not a new gameplay cap.
	"""
	var largest: int = 0
	for habitat_type: int in FishingScript.HABITAT_TYPE_COUNT:
		if FishingScript.EFFORT_SLOTS_BY_TYPE[habitat_type] > largest:
			largest = FishingScript.EFFORT_SLOTS_BY_TYPE[habitat_type]
	return largest


# --- gate 6: component local domains, live mirrors and the reverse walk -------------------------------

static func _component_gate(directory: SaveSectionDirectory.Record,
		derived: SaveSectionDirectory.Derived, components: Components, out: Result) -> bool:
	"""Fish rows, Forage zones, Forage patches, Jobs, then reverse Directory slots ascending."""
	if not _fish_component_gate(directory, derived, components.fish, out):
		return false
	if not _zone_component_gate(directory, derived, components.forage, out):
		return false
	if not _patch_component_gate(components.forage, out):
		return false
	if not _job_component_gate(directory, derived, components.jobs, out):
		return false
	return _reverse_component_gate(directory, components, out)


static func _fish_component_gate(directory: SaveSectionDirectory.Record,
		derived: SaveSectionDirectory.Derived, fish: FishComponents, out: Result) -> bool:
	"""Per habitat row: occupancy, then self-reference shape/identity, then values.

	An inactive row carries slot -1, generation 0 and zero used effort, but MAY retain its prior
	valid capacity after an ordinary public `destroy_habitat()`: 0..max is accepted there and the
	value is not normalized.
	"""
	var base: int = _kind_base_of(KIND_FISH_HABITAT)
	var ceiling: int = _max_effort_capacity()
	for row: int in HABITAT_ROWS:
		var present: int = fish.habitat_present[row]
		if present > 1:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"habitat row %d holds occupancy %d, not 0 or 1" % [row, present],
				OWNER_FISHING, SPACE_HABITAT, row)
		if present == 0:
			if fish.habitat_ref_slot[row] != NULL_SLOT \
					or fish.habitat_ref_generation[row] != NULL_GENERATION:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent habitat row %d holds the reference (%d, %d), not the blank (%d, %d)"
						% [row, fish.habitat_ref_slot[row], fish.habitat_ref_generation[row],
							NULL_SLOT, NULL_GENERATION],
					OWNER_FISHING, SPACE_HABITAT, row)
			if fish.habitat_effort_used[row] != 0:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent habitat row %d still uses %d effort slots"
						% [row, fish.habitat_effort_used[row]],
					OWNER_FISHING, SPACE_HABITAT, row)
			if fish.habitat_effort_slots[row] < 0 or fish.habitat_effort_slots[row] > ceiling:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent habitat row %d retains capacity %d, outside 0..%d"
						% [row, fish.habitat_effort_slots[row], ceiling],
					OWNER_FISHING, SPACE_HABITAT, row)
			continue
		var resolved: int = _live_typed_row(directory, derived.typed_owner_slot, base, HABITAT_ROWS,
			fish.habitat_ref_slot[row], fish.habitat_ref_generation[row], KIND_FISH_HABITAT)
		if resolved != row:
			return _refuse(out, CLAIM_CHECK_IDENTITY,
				"present habitat row %d names (%d, %d), which is not the live habitat row %d"
					% [row, fish.habitat_ref_slot[row], fish.habitat_ref_generation[row], row],
				OWNER_FISHING, SPACE_HABITAT, row)
		if fish.habitat_effort_slots[row] < 1 or fish.habitat_effort_slots[row] > ceiling:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"present habitat row %d declares capacity %d, outside 1..%d"
					% [row, fish.habitat_effort_slots[row], ceiling],
				OWNER_FISHING, SPACE_HABITAT, row)
		if fish.habitat_effort_used[row] < 0 \
				or fish.habitat_effort_used[row] > fish.habitat_effort_slots[row]:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"present habitat row %d uses %d of %d effort slots"
					% [row, fish.habitat_effort_used[row], fish.habitat_effort_slots[row]],
				OWNER_FISHING, SPACE_HABITAT, row)
	return true


static func _zone_component_gate(directory: SaveSectionDirectory.Record,
		derived: SaveSectionDirectory.Derived, zones: ForageComponents, out: Result) -> bool:
	"""Per zone row: occupancy, self-reference identity, then the basin pair and the reservation.

	A present zone's basin pair must be a bounded Directory slot with a positive generation but
	need NOT resolve: ordinary basin deletion leaves a surviving designation naming a dead basin.
	Claimed zones face the stronger claim-side rules instead.
	"""
	var base: int = _kind_base_of(KIND_HARVEST_ZONE)
	for row: int in ZONE_ROWS:
		var present: int = zones.zone_present[row]
		if present > 1:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"zone row %d holds occupancy %d, not 0 or 1" % [row, present],
				OWNER_FORAGE, SPACE_ZONE, row)
		if present == 0:
			if zones.zone_ref_slot[row] != NULL_SLOT \
					or zones.zone_ref_generation[row] != NULL_GENERATION \
					or zones.zone_basin_slot[row] != NULL_SLOT \
					or zones.zone_basin_generation[row] != NULL_GENERATION:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent zone row %d holds self (%d, %d) and basin (%d, %d), not the blanks"
						% [row, zones.zone_ref_slot[row], zones.zone_ref_generation[row],
							zones.zone_basin_slot[row], zones.zone_basin_generation[row]],
					OWNER_FORAGE, SPACE_ZONE, row)
			if zones.zone_quota_reserved_milli[row] != 0:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent zone row %d still reserves %d milli"
						% [row, zones.zone_quota_reserved_milli[row]],
					OWNER_FORAGE, SPACE_ZONE, row)
			continue
		var resolved: int = _live_typed_row(directory, derived.typed_owner_slot, base, ZONE_ROWS,
			zones.zone_ref_slot[row], zones.zone_ref_generation[row], KIND_HARVEST_ZONE)
		if resolved != row:
			return _refuse(out, CLAIM_CHECK_IDENTITY,
				"present zone row %d names (%d, %d), which is not the live zone row %d"
					% [row, zones.zone_ref_slot[row], zones.zone_ref_generation[row], row],
				OWNER_FORAGE, SPACE_ZONE, row)
		if zones.zone_basin_slot[row] < 0 or zones.zone_basin_slot[row] >= DIRECTORY_CAPACITY \
				or zones.zone_basin_generation[row] <= NULL_GENERATION:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"present zone row %d names the basin pair (%d, %d), which is out of bounds"
					% [row, zones.zone_basin_slot[row], zones.zone_basin_generation[row]],
				OWNER_FORAGE, SPACE_ZONE, row)
		if zones.zone_quota_reserved_milli[row] < 0:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"present zone row %d reserves %d milli"
					% [row, zones.zone_quota_reserved_milli[row]],
				OWNER_FORAGE, SPACE_ZONE, row)
	return true


static func _patch_component_gate(zones: ForageComponents, out: Result) -> bool:
	"""Per patch row: occupancy, then the owning zone at `row / PATCHES_PER_ZONE` and its mirror.

	A claim-independent present patch whose owner is absent, or whose saved zone pair does not
	exactly mirror that owner, is CLAIM_CHECK_COMPONENT AT THAT PATCH ROW. A zone owning no patch
	at all is legal; all five kinds are never required.
	"""
	for row: int in PATCH_ROWS:
		var present: int = zones.patch_present[row]
		if present > 1:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"patch row %d holds occupancy %d, not 0 or 1" % [row, present],
				OWNER_FORAGE, SPACE_PATCH, row)
		if present == 0:
			if zones.patch_zone_slot[row] != NULL_SLOT \
					or zones.patch_zone_generation[row] != NULL_GENERATION:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent patch row %d holds the zone pair (%d, %d), not the blank (%d, %d)"
						% [row, zones.patch_zone_slot[row], zones.patch_zone_generation[row],
							NULL_SLOT, NULL_GENERATION],
					OWNER_FORAGE, SPACE_PATCH, row)
			continue
		var zone_row: int = row / PATCHES_PER_ZONE
		if zones.zone_present[zone_row] != 1:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"present patch row %d is owned by zone row %d, which is absent" % [row, zone_row],
				OWNER_FORAGE, SPACE_PATCH, row)
		if zones.patch_zone_slot[row] != zones.zone_ref_slot[zone_row] \
				or zones.patch_zone_generation[row] != zones.zone_ref_generation[zone_row]:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"present patch row %d names (%d, %d), not its owning zone row %d's (%d, %d)"
					% [row, zones.patch_zone_slot[row], zones.patch_zone_generation[row], zone_row,
						zones.zone_ref_slot[zone_row], zones.zone_ref_generation[zone_row]],
				OWNER_FORAGE, SPACE_PATCH, row)
	return true


static func _job_component_gate(directory: SaveSectionDirectory.Record,
		derived: SaveSectionDirectory.Derived, jobs: JobComponents, out: Result) -> bool:
	"""Per Job row: occupancy, self-reference identity, then the creation tick.

	No `created_tick <= world_tick` rule is imposed: this checker has no world tick input and no
	such admission bound has been established by this lane.
	"""
	var base: int = _kind_base_of(KIND_JOB)
	for row: int in JOB_ROWS:
		var present: int = jobs.job_present[row]
		if present > 1:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"job row %d holds occupancy %d, not 0 or 1" % [row, present],
				OWNER_JOBS, SPACE_JOB, row)
		if present == 0:
			if jobs.job_ref_slot[row] != NULL_SLOT \
					or jobs.job_ref_generation[row] != NULL_GENERATION:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent job row %d holds the reference (%d, %d), not the blank (%d, %d)"
						% [row, jobs.job_ref_slot[row], jobs.job_ref_generation[row],
							NULL_SLOT, NULL_GENERATION],
					OWNER_JOBS, SPACE_JOB, row)
			if jobs.created_tick[row] != 0:
				return _refuse(out, CLAIM_CHECK_COMPONENT,
					"absent job row %d still declares created tick %d"
						% [row, jobs.created_tick[row]],
					OWNER_JOBS, SPACE_JOB, row)
			continue
		var resolved: int = _live_typed_row(directory, derived.typed_owner_slot, base, JOB_ROWS,
			jobs.job_ref_slot[row], jobs.job_ref_generation[row], KIND_JOB)
		if resolved != row:
			return _refuse(out, CLAIM_CHECK_IDENTITY,
				"present job row %d names (%d, %d), which is not the live job row %d"
					% [row, jobs.job_ref_slot[row], jobs.job_ref_generation[row], row],
				OWNER_JOBS, SPACE_JOB, row)
		if jobs.created_tick[row] < 0:
			return _refuse(out, CLAIM_CHECK_COMPONENT,
				"present job row %d declares created tick %d" % [row, jobs.created_tick[row]],
				OWNER_JOBS, SPACE_JOB, row)
	return true


static func _reverse_component_gate(directory: SaveSectionDirectory.Record,
		components: Components, out: Result) -> bool:
	"""Walk every live Directory entry of Habitat/HarvestZone/Job kind, ascending by slot.

	This is the other half of the BIJECTION for those THREE kinds: a forward mirror alone would
	accept a live Directory Job with no component behind it. No Expedition component exists or is
	invented, so Expedition slots are not walked here.
	"""
	var slot: int = directory.active.find(1, 0)
	while slot >= 0:
		var kind: int = directory.kind[slot]
		var row: int = directory.typed_row[slot]
		var generation: int = directory.generation[slot]
		if kind == KIND_FISH_HABITAT:
			var fish: FishComponents = components.fish
			if fish.habitat_present[row] != 1 or fish.habitat_ref_slot[row] != slot \
					or fish.habitat_ref_generation[row] != generation:
				return _refuse(out, CLAIM_CHECK_IDENTITY,
					"live directory slot %d is habitat row %d, which has no mirroring component"
						% [slot, row],
					OWNER_FISHING, SPACE_DIRECTORY_SLOT, slot)
		elif kind == KIND_HARVEST_ZONE:
			var zones: ForageComponents = components.forage
			if zones.zone_present[row] != 1 or zones.zone_ref_slot[row] != slot \
					or zones.zone_ref_generation[row] != generation:
				return _refuse(out, CLAIM_CHECK_IDENTITY,
					"live directory slot %d is zone row %d, which has no mirroring component"
						% [slot, row],
					OWNER_FORAGE, SPACE_DIRECTORY_SLOT, slot)
		elif kind == KIND_JOB:
			var jobs: JobComponents = components.jobs
			if jobs.job_present[row] != 1 or jobs.job_ref_slot[row] != slot \
					or jobs.job_ref_generation[row] != generation:
				return _refuse(out, CLAIM_CHECK_IDENTITY,
					"live directory slot %d is job row %d, which has no mirroring component"
						% [slot, row],
					OWNER_JOBS, SPACE_DIRECTORY_SLOT, slot)
		slot = directory.active.find(1, slot + 1)
	return true


# --- gate 7: active Fishing claims ------------------------------------------------------------------

static func _fishing_claim_gate(directory: SaveSectionDirectory.Record,
		derived: SaveSectionDirectory.Derived, block: SaveSectionInventories.OwnerRecord,
		components: Components, sums: Sums, math: IntMath.IntResult, out: Result) -> bool:
	"""Every active Fishing row: one Expedition pair, one Job pair, one habitat pair.

	Within a claim: owner pair, Job pair, ecological pair, quantity, then checked accumulation;
	an applicable earlier gate wins. A stale Expedition and/or Job is permitted and still
	contributes its full saved amount to the habitat total, with the two stale counts incremented
	independently. There is no live-Job state restriction: public membership can change after
	admission and cancellation may precede a normal release.
	"""
	var active: PackedByteArray = block.u8_column(SaveResourceClaims.FISH_ORDINAL_ACTIVE)
	var expedition_slot: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FISH_ORDINAL_EXPEDITION_SLOT)
	var expedition_generation: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FISH_ORDINAL_EXPEDITION_GENERATION)
	var habitat_slot: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FISH_ORDINAL_HABITAT_SLOT)
	var habitat_generation: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FISH_ORDINAL_HABITAT_GENERATION)
	var job_slot: PackedInt32Array = block.i32_column(SaveResourceClaims.FISH_ORDINAL_JOB_SLOT)
	var job_generation: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FISH_ORDINAL_JOB_GENERATION)
	var slot_count: PackedInt32Array = block.i32_column(SaveResourceClaims.FISH_ORDINAL_SLOT_COUNT)
	var owner_map: PackedInt32Array = derived.typed_owner_slot
	var base_expedition: int = _kind_base_of(KIND_EXPEDITION)
	var base_habitat: int = _kind_base_of(KIND_FISH_HABITAT)
	var base_job: int = _kind_base_of(KIND_JOB)
	var ceiling: int = _max_effort_capacity()
	for row: int in FISHING_CLAIM_ROWS:
		if active[row] != 1:
			continue
		var owner_state: int = _pair_state(directory, expedition_slot[row],
			expedition_generation[row])
		if owner_state == PAIR_FUTURE:
			return _refuse(out, CLAIM_CHECK_FUTURE_REF,
				"fishing claim %d names Expedition generation %d above the directory's %d"
					% [row, expedition_generation[row], directory.generation[expedition_slot[row]]],
				OWNER_FISHING, SPACE_CLAIM, row)
		if owner_state == PAIR_LIVE:
			if _live_typed_row(directory, owner_map, base_expedition, EXPEDITION_ROWS,
					expedition_slot[row], expedition_generation[row], KIND_EXPEDITION) != row:
				return _refuse(out, CLAIM_CHECK_IDENTITY,
					"fishing claim %d has a live owner (%d, %d) of the wrong kind or typed row"
						% [row, expedition_slot[row], expedition_generation[row]],
					OWNER_FISHING, SPACE_CLAIM, row)
		else:
			sums.stale_fishing_expeditions += 1
		var job_state: int = _pair_state(directory, job_slot[row], job_generation[row])
		if job_state == PAIR_FUTURE:
			return _refuse(out, CLAIM_CHECK_FUTURE_REF,
				"fishing claim %d names Job generation %d above the directory's %d"
					% [row, job_generation[row], directory.generation[job_slot[row]]],
				OWNER_FISHING, SPACE_CLAIM, row)
		if job_state == PAIR_LIVE:
			var job_row: int = _live_typed_row(directory, owner_map, base_job, JOB_ROWS,
				job_slot[row], job_generation[row], KIND_JOB)
			if job_row < 0 or components.jobs.job_present[job_row] != 1:
				return _refuse(out, CLAIM_CHECK_IDENTITY,
					"fishing claim %d has a live Job (%d, %d) of the wrong kind or with no component"
						% [row, job_slot[row], job_generation[row]],
					OWNER_FISHING, SPACE_CLAIM, row)
		else:
			sums.stale_fishing_jobs += 1
		var habitat_row: int = _live_typed_row(directory, owner_map, base_habitat, HABITAT_ROWS,
			habitat_slot[row], habitat_generation[row], KIND_FISH_HABITAT)
		if habitat_row < 0 or components.fish.habitat_present[habitat_row] != 1:
			return _refuse(out, CLAIM_CHECK_ECOLOGY,
				"fishing claim %d names the habitat (%d, %d), which is not a live present habitat"
					% [row, habitat_slot[row], habitat_generation[row]],
				OWNER_FISHING, SPACE_CLAIM, row)
		var amount: int = slot_count[row]
		if amount < FISHING_QUANTITY_MIN or amount > ceiling:
			return _refuse(out, CLAIM_CHECK_QUANTITY,
				"fishing claim %d holds %d effort slots, outside %d..%d"
					% [row, amount, FISHING_QUANTITY_MIN, ceiling],
				OWNER_FISHING, SPACE_CLAIM, row)
		if not _checked_total_into(sums.habitat_total[habitat_row], amount, math):
			return _refuse(out, CLAIM_CHECK_OVERFLOW,
				"fishing claim %d overflows the habitat row %d total: %s"
					% [row, habitat_row, math.error],
				OWNER_FISHING, SPACE_CLAIM, row)
		sums.habitat_total[habitat_row] = math.value
		sums.fishing_count += 1
	return true


# --- gate 8: active Forage claims -------------------------------------------------------------------

static func _forage_claim_gate(directory: SaveSectionDirectory.Record,
		derived: SaveSectionDirectory.Derived, block: SaveSectionInventories.OwnerRecord,
		next_persistent_id: int, components: Components, sums: Sums, math: IntMath.IntResult,
		out: Result) -> bool:
	"""Every active Forage row: one Job pair, two ecological refs, provenance, then the quantity.

	The owner pair IS the Job pair and is checked once. Both saved ecological refs must resolve
	to present zones; the designation's saved basin pair must equal the claim's; that basin must
	be self-bound; and the particular patch at `basin_row * 5 + saved_patch_kind` must be present
	and mirror the basin. The checked remaining amount is added to the basin total, and to the
	designation total ONLY when their resolved rows differ -- counted exactly once when equal,
	matching the reserve and release code.

	No seasonal quota, enabled/protected state, stock/floor, membership or cancellation condition
	is tested: normal deferred gameplay reconciliation owns those.
	"""
	var active: PackedByteArray = block.u8_column(SaveResourceClaims.FORAGE_ORDINAL_ACTIVE)
	var job_slot: PackedInt32Array = block.i32_column(SaveResourceClaims.FORAGE_ORDINAL_JOB_SLOT)
	var job_generation: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FORAGE_ORDINAL_JOB_GENERATION)
	var designation_slot: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FORAGE_ORDINAL_DESIGNATION_SLOT)
	var designation_generation: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FORAGE_ORDINAL_DESIGNATION_GENERATION)
	var basin_slot: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FORAGE_ORDINAL_BASIN_SLOT)
	var basin_generation: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FORAGE_ORDINAL_BASIN_GENERATION)
	var patch_kind: PackedInt32Array = block.i32_column(
		SaveResourceClaims.FORAGE_ORDINAL_PATCH_KIND)
	var remaining_milli: PackedInt64Array = block.i64_column(
		SaveResourceClaims.FORAGE_ORDINAL_REMAINING_MILLI)
	var created_tick: PackedInt64Array = block.i64_column(
		SaveResourceClaims.FORAGE_ORDINAL_CREATED_TICK)
	var persistent_id: PackedInt64Array = block.i64_column(
		SaveResourceClaims.FORAGE_ORDINAL_PERSISTENT_ID)
	var zones: ForageComponents = components.forage
	var owner_map: PackedInt32Array = derived.typed_owner_slot
	var base_zone: int = _kind_base_of(KIND_HARVEST_ZONE)
	var base_job: int = _kind_base_of(KIND_JOB)
	for row: int in FORAGE_CLAIM_ROWS:
		if active[row] != 1:
			continue
		var job_state: int = _pair_state(directory, job_slot[row], job_generation[row])
		if job_state == PAIR_FUTURE:
			return _refuse(out, CLAIM_CHECK_FUTURE_REF,
				"forage claim %d names Job generation %d above the directory's %d"
					% [row, job_generation[row], directory.generation[job_slot[row]]],
				OWNER_FORAGE, SPACE_CLAIM, row)
		if job_state == PAIR_LIVE:
			var job_row: int = _live_typed_row(directory, owner_map, base_job, JOB_ROWS,
				job_slot[row], job_generation[row], KIND_JOB)
			if job_row != row or components.jobs.job_present[row] != 1:
				return _refuse(out, CLAIM_CHECK_IDENTITY,
					"forage claim %d has a live Job (%d, %d) of the wrong kind, typed row or component"
						% [row, job_slot[row], job_generation[row]],
					OWNER_FORAGE, SPACE_CLAIM, row)
		else:
			sums.stale_forage_jobs += 1
		var designation_row: int = _live_typed_row(directory, owner_map, base_zone, ZONE_ROWS,
			designation_slot[row], designation_generation[row], KIND_HARVEST_ZONE)
		if designation_row < 0 or zones.zone_present[designation_row] != 1:
			return _refuse(out, CLAIM_CHECK_ECOLOGY,
				"forage claim %d names the designation (%d, %d), which is not a live present zone"
					% [row, designation_slot[row], designation_generation[row]],
				OWNER_FORAGE, SPACE_CLAIM, row)
		var basin_row: int = _live_typed_row(directory, owner_map, base_zone, ZONE_ROWS,
			basin_slot[row], basin_generation[row], KIND_HARVEST_ZONE)
		if basin_row < 0 or zones.zone_present[basin_row] != 1:
			return _refuse(out, CLAIM_CHECK_ECOLOGY,
				"forage claim %d names the basin (%d, %d), which is not a live present zone"
					% [row, basin_slot[row], basin_generation[row]],
				OWNER_FORAGE, SPACE_CLAIM, row)
		if zones.zone_basin_slot[designation_row] != basin_slot[row] \
				or zones.zone_basin_generation[designation_row] != basin_generation[row]:
			return _refuse(out, CLAIM_CHECK_ECOLOGY,
				"forage claim %d names basin (%d, %d) but designation row %d is bound to (%d, %d)"
					% [row, basin_slot[row], basin_generation[row], designation_row,
						zones.zone_basin_slot[designation_row],
						zones.zone_basin_generation[designation_row]],
				OWNER_FORAGE, SPACE_CLAIM, row)
		if zones.zone_basin_slot[basin_row] != zones.zone_ref_slot[basin_row] \
				or zones.zone_basin_generation[basin_row] != zones.zone_ref_generation[basin_row]:
			return _refuse(out, CLAIM_CHECK_ECOLOGY,
				"forage claim %d names zone row %d as a basin, but that zone is not self-bound"
					% [row, basin_row],
				OWNER_FORAGE, SPACE_CLAIM, row)
		var patch_row: int = basin_row * PATCHES_PER_ZONE + patch_kind[row]
		if zones.patch_present[patch_row] != 1:
			return _refuse(out, CLAIM_CHECK_ECOLOGY,
				"forage claim %d needs patch row %d of basin row %d, which is absent"
					% [row, patch_row, basin_row],
				OWNER_FORAGE, SPACE_CLAIM, row)
		if zones.patch_zone_slot[patch_row] != zones.zone_ref_slot[basin_row] \
				or zones.patch_zone_generation[patch_row] != zones.zone_ref_generation[basin_row]:
			return _refuse(out, CLAIM_CHECK_ECOLOGY,
				"forage claim %d needs patch row %d to mirror basin row %d, but it names (%d, %d)"
					% [row, patch_row, basin_row, zones.patch_zone_slot[patch_row],
						zones.patch_zone_generation[patch_row]],
				OWNER_FORAGE, SPACE_CLAIM, row)
		if not _forage_provenance_gate(directory, components.jobs, job_state, row, job_slot[row],
				persistent_id[row], created_tick[row], next_persistent_id, out):
			return false
		var amount: int = remaining_milli[row]
		if amount < FORAGE_QUANTITY_MIN or amount > FORAGE_QUANTITY_MAX:
			return _refuse(out, CLAIM_CHECK_QUANTITY,
				"forage claim %d holds %d milli, outside %d..%d"
					% [row, amount, FORAGE_QUANTITY_MIN, FORAGE_QUANTITY_MAX],
				OWNER_FORAGE, SPACE_CLAIM, row)
		if not _checked_total_into(sums.zone_total[basin_row], amount, math):
			return _refuse(out, CLAIM_CHECK_OVERFLOW,
				"forage claim %d overflows the basin zone row %d total: %s"
					% [row, basin_row, math.error],
				OWNER_FORAGE, SPACE_CLAIM, row)
		sums.zone_total[basin_row] = math.value
		if designation_row != basin_row:
			if not _checked_total_into(sums.zone_total[designation_row], amount, math):
				return _refuse(out, CLAIM_CHECK_OVERFLOW,
					"forage claim %d overflows the designation zone row %d total: %s"
						% [row, designation_row, math.error],
					OWNER_FORAGE, SPACE_CLAIM, row)
			sums.zone_total[designation_row] = math.value
		sums.forage_count += 1
	return true


static func _forage_provenance_gate(directory: SaveSectionDirectory.Record, jobs: JobComponents,
		job_state: int, row: int, job_slot: int, persistent_id: int, created_tick: int,
		next_persistent_id: int, out: Result) -> bool:
	"""PID lower, upper and cursor bounds first, then the live PID and live tick comparisons.

	Even a dead owner retains a formerly positive signed-i32 identity below the SAME world's
	next-PID cursor, so the three bounds apply to ANY active claim. A dead Job's tick cannot be
	re-derived and is preserved as the nonnegative value the codec already admitted; it is never
	guessed from a reused row. The public writer takes the claim row directly from the Job row,
	so these are provenance CHECKS and not a rewrite.
	"""
	if persistent_id < PERSISTENT_ID_MIN:
		return _refuse(out, CLAIM_CHECK_PROVENANCE,
			"forage claim %d carries persistent id %d, below %d"
				% [row, persistent_id, PERSISTENT_ID_MIN],
			OWNER_FORAGE, SPACE_CLAIM, row)
	if persistent_id > MAX_INT32:
		return _refuse(out, CLAIM_CHECK_PROVENANCE,
			"forage claim %d carries persistent id %d, above the signed-i32 maximum %d"
				% [row, persistent_id, MAX_INT32],
			OWNER_FORAGE, SPACE_CLAIM, row)
	if persistent_id >= next_persistent_id:
		return _refuse(out, CLAIM_CHECK_PROVENANCE,
			"forage claim %d carries persistent id %d, not below the cursor %d"
				% [row, persistent_id, next_persistent_id],
			OWNER_FORAGE, SPACE_CLAIM, row)
	if job_state != PAIR_LIVE:
		return true
	if persistent_id != directory.persistent_id[job_slot]:
		return _refuse(out, CLAIM_CHECK_PROVENANCE,
			"forage claim %d carries persistent id %d, not its live Job's %d"
				% [row, persistent_id, directory.persistent_id[job_slot]],
			OWNER_FORAGE, SPACE_CLAIM, row)
	if created_tick != jobs.created_tick[row]:
		return _refuse(out, CLAIM_CHECK_PROVENANCE,
			"forage claim %d carries created tick %d, not its live Job's %d"
				% [row, created_tick, jobs.created_tick[row]],
			OWNER_FORAGE, SPACE_CLAIM, row)
	return true


# --- gates 9 and 10: the saved aggregates ------------------------------------------------------------

static func _fishing_total_gate(fish: FishComponents, sums: Sums, out: Result) -> bool:
	"""Compare ALL 32 habitat rows: total == saved used AND total <= saved capacity.

	A free row must carry zero, and no claim may name one. Nothing is repaired: no canonical
	total, aggregate or scratch column is written anywhere.
	"""
	for row: int in HABITAT_ROWS:
		var total: int = sums.habitat_total[row]
		if fish.habitat_present[row] != 1:
			if total != 0:
				return _refuse(out, CLAIM_CHECK_TOTAL,
					"absent habitat row %d is claimed for %d effort slots" % [row, total],
					OWNER_FISHING, SPACE_HABITAT, row)
			continue
		if total != fish.habitat_effort_used[row]:
			return _refuse(out, CLAIM_CHECK_TOTAL,
				"habitat row %d saves %d used effort slots, but its claims total %d"
					% [row, fish.habitat_effort_used[row], total],
				OWNER_FISHING, SPACE_HABITAT, row)
		if total > fish.habitat_effort_slots[row]:
			return _refuse(out, CLAIM_CHECK_TOTAL,
				"habitat row %d totals %d effort slots against a capacity of %d"
					% [row, total, fish.habitat_effort_slots[row]],
				OWNER_FISHING, SPACE_HABITAT, row)
	return true


static func _forage_total_gate(zones: ForageComponents, sums: Sums, out: Result) -> bool:
	"""Compare ALL 128 saved `zone_quota_reserved_milli` values, including claim-free zones.

	A zone with no matching claim must save zero, which is what catches a missing claim as surely
	as a stray one. No quota reconciliation, key refresh, trim or purge happens here.
	"""
	for row: int in ZONE_ROWS:
		var total: int = sums.zone_total[row]
		if zones.zone_present[row] != 1:
			if total != 0:
				return _refuse(out, CLAIM_CHECK_TOTAL,
					"absent zone row %d is claimed for %d milli" % [row, total],
					OWNER_FORAGE, SPACE_ZONE, row)
			continue
		if total != zones.zone_quota_reserved_milli[row]:
			return _refuse(out, CLAIM_CHECK_TOTAL,
				"zone row %d saves %d reserved milli, but its claims total %d"
					% [row, zones.zone_quota_reserved_milli[row], total],
				OWNER_FORAGE, SPACE_ZONE, row)
	return true


# --- the one checked accumulation helper --------------------------------------------------------------

static func _checked_total_into(current: int, amount: int, out: IntMath.IntResult) -> bool:
	"""Add one claim's amount to a private total, delegating to the existing checked adder.

	EVERY accumulation in this module calls this, and every false maps to CLAIM_CHECK_OVERFLOW.
	The guarded path is UNREACHABLE through admitted full-table quantities -- the maxima are 3072
	and 9666560000, neither of which can overflow int64 -- so neither this helper's own synthetic
	test nor any forged input is a public overflow reproduction, and no quantity bound is weakened
	to reach it.
	"""
	return IntMath.checked_add_into(current, amount, out)
