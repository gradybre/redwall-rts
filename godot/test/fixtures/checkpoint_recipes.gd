extends RefCounted
## The named test checkpoints and how each one is replayed from tick 0 (decision 1240).
##
## `test/generate_checkpoints.gd` runs a recipe once and commits its saves through
## `checkpoint_store.gd`; `test_checkpoint_equivalence.gd` (slow tier) runs it again and requires
## the committed files to be byte-identical to the replay. A suite that starts from a checkpoint
## loads it with `Store.load_into()` instead of replaying the same ticks itself.
##
## Every recipe drives the GameManager AUTOLOAD exactly as its suites did (100 ms frames, three
## ticks each), saves at the frame boundary where each named point first holds, and hands the
## autoload back at tick 0 (decision 1236). Load this script at run time: it names the autoload.
##
##   underground_entry  first_brace_after_2000  the live entry chain in a funded BRACE phase
##                      first_install           the chain's first installed connector group
##
## Only a replay that costs much more than a load (about 1-2 s) earns a recipe. The generated surface
## settlement reaches ARCH-SAVE-006's fork (tick 3000) in 1.7 s, so test_settlement_save_parity keeps
## its own prologue (decision 1240).

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
const NAMES: PackedStringArray = [UNDERGROUND]
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


class Built:
	"""A recipe's replay: point name -> [tick, save bytes], or why it failed."""
	var points: Dictionary = {}
	var error: String = ""


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
	if refused != &"":
		built.error = "%s: the chain did not start (%s)" % [UNDERGROUND, refused]
	elif GameManager.bind_simulation(host.run_tick, host.run_day_boundary):
		_drive_underground(built, host)
	else:
		built.error = "%s: bind refused %s" % [UNDERGROUND, GameManager.last_refusal()]
	host.free()
	_release(built)
	return built


static func _drive_underground(built: Built, host: Node) -> void:
	"""Advance frame by frame until every point has been saved or UNDERGROUND_LIMIT passes."""
	while GameManager.clock().completed_tick() < UNDERGROUND_LIMIT and built.points.size() < 2:
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
			GameManager.bind_simulation(host.run_tick, host.run_day_boundary)
	GameManager.unbind_simulation()
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
