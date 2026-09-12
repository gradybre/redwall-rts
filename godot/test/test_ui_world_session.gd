extends "res://test/framework/test_case.gd"
## Coverage for UI-SET-103 New settlement: the form's rules, and the real world it generates.
##
## This is the suite that decides whether "New Settlement is wired to real state" is a claim or
## a fact. `test_generating_the_abbey_publishes_section_five_ones_authored_world` drives the
## form exactly as the modal does and then counts what landed in the STORES: 1695 resource
## nodes, 7 ecology basins and 9 fish stocks at the seed §5.1 fixes. A form that rendered
## beautifully and generated nothing fails here.
##
## The counts are quoted from task 04.3's own record of `world_init.gd`'s output, not read back
## from the generator, so a generator that quietly stopped placing trees fails rather than
## agreeing with itself.
##
## ---------------------------------------------------------------------------------------
## THE REFUSALS MATTER AS MUCH AS THE GENERATION. §4.3's dropdown has three architectures and
## two modes; exactly one of each is authored. A form that generated the abbey for HOLT would be
## the "no other scenario gets the refuge's values by fallback" failure task 04.3 names, and it
## would be invisible on screen -- the player would simply get an abbey. So the refusals are
## asserted by code, and the inline reason is asserted to name what is missing.

const UiWorldSession := preload("res://scripts/ui/ui_world_session.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")

## Task 04.3's recorded output of one §5.1 generation, quoted: "1695 resource nodes, 7 basins,
## 9 stocks", at the seed §5.1 fixes.
const EXPECTED_RESOURCE_NODES: int = 1695
const EXPECTED_BASINS: int = 7
const EXPECTED_FISH_STOCKS: int = 9
const AUTHORED_SEED: int = 20260905

## §4.3's field defaults, quoted.
const SPEC_DEFAULT_NAME: String = "Rowan's Refuge"
const SPEC_DEFAULT_SEED: int = 20260905
const NAME_MIN: int = 2
const NAME_MAX: int = 32
const SEED_MIN: int = 1
const SEED_MAX: int = 2147483647

var _residents: ResidentsScript = null
var _jobs: JobsScript = null
var _directory: EntityDirectoryScript = null
var _nodes: ResourceNodesScript = null
var _forage: ForageScript = null
var _fishing: FishingScript = null
var _rng: RngScript = null
var _session: UiWorldSession = null
var _report: UiWorldSession.Report = null


func before_each() -> void:
	"""Compose one settlement's stores, sharing a directory, and a fresh form session."""
	_residents = ResidentsScript.new()
	_jobs = JobsScript.new(_residents)
	_directory = _jobs.directory()
	_nodes = ResourceNodesScript.new(_directory)
	_forage = ForageScript.new(_directory, _jobs)
	_fishing = FishingScript.new(_directory, _forage, _jobs)
	_rng = RngScript.new()
	_session = UiWorldSession.new()
	_report = UiWorldSession.Report.new()


func after_each() -> void:
	"""Drop every store so no generated world crosses a test boundary."""
	_session = null
	_report = null
	_rng = null
	_fishing = null
	_forage = null
	_nodes = null
	_directory = null
	_jobs = null
	_residents = null


func _create() -> bool:
	"""Run the Create action against this suite's stores."""
	return _session.create_into(_directory, _nodes, _forage, _fishing, _rng,
		null, null, _jobs, null, _report)


# --- §4.3's defaults ------------------------------------------------------------------------------

func test_the_form_opens_on_the_documented_defaults() -> void:
	"""§4.3 fixes the opening values of every field; three of them are used unchanged."""
	assert_equal(_session.settlement_name(), SPEC_DEFAULT_NAME, "the default name")
	assert_equal(_session.seed_value(), SPEC_DEFAULT_SEED, "the default seed")
	assert_equal(_session.architecture(), UiWorldSession.ARCHITECTURE_ABBEY, "ABBEY by default")
	assert_equal(_session.mode(), UiWorldSession.MODE_STANDARD, "STANDARD by default")
	assert_true(_session.can_create(), "so Create is enabled on an untouched form")


