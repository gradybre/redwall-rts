# Movement dependency source excerpts

Source excerpts only, not runtime evidence. Full-source SHA256 records permit exact provenance.

## godot/scripts/core/residents.gd

SHA256 90a99e562e4e0b41da5f2afad5df7ab64f297b93b86f985d21535ebd72c3a06c

```gdscript
const RESIDENT_CAPACITY: int = 512
const SIZE_MOVEMENT_U_PER_S: Array[int] = [3277, 4096, 3072]
```

## godot/scripts/core/spatial_world.gd

SHA256 3825788db07885db94dab7288c832b8219f89e54da22d871d58e98e2d590b26b

```gdscript
const CELLS_X: int = 512
const CELLS_Z: int = 512
const CELL_COUNT: int = CELLS_X * CELLS_Z
const CELL_SIZE_UNITS: int = 512
const CELL_CENTRE_OFFSET_UNITS: int = 256
static func cell_centre_x_units(cell: int) -> int:
	"""The X centre of a cell in GDD 4.2's 1/1024 m units. Caller checks `is_cell()` first."""
	return (cell % CELLS_X) * CELL_SIZE_UNITS + CELL_CENTRE_OFFSET_UNITS
static func cell_centre_z_units(cell: int) -> int:
	"""The Z centre of a cell in GDD 4.2's 1/1024 m units. Caller checks `is_cell()` first."""
	return (cell / CELLS_X) * CELL_SIZE_UNITS + CELL_CENTRE_OFFSET_UNITS
```

## godot/scripts/core/navigation.gd

SHA256 00f43ec4f4d834fb836c2a72bdc882cb7eddd5d53e596ecd154a4d83f7caacf2

```gdscript
const COST_ORTHOGONAL: int = 10
const COST_DIAGONAL: int = 14
```
