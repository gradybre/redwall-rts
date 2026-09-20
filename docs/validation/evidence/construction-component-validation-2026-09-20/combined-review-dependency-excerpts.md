# godot/scripts/core/save_header.gd sha256=55570d407a9f18dd2d8471f7fd58e98f34fce241b8d5fc06f44b49fbcd27eaa0

Lines 160–175
```gdscript
class Refusal:
	"""One refusal: a StringName code and the detail behind it. `REFUSE_NONE` means accepted."""
	var code: StringName
	var detail: String

	func _init(p_code: StringName, p_detail: String) -> void:
		"""Store the refusal code and its detail."""
		code = p_code
		detail = p_detail

	func is_ok() -> bool:
		"""True when this record carries no refusal."""
		return code == REFUSE_NONE


class Header:
```

# godot/scripts/core/entity_directory.gd sha256=0367a5995327721bbd1d467cff494efa1ec9b5d707e5e997949fbac3575c709a

Lines 55–160
```gdscript

const NULL_SLOT: int = -1
const NULL_GENERATION: int = 0
const NULL_REF: Vector2i = Vector2i(NULL_SLOT, NULL_GENERATION)

## Validator mode for `is_valid_of_kind`, never a stored kind value (ARCH-ID-003).
const KIND_ANY: int = -1

## Largest int32. Bounds generation, persistent ID, and every packed column.
const MAX_INT32: int = 2147483647

## The first persistent identity a new world issues (REG-R01, §1 `_next_persistent_id`).
const PERSISTENT_ID_MIN: int = 1

## The cursor left AFTER the final signed-int32 identity has been issued. It is a legal SAVED
## cursor and an illegal COLUMN value: no live `_persistent_id` may ever carry it.
const PERSISTENT_ID_EXHAUSTED: int = MAX_INT32 + 1

## Kind IDs are the index of each key in ascending ASCII order (ARCH-ID-001).
const KIND_BUILDING: int = 0
const KIND_CONSTRUCTION: int = 1
const KIND_EXPEDITION: int = 2
const KIND_FARM_PLOT: int = 3
const KIND_FEAST: int = 4
const KIND_FISH_HABITAT: int = 5
const KIND_FURNITURE: int = 6
const KIND_HARVEST_ZONE: int = 7
const KIND_HIVE: int = 8
const KIND_INVENTORY_CONTAINER: int = 9
const KIND_INVENTORY_LOT: int = 10
const KIND_JOB: int = 11
const KIND_ORCHARD_PLOT: int = 12
const KIND_PRODUCTION_ORDER: int = 13
const KIND_RESIDENT: int = 14
const KIND_RESOURCE_NODE: int = 15
const KIND_ROOM: int = 16
const KIND_WORLD: int = 17
const KIND_COUNT: int = 18

## Kind keys in the ascending ASCII order that fixes the IDs above.
const KIND_KEYS: Array[StringName] = [
	&"building", &"construction", &"expedition", &"farm_plot", &"feast",
	&"fish_habitat", &"furniture", &"harvest_zone", &"hive",
	&"inventory_container", &"inventory_lot", &"job", &"orchard_plot",
	&"production_order", &"resident", &"resource_node", &"room", &"world",
]

## Maximum rows per kind, systems_architecture.md §2.1. Sums to DIRECTORY_CAPACITY.
const KIND_CAPACITY: Array[int] = [
	1024, 82944, 512, 4096, 1,
	32, 81920, 128, 1024,
	101376, 16384, 8192, 1024,
	32768, 512, 4096, 16384, 1,
]

## Refusal code per kind, ARCH-ID-004 `CAPACITY_<STORE>`. Precomputed so the
## refusal path never concatenates a string.
const KIND_CAPACITY_REFUSAL: Array[StringName] = [
	&"CAPACITY_BUILDING", &"CAPACITY_CONSTRUCTION", &"CAPACITY_EXPEDITION",
	&"CAPACITY_FARM_PLOT", &"CAPACITY_FEAST", &"CAPACITY_FISH_HABITAT",
	&"CAPACITY_FURNITURE", &"CAPACITY_HARVEST_ZONE", &"CAPACITY_HIVE",
	&"CAPACITY_INVENTORY_CONTAINER", &"CAPACITY_INVENTORY_LOT", &"CAPACITY_JOB",
	&"CAPACITY_ORCHARD_PLOT", &"CAPACITY_PRODUCTION_ORDER", &"CAPACITY_RESIDENT",
	&"CAPACITY_RESOURCE_NODE", &"CAPACITY_ROOM", &"CAPACITY_WORLD",
]

## Directory length G, systems_architecture.md §2.1.
const DIRECTORY_CAPACITY: int = 352418

## Resident storage is 512 slots but living residents never exceed 256 (GDD §4.1).
const RESIDENT_LIVING_CAP: int = 256

const REFUSAL_NONE: StringName = &""
const REFUSAL_UNKNOWN_KIND: StringName = &"UNKNOWN_KIND"
const REFUSAL_DIRECTORY_FULL: StringName = &"CAPACITY_DIRECTORY"
const REFUSAL_PERSISTENT_ID: StringName = &"PERSISTENT_ID_EXHAUSTED"
const REFUSAL_LIVING_CAP: StringName = &"LIVING_CAP_RESIDENT"

## Bulk column refusals, read through `last_column_refusal()` and never through `last_refusal()`.
## ARCH-ID-004 numbers the `create()` codes above; it publishes no registry for column operations,
## so these spellings are this module's PROPOSAL (decision 0105) and change if one lands.
const REFUSAL_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
const REFUSAL_COLUMN_ACTIVE_BYTE: StringName = &"COLUMN_ACTIVE_BYTE"
const REFUSAL_COLUMN_RETIRED_BYTE: StringName = &"COLUMN_RETIRED_BYTE"
const REFUSAL_COLUMN_GENERATION_NEGATIVE: StringName = &"COLUMN_GENERATION_NEGATIVE"
const REFUSAL_COLUMN_LIVE_GENERATION: StringName = &"COLUMN_LIVE_GENERATION"
const REFUSAL_COLUMN_LIVE_PERSISTENT_ID: StringName = &"COLUMN_LIVE_PERSISTENT_ID"
const REFUSAL_COLUMN_LIVE_KIND: StringName = &"COLUMN_LIVE_KIND"
const REFUSAL_COLUMN_LIVE_ROW: StringName = &"COLUMN_LIVE_ROW"
const REFUSAL_COLUMN_FREE_IDENTITY: StringName = &"COLUMN_FREE_IDENTITY"
const REFUSAL_COLUMN_RETIREMENT: StringName = &"COLUMN_RETIREMENT"
const REFUSAL_COLUMN_DUPLICATE_TYPED_ROW: StringName = &"COLUMN_DUPLICATE_TYPED_ROW"
const REFUSAL_COLUMN_LIVING_CAP: StringName = &"COLUMN_LIVING_CAP"
## D2 cursor refusals. `RANGE` is a cursor outside `1..PERSISTENT_ID_EXHAUSTED`; `STALE` is one
## that does not exceed every positive stored id, which would reissue a spent identity.
const REFUSAL_COLUMN_CURSOR_RANGE: StringName = &"COLUMN_CURSOR_RANGE"
const REFUSAL_COLUMN_CURSOR_STALE: StringName = &"COLUMN_CURSOR_STALE"

# EntityIdentity columns, systems_architecture.md §2.2.
var _persistent_id: PackedInt32Array = PackedInt32Array()
var _generation: PackedInt32Array = PackedInt32Array()
var _kind: PackedInt32Array = PackedInt32Array()
var _active: PackedByteArray = PackedByteArray()

# DirectoryIndex columns, systems_architecture.md §3.
# `_typed_row` locates the row in the kind's typed store and `_typed_owner_slot`
```

