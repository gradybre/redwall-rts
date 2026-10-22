extends RefCounted
## Decision 2041 (P-DF-2/3/4/6, ruled 2026-10-16): the derived geometry and bill of F40, the straight earth/timber
## flight that takes the first entrance down a full level at ADR 1209's 128 u rise per 512 u run. Stateless and cold.
## Nothing here is chosen: every value follows from ADR 1209 (T_k is T0 translated by (0, -128k, -512k); D1 the sill;
## D2 the 1,536 u run-out; D3 the per-tread bill), DEC-059 (5,640 milli-WU a tread), SET-BUILD-001 §7.2 (one cube's
## price) and the level pack's 5,120 u spacing. Source-local frame as `tread_geometry.gd`: the stair top's walking
## surface is y = 0, the flight descends along -Z, the slot is two cubes wide (x in [-1024, 1024]).
##
## Every function takes `steps`, the number of 128 u descents: 40 (F40, one level, the ruled flight) or 8 (today's
## first-entry flight, decision 2041 F5's cross-check and one module of decision 2043's M5). Nothing else is ruled, so
## anything else refuses. Counts refuse with -1 and coordinates with 1 (both outside every valid range); anything a
## runtime would publish (a stop, a cube, a bill) comes only through a bool `_into` call that leaves its packet
## untouched on refusal. A row is
## 1,024 u of slot along -Z from the stair top (row r spans z in [-1024(r + 1), -1024r]); its depth is the number of
## cubes cut per column, counted down from the stair top (P-DF-3 (a): open to the sky). A tread row's floor is the
## least whole number of quanta that keeps every post in it at least 64 u long (decision 2041 §2.1); the last tread is
## the sill, resting on the level floor (D1). Phase 2b's runtime reads this module; it never edits it.
##
## Decision 2043 P-2043-1 (a), ruled 2026-10-16: the flight phase 2b builds is **M5**, not F40, because F40 cannot be
## built in place with qualified motion (2043 §3). M5 is today's 1 m module (`steps` = 8) five times in a straight line:
## module j is that module translated by (0, -1024j, -5120j), and module j >= 1 has no L0, its landing being module
## j-1's natural run-out. The `layout_*` functions (P-2043-2 (a)) serve both layouts, M5 and F40; the `steps`
## functions above them stay as the record of the F40 derivation and as the one-module geometry M5 repeats.

const Contract := preload("res://scripts/core/excavation_contract.gd")
const RISE: int = 128
const RUN: int = 512
const QUANTUM: int = 1024
const L0_FAR_Z: int = -2048
const T0_FAR_Z: int = -2560
const RUN_OUT: int = 1536 # ADR 1209 D2: the seventh row, from the sill's far edge to the end wall.
const DECK_AND_BEARER: int = 192 # T0's top -128, post 704, floor -1024.
const MIN_POST: int = 64 # T5's post, the shortest T0-family post.
const FIRST_ENTRY_STEPS: int = 8
const F40_STEPS: int = 40
const LEVEL_DROP: int = 5120 # initial_level_pack.json level_spacing_u.
const WIDTH_CUBES: int = 2
const HALF_WIDTH: int = 1024
const LANDING_ROWS: int = 2 # L0's 2,048 u, cut one cube deep as today.
const ALLOWED_ROTATION_MASK: int = 1 # P-DF-6 (a): rotation 0 only, room_connectors.gd's four-bit quarter-turn mask.
const PARTS_PER_ASSEMBLY: int = 7 # tread_geometry.gd PARTS_PER_TREAD; L0 has seven too.
const SILL_PARTS: int = 3
const FLOOR_ASCENT_START: int = 169 # Beyond the sill's far edge (decision 1981): the floor's U.
const FLOOR_ARRIVAL: int = 343 # F.
const FLOOR_WALK_OFF: int = 686 # F'.
const L0_WOOD_MILLI: int = 4000
const L0_WORK_MWU: int = 32000
const T0_WOOD_MILLI: int = 1000
const T0_WORK_MWU: int = 12000
const TREAD_WOOD_MILLI: int = 1000 # ADR 1209 D3.
const TREAD_WORK_MWU: int = 5640 # DEC-059 P3: 12,000 x 0.47.
const BILL_WOOD: int = 0
const BILL_STONE: int = 1
const BILL_WORK: int = 2
const BILL_EARTH: int = 3
const BILL_FIELDS: int = 4
const LAYOUT_F40: int = 0
const LAYOUT_M5: int = 1
const M5_MODULES: int = 5
## Decision 2044 (P-2044-15, "Land M2 now"): the interim layout, M5's first two modules, ending on module 1's floor
## 2,048 u down. M5 stays the target.
const LAYOUT_M2: int = 2
const M2_MODULES: int = 2
const MODULE_ROWS: int = 5 # A module's pitch: 3,584 u of treads and 1,536 u of run-out, 5,120 u.
const MODULE_DROP: int = 1024
## Decision 2046 (P-2054-3 (a), Brendan 2026-10-22, "Widen it"): M5's bottom run-out is cut one cell wider on each
## side, so a painted level-1 room's front station can strike one cube and be reached by a turn (decision 2054 B4).
## The run-out lies in the last two rows (the last sill's far half and the end row); both are cut four cells across,
## open to the sky as the slot is, to the floor's depth. M2 (it reaches no level) and F40 keep the slot's two cells.
const FOOT_ROWS: int = 2
const FOOT_HALF_WIDTH: int = 2048
const FOOT_SIDE_CUBES: int = 1 # Cubes a foot row adds per side, per layer.


