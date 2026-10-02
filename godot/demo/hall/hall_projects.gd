extends RefCounted
## THE HALL'S PROJECTS (decision 0771): its tier, the tier-2 upgrade and the banners, each a construction project with
## materials and work (hall_rules.gd). Presentation only: integer state in packed columns, nothing written into the
## simulation. The builders (hall_crew.gd) carry and work; this model only counts, and refuses in words.
##
## A PROJECT is NONE (not planned), DELIVERING (its materials being carried in), BUILDING (all delivered; work under
## way) or DONE (a banner hung; the upgrade raised). Per project and material it keeps what is DELIVERED to the hall,
## what is in TRANSIT (in a carrier's arms, taken from the stores) and what is RESERVED (a carrier on its way to fetch
## it: nothing is taken from the stores until it is lifted, REQ-SET-124). Every milli-U is in exactly one place --
## the stores, a reservation's source, a carrier's arms or the project -- until the project is done (`conserved`).
##
## THE ONE UPGRADE. `plan_upgrade` refuses at tier 2 (BAL-SAFE-013: "a second application SHALL be refused"; §5.9:
## "Only one upgrade per building; tier 3 is absent"), while locked (hall_rules.gd THE UNLOCK) and while planned.
## `cancel` gives back REQ-SET-126's share of what was delivered, and any load still in arms whole, never having been
## delivered; the crew then lets its carriers go (hall_crew.gd `release_project`), setting down nothing more.
##
## THE CLOTH is the village's one cloth in the stores (tunnel_stores.gd CLOTH, decision 0993): a carrier setting off for
## cloth reserves it there under the hall's claim, so the infirmary and the treatments cannot take it meanwhile.

