## godot/scripts/core/catalog.gd lines 302-327
Full source SHA256: 3fcc06650e93ffd78a973c53a21544ba0d8d31a8095c549820292e2d63926cb1
```gdscript
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
```

## godot/scripts/core/entity_directory.gd lines 53-62
Full source SHA256: 0367a5995327721bbd1d467cff494efa1ec9b5d707e5e997949fbac3575c709a
```gdscript
## Promoted from the verified `docs/validation/headless/resident_slots.gd`
## kernel, which stays in place as the isolated experimental control.

const NULL_SLOT: int = -1
const NULL_GENERATION: int = 0
const NULL_REF: Vector2i = Vector2i(NULL_SLOT, NULL_GENERATION)

## Validator mode for `is_valid_of_kind`, never a stored kind value (ARCH-ID-003).
const KIND_ANY: int = -1

```

## godot/scripts/core/entity_directory.gd lines 118-125
Full source SHA256: 0367a5995327721bbd1d467cff494efa1ec9b5d707e5e997949fbac3575c709a
```gdscript
	&"CAPACITY_RESOURCE_NODE", &"CAPACITY_ROOM", &"CAPACITY_WORLD",
]

## Directory length G, systems_architecture.md §2.1.
const DIRECTORY_CAPACITY: int = 352418

## Resident storage is 512 slots but living residents never exceed 256 (GDD §4.1).
const RESIDENT_LIVING_CAP: int = 256
```
