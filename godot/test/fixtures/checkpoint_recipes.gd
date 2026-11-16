extends RefCounted
## The named test checkpoints and how each one is replayed from tick 0 (decision 1240).
##
## `test/generate_checkpoints.gd` runs a recipe once and commits its saves through
## `checkpoint_store.gd`; `test_checkpoint_equivalence.gd` (slow tier) runs it again and requires
## the committed files to be byte-identical to the replay. A suite that starts from a checkpoint
## loads it with `Store.load_into()` instead of replaying the same ticks itself.
##
## Every recipe drives the GameManager AUTOLOAD as its suites did (underground_entry: 100 ms frames,
## three ticks each; underground_spare: one tick a frame, as the host suites' run_tick loops step),
## saves at the frame boundary where each named point first holds, and hands the autoload back at
## tick 0 (decision 1236). Load this script at run time: it names the autoload.
##
##   underground_entry  first_brace_after_2000  the live entry chain in a funded BRACE phase
##                      first_install           the chain's first installed connector group
##   underground_spare  install_<o>_stage_<s>   the host suites' chain with a spare mole, its crew a few
##                                              ticks into installation <o>'s installer stage <s>
##                                              (decision 1895)
##
## Only a replay that costs much more than a load (about 1-2 s) earns a recipe. The generated surface
## settlement reaches ARCH-SAVE-006's fork (tick 3000) in 0.5 s, so the test_settlement_save_parity_<n>
## suites keep their own prologue (decisions 1240, 1895).

const Store := preload("res://test/fixtures/checkpoint_store.gd")
const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")

## This script and the GameManager autoload: the roots of every recipe's source fingerprint.
const SELF_PATH: String = "res://test/fixtures/checkpoint_recipes.gd"
const GAME_MANAGER_PATH: String = "res://scripts/systems/game_manager.gd"
const UNDERGROUND: String = "underground_entry"
const SPARE: String = "underground_spare"
const NAMES: PackedStringArray = [UNDERGROUND, SPARE]
## 100 ms host frames: exactly three ticks at 1x.
const FRAME_USEC: int = 100000

## By tick 2000 the crew has hauled; the next funded BRACE holds Sites, funding receipts and Router
## state (test_save_underground_columns.gd).
const BRACE_POINT: String = "first_brace_after_2000"
const BRACE_FROM_TICK: int = 2000
## The paid L0 installation's first installed group (test_save_installed_geometry.gd).
const INSTALL_POINT: String = "first_install"
## ADR 1228's goal chain stops by here; every underground point must be reached before it.
const UNDERGROUND_LIMIT: int = 4800
## The foreman's STAGE_EARN: a funded phase is being worked.
const STAGE_EARN: int = 4
## One tick per 1x host frame (30 ticks a second; the 20 debt units left per frame make a second tick only after
## 50,000 frames), so a spare-chain point is saved on the first tick it holds, as the host suites' run_tick loops
## stop on it.
const TICK_USEC: int = 33334
## DEC-057's installer stages ([ordinal, stage]) a crew is lost in (test_underground_host_crew_loss.gd), in the
## order the live chain crosses them. The underground_host_case.gd chain finishes its prefix by tick 3462.
const LOSS_STAGES: Array = [[0, 10], [0, 2], [0, 4], [0, 5], [0, 6], [0, 7], [1, 9]]
const SPARE_LIMIT: int = 8000


class Built:
	"""A recipe's replay: point name -> [tick, save bytes], or why it failed."""
	var points: Dictionary = {}
	var error: String = ""


class Stepper extends RefCounted:
	"""The step a recipe binds to the GameManager clock: the host's run_tick, remembering the first tick it
	refused. GameManager's clock adapter discards run_tick's bool, so without this a refused tick would pass
	unseen through regeneration and the equivalence replay (decision 1895, review M1)."""
	var host: Node = null
	var failed_tick: int = -1

	func _init(settlement: Node) -> void:
		"""Step `settlement`."""
		host = settlement

	func step(tick: int) -> bool:
		"""Run one tick; record it when the settlement refuses it."""
		var ok: bool = host.run_tick(tick)
		if not ok and failed_tick < 0:
			failed_tick = tick
		return ok


