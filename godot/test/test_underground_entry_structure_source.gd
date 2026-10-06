extends "res://test/framework/test_case.gd"
## Real published profile/level sources and real generated Host. No synthetic motion or permission.

const Host := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-install-v3/catalog_source.gd")
# ADR1194: the content-3 structural-v1 bytes are superseded by the same structure rebound to content 4.
const CATALOG_PATH: String = Bundle.CATALOG_PATH
const CATALOG_SHA: String = Bundle.CATALOG_SHA
const GROUP_PATH: String = Bundle.GROUPING_PATH
const GROUP_SHA: String = Bundle.GROUPING_SHA
const RECIPE_PATH: String = Bundle.RECIPE_PATH
const RECIPE_SHA: String = Bundle.RECIPE_SHA

var _host: Host = null
var _content: Content = null
var _session: Session = null
var _catalog: Catalog = null
var _assemblies: Assemblies = null
var _recipes: Recipes = null


func before_each() -> void:
	"""Borrow the original actual namespaces; the separate cold source reader creates no live entry owner."""
	_host = Host.new()
	_content = Content.new()
	assert_equal(_content.load_file(Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA,
		Session.PRESENTATION_BYTES), &"", "actual supplied source image")
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "actual generated settlement")
	assert_true(_host.mount_underground(_content), "original mounted source: %s" % _host.last_refusal())
	_session = _host.underground_session()
	if _session == null: return
	assert_true(_host.compose_underground_room_owners(), "actual Room owners")
	assert_true(_host.compose_underground_route_owners(), "actual ground owners")
	var o: Session.Retirement.Owners = _session._retirement_owners
	_catalog = Catalog.new()
	assert_equal(_catalog.configure(Catalog.RESERVED_BYTES), &"", "full catalog reservation")
	assert_equal(_catalog.bind_actual(o.profiles, o.world_routes._levels, o.world_routes._movement,
		o.residents, o.transforms, o.space._domain), &"", "original complete owner tuple")


func after_each() -> void:
	"""Only this test's original graph and independent immutable readers are released."""
	_assemblies = null
	_recipes = null
	_catalog = null
	_session = null
	_content = null
	if _host != null: _host.free()
	_host = null


func test_real_catalog_and_bills_load_without_creating_paid_or_traversable_state() -> void:
	"""Every real reader validates hashes and source identities; two whole bills retain wood-only arithmetic."""
	var o: Session.Retirement.Owners = _session._retirement_owners
	var inventory: PackedByteArray = _host.inventory().state_bytes()
	var jobs: PackedByteArray = _host.jobs().state_bytes()
	var buildings: PackedByteArray = _host.buildings().spatial_state_bytes()
	assert_equal(_catalog.load_file(CATALOG_PATH, CATALOG_SHA, 1), &"", "real structural catalog")
	_bind_bills()
	var quote: Contract.Quote = Contract.Quote.new()
	var record: Assemblies.AssemblyRecord = Assemblies.AssemblyRecord.new()
	for assembly: int in 2:
		assert_equal(_assemblies.assembly_into(0, 1, 1, assembly, record), &"", "whole partition")
		assert_equal(_recipes.recipe_into(0, 1, record.recipe_anchor, 1, quote), &"", "one actual whole assembly bill")
		assert_equal(quote.input_count, 1, "only wood")
		assert_equal(quote.input_keys[0], &"wood", "approved material")
		assert_equal(quote.input_milli[0], 4000 if assembly == 0 else 1000, "approved whole quantity")
		assert_equal(quote.total_mwu, 32000 if assembly == 0 else 12000, "approved work")
	assert_equal(_host.inventory().state_bytes(), inventory, "decoding neither pays nor creates stock")
	assert_equal(_host.jobs().state_bytes(), jobs, "no job")
	assert_equal(_host.buildings().spatial_state_bytes(), buildings, "no entry or room")
	assert_equal(o.sites._count, 0, "no excavated cube")
	assert_equal(o.routes._live.edge_count, 0, "no route")
	assert_equal(o.locations._live.count, 0, "no endpoint")
	assert_equal(o.world_routes._catalog._live.header[1], 1, "mounted entry structure untouched (ADR1195: one variant)")


func _bind_bills() -> void:
	"""Load the existing acyclic Catalog to Grouping to Recipe source relationship with full production capacities."""
	_recipes = Recipes.new()
	assert_equal(_recipes.configure(Recipes.MAX_PARTS, Recipes.required_bytes(Recipes.MAX_PARTS)), &"", "recipe arena")
	assert_equal(_recipes.bind_actual(_catalog, _host.item_definitions(), _host.inventory()), &"", "original registration")
	assert_equal(_recipes.load_file(RECIPE_PATH, RECIPE_SHA, 1, GROUP_SHA, 1), &"", "actual recipe bytes")
	_assemblies = Assemblies.new()
	assert_equal(_assemblies.configure(Assemblies.MAX_GROUPS, Assemblies.required_bytes(Assemblies.MAX_GROUPS)), &"", "group arena")
	assert_equal(_assemblies.bind_actual(_catalog, _recipes, _host.item_definitions(), _host.inventory()), &"", "original bill owners")
	assert_equal(_assemblies.load_file(GROUP_PATH, GROUP_SHA, 1, RECIPE_SHA, 1), &"", "complete part partition")


func test_structure_cannot_supply_a_stair_pace_or_accept_a_stale_hash() -> void:
	"""Geometry publication cannot grant travel by borrowing the existing ground cap."""
	assert_equal(_catalog.load_file(CATALOG_PATH, "0".repeat(64), 1), &"CONNECTOR_CATALOG_SOURCE_HASH", "stale digest")
	assert_equal(_catalog.content_revision(), 0, "failed read remains empty")
	assert_equal(_catalog.load_file(CATALOG_PATH, CATALOG_SHA, 1), &"", "exact source")
	var pace: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	pace.value = 99
	assert_equal(_catalog.pace_into(12, 1, 3, 0, 0, 1, pace), &"CONNECTOR_PACE_UNAUTHORED", "no authored timber pace")
	assert_equal(pace.value, 99, "refusal preserves output")