static func valid(steps: int) -> bool:
	"""F40 or today's 1 m flight: the only two ruled flights."""
	return steps == F40_STEPS or steps == FIRST_ENTRY_STEPS


static func drop_u(steps: int) -> int:
	"""The flight's total fall, stair top to floor; -1 when `steps` is not valid."""
	return RISE * steps if valid(steps) else -1


static func bottom_depth(steps: int) -> int:
	"""The floor's depth in cubes; -1 when `steps` is not valid."""
	@warning_ignore("integer_division") var depth: int = drop_u(steps) / QUANTUM
	return depth if valid(steps) else -1


static func tread_count(steps: int) -> int:
	"""T0 to the sill: one fewer than the steps (the last step lands on the floor)."""
	return steps - 1 if valid(steps) else -1


static func sill(steps: int) -> int:
	"""The sill's tread index (D1)."""
	return steps - 2 if valid(steps) else -1


static func is_tread(steps: int, k: int) -> bool:
	"""T0 (k = 0) to the sill."""
	return valid(steps) and k >= 0 and k <= sill(steps)


static func top_y(k: int) -> int:
	"""The walking surface of L0 (k = -1) or T_k."""
	return 0 if k < 0 else -RISE * (k + 1)


static func far_z(k: int) -> int:
	"""The far (downhill) edge of L0 (k = -1) or T_k."""
	return L0_FAR_Z if k < 0 else T0_FAR_Z - RUN * k


static func translation(k: int) -> Vector3i:
	"""T_k is T0 translated by this (ADR 1209); only its posts differ."""
	return Vector3i(0, -RISE * k, -RUN * k)


static func row_of(k: int) -> int:
	"""The row holding T_k's deck: each tread lies wholly in one row, two treads a row."""
	@warning_ignore("integer_division") var row: int = (-L0_FAR_Z + RUN * k) / QUANTUM
	return row if k >= 0 else -1


static func row_count(steps: int) -> int:
	"""L0's two rows, the treads and the run-out, in whole rows; -1 when `steps` is not valid."""
	if not valid(steps): return -1
	var length: int = -L0_FAR_Z + RUN * tread_count(steps) + RUN_OUT
	return _ceil_div(length, QUANTUM)


static func floor_depth(steps: int, row: int) -> int:
	"""Cubes cut per column in `row`: L0's rows one; a tread row the least quanta that keep the post of its deeper
	tread, T_(2(row - 2) + 1), at least MIN_POST long, never below the level floor. The cap is what puts the sill's
	row and the run-out on the floor: there the formula passes it (the sill's own "post" would be -64, D1). -1 outside
	the flight."""
	if not valid(steps) or row < 0 or row >= row_count(steps): return -1
	if row < LANDING_ROWS: return 1
	var deeper_top: int = RISE * (2 * (row - LANDING_ROWS) + 2)
	return mini(_ceil_div(deeper_top + DECK_AND_BEARER + MIN_POST, QUANTUM), bottom_depth(steps))


static func floor_y(steps: int, row: int) -> int:
	"""The cut floor of `row`, source-local; 1 when `row` is outside the flight (never a floor)."""
	var depth: int = floor_depth(steps, row)
	return -QUANTUM * depth if depth >= 0 else 1


