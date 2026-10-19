extends RefCounted
## Decision 2044 (P-2044-9 (a)): the module-aware successor of `qualified-claw-runtime-v2/tread_geometry.gd` for M5's
## one 232-part variant (decision 2043 P-2043-1 (a)). Module j is today's module translated by (0, -1024j, -5120j);
## assembly 0 is L0 and module j's T0..T6 (T6 the sill) are assemblies 1 + 7j .. 7 + 7j. Module 0 is exactly the
## published geometry, so every function here returns the published module's value for assemblies 0-7 (delegated),
## and the same value moved by the module translation for a later module's tread. The published file is not edited.

const Base := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd")
const TREADS: int = Base.TREADS
const L0_FAR_Z: int = Base.L0_FAR_Z
const T0_FAR_Z: int = Base.T0_FAR_Z
const RISE: int = Base.RISE
const RUN: int = Base.RUN
const ARRIVAL: int = Base.ARRIVAL
const STATION: int = Base.STATION
const ASCENT_START: int = Base.ASCENT_START
const PARTS_PER_TREAD: int = Base.PARTS_PER_TREAD
const SILL_PARTS: int = Base.SILL_PARTS
const SILL: int = Base.SILL
const T0_BEARER_PART: int = Base.T0_BEARER_PART
const T0_TURN: int = Base.T0_TURN
const T0_TRANSLATION: Vector3i = Base.T0_TRANSLATION
## Decision 2044 (P-2044-15, "Land M2 now"): the M2 interim (`qualified-stairs-m2-v1`) mounted the first two modules.
## Decision 2045: the M5 round mounts all five (`qualified-stairs-m5-v1`), ending on level 1's floor 5,120 u down: this
## count, the mounted bundle and the work area's rows are the switch. Every function here holds for any module count.
const MODULES: int = 5
const ASSEMBLIES_PER_MODULE: int = TREADS + 1 # T0..T5 and the sill.
const MODULE_DROP: int = 1024
const MODULE_RUN: int = 5120
const MODULE_PARTS: int = 45 # T0..T5 at seven parts and the sill at three.
const FIRST_MODULE_PARTS: int = 52 # L0, T0..T5 and the sill.
## Module j's H': its T0's station, L0's station (0, 0, -1536) translated (the prefix's endpoint 3).
const T0_STATION: Vector3i = Vector3i(0, 0, -1536)
## The slot's rows (2043 §3: L0's two and five rows a module), each one cube (ROW_U) long: 12 for M2, 27 for M5.
const ROWS: int = 2 + 5 * MODULES
const ROW_U: int = 1024
## Decision 2044: a deep station stands on the floor of the row uphill of the cube it strikes, DEEP_INSIDE u inside
## that row's downhill edge (the land stations' 406 u stand-off), at x DEEP_X[column]: claw dig row 56's contact
## (224, 0, -544) then lands 138 u inside the cube, and the all-yaw WALK's turns (+-712) stay inside the 2 m slot.
const DEEP_X: Array[int] = [-300, 300]
const DEEP_INSIDE: int = 406


static func valid_assembly(assembly: int) -> bool:
	"""L0 or one of the five modules' T0..T6."""
	return assembly >= 0 and assembly <= MODULES * ASSEMBLIES_PER_MODULE


static func module_of(assembly: int) -> int:
	"""The module an assembly belongs to (L0 is module 0's); -1 for no assembly."""
	if not valid_assembly(assembly): return -1
	@warning_ignore("integer_division") var module: int = maxi(assembly - 1, 0) / ASSEMBLIES_PER_MODULE
	return module


static func level_of(assembly: int) -> int:
	"""The tread index k of T_k within its module (L0 is -1); -2 for no assembly."""
	if not valid_assembly(assembly): return -2
	return -1 if assembly == 0 else (assembly - 1) % ASSEMBLIES_PER_MODULE