# godot/scripts/core/catalog.gd sha256=3fcc06650e93ffd78a973c53a21544ba0d8d31a8095c549820292e2d63926cb1

Lines 228–349
```gdscript
}

# --- compiled enum domains (GDD §4.2 closing paragraph, BAL-CAT-001/002) -------------------------

const BUILDING_DEFINITION_DOMAIN: String = "BuildingDefinition"
const COMMAND_KIND_DOMAIN: String = "CommandKind"
const CROP_FAMILY_DOMAIN: String = "CropFamily"
const EVENT_DEFINITION_DOMAIN: String = "EventDefinition"
const FURNITURE_DEFINITION_DOMAIN: String = "FurnitureDefinition"
const HABITAT_TYPE_DOMAIN: String = "HabitatType"
const STATION_DOMAIN: String = "Station"

## The protected Milestone domain's own name, used wherever a caller asks for it by string.
const MILESTONE_DOMAIN: String = "Milestone"

## The protected InjuryKind domain's own name. SET-MOVE-ECON-001 HAZ-001/002/003 and the
## aggregate injury/care owner ask for it by string; nothing else may spell it.
const INJURY_KIND_DOMAIN: String = "InjuryKind"

## GDD §4.2: "empty catalog IDs are -1". Absence, never a refusal channel and never a key.
const EMPTY_CATALOG_ID: int = -1

## ARCH-CMD-003's 24 settlement command kinds. The architecture prints them as a "`[NEW sorted
## ASCII domain]`" and says "compile IDs from this exact list; reject unknown kinds", so the list
## IS the domain and its order is the ASCII rule's own output, proven by verify_compiled_enum()
## like the three below. The ids are save- and replay-carried (§8.1's command record field at
## offset 20), so renumbering one silently re-points every stored command at a different action.
## ARCH-CMD-002's speed/pause scheduler events are deliberately ABSENT: task 04.1 requires them
## queued separately and says in terms "retain ARCH-CMD-003's 24 stable command IDs unchanged. Do
## not insert speed/pause keys into the sorted catalog" -- inserting one would renumber every kind
## that sorts after it.
const COMMAND_KIND: Dictionary = {
	"ACCEPT_CANDIDATES": 0, "APPOINT_WARDEN": 1, "ASSIGN_BED": 2, "CANCEL_JOB": 3,
	"CANCEL_MANUAL": 4, "CONFIRM_FEAST": 5, "DEMOLISH": 6, "DESIGNATE_ROOM": 7,
	"DESIGNATE_ZONE": 8, "EDIT_ORDER": 9, "EQUIP": 10, "NAME_RESIDENT": 11,
	"PLACE_BLUEPRINT": 12, "PLACE_FURNITURE": 13, "REQUEST_RELIEF_SEEDS": 14,
	"SET_ACTIVITY_SCHEDULE": 15, "SET_DOOR_OPEN": 16, "SET_FIELD_ROTATION": 17,
	"SET_JOB_PRIORITIES": 18, "SET_MANUAL_TASK": 19, "SET_POLICY": 20, "SET_STORE_FILTER": 21,
	"SET_STORE_MINIMUM": 22, "UPGRADE": 23,
}

## BAL-CAT-002: "Category, effect, recipe-family, crop-family, and station domains use the keys
## printed in these tables and numeric IDs generated by BAL-CAT-001." The keys are §5.6's own
## uppercase family names; the IDs are their ascending ASCII order, not §5.6's printed order.
const CROP_FAMILY: Dictionary = {"CEREAL": 0, "FIBER": 1, "LEAF": 2, "LEGUME": 3, "ROOT": 4}

## §5.10's seven event rows, keyed by their snake_case names. `Weather.event` stores THESE ids;
## §5.10's printed order governs only the weighted selection scan, which weather.gd keeps.
const EVENT_DEFINITION: Dictionary = {
	"blight": 0, "calm_days": 1, "drought": 2, "early_frost": 3,
	"hard_freeze": 4, "heavy_rain": 5, "ideal_spell": 6,
}

## `FishHabitat.type`'s domain. The uppercase key spelling is the ruling's explicit choice; the
## resulting order is inherited from the ASCII rule, and disagrees with §5.4's printed
## River/Lake/Coast table order on every value.
const HABITAT_TYPE: Dictionary = {"COAST": 0, "LAKE": 1, "RIVER": 2}

## `Building.type_id`'s domain: ALL THIRTY of the owning catalog's BuildingDefinition rows
## (gameplay_balance.md §4.1, whose normalized keys join GDD §5.9's thirty printed building rows
## and are the stable identifiers BAL-CAT-006/007 build definitions from). The complete domain is
## published here rather than the seven keys the starter colony happens to place, because a
## partial domain renumbers every building the moment an eighth is implemented -- and these ids
## are persisted in `Building.type_id`.
##
## The keys are identifiers, never display names: §5.9 prints "Refuge/community hall",
## "Workbench shelter" and "Preserver/smokehouse" while the owning rows key them `hall`,
## `workbench` and `preserver`. Ordering is the ASCII rule's output over those keys, proven by
## verify_compiled_enum(), and has nothing to do with either printed order.
##
## This domain carries IDENTITY ONLY. Footprints, materials, work, slots, managed_interior,
## room_tiles, unlock, base_store_g, passive_slots and max_builders live in the owning catalog's
## §4.1/§4.2 rows and belong to the packed Building store that reads them; none of them is
## transcribed here, so there is no second copy of a value to drift.
const BUILDING_DEFINITION: Dictionary = {
	"apiary": 0, "boathouse": 1, "brewery": 2,
	"cellar": 3, "composter": 4, "covered_store": 5,
	"dirt_path": 6, "dryer": 7, "fence": 8,
	"fisher_shelter": 9, "forester_lodge": 10, "gate": 11,
	"hall": 12, "infirmary": 13, "kitchen": 14,
	"lookout": 15, "memorial_garden": 16, "mill": 17,
	"nursery": 18, "open_stockpile": 19, "paved_path": 20,
	"preserver": 21, "quarry_shed": 22, "residence": 23,
	"saltpan": 24, "stone_wall": 25, "weir": 26,
	"well": 27, "workbench": 28, "workshop": 29,
}

## `Furniture.type_id`'s domain: all NINE of the owning catalog's FurnitureDefinition rows
## (gameplay_balance.md §4.3, joining GDD §5.9's nine printed furniture rows). BAL-CAT-007: "a
## building ID denotes its exterior structure. Furniture definitions occupy a separate domain" --
## so this is its own domain and a furniture id is never a building id. Identity only, on the
## same terms as BUILDING_DEFINITION above.
const FURNITURE_DEFINITION: Dictionary = {
	"bed": 0, "decoration": 1, "hearth": 2,
	"interior_door": 3, "interior_partition": 4, "kitchen_bench": 5,
	"patient_bed": 6, "seat": 7, "shelf": 8,
}

## `RecipeDefinition.station`'s domain: all ELEVEN service keys BAL-CAT-011 authors
## (gameplay_balance.md:60), published under R-BUILD-DOM-002 (decision 0074).
##
## THIS IS NOT `BuildingDefinition`. BAL-CAT-011 says in terms that `station` "indexes a
## **service domain**, not the BuildingDefinition index", and eight of these keys are spelled
## identically to building keys while carrying different ids: `kitchen` is service 3 and
## building 14, `well` is service 8 and building 27, `workshop` is service 10 and building 29.
## A range check cannot catch a wrong-domain integer here, because every station id is also a
## valid building id; only importing by the field's named domain can. `building_definitions.gd`
## holds the explicit building -> station provider mapping, so the two are joined in one place.
##
## `kitchen_bench` is a FurnitureDefinition, not a twelfth station key: BAL-CAT-011 gives the
## kitchen service two providers -- "one exterior kitchen's 2 cooking slots or each valid
## interior kitchen_bench's 1 slot" -- and both satisfy service id 3 through different refs.
##
## Ordering is the ASCII rule's own output over these keys, proven by verify_compiled_enum().
const STATION: Dictionary = {
	"brewery": 0, "composter": 1, "dryer": 2,
	"kitchen": 3, "mill": 4, "nursery": 5,
	"preserver": 6, "saltpan": 7, "well": 8,
	"workbench": 9, "workshop": 10,
}

const COMPILED_ENUM_DOMAINS: Array[String] = [
```