static func roots() -> PackedStringArray:
	"""The fingerprint roots shared by every recipe: this script (which preloads the settlement and
	the fixtures) and the one autoload the simulation reaches by name. The UI, economy and entity
	autoloads are not roots: nothing under scripts/core or settlement_system.gd names them, so a HUD
	or art change does not stale a checkpoint (decision 1240)."""
	return PackedStringArray([SELF_PATH, GAME_MANAGER_PATH])


static func build(name: String) -> Built:
	"""Replay recipe `name` from tick 0 and save at each of its points."""
	if name == UNDERGROUND:
		return _build_underground()
	if name == SPARE:
		return _build_spare()
	var unknown: Built = Built.new()
	unknown.error = "no checkpoint recipe named '%s' (known: %s)" % [name, ", ".join(NAMES)]
	return unknown


static func underground_content() -> RefCounted:
	"""The production actor image every underground point re-mounts with on load."""
	return Chain.load_content()


# --- shared steps --------------------------------------------------------------------------------

static func _save_point(built: Built, host: Node, point: String) -> void:
	"""Save `host` at the current boundary as `point`, or record why the save refused."""
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: SaveHeader.Refusal = SettlementSave.save_bytes(host, GameManager, bytes)
	if refusal.is_ok():
		built.points[point] = [GameManager.clock().completed_tick(), bytes]
	elif built.error == "":
		built.error = "%s: save refused %s %s" % [point, refusal.code, refusal.detail]


static func _bind(built: Built, stepper: Stepper, name: String) -> bool:
	"""Bind `stepper` to the autoload clock; a refusal fails the build."""
	if GameManager.bind_simulation(stepper.step, stepper.host.run_day_boundary):
		return true
	if built.error == "":
		built.error = "%s: bind refused %s" % [name, GameManager.last_refusal()]
	return false


static func _check_steps(built: Built, stepper: Stepper, name: String) -> void:
	"""Fail the build when the settlement refused any tick of its replay."""
	if stepper.failed_tick >= 0 and built.error == "":
		built.error = "%s: the settlement refused tick %d: %s" % [name, stepper.failed_tick, stepper.host.last_refusal()]


static func _release(built: Built) -> void:
	"""Hand the autoload back at tick 0; a refusal to do so fails the build."""
	if not AutoloadClockReset.release() and built.error == "":
		built.error = "the GameManager autoload was not handed back at tick 0"


# --- underground_entry ---------------------------------------------------------------------------

static func _build_underground() -> Built:
	"""The live entry chain as test_settlement_save_underground drives it, saved at each point."""
	var built: Built = Built.new()
	var host: Node = Settlement.new()
	var content: RefCounted = Chain.load_content()
	var refused: StringName = &"FIXTURE_CONTENT" if content == null else Chain.mount_and_compose(host, content)
	if refused == &"" and not GameManager.start_game():
		refused = &"FIXTURE_CLOCK"
	if refused == &"":
		refused = Chain.begin_entry(host)
	var stepper: Stepper = Stepper.new(host)
	if refused != &"":
		built.error = "%s: the chain did not start (%s)" % [UNDERGROUND, refused]
	elif _bind(built, stepper, UNDERGROUND):
		_drive_underground(built, stepper)
	host.free()
	_release(built)
	return built


static func _drive_underground(built: Built, stepper: Stepper) -> void:
	"""Advance frame by frame until every point has been saved or UNDERGROUND_LIMIT passes."""
	var host: Node = stepper.host
	while GameManager.clock().completed_tick() < UNDERGROUND_LIMIT and built.points.size() < 2 \
			and stepper.failed_tick < 0 and built.error == "":
		GameManager.advance_host_time(FRAME_USEC)
		var tick: int = GameManager.clock().completed_tick()
		var due: PackedStringArray = PackedStringArray()
		if not built.points.has(BRACE_POINT) and tick >= BRACE_FROM_TICK and is_bracing(host):
			due.append(BRACE_POINT)
		if not built.points.has(INSTALL_POINT) and installed_row(host) >= 0:
			due.append(INSTALL_POINT)
		if not due.is_empty():
			GameManager.unbind_simulation()
			for point: String in due:
				_save_point(built, host, point)
			_bind(built, stepper, UNDERGROUND)
	GameManager.unbind_simulation()
	_check_steps(built, stepper, UNDERGROUND)
	for point: String in [BRACE_POINT, INSTALL_POINT]:
		if not built.points.has(point) and built.error == "":
			built.error = "%s: %s was never reached by tick %d" % [UNDERGROUND, point, UNDERGROUND_LIMIT]