static func is_sill(steps: int, k: int) -> bool:
	"""The last tread: T0's deck and bearers, the bearers cut to 64 u, no posts (D1)."""
	return valid(steps) and k == sill(steps)


static func post_length(steps: int, k: int) -> int:
	"""T_k's post from deck bearer to its row's floor; -1 for no tread. The sill has no posts (D1) and returns 0: read
	`is_sill` before emitting a post part, never a zero-length one."""
	if not is_tread(steps, k): return -1
	if is_sill(steps, k): return 0
	return QUANTUM * floor_depth(steps, row_of(k)) - RISE * (k + 1) - DECK_AND_BEARER


static func stop(k: int, behind: int) -> Vector3i:
	"""A stop on L0 (k = -1) or T_k, `behind` u behind its far edge on the centre line (as tread_geometry.gd)."""
	return Vector3i(0, top_y(k), far_z(k) + behind)


static func floor_stop_into(steps: int, beyond: int, out: PackedInt32Array) -> bool:
	"""A stop on the flight's floor, `beyond` u past the sill's far edge (U 169, F 343, F' 686), as [x, y, z]; false,
	and `out` untouched, for an invalid flight, a mis-sized packet or a point outside the run-out."""
	if not valid(steps) or out.size() != 3 or beyond <= 0 or far_z(sill(steps)) - beyond <= end_wall_z(steps):
		return false
	out[0] = 0
	out[1] = -drop_u(steps)
	out[2] = far_z(sill(steps)) - beyond
	return true


static func end_wall_z(steps: int) -> int:
	"""The run-out's end: the slot's last row boundary."""
	return -QUANTUM * row_count(steps) if valid(steps) else 1


static func cube_count(steps: int) -> int:
	"""Every cut cube of the slot: two columns, each row its depth; -1 when `steps` is not valid."""
	if not valid(steps): return -1
	var total: int = 0
	for row: int in row_count(steps):
		total += floor_depth(steps, row)
	return WIDTH_CUBES * total


static func deep_cube_count(steps: int) -> int:
	"""Cubes below the stair top's first metre: those no station on the land can strike (decision 2041 F7)."""
	return cube_count(steps) - WIDTH_CUBES * row_count(steps) if valid(steps) else -1


static func cubes_into(steps: int, out: PackedInt32Array) -> bool:
	"""Every cut cube as a source-local box [x0, y0, z0, x1, y1, z1] in storage order: by row, then column (-x first),
	then layer from the top down. This is not a dig order (decision 2043 §3 sets that). False, and `out` untouched,
	when `steps` is not valid."""
	if not valid(steps): return false
	out.resize(6 * cube_count(steps))
	var at: int = 0
	for row: int in row_count(steps):
		for column: int in WIDTH_CUBES:
			for layer: int in floor_depth(steps, row):
				_write_cube(out, at, -HALF_WIDTH + QUANTUM * column, layer, row)
				at += 6
	return true


static func _write_cube(out: PackedInt32Array, at: int, x0: int, layer: int, row: int) -> void:
	"""One cube's box at `at`, written in place."""
	out[at] = x0
	out[at + 1] = -QUANTUM * (layer + 1)
	out[at + 2] = -QUANTUM * (row + 1)
	out[at + 3] = x0 + QUANTUM
	out[at + 4] = -QUANTUM * layer
	out[at + 5] = -QUANTUM * row


static func tread_cubes(steps: int, k: int) -> int:
	"""T_k's share of the cut: half its row across both columns, so its row's depth in cubes; -1 for no tread."""
	return floor_depth(steps, row_of(k)) if is_tread(steps, k) else -1


static func top_landing_cubes(steps: int) -> int:
	"""L0's two rows, one cube deep, two columns."""
	return WIDTH_CUBES * LANDING_ROWS if valid(steps) else -1


static func bottom_landing_cubes(steps: int) -> int:
	"""The run-out: every cube not L0's and not a tread's (the sill row's second half and the rows past it)."""
	if not valid(steps): return -1
	var treads: int = 0
	for k: int in tread_count(steps):
		treads += tread_cubes(steps, k)
	return cube_count(steps) - top_landing_cubes(steps) - treads


