extends "res://test/framework/test_case.gd"
## ADR 1229: the T1-T6 bundle (`qualified-stairs-v8`, increment 6; v7 lacked the seventh row's CUT group) through
## the actual Catalog, Recipes, Assemblies and Frontier readers, against content 10 loaded in a fixture Profiles store.
## The mounted Session runs this very bundle; nothing here grants a Location, route or Job.

const Host := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-stairs-v9/catalog_source.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd")
const CAPACITIES: Vector3i = Vector3i(67, 547, 6)

var _host: Host = null
var _content: Content = null
var _session: Session = null
var _profiles: Profiles = null
var _catalog: Catalog = null
var _assemblies: Assemblies = null
var _recipes: Recipes = null
var _frontier: Frontier = null


func before_each() -> void:
	"""The original mounted owners supply World, levels and Movement; content 9 is a separate fixture store."""
	_host = Host.new()
	_content = Content.new()
	assert_equal(_content.load_file(Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA, Session.PRESENTATION_BYTES), &"",
		"actual supplied source image")
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "actual generated settlement")
	assert_true(_host.mount_underground(_content), "original mounted source: %s" % _host.last_refusal())
	_session = _host.underground_session()
	assert_true(_host.compose_underground_room_owners(), "actual Room owners")
	assert_true(_host.compose_underground_route_owners(), "actual ground owners")
	_profiles = _content_ten()
	var o: Session.Retirement.Owners = _session._retirement_owners
	_catalog = Catalog.new()
	assert_equal(_catalog.configure(Catalog.RESERVED_BYTES), &"", "full catalog reservation")
	assert_equal(_catalog.bind_actual(_profiles, o.world_routes._levels, o.world_routes._movement, o.residents,
		o.transforms, o.space._domain), &"", "content 9 with the original World owners")


func after_each() -> void:
	"""Release the readers before the original owner graph."""
	_frontier = null
	_assemblies = null
	_recipes = null
	_catalog = null
	_profiles = null
	_session = null
	_content = null
	if _host != null: _host.free()
	_host = null


