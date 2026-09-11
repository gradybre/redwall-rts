extends RefCounted
## UI-SET-103 New settlement: the form's five fields, their validation, and the real generation.
##
## §4.3 fixes the form exactly: "`settlement_name` text 2-32 Unicode characters, default
## "Rowan's Refuge"; `seed` integer 1-2147483647, default 20260905; `architecture` dropdown
## ABBEY/HOLT/FORTRESS, default ABBEY; `mode` STANDARD/SANDBOX, default STANDARD; `tutorial`
## bool, default true. Invalid fields disable Create (066) and expose an inline reason. ...
## Generation succeeds into paused world inspection with PLAYER pause; the first Resume starts
## tick advancement."
##
## This module owns the first three sentences. The pause belongs to `ui_manager.gd`, which owns
## the time source.
##
## ---------------------------------------------------------------------------------------
## TWO DROPDOWN VALUES AND ONE TOGGLE ARE OFFERED AND REFUSED, WHICH IS THE POINT. Task 04.3:
## "Scenario identity is an explicit versioned initialization input. First use the specified
## refuge as an engineering fixture; NO OTHER SCENARIO GETS THE REFUGE'S VALUES BY FALLBACK."
## `world_init.gd` implements exactly one scenario, SCENARIO_ESTUARY_V1. So:
##   * ABBEY generates the authored estuary refuge;
##   * HOLT and FORTRESS are listed -- §4.3 says the dropdown has three values -- and REFUSE with
##     the named missing authoring, because generating the abbey under another name is the
##     fallback that ruling forbids;
##   * SANDBOX refuses for the same reason: no sandbox ruleset exists;
##   * `tutorial` is rendered unavailable and held false. §4.3's default is TRUE, and this is a
##     deliberate, recorded deviation: there is no tutorial disclosure state in this project, so
##     a toggle reading "on" would promise prompts that do not exist. The field, its spec default
##     and the reason are all published below rather than quietly dropped.
##
## ---------------------------------------------------------------------------------------
## THE ITEM REGISTRY IS LOADED PRIVATELY, AND ONLY TO RESOLVE IDS. `WorldInit.bound_request()`
## needs a loaded `ItemDefinitions` to resolve READY_07's seventeen bindings by key, and
## `EconomySystem` publishes no accessor for the one it loads. So this module loads its own
## against a private `Inventory` used for nothing else. That registry is never written into by
## the game and never reads game state: the ids it produces are verified against the committed
## `catalog_ids.json` artifact by `resource_catalog_binding.gd` before generation starts, so a
## stale or disagreeing catalog refuses rather than seeding a world with wrong ids.
##
## ---------------------------------------------------------------------------------------
## GENERATION IS THE ONLY STORE WRITE ANY UI MODULE MAKES, AND IT IS NOT A GAMEPLAY EDIT.
## 04.2's rule is about player edits to "resident, ecology, jobs or inventory stores" -- the
## edits that must carry a command envelope. Creating a world is not one of those: it has no
## target, no sequence and no tick, it happens before the first tick exists, and 04.4 names the
## New Settlement control as the thing that should compose `world_init.gd`. Every ordinary
## player action still goes through `ui_command_bridge.gd`.