static func part_count(steps: int) -> int:
	"""L0 and every tread at seven parts, the sill at three (tread_geometry.gd); -1 when `steps` is not valid."""
	return PARTS_PER_ASSEMBLY * tread_count(steps) + SILL_PARTS if valid(steps) else -1


static func fixture_bill_into(steps: int, out: PackedInt64Array) -> bool:
	"""The fixture recipe: L0, T0 and every later tread (sill included) at their bills (D3; DEC-059's 5,640 milli-WU
	for each tread after T0). No stone, no earth."""
	if not valid(steps) or out.size() != BILL_FIELDS: return false
	out[BILL_WOOD] = L0_WOOD_MILLI + T0_WOOD_MILLI + TREAD_WOOD_MILLI * (tread_count(steps) - 1)
	out[BILL_STONE] = 0
	out[BILL_WORK] = L0_WORK_MWU + T0_WORK_MWU + TREAD_WORK_MWU * (tread_count(steps) - 1)
	out[BILL_EARTH] = 0
	return true


static func excavation_bill_into(steps: int, out: PackedInt64Array) -> bool:
	"""SET-BUILD-001 §7.2 per cube: brace wood and stone, brace + cut + finish work, earth out."""
	if not valid(steps) or out.size() != BILL_FIELDS: return false
	_price_cubes(cube_count(steps), out)
	return true


static func _price_cubes(cubes: int, out: PackedInt64Array) -> void:
	"""SET-BUILD-001 §7.2's price of `cubes` cut cubes into a checked packet."""
	out[BILL_WOOD] = cubes * Contract.BRACE_WOOD_MILLI
	out[BILL_STONE] = cubes * Contract.BRACE_STONE_MILLI
	out[BILL_WORK] = cubes * (Contract.BRACE_WORK_MWU + Contract.CUT_WORK_MWU + Contract.FINISH_WORK_MWU)
	out[BILL_EARTH] = cubes * Contract.EARTH_MILLI


static func total_bill_into(steps: int, out: PackedInt64Array) -> bool:
	"""The connector's whole bill (SET-BUILD-001 §9): the excavation plus the fixture recipe."""
	var fixtures: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	if not fixture_bill_into(steps, fixtures) or not excavation_bill_into(steps, out): return false
	for field: int in BILL_FIELDS:
		out[field] += fixtures[field]
	return true


static func layout_valid(layout: int) -> bool:
	"""M5 (ruled, P-2043-1 (a)), its M2 interim (2044 P-2044-15) or F40 (the record of P-DF-2 (a))."""
	return _modular(layout) or layout == LAYOUT_F40


static func _modular(layout: int) -> bool:
	"""M5 or M2: the 1 m module repeated, module j translated by (0, -1024j, -5120j)."""
	return layout == LAYOUT_M5 or layout == LAYOUT_M2


static func _modules(layout: int) -> int:
	"""Modules of a modular layout: five for M5, two for M2."""
	return M5_MODULES if layout == LAYOUT_M5 else M2_MODULES


static func module_count(layout: int) -> int:
	"""Five modules for M5; F40 is one continuous flight; -1 for no layout."""
	if not layout_valid(layout): return -1
	return _modules(layout) if _modular(layout) else 1


static func module_translation(layout: int, module: int) -> Vector3i:
	"""Where module `module` sits relative to the first: (0, -1024j, -5120j) for M5. (0, 1, 0) means no module and is
	never a placement: a caller placing parts checks `module < module_count(layout)` first."""
	if module < 0 or module >= module_count(layout): return Vector3i(0, 1, 0)
	return Vector3i(0, -MODULE_DROP * module, -QUANTUM * MODULE_ROWS * module)


static func layout_row_count(layout: int) -> int:
	"""M5: L0's two rows and five modules of five rows (27); F40: 23; -1 for no layout."""
	if layout == LAYOUT_F40: return row_count(F40_STEPS)
	return LANDING_ROWS + _modules(layout) * MODULE_ROWS if _modular(layout) else -1


static func layout_floor_depth(layout: int, row: int) -> int:
	"""Cubes cut per column in `row`, open to the sky: M5's module j cuts its five rows to depth j + 1, L0's rows one;
	-1 outside the flight."""
	if layout == LAYOUT_F40: return floor_depth(F40_STEPS, row)
	if not _modular(layout) or row < 0 or row >= layout_row_count(layout): return -1
	if row < LANDING_ROWS: return 1
	@warning_ignore("integer_division") var module: int = (row - LANDING_ROWS) / MODULE_ROWS
	return module + 1