func test_the_tutorial_default_deviates_and_the_deviation_is_published() -> void:
	"""§4.3's default is true; no tutorial state exists, so the module states both values."""
	assert_true(UiWorldSession.SPEC_DEFAULT_TUTORIAL, "the specification's default is recorded")
	assert_false(UiWorldSession.SUPPORTED_TUTORIAL, "and this milestone's supported value is false")
	assert_equal(_session.tutorial(), UiWorldSession.SUPPORTED_TUTORIAL, "the form holds false")
	assert_false(_session.set_tutorial(true), "turning it on refuses")
	assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_TUTORIAL_UNAVAILABLE,
		"naming the missing tutorial state")


# --- field validation -----------------------------------------------------------------------------

func test_the_name_field_enforces_section_four_threes_character_bounds() -> void:
	"""2 to 32 Unicode characters, with both ends tested at the boundary."""
	assert_false(_session.set_settlement_name("R"), "one character refuses")
	assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_NAME_LENGTH, "on length")
	assert_true(_session.set_settlement_name("Ro"), "two characters is the minimum")
	assert_true(_session.set_settlement_name("R".repeat(NAME_MAX)), "thirty-two is the maximum")
	assert_false(_session.set_settlement_name("R".repeat(NAME_MAX + 1)), "thirty-three refuses")


func test_a_control_character_in_the_name_is_refused_separately() -> void:
	"""A name of a legal length can still be illegal, and says which rule it broke."""
	assert_false(_session.set_settlement_name("Row%san" % String.chr(7)),
		"a bell character refuses")
	assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_NAME_CONTROL_CHARACTER,
		"under its own code, not the length code")
	assert_true(_session.set_settlement_name("Rowan's Refuge"), "an ordinary name passes")


func test_the_seed_field_enforces_its_documented_range() -> void:
	"""§4.3: "seed integer 1-2147483647"; zero and negatives are outside it."""
	assert_false(_session.set_seed(0), "zero refuses")
	assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_SEED_RANGE, "on range")
	assert_false(_session.set_seed(-1), "a negative seed refuses")
	assert_true(_session.set_seed(SEED_MIN), "one is the minimum")
	assert_true(_session.set_seed(SEED_MAX), "and 2147483647 is the maximum")
	assert_false(_session.set_seed(SEED_MAX + 1), "one past it refuses")


func test_an_invalid_field_disables_create_and_exposes_its_reason() -> void:
	"""§4.3: "Invalid fields disable Create (066) and expose an inline reason"."""
	assert_true(_session.can_create(), "the untouched form can create")
	_session.set_seed(0)
	assert_true(_session.can_create(), "a refused edit did not corrupt the valid seed")
	_session.set_architecture(UiWorldSession.ARCHITECTURE_HOLT)
	assert_false(_session.can_create(), "an unauthored architecture disables Create")
	var reason: String = UiWorldSession.inline_reason(_session.form_refusal())
	assert_true(reason.contains("ABBEY"), "the inline reason names what is authored")
	assert_true(reason.length() > 40, "and explains it: '%s'" % reason)


# --- the refusals that keep the scenario honest ------------------------------------------------

func test_holt_and_fortress_refuse_rather_than_generating_the_abbey() -> void:
	"""04.3: "no other scenario gets the refuge's values by fallback"."""
	for architecture: int in [UiWorldSession.ARCHITECTURE_HOLT, UiWorldSession.ARCHITECTURE_FORTRESS]:
		assert_false(_session.set_architecture(architecture),
			"%s is not authored" % UiWorldSession.ARCHITECTURE_KEYS[architecture])
		assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_ARCHITECTURE_UNAUTHORED,
			"under the unauthored-architecture code")
		assert_false(_create(), "and Create refuses")
		assert_equal(_nodes.count(), 0, "with no world generated at all")


func test_sandbox_mode_refuses_for_the_same_reason() -> void:
	"""§4.3 lists SANDBOX; no sandbox ruleset exists, so it cannot quietly run the standard one."""
	assert_false(_session.set_mode(UiWorldSession.MODE_SANDBOX), "SANDBOX is not authored")
	assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_MODE_UNAUTHORED, "under its code")
	assert_false(_create(), "Create refuses")
	assert_equal(_report.error, UiWorldSession.REFUSE_MODE_UNAUTHORED, "and the report says why")
	assert_false(_session.has_world(), "no world was published")


func test_an_unknown_dropdown_value_is_refused_separately_from_an_unauthored_one() -> void:
	""""There is no such architecture" and "that architecture is not authored" are different."""
	assert_false(_session.set_architecture(UiWorldSession.ARCHITECTURE_COUNT), "a fourth refuses")
	assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_ARCHITECTURE_RANGE,
		"as an unknown value")
	assert_false(_session.set_mode(-1), "a negative mode refuses")
	assert_equal(_session.last_refusal(), UiWorldSession.REFUSE_MODE_RANGE, "as an unknown value")