const WorldInitScript := preload("res://scripts/core/world_init.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const RngScript := preload("res://scripts/core/rng.gd")

# --- §4.3's field catalog -------------------------------------------------------------------------

const FIELD_NAME: int = 0
const FIELD_SEED: int = 1
const FIELD_ARCHITECTURE: int = 2
const FIELD_MODE: int = 3
const FIELD_TUTORIAL: int = 4
const FIELD_COUNT: int = 5

const FIELD_KEYS: Array[StringName] = [
	&"settlement_name", &"seed", &"architecture", &"mode", &"tutorial",
]

const NAME_MIN_CHARACTERS: int = 2
const NAME_MAX_CHARACTERS: int = 32
const DEFAULT_NAME: String = "Rowan's Refuge"

const SEED_MINIMUM: int = 1
const SEED_MAXIMUM: int = 2147483647
const DEFAULT_SEED: int = 20260905

const ARCHITECTURE_ABBEY: int = 0
const ARCHITECTURE_HOLT: int = 1
const ARCHITECTURE_FORTRESS: int = 2
const ARCHITECTURE_COUNT: int = 3
const ARCHITECTURE_KEYS: Array[StringName] = [&"ABBEY", &"HOLT", &"FORTRESS"]

const MODE_STANDARD: int = 0
const MODE_SANDBOX: int = 1
const MODE_COUNT: int = 2
const MODE_KEYS: Array[StringName] = [&"STANDARD", &"SANDBOX"]

## §4.3's stated default for `tutorial`, kept here so the deviation below is visible rather than
## implied. The control is rendered unavailable and the value is held at false.
const SPEC_DEFAULT_TUTORIAL: bool = true
const SUPPORTED_TUTORIAL: bool = false

const REFUSE_NONE: StringName = &""
const REFUSE_NAME_LENGTH: StringName = &"UI_SETTLEMENT_NAME_LENGTH"
const REFUSE_NAME_CONTROL_CHARACTER: StringName = &"UI_SETTLEMENT_NAME_CONTROL_CHARACTER"
const REFUSE_SEED_RANGE: StringName = &"UI_SEED_OUT_OF_RANGE"
const REFUSE_ARCHITECTURE_RANGE: StringName = &"UI_UNKNOWN_ARCHITECTURE"
const REFUSE_ARCHITECTURE_UNAUTHORED: StringName = &"UI_ARCHITECTURE_NOT_AUTHORED"
const REFUSE_MODE_RANGE: StringName = &"UI_UNKNOWN_MODE"
const REFUSE_MODE_UNAUTHORED: StringName = &"UI_MODE_NOT_AUTHORED"
const REFUSE_TUTORIAL_UNAVAILABLE: StringName = &"UI_NO_TUTORIAL_STATE"
const REFUSE_UNKNOWN_FIELD: StringName = &"UI_UNKNOWN_FORM_FIELD"
const REFUSE_NO_STORES: StringName = &"UI_NO_SETTLEMENT_STORES"
const REFUSE_CATALOG: StringName = &"UI_ITEM_CATALOG_UNAVAILABLE"

## The inline reason each refusal shows beside its field, per §4.3's "expose an inline reason".
const FIELD_REASONS: Dictionary = {
	&"UI_SETTLEMENT_NAME_LENGTH": "A settlement name is 2 to 32 characters.",
	&"UI_SETTLEMENT_NAME_CONTROL_CHARACTER": "A settlement name may not contain control characters.",
	&"UI_SEED_OUT_OF_RANGE": "A seed is a whole number from 1 to 2147483647.",
	&"UI_UNKNOWN_ARCHITECTURE": "Choose ABBEY, HOLT or FORTRESS.",
	&"UI_ARCHITECTURE_NOT_AUTHORED":
		"Only ABBEY is authored; it is the estuary refuge fixture. HOLT and FORTRESS have no scenario definition, and neither may inherit the refuge's values.",
	&"UI_UNKNOWN_MODE": "Choose STANDARD or SANDBOX.",
	&"UI_MODE_NOT_AUTHORED": "Only STANDARD is authored; no sandbox ruleset exists.",
	&"UI_NO_TUTORIAL_STATE": "No tutorial disclosure state exists, so tutorial prompts cannot be enabled.",
	&"UI_NO_SETTLEMENT_STORES": "The interface has no settlement stores to generate into.",
	&"UI_ITEM_CATALOG_UNAVAILABLE": "The item catalog could not be loaded.",
}


class Report:
	"""What one generation attempt did, or the exact assertion that stopped it.

	`ok` MUST be read first. A refusal carries the owning module's own code -- `world_init.gd`'s
	failed assertion or the binding boundary's refusal -- and leaves every store untouched,
	because `world_init.gd` decides refusals before it writes anything.
	"""

	var ok: bool = false
	var error: StringName = REFUSE_NONE
	var detail: String = ""
	var attempts: int = 0
	var accepted_seed: int = 0
	var resource_nodes: int = 0
	var basins: int = 0
	var fish_stocks: int = 0

	func reset() -> void:
		"""Clear the report so a refused attempt cannot show the previous one's counts."""
		ok = false
		error = REFUSE_NONE
		detail = ""
		attempts = 0
		accepted_seed = 0
		resource_nodes = 0
		basins = 0
		fish_stocks = 0


# --- form state ------------------------------------------------------------------------------------

var _name: String = DEFAULT_NAME
var _seed: int = DEFAULT_SEED
var _architecture: int = ARCHITECTURE_ABBEY
var _mode: int = MODE_STANDARD
var _tutorial: bool = SUPPORTED_TUTORIAL

var _world: WorldInitScript = null
var _items: ItemDefinitionsScript = null
var _registry_inventory: InventoryScript = null
var _report: Report = Report.new()
var _generated_count: int = 0
var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Start at §4.3's defaults and prove the field catalog is completely named."""
	_assert_contracts()


func _assert_contracts() -> void:
	"""Every §4.3 field, architecture and mode must have a key, and every refusal a reason."""
	assert(FIELD_KEYS.size() == FIELD_COUNT, "every UI-SET-103 field must be named")
	assert(ARCHITECTURE_KEYS.size() == ARCHITECTURE_COUNT, "every architecture must be named")
	assert(MODE_KEYS.size() == MODE_COUNT, "every mode must be named")
	assert(FIELD_REASONS.has(REFUSE_ARCHITECTURE_UNAUTHORED),
		"the unauthored-architecture refusal must carry its inline reason")


func set_settlement_name(value: String) -> bool:
	"""Set `settlement_name`, refusing a length or control character §4.3 forbids."""
	var code: StringName = name_refusal(value)
	if code != REFUSE_NONE:
		return _refuse(code)
	_name = value
	_last_refusal = REFUSE_NONE
	return true


static func name_refusal(value: String) -> StringName:
	"""§4.3's name rule: 2-32 Unicode characters, no control characters."""
	if value.length() < NAME_MIN_CHARACTERS or value.length() > NAME_MAX_CHARACTERS:
		return REFUSE_NAME_LENGTH
	for index: int in value.length():
		var code_point: int = value.unicode_at(index)
		if code_point < 0x20 or code_point == 0x7F:
			return REFUSE_NAME_CONTROL_CHARACTER
	return REFUSE_NONE


func set_seed(value: int) -> bool:
	"""Set `seed`, refusing anything outside §4.3's 1..2147483647."""
	if value < SEED_MINIMUM or value > SEED_MAXIMUM:
		return _refuse(REFUSE_SEED_RANGE)
	_seed = value
	_last_refusal = REFUSE_NONE
	return true


func set_architecture(value: int) -> bool:
	"""Set `architecture`. HOLT and FORTRESS are selectable and refuse: neither is authored."""
	if value < 0 or value >= ARCHITECTURE_COUNT:
		return _refuse(REFUSE_ARCHITECTURE_RANGE)
	_architecture = value
	if value != ARCHITECTURE_ABBEY:
		return _refuse(REFUSE_ARCHITECTURE_UNAUTHORED)
	_last_refusal = REFUSE_NONE
	return true


func set_mode(value: int) -> bool:
	"""Set `mode`. SANDBOX is selectable and refuses: no sandbox ruleset exists."""
	if value < 0 or value >= MODE_COUNT:
		return _refuse(REFUSE_MODE_RANGE)
	_mode = value
	if value != MODE_STANDARD:
		return _refuse(REFUSE_MODE_UNAUTHORED)
	_last_refusal = REFUSE_NONE
	return true


func set_tutorial(value: bool) -> bool:
	"""Set `tutorial`. Enabling it refuses: there is no tutorial disclosure state to enable."""
	if value != SUPPORTED_TUTORIAL:
		return _refuse(REFUSE_TUTORIAL_UNAVAILABLE)
	_tutorial = value
	_last_refusal = REFUSE_NONE
	return true


func form_refusal() -> StringName:
	"""The first field refusal blocking Create (UI-SET-066), or the empty name when it is valid.

	§4.3: "Invalid fields disable Create (066) and expose an inline reason." This is the single
	question that button's disabled state is derived from.
	"""
	var code: StringName = name_refusal(_name)
	if code != REFUSE_NONE:
		return code
	if _seed < SEED_MINIMUM or _seed > SEED_MAXIMUM:
		return REFUSE_SEED_RANGE
	if _architecture != ARCHITECTURE_ABBEY:
		return REFUSE_ARCHITECTURE_UNAUTHORED
	if _mode != MODE_STANDARD:
		return REFUSE_MODE_UNAUTHORED
	if _tutorial != SUPPORTED_TUTORIAL:
		return REFUSE_TUTORIAL_UNAVAILABLE
	return REFUSE_NONE


func can_create() -> bool:
	"""Whether UI-SET-066 Create is enabled: true only when every field is valid."""
	return form_refusal() == REFUSE_NONE


static func inline_reason(code: StringName) -> String:
	"""The sentence shown beside a refused field, or the code itself when it is not a form code."""
	if code == REFUSE_NONE:
		return ""
	if FIELD_REASONS.has(code):
		return FIELD_REASONS[code]
	return String(code)


func create_into(directory: EntityDirectoryScript, nodes: ResourceNodesScript,
		forage: ForageScript, fishing: FishingScript, rng: RngScript,
		farming: FarmingScript, orchards: OrchardHiveScript, jobs: JobsScript,
		commands: CommandsScript, out: Report) -> bool:
	"""Generate §5.1's authored world into the settlement's own stores, or refuse and report.

	Every collaborator is the caller's live store, so the world this publishes is the one the
	running settlement ticks. A refusal leaves all of them byte-identical: `world_init.gd`
	proves every assertion before `_publish()` touches anything.
	"""
	out.reset()
	if not can_create():
		return _report_refusal(out, form_refusal(), inline_reason(form_refusal()))
	if directory == null or nodes == null or forage == null or fishing == null or rng == null:
		return _report_refusal(out, REFUSE_NO_STORES, inline_reason(REFUSE_NO_STORES))
	if not _open_catalog():
		return _report_refusal(out, REFUSE_CATALOG, inline_reason(REFUSE_CATALOG))
	_world = WorldInitScript.new(directory, nodes, forage, fishing, rng, farming, orchards,
		jobs, commands)
	return _generate_into(out)


func _generate_into(out: Report) -> bool:
	"""Build the bound request and run one generation, copying its own counts into the report."""
	var request: WorldInitScript.RequestResult = WorldInitScript.bound_request(_items, _seed)
	if not request.ok:
		return _report_refusal(out, request.error, request.detail)
	var result: WorldInitScript.GenerateResult = _world.generate(request.request)
	out.attempts = result.attempts
	if not result.ok:
		return _report_refusal(out, result.error, "generation refused after %d attempt(s)"
			% result.attempts)
	out.ok = true
	out.accepted_seed = result.accepted_seed
	out.resource_nodes = result.resource_nodes_created
	out.basins = result.basins_created
	out.fish_stocks = result.fish_stocks_created
	_generated_count += 1
	_last_refusal = REFUSE_NONE
	return true


func _report_refusal(out: Report, code: StringName, detail: String) -> bool:
	"""Record a refusal in both the report and this session, and leave the report not-ok."""
	out.ok = false
	out.error = code
	out.detail = detail
	return _refuse(code)


func _open_catalog() -> bool:
	"""Load the item registry this session resolves the seventeen world bindings through."""
	if _items != null and _items.is_loaded():
		return true
	_registry_inventory = InventoryScript.new()
	_items = ItemDefinitionsScript.new()
	var loaded: ItemDefinitionsScript.LoadResult = _items.load_from_file(
		ItemDefinitionsScript.DEFAULT_JSON_PATH, _registry_inventory)
	if not loaded.ok:
		_items = null
		return false
	return true


func world() -> WorldInitScript:
	"""The generator that published the current world, or null before the first generation.

	The UI owns this instance until the integration lead composes `world_init.gd` into
	`settlement_system.gd`. It is the only source of the published terrain, soil, basin and
	danger masks the minimap and the tile detail read.
	"""
	return _world


func has_world() -> bool:
	"""True once a generation has published a world into the settlement's stores."""
	return _world != null and _world.is_published()


func generated_count() -> int:
	"""How many worlds this session has published."""
	return _generated_count


func settlement_name() -> String:
	"""The current `settlement_name` field value."""
	return _name


func seed_value() -> int:
	"""The current `seed` field value."""
	return _seed


func architecture() -> int:
	"""The current `architecture` field value."""
	return _architecture


func mode() -> int:
	"""The current `mode` field value."""
	return _mode


func tutorial() -> bool:
	"""The current `tutorial` field value, which this milestone holds at false."""
	return _tutorial


func last_report() -> Report:
	"""The reusable report instance, for a caller with no report of its own."""
	return _report


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