static func layout_foot_rows(layout: int) -> int:
	"""Decision 2046: the widened foot's rows, counted back from the end wall: M5's last two; none for M2 or F40; -1
	for no layout."""
	if not layout_valid(layout): return -1
	return FOOT_ROWS if layout == LAYOUT_M5 else 0


static func layout_foot_half_width(layout: int) -> int:
	"""Decision 2046: the cut's half width over the foot rows: 2,048 u for M5, the slot's 1,024 u otherwise; -1 for no
	layout."""
	if not layout_valid(layout): return -1
	return FOOT_HALF_WIDTH if layout == LAYOUT_M5 else HALF_WIDTH


static func layout_row_width_cubes(layout: int, row: int) -> int:
	"""Decision 2046: cubes across `row`: four on M5's foot rows, the slot's two elsewhere; -1 outside the flight."""
	if layout_floor_depth(layout, row) < 0: return -1
	var foot: bool = row >= layout_row_count(layout) - layout_foot_rows(layout)
	@warning_ignore("integer_division") var across: int = 2 * layout_foot_half_width(layout) / QUANTUM
	return across if foot else WIDTH_CUBES


static func layout_tread_count(layout: int) -> int:
	"""M5: seven treads (T0-T5 and the sill) a module, 35; F40: 39; -1 for no layout."""
	if layout == LAYOUT_F40: return tread_count(F40_STEPS)
	return _modules(layout) * tread_count(FIRST_ENTRY_STEPS) if _modular(layout) else -1


static func tread_module(layout: int, tread: int) -> int:
	"""The module holding the layout's tread `tread` (0-based along the flight); -1 for no tread."""
	if tread < 0 or tread >= layout_tread_count(layout): return -1
	@warning_ignore("integer_division") var module: int = tread / tread_count(FIRST_ENTRY_STEPS)
	return module if _modular(layout) else 0


static func tread_k(layout: int, tread: int) -> int:
	"""The tread's index inside its module (T_k of `tread_geometry.gd`); -1 for no tread."""
	if tread_module(layout, tread) < 0: return -1
	return tread % tread_count(FIRST_ENTRY_STEPS) if _modular(layout) else tread


static func _module_steps(layout: int) -> int:
	"""The `steps` of one module's geometry: 8 for M5, 40 for F40."""
	return FIRST_ENTRY_STEPS if _modular(layout) else F40_STEPS


static func layout_is_sill(layout: int, tread: int) -> bool:
	"""M5 ends each module with a sill (D1); F40 has one, at its foot. No tread (`tread_k` -1) is no sill."""
	return is_sill(_module_steps(layout), tread_k(layout, tread))


static func layout_is_t0(layout: int, tread: int) -> bool:
	"""A T0, installed from L0 or a natural landing and priced at T0's bill (P-DF-4 (a)): one a module."""
	return tread_k(layout, tread) == 0


static func layout_post_length(layout: int, tread: int) -> int:
	"""The tread's post (0 for a sill: read `layout_is_sill` first); -1 for no tread."""
	if tread_module(layout, tread) < 0: return -1
	return post_length(_module_steps(layout), tread_k(layout, tread))


static func layout_tread_top_y(layout: int, tread: int) -> int:
	"""The tread's walking surface, source-local; 1 for no tread."""
	if tread_module(layout, tread) < 0: return 1
	return top_y(tread_k(layout, tread)) + module_translation(layout, tread_module(layout, tread)).y


static func layout_tread_far_z(layout: int, tread: int) -> int:
	"""The tread's far (downhill) edge, source-local; 1 for no tread."""
	if tread_module(layout, tread) < 0: return 1
	return far_z(tread_k(layout, tread)) + module_translation(layout, tread_module(layout, tread)).z


static func layout_end_wall_z(layout: int) -> int:
	"""The last run-out's end; 1 for no layout."""
	return -QUANTUM * layout_row_count(layout) if layout_valid(layout) else 1


static func layout_floor_stop_into(layout: int, beyond: int, out: PackedInt32Array) -> bool:
	"""A stop on the level floor `beyond` u past the last sill's far edge (U 169, F 343, F' 686), as [x, y, z]: the
	last module's own floor stop moved by its translation. False, `out` untouched, on any refusal."""
	if not layout_valid(layout) or out.size() != 3: return false
	var local: PackedInt32Array = PackedInt32Array([0, 0, 0])
	if not floor_stop_into(_module_steps(layout), beyond, local): return false
	var moved: Vector3i = module_translation(layout, module_count(layout) - 1)
	for axis: int in 3:
		out[axis] = local[axis] + moved[axis]
	return true