static func is_bracing(host: Node) -> bool:
	"""The entry's foreman is working a funded BRACE phase (its inputs hold funding receipts)."""
	var foreman: RefCounted = host.underground_entry()._foreman
	if foreman == null or foreman._index >= foreman._tasks.size():
		return false
	return foreman._stage == STAGE_EARN \
		and foreman._tasks[foreman._index].operation == foreman.Contract.OP_BRACE


static func installed_row(host: Node) -> int:
	"""The first live Placement with an installed group, or -1."""
	var placements: Placements = host.underground_session()._retirement_owners.placements
	for row: int in placements._capacity:
		if placements._live.present[row] == 1 \
				and placements._get32(placements._live, Placements.INSTALLED, row) > 0:
			return row
	return -1


# --- underground_spare ---------------------------------------------------------------------------

static func loss_point(at: Array) -> String:
	"""The underground_spare point of DEC-057 loss stage `at` ([installation ordinal, installer stage])."""
	return "install_%d_stage_%d" % at


static func spare_points() -> PackedStringArray:
	"""Every underground_spare point, in the order the chain reaches them."""
	var points: PackedStringArray = PackedStringArray()
	for at: Array in LOSS_STAGES:
		points.append(loss_point(at))
	return points


static func installing_at(entry: RefCounted, ordinal: int, stage: int) -> bool:
	"""The crew has spent a few ticks in this installation's installer stage."""
	var foreman: RefCounted = entry._foreman
	var installer: RefCounted = foreman._installer if foreman != null else null
	return installer != null and installer._plan.ordinal == ordinal and installer.stage() == stage \
		and foreman._stage_ticks > 3


static func _build_spare() -> Built:
	"""underground_host_case.gd's `_live_with_spare()` chain, one tick a frame, saved at each loss stage."""
	var built: Built = Built.new()
	var host: Node = Settlement.new()
	var content: RefCounted = Chain.load_content()
	var refused: StringName = &"FIXTURE_CONTENT" if content == null else Chain.mount_and_compose(host, content)
	if refused == &"" and not GameManager.start_game():
		refused = &"FIXTURE_CLOCK"
	if refused == &"":
		refused = Chain.begin_with_spare(host)
	var stepper: Stepper = Stepper.new(host)
	if refused != &"":
		built.error = "%s: the chain did not start (%s)" % [SPARE, refused]
	elif _bind(built, stepper, SPARE):
		_drive_spare(built, stepper)
	host.free()
	_release(built)
	return built


static func _drive_spare(built: Built, stepper: Stepper) -> void:
	"""Advance one tick a frame until every point has been saved, the chain stops or SPARE_LIMIT passes."""
	var host: Node = stepper.host
	var pending: PackedStringArray = spare_points()
	while not pending.is_empty() and host.underground_entry().is_running() and stepper.failed_tick < 0 \
			and GameManager.clock().completed_tick() < SPARE_LIMIT and built.error == "":
		if GameManager.advance_host_time(TICK_USEC) != 1:
			built.error = "%s: a frame did not run exactly one tick" % SPARE
		var due: PackedStringArray = PackedStringArray()
		for at: Array in LOSS_STAGES:
			if pending.has(loss_point(at)) and installing_at(host.underground_entry(), at[0], at[1]):
				due.append(loss_point(at))
		if not due.is_empty():
			GameManager.unbind_simulation()
			for point: String in due:
				_save_point(built, host, point)
				pending.remove_at(pending.find(point))
			_bind(built, stepper, SPARE)
	GameManager.unbind_simulation()
	_check_steps(built, stepper, SPARE)
	if not pending.is_empty() and built.error == "":
		built.error = "%s: %s never reached by tick %d" % [SPARE, ", ".join(pending), SPARE_LIMIT]