func test_creating_without_stores_refuses_instead_of_reporting_success() -> void:
	"""A modal bound to nothing must say so rather than showing a generated world that is not."""
	assert_false(_session.create_into(null, null, null, null, null, null, null, null, null,
		_report), "Create with no stores refuses")
	assert_equal(_report.error, UiWorldSession.REFUSE_NO_STORES, "naming the missing stores")
	assert_false(_report.ok, "and the report is not ok")


# --- the real generation ---------------------------------------------------------------------------

func test_generating_the_abbey_publishes_section_five_ones_authored_world() -> void:
	"""Create runs `world_init.gd` against the settlement's own stores and fills them."""
	assert_equal(_nodes.count(), 0, "the world is empty before Create")
	assert_true(_create(), "Create succeeds (error: %s, %s)" % [_report.error, _report.detail])
	assert_equal(_report.resource_nodes, EXPECTED_RESOURCE_NODES, "§5.1's 1695 resource nodes")
	assert_equal(_report.basins, EXPECTED_BASINS, "its seven ecology basins")
	assert_equal(_report.fish_stocks, EXPECTED_FISH_STOCKS, "and its nine fish stocks")
	assert_equal(_report.accepted_seed, AUTHORED_SEED, "at the seed §5.1 fixes")


func test_the_generated_rows_are_in_the_settlements_own_stores() -> void:
	"""The report is not the evidence; the stores are."""
	assert_true(_create(), "Create succeeds (error: %s)" % _report.error)
	assert_equal(_nodes.count(), EXPECTED_RESOURCE_NODES, "the node store holds them")
	assert_equal(_forage.zone_count(), WorldInitScript.FOREST_BASIN_COUNT
		+ WorldInitScript.FISH_BASIN_COUNT, "the forage store holds all seven basins")
	assert_true(_session.has_world(), "and the session reports a published world")
	assert_equal(_session.generated_count(), 1, "from exactly one generation")


func test_the_published_map_is_readable_for_the_minimap_and_tile_detail() -> void:
	"""The UI owns this generator until it is composed in, so its masks must be readable."""
	assert_true(_create(), "Create succeeds (error: %s)" % _report.error)
	var world: WorldInitScript = _session.world()
	assert_not_null(world, "the session kept the generator")
	assert_true(world.is_published(), "which has published a world")
	assert_true(world.terrain_at(0).ok, "tile 0 has a terrain value")
	assert_equal(world.terrain_at(0).value, WorldInitScript.TERRAIN_COAST,
		"and §5.1's first row is the coast")
	assert_true(world.basin_index_at(WorldInitScript.tile_index_of(20, 30)).ok,
		"a forest tile reports its basin")


func test_a_second_generation_replaces_the_first_rather_than_accumulating() -> void:
	"""`world_init.gd` resets its stores before publishing, so counts do not double."""
	assert_true(_create(), "the first generation succeeds")
	assert_true(_create(), "the second generation succeeds (error: %s)" % _report.error)
	assert_equal(_nodes.count(), EXPECTED_RESOURCE_NODES, "the node count is unchanged")
	assert_equal(_session.generated_count(), 2, "though two worlds were generated")


func test_a_different_valid_seed_is_accepted_and_reported() -> void:
	"""The seed field reaches the generator; §5.1's geometry is authored, so the counts hold."""
	assert_true(_session.set_seed(12345), "a different seed is accepted")
	assert_true(_create(), "Create succeeds (error: %s)" % _report.error)
	assert_equal(_report.accepted_seed, 12345, "the generator used the seed the player typed")
	assert_equal(_report.resource_nodes, EXPECTED_RESOURCE_NODES,
		"§5.1's authored geometry is seed independent")


func test_a_refused_create_leaves_the_stores_exactly_as_they_were() -> void:
	"""04.3: failed initialization retains the previous valid world."""
	assert_true(_create(), "a world is generated first")
	var nodes_before: int = _nodes.count()
	_session.set_architecture(UiWorldSession.ARCHITECTURE_FORTRESS)
	assert_false(_create(), "the next Create refuses")
	assert_equal(_nodes.count(), nodes_before, "the previous world is untouched")
	assert_true(_session.has_world(), "and is still published")
