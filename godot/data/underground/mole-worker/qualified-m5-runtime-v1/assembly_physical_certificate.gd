extends RefCounted
## Decision 2044 (P-2044-9 (a)): the module-aware successor of `qualified-assembly-v1/physical_certificate.gd`'s
## assembly-bound station rule. The published certificate admits a handling station only at L0's root (-832, 0, 512)
## or T0's (0, 0, -1536) and refuses every other assembly. A later M5 module's T0 is handled at T0's root moved by its
## module translation (`tread_geometry.gd` `t0_station_of`), with its staged bearer judged by
## `assembly_source_program.gd`. Everything else (owners, footing, air, volumes) stays the published certificate's.

const Published := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const Source := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/assembly_source_program.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const REFUSE: StringName = Published.REFUSE


static func station_refusal(origin: Vector3i, assembly: int, root: Vector3i) -> StringName:
	"""A module's T0 stands at T0's root in its module; L0 and module 0's T0 keep the published roots."""
	if not Tread.is_t0(assembly): return REFUSE
	return &"" if root == origin + Tread.t0_station_of(assembly) else REFUSE


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i) -> StringName:
	"""The staged T0 bearer of the assembly's module."""
	return Source.part_refusal(assembly, part, turn, translation)


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""T0's relative bearer prism."""
	return Source.bearer_refusal(assembly, point, bounds)