static func base_assembly(assembly: int) -> int:
	"""The published module's assembly with the same tread index (0..7); -1 for no assembly."""
	return level_of(assembly) + 1 if valid_assembly(assembly) else -1


static func offset(module: int) -> Vector3i:
	"""Module j's translation."""
	return Vector3i(0, -MODULE_DROP * module, -MODULE_RUN * module)


static func is_tread(assembly: int) -> bool:
	"""T1-T6 of any module (the published file's 2-7 in module 0)."""
	return valid_assembly(assembly) and Base.is_tread(base_assembly(assembly))


static func is_t0(assembly: int) -> bool:
	"""A module's T0 (assembly 1 in module 0): installed from L0 or its natural landing."""
	return valid_assembly(assembly) and level_of(assembly) == 0


static func is_sill(assembly: int) -> bool:
	"""A module's sill T6."""
	return valid_assembly(assembly) and level_of(assembly) == SILL


static func first_tread(assembly: int) -> bool:
	"""A module's T1, whose order hauls every tread of its module's wood (DEC-059 P1)."""
	return valid_assembly(assembly) and level_of(assembly) == 1


static func part_base(module: int) -> int:
	"""The first part of module j's T0."""
	return PARTS_PER_TREAD if module == 0 else FIRST_MODULE_PARTS + MODULE_PARTS * (module - 1)


static func top_y(level: int) -> int:
	"""Module 0's walking surface of L0 (level -1) or T_level."""
	return Base.top_y(level)


static func far_z(level: int) -> int:
	"""Module 0's far edge of L0 (level -1) or T_level."""
	return Base.far_z(level)


static func stop(level: int, behind: int) -> Vector3i:
	"""Module 0's stop on L0 (level -1) or T_level."""
	return Base.stop(level, behind)


static func module_stop(module: int, level: int, behind: int) -> Vector3i:
	"""A stop on module j's L0 position (level -1, its natural landing) or T_level."""
	return Base.stop(level, behind) + offset(module)


static func station_of(assembly: int) -> Vector3i:
	"""A tread's station on the tread above (310 u behind its far edge), in its module."""
	return Base.station_of(base_assembly(assembly)) + offset(module_of(assembly))


static func t0_station_of(assembly: int) -> Vector3i:
	"""A T0's station: L0's (0, 0, -1536) in its module."""
	return T0_STATION + offset(module_of(assembly))


static func bearer_height(assembly: int) -> int:
	"""A tread bearer's height; a sill's is cut to 64 u (D1)."""
	return Base.bearer_height(base_assembly(assembly))


static func bearer_part(assembly: int) -> int:
	"""The staged left bearer of a tread or T0: its assembly's first part plus one."""
	if assembly == 0: return 1 # L0's left bearer (the prefix's own source).
	if module_of(assembly) == 0: return Base.bearer_part(assembly) if assembly >= 2 else T0_BEARER_PART
	return part_base(module_of(assembly)) + PARTS_PER_TREAD * level_of(assembly) + 1


static func module_shift(module: int) -> Vector3i:
	"""d - R(d) for the module offset d (R(x, z) = (z, -x)): what a turn-3 staged transform moves by."""
	var d: Vector3i = offset(module)
	return Vector3i(-d.z, 0, d.z)


static func bearer_translation(assembly: int) -> Vector3i:
	"""The staged bearer's translation after turn 3: the published module's, moved by the module shift."""
	var base: int = base_assembly(assembly)
	var published: Vector3i = Base.bearer_translation(base) if base >= 2 else T0_TRANSLATION
	return published + module_shift(module_of(assembly))


static func bearer_prism_into(assembly: int, root: Vector3i, out: PackedInt32Array) -> bool:
	"""A tread's staged bearer prism around its station root (relative, so module-independent)."""
	return is_tread(assembly) and Base.bearer_prism_into(base_assembly(assembly), root, out)


static func deep_first_row(landing: int) -> int:
	"""The first row layer landing + 1 cuts: module j's first row (landing j's deep stations start one row uphill)."""
	return 2 + 5 * landing
