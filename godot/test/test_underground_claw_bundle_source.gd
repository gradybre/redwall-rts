extends "res://test/framework/test_case.gd"
## ADR 1217 step 4e: the claw first-entry bundle (`qualified-claw-v6`) through the actual Catalog, Recipes,
## Assemblies and Frontier readers, against content 9 loaded in a fixture Profiles store. The mounted Session keeps
## content 6: nothing here switches the active content or grants a Location, route or Job.

const Host := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-claw-v6/catalog_source.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-approach-v10/catalog_source.gd")
const Stone := preload("res://data/underground/first-entry-prefix-v1/qualified-stone-v5/catalog_source.gd")
const CAPACITIES: Vector3i = Vector3i(60, 517, 6)
const TRAVEL: PackedInt32Array = [43, 43, 47, 43, 42, 42, 42, 42, 42, 42, 42, 42, 42, 47]

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
	_profiles = _content_nine()
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


func _content_nine() -> Profiles:
	"""Content 9 through the actual loader, in its exact capacity."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (CAPACITIES.x * Profiles.PROFILE_WIRE_BYTES + CAPACITIES.y * 28 + CAPACITIES.z * 32 + 32)
	assert_equal(store.configure(CAPACITIES.x, CAPACITIES.y, CAPACITIES.z, packed + Profiles.CONTROL_RESERVE), &"",
		"capacity")
	assert_equal(store.load_file(Bundle.PROFILE_PATH, Bundle.PROFILE_SHA, 9), &"", "content 9")
	return store


func _readers() -> void:
	"""Structure, bills and the Frontier through the actual readers."""
	assert_equal(_catalog.load_file(Bundle.CATALOG_PATH, Bundle.CATALOG_SHA, 1), &"", "claw structure on source 4")
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
	var capacities: PackedInt32Array = PackedInt32Array([2, 8, 2, 10, Bundle.ENDPOINT_COUNT, 6])
	assert_equal(_frontier.configure(capacities, Frontier.required_bytes(capacities)), &"", "Frontier capacity")
	assert_equal(_frontier.bind_actual(_catalog, _assemblies, _recipes, _profiles), &"", "source chain")


func test_structure_binds_the_claw_source_and_its_ground_caps() -> void:
	"""Content 9 and source 4; the bills keep their wood-only arithmetic; nothing is paid or traversable."""
	_readers()
	assert_equal(_catalog._live.header[8], 9, "content 9")
	assert_equal(_catalog._live.header[10], 4, "claw source")
	assert_equal(_catalog._live.header[7], 24, "ground caps")
	var o: Session.Retirement.Owners = _session._retirement_owners
	assert_equal(o.routes._live.edge_count, 0, "no route")
	assert_equal(o.locations._live.count, 0, "no endpoint")
	assert_equal(o.world_routes._catalog._live.header[8], Stone.CONTENT_REVISION, "the mounted content is unchanged")


func test_frontier_loads_with_claw_stations_at_1430_and_mapped_travel() -> void:
	"""Every cut station stands at x = +-1,430 on a source-4 dig row; installs use the claw tap; travel is mapped."""
	_readers()
	assert_equal(_frontier.load_file(Bundle.FRONTIER_PATH, Bundle.FRONTIER_SHA, Bundle.FRONTIER_REVISION), &"",
		"actual Frontier reader")
	var station: PackedInt32Array = PackedInt32Array(); station.resize(9)
	var revision: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	for index: int in 8:
		assert_equal(_frontier.station_into(index, station, revision), &"", "station")
		var profile: int = station[5]
		assert_equal(_profiles._live.fields[Profiles.F_SOURCE * _profiles._profile_capacity + profile], 4, "source 4")
		if index < 2:
			assert_equal(profile, Pins.CLAW_TAP_ROWS[0], "claw seating tap")
		else:
			assert_equal(absi(station[1]), 1430, "moved in by 106 u")
			assert_equal(profile, Pins.CLAW_DIG_ROWS[3] if station[1] < 0 else Pins.CLAW_DIG_ROWS[1], "dig heading")
	_assert_travel()


func _assert_travel() -> void:
	"""Endpoint travel, like for like: narrow approach, narrow retreat, canonical ground."""
	var profile: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	var revision: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	for index: int in Bundle.ENDPOINT_COUNT:
		assert_equal(_frontier.endpoint_travel_into(index, profile, revision), &"", "travel")
		assert_equal(profile.value, TRAVEL[index], "endpoint %d" % index)


func test_pick_frontier_cannot_bind_content_nine() -> void:
	"""The stone-v5 Frontier names source 0 and content 6: it refuses against the claw structure."""
	_readers()
	assert_equal(_frontier.load_file(Stone.FRONTIER_PATH, Stone.FRONTIER_SHA, Stone.FRONTIER_REVISION),
		Frontier.REFUSE_SOURCE, "content and source are bound")
	assert_equal(_frontier.content_revision(), 0, "nothing published")


func test_workpieces_header_binds_paw_handling_distinct_from_the_frontier() -> void:
	"""The set-down program is source 5, row 59, and its digest differs from the Frontier's source digest."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(Bundle.WORKPIECES_PATH)
	assert_equal(FileAccess.get_sha256(Bundle.WORKPIECES_PATH), Bundle.WORKPIECES_SHA, "pinned bytes")
	assert_equal(bytes.decode_s64(52), 9, "content 9")
	assert_equal(bytes.decode_s64(76), 5, "paw-handling source")
	assert_equal(bytes.slice(180, 212), _profiles._live.sources.slice(160, 192), "source 5 digest")
	assert_true(bytes.slice(180, 212) != _profiles._live.sources.slice(128, 160), "distinct from the Frontier source")
	for row: int in 2:
		assert_equal(bytes.decode_s32(212 + 32 * row + 20), Pins.PAW_HANDLING_ROW, "paw handling set-down")
