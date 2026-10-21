extends RefCounted
## Decision 2044 (P-2044-9 (a)): the module-aware successor of `qualified-assembly-v1/source_program.gd`'s two
## assembly-bound source checks. The published file accepts only L0 and T0 (assemblies 0 and 1). M5's later modules
## each install a T0 from their natural landing; its staged bearer is T0's part, turn and transform moved by the
## module's shift, and its prism T0's relative prism. Module 0 is handed to the published file unchanged.

const Published := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i) -> StringName:
	"""L0/T0's published transforms; a later module's T0 as T0's in its module frame."""
	if Tread.module_of(assembly) <= 0 or not Tread.is_t0(assembly):
		return Published.part_refusal(assembly, part, turn, translation)
	var shift: Vector3i = Tread.module_shift(Tread.module_of(assembly))
	return Published.part_refusal(1, part - Tread.part_base(Tread.module_of(assembly)) + Tread.PARTS_PER_TREAD, turn,
		translation - shift)


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""L0/T0's published relative prisms; a later module's T0 as T0's (relative to its root, so unmoved)."""
	if Tread.module_of(assembly) <= 0 or not Tread.is_t0(assembly):
		return Published.bearer_refusal(assembly, point, bounds)
	return Published.bearer_refusal(1, point, bounds)