func _content_ten() -> Profiles:
	"""Content 10 through the actual loader, in its exact capacity."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (CAPACITIES.x * Profiles.PROFILE_WIRE_BYTES + CAPACITIES.y * 28 + CAPACITIES.z * 32 + 32)
	assert_equal(store.configure(CAPACITIES.x, CAPACITIES.y, CAPACITIES.z, packed + Profiles.CONTROL_RESERVE), &"",
		"capacity")
	assert_equal(store.load_file(Bundle.PROFILE_PATH, Bundle.PROFILE_SHA, 10), &"", "content 10")
	return store


func _readers() -> void:
	"""Structure, bills and the Frontier through the actual readers."""
	assert_equal(_catalog.load_file(Bundle.CATALOG_PATH, Bundle.CATALOG_SHA, 1), &"", "stair structure on source 4")
	_recipes = Recipes.new()
	assert_equal(_recipes.configure(Recipes.MAX_PARTS, Recipes.required_bytes(Recipes.MAX_PARTS)), &"", "recipe arena")
	assert_equal(_recipes.bind_actual(_catalog, _host.item_definitions(), _host.inventory()), &"", "registration")
	assert_equal(_recipes.load_file(Bundle.RECIPE_PATH, Bundle.RECIPE_SHA, 1, Bundle.GROUPING_SHA, 1), &"", "recipes")
	_assemblies = Assemblies.new()
	assert_equal(_assemblies.configure(Assemblies.MAX_GROUPS, Assemblies.required_bytes(Assemblies.MAX_GROUPS)), &"",
		"group arena")
	assert_equal(_assemblies.bind_actual(_catalog, _recipes, _host.item_definitions(), _host.inventory()), &"", "bills")
	assert_equal(_assemblies.load_file(Bundle.GROUPING_PATH, Bundle.GROUPING_SHA, 1, Bundle.RECIPE_SHA, 1), &"", "groups")
	_frontier = Frontier.new()
	var capacities: PackedInt32Array = PackedInt32Array([Bundle.INSTALL_COUNT, Bundle.STATION_COUNT, Bundle.CUT_COUNT,
		Bundle.BEARING_COUNT, Bundle.ENDPOINT_COUNT, Bundle.EPISODE_COUNT])
	assert_equal(_frontier.configure(capacities, Frontier.required_bytes(capacities)), &"", "Frontier capacity")
	assert_equal(_frontier.bind_actual(_catalog, _assemblies, _recipes, _profiles), &"", "source chain")


func test_structure_carries_the_flight_and_the_stair_paces() -> void:
	"""Content 10 on source 4; 52 parts in eight assemblies; content 10's ground caps and DEC-050's three stair rows."""
	_readers()
	assert_equal([_catalog._live.header[8], _catalog._live.header[10], _catalog._live.header[7]], [10, 4, 29],
		"content, source, paces")
	var pace: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	for row: Vector2i in [Vector2i(Pins.CLAW_DESCENT_ROW, 528), Vector2i(Pins.CLAW_ASCENT_ROW, 528),
			Vector2i(Pins.CLAW_TURN_ROW, 116)]:
		assert_equal(_catalog.pace_into(row.x, 1, 10, 0, 0, 1, pace), &"", "authored pace %d" % row.x)
		assert_equal(pace.value, row.y, "DEC-050 rate of row %d" % row.x)
	assert_equal(_assemblies._header[5], 8, "L0, T0..T6")
	var o: Session.Retirement.Owners = _session._retirement_owners
	assert_equal([o.world_routes._catalog._live.header[8], o.world_routes._catalog._live.digests.decode_s64(0)],
		[Bundle.CONTENT_REVISION, Bundle.CATALOG_DIGEST_0], "the mounted structure is this bundle's")


func test_frontier_loads_the_tread_installs_and_stops() -> void:
	"""Eight installs; each tread's station is its derived stop on the tread above, on the tread fitting tap."""
	_readers()
	assert_equal(_frontier.load_file(Bundle.FRONTIER_PATH, Bundle.FRONTIER_SHA, Bundle.FRONTIER_REVISION), &"",
		"actual Frontier reader")
	var install: PackedInt32Array = PackedInt32Array(); install.resize(9)
	var station: PackedInt32Array = PackedInt32Array(); station.resize(9)
	var revision: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	for assembly: int in range(2, 8):
		assert_equal(_frontier.installation_into(assembly, install), &"", "install %d" % assembly)
		assert_equal(_frontier.station_into(install[1], station, revision), &"", "station")
		assert_equal(Vector3i(station[1], station[2], station[3]), Tread.station_of(assembly), "derived station")
		assert_equal([station[4], station[5]], [0, Pins.CLAW_TREAD_TAP_ROW], "tread fitting tap, facing down")


func test_workpieces_name_the_derived_tread_bearers() -> void:
	"""Rows 65 for L0/T0 and 66 for every tread, with TreadGeometry's part, turn and translation."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(Bundle.WORKPIECES_PATH)
	assert_equal(FileAccess.get_sha256(Bundle.WORKPIECES_PATH), Bundle.WORKPIECES_SHA, "pinned bytes")
	assert_equal([bytes.decode_s64(52), bytes.decode_s64(76)], [10, 5], "content 10, paw source")
	for assembly: int in 8:
		var at: int = 212 + 32 * assembly
		assert_equal(bytes.decode_s32(at + 20), Pins.PAW_HANDLING_ROW if assembly < 2 else Pins.PAW_TREAD_HANDLING_ROW,
			"set-down row of %d" % assembly)
		if assembly < 2: continue
		assert_equal([bytes.decode_s32(at), bytes.decode_s32(at + 4)], [Tread.bearer_part(assembly), 3], "part, turn")
		assert_equal(Vector3i(bytes.decode_s32(at + 8), bytes.decode_s32(at + 12), bytes.decode_s32(at + 16)),
			Tread.bearer_translation(assembly), "translation")