const Rules := preload("res://demo/hall/hall_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

const PHASE_NONE: int = 0
const PHASE_DELIVERING: int = 1
const PHASE_BUILDING: int = 2
const PHASE_DONE: int = 3
const PHASE_WORDS: Array[String] = ["not planned", "materials being carried in", "being built", "done"]

const REFUSE_SECOND: String = "The hall has had its one upgrade: there is no tier 3 (GDD §5.9)"
const REFUSE_PLANNED: String = "The upgrade is planned already"
const REFUSE_LOCKED: String = "The upgrade opens %s"
const REFUSE_BANNERS_FULL: String = "All four banners are hung or planned: decorations add at most 1000 comfort"
const REFUSE_NOTHING: String = "Nothing to cancel there"
const REFUSE_DONE: String = "It is finished: nothing to cancel"

## The hall's tier (hall_rules.gd TIER_*).
var tier: int = Rules.TIER_REFUGE
## Whether the upgrade may be planned (hall_rules.gd THE UNLOCK; the hall node sets it).
var unlocked: bool = Rules.UNLOCK_CONDITION == Rules.UNLOCK_AT_START
## The village's cloth, milli-U: the stores' one cloth (see THE CLOTH), read through.
var cloth_milli: int:
	get:
		return _stores.cloth_milli_u
## Per project: its phase, its generation (bumped whenever it is planned or cancelled), and its work done (demo usec).
var phase: PackedByteArray = PackedByteArray()
var generation: PackedInt32Array = PackedInt32Array()
var work_usec: PackedInt64Array = PackedInt64Array()
## Per project x material (project * MAT_COUNT + mat), milli-U.
var delivered: PackedInt64Array = PackedInt64Array()
var transit: PackedInt64Array = PackedInt64Array()
var reserved: PackedInt64Array = PackedInt64Array()
## The calendar tick each project was finished at (-1: not finished).
var done_tick: PackedInt64Array = PackedInt64Array()
## What came back at the last cancel, in words ("" none).
var last_refund: String = ""
## Bumped on every change, so readers redraw only when something changed.
var revision: int = 0

var _stores: StoresScript = null
## `done(project)`: told once when a project is finished (the hall node's chronicle).
var _on_done: Callable = Callable()


func _init(stores: StoresScript) -> void:
	"""Projects paid from these village stores (wood, stone and the village's one cloth)."""
	_stores = stores
	phase.resize(Rules.PROJECT_COUNT)
	generation.resize(Rules.PROJECT_COUNT)
	work_usec.resize(Rules.PROJECT_COUNT)
	done_tick.resize(Rules.PROJECT_COUNT)
	done_tick.fill(-1)
	var cells: int = Rules.PROJECT_COUNT * Rules.MAT_COUNT
	delivered.resize(cells)
	transit.resize(cells)
	reserved.resize(cells)


func set_done_hook(hook: Callable) -> void:
	"""`hook(project: int)` is called once when a project is finished."""
	_on_done = hook


# --- reading ----------------------------------------------------------------------------------------------------

func is_active(project: int) -> bool:
	"""Whether `project` is being delivered or built."""
	return Rules.is_project(project) and (phase[project] == PHASE_DELIVERING or phase[project] == PHASE_BUILDING)


func banners_hung() -> int:
	"""How many banners are hung."""
	var n: int = 0
	for p: int in range(Rules.PROJECT_BANNER_FIRST, Rules.PROJECT_COUNT):
		n += 1 if phase[p] == PHASE_DONE else 0
	return n


func banners_planned() -> int:
	"""How many banners are planned and not yet hung."""
	var n: int = 0
	for p: int in range(Rules.PROJECT_BANNER_FIRST, Rules.PROJECT_COUNT):
		n += 1 if is_active(p) else 0
	return n


func comfort_target() -> int:
	"""The common room's comfort target now (hall_rules.gd `comfort_target`)."""
	return Rules.comfort_target(tier, banners_hung())


func fuel_permille() -> int:
	"""A hearth's fuel use here now, per mille (hall_rules.gd `fuel_permille`)."""
	return Rules.fuel_permille(tier)


func cell(project: int, mat: int) -> int:
	"""The column index of `project`'s material `mat`."""
	return project * Rules.MAT_COUNT + mat


func outstanding(project: int, mat: int) -> int:
	"""What of `mat` still has nobody fetching it: needed less delivered, in arms and reserved (milli-U)."""
	if not is_active(project) or mat < 0 or mat >= Rules.MAT_COUNT:
		return 0
	var k: int = cell(project, mat)
	return maxi(Rules.need_milli(project, mat) - delivered[k] - transit[k] - reserved[k], 0)


func in_stock(mat: int) -> int:
	"""What the stores hold of `mat` that no carrier has reserved (milli-U): the cloth any claimant has reserved is not
	free (see THE CLOTH)."""
	if mat == Rules.MAT_CLOTH:
		return _stores.cloth_free()
	var held: int = 0
	if mat == Rules.MAT_WOOD:
		held = _stores.wood_milli_u
	elif mat == Rules.MAT_STONE:
		held = _stores.stone_milli_u
	var claimed: int = 0
	for p: int in Rules.PROJECT_COUNT:
		claimed += reserved[cell(p, mat)]
	return maxi(held - claimed, 0)


func fetchable(project: int, mat: int) -> int:
	"""What of `mat` a carrier could set off for now: outstanding and in stock (milli-U)."""
	return mini(outstanding(project, mat), in_stock(mat))


func next_material(project: int) -> int:
	"""The first material of `project` a carrier could set off for now (-1: none)."""
	for mat: int in Rules.MAT_COUNT:
		if fetchable(project, mat) > 0:
			return mat
	return -1


func all_delivered(project: int) -> bool:
	"""Whether every material `project` needs is at the hall."""
	for mat: int in Rules.MAT_COUNT:
		if delivered[cell(project, mat)] < Rules.need_milli(project, mat):
			return false
	return true


func work_total_usec(project: int) -> int:
	"""Project `project`'s whole work in demo usec (one worker's)."""
	return Rules.work_wu(project) * Rules.USEC_PER_WU


func work_left_usec(project: int) -> int:
	"""The work still to do on `project` (demo usec, one worker's)."""
	if phase[project] == PHASE_DONE:
		return 0
	return maxi(work_total_usec(project) - work_usec[project], 0)


func work_done_wu(project: int) -> int:
	"""Whole WU done on `project`."""
	@warning_ignore("integer_division")
	return work_usec[project] / Rules.USEC_PER_WU


func delivered_permille(project: int) -> int:
	"""How much of `project`'s materials is at the hall, by mass, per mille."""
	var need_g: int = 0
	var have_g: int = 0
	for mat: int in Rules.MAT_COUNT:
		need_g += Rules.need_milli(project, mat) * Rules.MAT_GRAMS_PER_U[mat]
		have_g += delivered[cell(project, mat)] * Rules.MAT_GRAMS_PER_U[mat]
	if need_g <= 0:
		return Rules.PERMILLE
	@warning_ignore("integer_division")
	return have_g * Rules.PERMILLE / need_g


func percent(project: int) -> int:
	"""How far `project` is: its delivery while DELIVERING, its work while BUILDING (0-100)."""
	match phase[project]:
		PHASE_DELIVERING:
			@warning_ignore("integer_division")
			return delivered_permille(project) / 10
		PHASE_BUILDING:
			@warning_ignore("integer_division")
			return mini(100, work_usec[project] * 100 / maxi(work_total_usec(project), 1))
		PHASE_DONE:
			return 100
	return 0


func held_total(mat: int) -> int:
	"""Every milli-U of `mat` the village owns: the stores', in arms, and delivered to a project not yet finished
	(`conserved`'s left side)."""
	var total: int = _stores.cloth_milli_u
	if mat == Rules.MAT_WOOD:
		total = _stores.wood_milli_u
	elif mat == Rules.MAT_STONE:
		total = _stores.stone_milli_u
	for p: int in Rules.PROJECT_COUNT:
		if is_active(p):
			total += delivered[cell(p, mat)] + transit[cell(p, mat)]
	return total


# --- planning and cancelling --------------------------------------------------------------------------------------

func upgrade_refusal() -> String:
	"""Why the upgrade cannot be planned now ("" when it can): BAL-SAFE-013, the unlock, or planned already."""
	if tier >= Rules.TIER_GREAT or phase[Rules.PROJECT_UPGRADE] == PHASE_DONE:
		return REFUSE_SECOND
	if is_active(Rules.PROJECT_UPGRADE):
		return REFUSE_PLANNED
	if not unlocked:
		return REFUSE_LOCKED % Rules.UNLOCK_WORDS[Rules.UNLOCK_CONDITION]
	return ""


func plan_upgrade() -> String:
	"""Plan the tier-2 upgrade: "" when planned, else why not (see THE ONE UPGRADE)."""
	var why: String = upgrade_refusal()
	if not why.is_empty():
		return why
	_open(Rules.PROJECT_UPGRADE)
	return ""


func free_banner() -> int:
	"""The first banner project not planned (-1: all four are hung or planned)."""
	for p: int in range(Rules.PROJECT_BANNER_FIRST, Rules.PROJECT_COUNT):
		if phase[p] == PHASE_NONE:
			return p
	return -1


func plan_banner() -> int:
	"""Plan one more banner: its project, or -1 when all four are hung or planned (REFUSE_BANNERS_FULL)."""
	var p: int = free_banner()
	if p >= 0:
		_open(p)
	return p


func last_planned_banner() -> int:
	"""The latest banner planned and not yet hung (-1: none)."""
	for p: int in range(Rules.PROJECT_COUNT - 1, Rules.PROJECT_BANNER_FIRST - 1, -1):
		if is_active(p):
			return p
	return -1


func _open(project: int) -> void:
	"""Project `project` starts DELIVERING, with nothing delivered, carried or reserved."""
	phase[project] = PHASE_DELIVERING
	generation[project] += 1
	work_usec[project] = 0
	done_tick[project] = -1
	_clear_cells(project)
	revision += 1
	if all_delivered(project):
		phase[project] = PHASE_BUILDING


func _clear_cells(project: int) -> void:
	"""Zero `project`'s delivered, transit and reserved columns; a cloth reservation goes back to the stores."""
	_stores.release_cloth(StoresScript.CLOTH_HALL, reserved[cell(project, Rules.MAT_CLOTH)])
	for mat: int in Rules.MAT_COUNT:
		var k: int = cell(project, mat)
		delivered[k] = 0
		transit[k] = 0
		reserved[k] = 0


func cancel(project: int) -> String:
	"""Cancel `project` (REQ-SET-126): its delivered materials come back -- all of them before work began, 80% rounded
	down after -- into the stores; any load in arms comes back whole, never having been
	delivered, so the crew's carriers set down nothing when they are let go after (hall_crew.gd `release_project`,
	called after this by demo_hall.gd). "" when cancelled, else why not."""
	if not Rules.is_project(project) or phase[project] == PHASE_NONE:
		return REFUSE_NOTHING
	if phase[project] == PHASE_DONE:
		return REFUSE_DONE
	var begun: bool = work_usec[project] > 0
	var back := PackedStringArray()
	for mat: int in Rules.MAT_COUNT:
		var refund: int = Rules.refund_milli(delivered[cell(project, mat)], begun)
		_put_back(mat, transit[cell(project, mat)])
		if refund > 0:
			_put_back(mat, refund)
			back.append("%s %s" % [StoresScript.units_text(refund), Rules.MAT_NAMES[mat]])
	last_refund = ", ".join(back) if not back.is_empty() else "nothing"
	phase[project] = PHASE_NONE
	generation[project] += 1
	work_usec[project] = 0
	_clear_cells(project)
	revision += 1
	return ""


func _put_back(mat: int, milli: int) -> void:
	"""Material `mat` comes back into the stores; nothing for none."""
	if milli <= 0:
		return
	if mat == Rules.MAT_WOOD:
		_stores.add_wood(milli)
	elif mat == Rules.MAT_STONE:
		_stores.add_stone(milli)
	else:
		_stores.add_cloth(milli)


# --- carrying -----------------------------------------------------------------------------------------------------

func reserve(project: int, mat: int, want_milli: int) -> int:
	"""A carrier sets off for up to `want_milli` of `mat` for `project`: what it may fetch is reserved (nothing leaves
	the stores yet; cloth is reserved in the stores too, see THE CLOTH). How much (0: nothing to fetch)."""
	var take: int = mini(maxi(want_milli, 0), fetchable(project, mat))
	if mat == Rules.MAT_CLOTH:
		take = _stores.reserve_cloth(StoresScript.CLOTH_HALL, take)
	if take > 0:
		reserved[cell(project, mat)] += take
		revision += 1
	return take


func unreserve(project: int, mat: int, milli: int) -> void:
	"""A carrier gives up a reservation it had not lifted (what the project still holds of it; cloth back to the
	stores' free cloth)."""
	if not Rules.is_project(project) or mat < 0 or mat >= Rules.MAT_COUNT or milli <= 0:
		return
	var k: int = cell(project, mat)
	var freed: int = mini(milli, reserved[k])
	reserved[k] -= freed
	if mat == Rules.MAT_CLOTH:
		_stores.release_cloth(StoresScript.CLOTH_HALL, freed)
	revision += 1


func lift(project: int, mat: int, reserved_milli: int) -> int:
	"""At the stockpile: the reservation becomes a load taken from the stores, as much of it as is there. How much is
	now in arms (0: the stores had none of it; the reservation is gone either way)."""
	unreserve(project, mat, reserved_milli)
	if not is_active(project):
		return 0
	var take: int = mini(reserved_milli, mini(in_stock(mat), outstanding(project, mat)))
	if take <= 0 or not _take_from_stores(mat, take):
		return 0
	transit[cell(project, mat)] += take
	revision += 1
	return take


func _take_from_stores(mat: int, milli: int) -> bool:
	"""Take `milli` of `mat` out of the stores -- all of it, or (false) none."""
	if mat == Rules.MAT_WOOD:
		return _stores.pay(milli, 0)
	if mat == Rules.MAT_STONE:
		return _stores.pay(0, milli)
	return _stores.take_cloth(milli)


func deliver(project: int, mat: int, milli: int) -> void:
	"""A load is set down at the hall: in arms becomes delivered; with everything delivered, building starts
	(REQ-SET-125)."""
	if not is_active(project) or milli <= 0:
		return
	var k: int = cell(project, mat)
	var moved: int = mini(milli, transit[k])
	transit[k] -= moved
	delivered[k] += moved
	if phase[project] == PHASE_DELIVERING and all_delivered(project):
		phase[project] = PHASE_BUILDING
	revision += 1


func return_load(project: int, mat: int, milli: int) -> void:
	"""A load that was never set down at the hall goes back into the stores, whole (a carrier called away, a project
	cancelled)."""
	if not Rules.is_project(project) or mat < 0 or mat >= Rules.MAT_COUNT or milli <= 0:
		return
	var k: int = cell(project, mat)
	var moved: int = mini(milli, transit[k])
	transit[k] -= moved
	_put_back(mat, moved)
	revision += 1


# --- building -----------------------------------------------------------------------------------------------------

func add_work(project: int, usec: int, at_tick: int) -> bool:
	"""Credit `usec` of one builder's work to `project` while it is BUILDING (builders' work sums, §5.9); finished, it
	is DONE -- the upgrade sets tier 2, once -- and the done hook is told. Whether it is finished."""
	if not Rules.is_project(project):
		return false
	if phase[project] != PHASE_BUILDING or usec <= 0:
		return phase[project] == PHASE_DONE
	var before_wu: int = work_done_wu(project)
	var began: bool = work_usec[project] == 0
	work_usec[project] = mini(work_usec[project] + usec, work_total_usec(project))
	if began or work_done_wu(project) != before_wu:
		revision += 1
	if work_usec[project] < work_total_usec(project):
		return false
	_finish(project, at_tick)
	return true


func _finish(project: int, at_tick: int) -> void:
	"""`project` is DONE: its delivered materials are built in; the upgrade raises the hall to tier 2."""
	phase[project] = PHASE_DONE
	done_tick[project] = at_tick
	_clear_cells(project)
	if project == Rules.PROJECT_UPGRADE:
		tier = Rules.TIER_GREAT
	revision += 1
	if _on_done.is_valid():
		_on_done.call(project)
