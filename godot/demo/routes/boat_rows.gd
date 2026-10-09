extends RefCounted
## BOAT CROSSING ROWS (decision 1821): crossings the route planner may take by boat -- a boat on a fixed route between
## two landings, boarded on a timetable. Presentation over integer rules, like every demo crossing (decision 0196).
##
## A ROW (packed columns, MAX_ROWS rows, sized once): its two landings' land ends (end a, end b; metres, where the
## router's nodes stand), the ride in calendar ticks (deck walks and the row, landing to landing), the longest wait a
## passenger accepts in ticks, and for each landing up to MAX_BOARDINGS upcoming BOARDINGS in ticks from now, strictly
## ascending, each one with a seat free for the walker the row is filled for. A boat row's service (boat_service.gd)
## fills it for each trip; a closed, unstaffed or full boat lists no boardings, and a row with none is not offered.
## Crossing rows ROW0 .. ROW0 + MAX_ROWS - 1 are boat rows (water_crossings.gd); the ferry is row 0 (FERRY_ROW 3500).
##
## WAITING FOR THE BOAT. A bridge costs the same whenever it is reached; a boat does not. The router asks `far_mm` when it
## settles a landing at label `at_mm` (millimetres at the walker's pace, PACE): the walker reaches the landing at tick
## `ticks_to_cover(at_mm, pace)` (rounded up), boards the first boarding at or after it, and stands at the other landing
## at `max(at_mm, boarding) + ride`, both as millimetres at its pace. No boarding listed from then, or a wait longer
## than the row's limit: no crossing (NONE).
##
## WHY THE SEARCH STAYS EXACT. A timetable is FIFO: reaching a landing later never boards earlier. So `far_mm` never falls
## as `at_mm` rises, Dijkstra's labels stay correct, and the router's lazy surface lower bounds (tunnel_router.gd LAZY
## SURFACE COSTS) stay lower bounds through a boat row: an earlier arrival boards no later.
##
## INTEGERS. Ticks and millimetres (or any length unit, with a speed in the same unit a second). The calendar's own
## exact ratio converts them (demo_calendar.gd HOUR_USEC: 25 s, 750 ticks a game hour). Nothing here reads a float.

const SimClock := preload("res://scripts/core/sim_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

## The first boat row's crossing row, and how many there are (rows 3500..3507: clear of the route preview's 3000 and the
## swim ashore's 4000).
const ROW0: int = 3500
const MAX_ROWS: int = 8
## Boardings listed per landing, at most.
const MAX_BOARDINGS: int = 8
const NONE: int = -1
const USEC_PER_SECOND: int = 1000000
const MM_PER_M: int = 1000

## The pace of the walker the rows are filled for (mm a second at its walk, its carry's when loaded).
var pace_mm_s: int = MM_PER_M
var open: PackedByteArray = PackedByteArray()
var land_a: PackedVector2Array = PackedVector2Array()
var land_b: PackedVector2Array = PackedVector2Array()
var ride_ticks: PackedInt32Array = PackedInt32Array()
var max_wait_ticks: PackedInt32Array = PackedInt32Array()
## Per row and landing (row * 2 + end): how many boardings are listed, and the boardings themselves (MAX_BOARDINGS each).
var board_count: PackedInt32Array = PackedInt32Array()
var boards: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	"""Every column sized once for MAX_ROWS rows, all closed."""
	open.resize(MAX_ROWS)
	land_a.resize(MAX_ROWS)
	land_b.resize(MAX_ROWS)
	ride_ticks.resize(MAX_ROWS)
	max_wait_ticks.resize(MAX_ROWS)
	board_count.resize(MAX_ROWS * 2)
	boards.resize(MAX_ROWS * 2 * MAX_BOARDINGS)


static func is_boat_row(row: int) -> bool:
	"""Whether crossing row `row` is a boat row."""
	return row >= ROW0 and row < ROW0 + MAX_ROWS


static func ticks_to_cover(distance: int, speed_per_s: int) -> int:
	"""Calendar ticks to cover `distance` at `speed_per_s` (the same unit a second), rounded up; NONE for no speed."""
	if speed_per_s <= 0:
		return NONE
	var num: int = maxi(distance, 0) * USEC_PER_SECOND * SimClock.TICKS_PER_HOUR
	var den: int = speed_per_s * CalendarScript.HOUR_USEC
	@warning_ignore("integer_division") return (num + den - 1) / den


static func distance_in(ticks: int, speed_per_s: int) -> int:
	"""How far `speed_per_s` goes in `ticks` calendar ticks, rounded down."""
	var num: int = maxi(ticks, 0) * maxi(speed_per_s, 0) * CalendarScript.HOUR_USEC
	@warning_ignore("integer_division") return num / (SimClock.TICKS_PER_HOUR * USEC_PER_SECOND)


func clear_row(r: int) -> void:
	"""Row `r` closed, with no boardings."""
	open[r] = 0
	board_count[r * 2] = 0
	board_count[r * 2 + 1] = 0


func open_row(r: int, end_a: Vector2, end_b: Vector2, ride: int, max_wait: int) -> void:
	"""Row `r` open between `end_a` and `end_b`, its ride `ride` ticks and its longest wait `max_wait`; no boardings yet."""
	clear_row(r)
	open[r] = 1
	land_a[r] = end_a
	land_b[r] = end_b
	ride_ticks[r] = maxi(ride, 0)
	max_wait_ticks[r] = maxi(max_wait, 0)


func add_boarding(r: int, end: int, tick: int) -> bool:
	"""List a boarding at landing `end` (0: a, 1: b) of open row `r`, `tick` ticks from now. False, nothing listed, when
	the row is closed, the landing's list is full, or `tick` is negative or not after the last one listed."""
	var at: int = r * 2 + end
	var n: int = board_count[at]
	if open[r] == 0 or n >= MAX_BOARDINGS or tick < 0:
		return false
	if n > 0 and tick <= boards[at * MAX_BOARDINGS + n - 1]:
		return false
	boards[at * MAX_BOARDINGS + n] = tick
	board_count[at] = n + 1
	return true


func offered(r: int) -> bool:
	"""Whether row `r` is open with a boarding listed at either landing."""
	return open[r] == 1 and board_count[r * 2] + board_count[r * 2 + 1] > 0


func first_boarding(r: int, end: int, from_tick: int) -> int:
	"""The first boarding at landing `end` of row `r` at or after `from_tick` (NONE: none listed)."""
	var at: int = r * 2 + end
	for k: int in board_count[at]:
		var tick: int = boards[at * MAX_BOARDINGS + k]
		if tick >= from_tick:
			return tick
	return NONE


func far_mm(r: int, end: int, at_mm: int) -> int:
	"""Where a walker settled at landing `end` of row `r` at label `at_mm` stands at the other landing, as millimetres at
	`pace_mm_s` (see WAITING FOR THE BOAT); NONE when it cannot board in time."""
	if open[r] == 0:
		return NONE
	var arrive: int = ticks_to_cover(at_mm, pace_mm_s)
	var board: int = first_boarding(r, end, arrive)
	if board == NONE or board - arrive > max_wait_ticks[r]:
		return NONE
	return maxi(at_mm, distance_in(board, pace_mm_s)) + distance_in(ride_ticks[r], pace_mm_s)