static func landing_stop_into(layout: int, module: int, behind: int, out: PackedInt32Array) -> bool:
	"""A stop on module `module`'s natural landing (module >= 1: the previous module's run-out), `behind` u behind
	its T0's near edge, as [x, y, z]; the landing is RUN_OUT long. False, `out` untouched, otherwise."""
	if not _modular(layout) or module < 1 or module >= _modules(layout) or out.size() != 3: return false
	if behind <= 0 or behind >= RUN_OUT: return false
	var at: Vector3i = stop(-1, behind) + module_translation(layout, module)
	for axis: int in 3:
		out[axis] = at[axis]
	return true


static func layout_cube_count(layout: int) -> int:
	"""Every cut cube: each row's columns (decision 2046: four on M5's foot rows) times its depth; -1 for no layout."""
	if not layout_valid(layout): return -1
	var total: int = 0
	for row: int in layout_row_count(layout):
		total += layout_row_width_cubes(layout, row) * layout_floor_depth(layout, row)
	return total


static func layout_deep_cube_count(layout: int) -> int:
	"""Cubes below the top metre (decision 2041 F7): every cube but one a column a row."""
	if not layout_valid(layout): return -1
	var top: int = 0
	for row: int in layout_row_count(layout):
		top += layout_row_width_cubes(layout, row)
	return layout_cube_count(layout) - top


static func layout_cubes_into(layout: int, out: PackedInt32Array) -> bool:
	"""Every cut cube as a box, in the same storage order as `cubes_into` (not a dig order): by row, then column from
	-x (decision 2046: four on M5's foot rows), then layer from the top. False, `out` untouched, for no layout."""
	if not layout_valid(layout): return false
	out.resize(6 * layout_cube_count(layout))
	var at: int = 0
	for row: int in layout_row_count(layout):
		var across: int = layout_row_width_cubes(layout, row)
		@warning_ignore("integer_division") var west: int = -QUANTUM * across / 2
		for column: int in across:
			for layer: int in layout_floor_depth(layout, row):
				_write_cube(out, at, west + QUANTUM * column, layer, row)
				at += 6
	return true


static func layout_part_count(layout: int) -> int:
	"""L0's seven parts, seven a tread and three a sill: M5 7 + 5 x (6 x 7 + 3) = 232; F40 276; -1 for no layout."""
	if layout == LAYOUT_F40: return part_count(F40_STEPS)
	if not _modular(layout): return -1
	return PARTS_PER_ASSEMBLY + _modules(layout) * (PARTS_PER_ASSEMBLY * (tread_count(FIRST_ENTRY_STEPS) - 1) + SILL_PARTS)


static func layout_fixture_bill_into(layout: int, out: PackedInt64Array) -> bool:
	"""One L0, one T0 a module at T0's bill, every other tread at D3 / DEC-059's (P-DF-4 (a))."""
	if not layout_valid(layout) or out.size() != BILL_FIELDS: return false
	var t0s: int = module_count(layout)
	var others: int = layout_tread_count(layout) - t0s
	out[BILL_WOOD] = L0_WOOD_MILLI + T0_WOOD_MILLI * t0s + TREAD_WOOD_MILLI * others
	out[BILL_STONE] = 0
	out[BILL_WORK] = L0_WORK_MWU + T0_WORK_MWU * t0s + TREAD_WORK_MWU * others
	out[BILL_EARTH] = 0
	return true


static func layout_total_bill_into(layout: int, out: PackedInt64Array) -> bool:
	"""The connector's whole bill: §7.2 per cube plus the fixture recipe. False, `out` untouched, on refusal."""
	var fixtures: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	if out.size() != BILL_FIELDS or not layout_fixture_bill_into(layout, fixtures): return false
	_price_cubes(layout_cube_count(layout), out)
	for field: int in BILL_FIELDS:
		out[field] += fixtures[field]
	return true


static func _ceil_div(value: int, divisor: int) -> int:
	"""Positive integer ceiling division (both arguments positive here)."""
	@warning_ignore("integer_division") var quotient: int = (value + divisor - 1) / divisor
	return quotient
