# Frozen Residents bridge source excerpts

Source: godot/scripts/core/residents.gd SHA256 7ce35ffc7e14ff9e8ba86d70d54a1401e0814751d0b71779d92ba476cd89655c. Excerpts retain line numbers and source text; shared static columns_refusal is specified by accepted contract, not present yet.

```gdscript
115: # --- species catalog, GDD §4.3 --------------------------------------------------------------
116: 
117: const SPECIES_DOMAIN: String = "SpeciesDefinition"
118: 
119: ## "Species catalog release 1: mouse, shrew, mole, ... wolverine", split by the following
120: ## sentence: "Small species are the first six, medium the next six, large the last four."
121: const SPECIES_SMALL_KEYS: Array[StringName] = [
122: 	&"mouse", &"shrew", &"mole", &"rat", &"squirrel", &"sparrow",
123: ]
124: const SPECIES_MEDIUM_KEYS: Array[StringName] = [
125: 	&"otter", &"hare", &"ferret", &"weasel", &"hedgehog", &"kestrel",
126: ]
127: const SPECIES_LARGE_KEYS: Array[StringName] = [&"badger", &"fox", &"wildcat", &"wolverine"]
128: 
129: const SPECIES_COUNT: int = 16
130: 
131: # --- life stage, MOVE-DEP-R02 / GDD §4.2 (2026-09-12) ---------------------------------------
132: 
133: ## The whole stage domain. Fixed and bounded, never an open enum: MOVE-DEP-R02 states the
134: ## encoding is stable and that COUNT "is a bound, never a stored stage".
135: const LIFE_STAGE_ADULT: int = 0
136: const LIFE_STAGE_CHILD: int = 1
137: const LIFE_STAGE_ELDER: int = 2
138: const LIFE_STAGE_COUNT: int = 3
139: 
140: ## Display/report names, indexed by the stage value. NOT a compiled catalog domain: §4.3 numbers
141: ## this enum explicitly, so it is protected data and must never be renumbered from key order.
142: const LIFE_STAGE_KEYS: Array[StringName] = [&"ADULT", &"CHILD", &"ELDER"]
143: 
144: # --- logical rig identity, MOVE-DEP-R03 -----------------------------------------------------
145: 
146: const RIG_DOMAIN: String = "RigDefinition"
147: 
148: ## MOVE-DEP-R03's table verbatim, one logical base/adult rig key per §4.3 species key. These are
149: ## identities, not assets: none of the sixteen is claimed to have a skeleton or a clip.
150: const SPECIES_RIG_KEY: Dictionary = {
151: 	&"badger": &"rig_badger_v1",
152: 	&"ferret": &"rig_ferret_v1",
153: 	&"fox": &"rig_fox_v1",
154: 	&"hare": &"rig_hare_v1",
155: 	&"hedgehog": &"rig_hedgehog_v1",
156: 	&"kestrel": &"rig_kestrel_v1",
157: 	&"mole": &"rig_mole_v1",
158: 	&"mouse": &"rig_mouse_v1",
159: 	&"otter": &"rig_otter_v1",
160: 	&"rat": &"rig_rat_v1",
161: 	&"shrew": &"rig_shrew_v1",
162: 	&"sparrow": &"rig_sparrow_v1",
163: 	&"squirrel": &"rig_squirrel_v1",
164: 	&"weasel": &"rig_weasel_v1",
165: 	&"wildcat": &"rig_wildcat_v1",
166: 	&"wolverine": &"rig_wolverine_v1",
167: }
168: 
169: ## One rig per species in release 1. A shared rig would make this smaller, and MOVE-DEP-R03
170: ## forbids assuming one: "equal bone names alone do not establish compatible bindings".
171: const RIG_COUNT: int = 16
172: 
173: ## Size classes, matching needs.gd so one resident has one size everywhere.
174: const SIZE_SMALL: int = NeedsScript.SIZE_SMALL
175: const SIZE_MEDIUM: int = NeedsScript.SIZE_MEDIUM
176: const SIZE_LARGE: int = NeedsScript.SIZE_LARGE
177: const SIZE_COUNT: int = NeedsScript.SIZE_COUNT
178: 
179: ## GDD §5.2: "Small size multiplier 1000, medium 1200, large 1600, denominator 1000."
180: const SIZE_MULTIPLIER: Array[int] = NeedsScript.SIZE_MULTIPLIER
181: const SIZE_DENOMINATOR: int = NeedsScript.SIZE_DENOMINATOR
182: 
183: ## GDD §5.2: "Carry capacities 12000/16000/24000 g; movement caps 3277/4096/3072 u/second."
184: ## The large movement cap is genuinely below the medium one in the specification; it is copied,
185: ## not corrected.
186: const SIZE_CARRY_G: Array[int] = [12000, 16000, 24000]
187: const SIZE_MOVEMENT_U_PER_S: Array[int] = [3277, 4096, 3072]
188: 
189: # --- daily nutrition demand, GDD §4.1 / §5.2 / §5.8 -----------------------------------------
190: 
191: ## GDD §4.1: "small resident requires 6000/day at baseline".
192: const BASE_NUTRITION_PER_DAY_NP: int = 6000
193: 
194: ## GDD §5.2 hunger row: "250 x size multiplier; winter x1.20". Non-winter seasons do not scale.
195: const SEASON_MULTIPLIER_WINTER: int = NeedsScript.WINTER_HUNGER_MULTIPLIER
196: const SEASON_MULTIPLIER_DEFAULT: int = NeedsScript.SEASON_DENOMINATOR
197: const SEASON_DENOMINATOR: int = NeedsScript.SEASON_DENOMINATOR
198: 
199: ## One divisor for the compound size x season multiplication, applied after both multiplies so
200: ## the §5.2 "compound multipliers are applied in int64 before division" rule holds.
201: const DEMAND_DENOMINATOR: int = SIZE_DENOMINATOR * SEASON_DENOMINATOR
202: 
203: # --- roles and skills, GDD §4.3 / §5.3 ------------------------------------------------------
204: 
205: const ROLE_RESIDENT: int = 0
206: const ROLE_WARDEN: int = 1
207: const ROLE_SPECIALIST: int = 2
208: const ROLE_COUNT: int = 3
209: 
210: ## GDD §4.2 `Skills`: one fixed 12-column set per resident, indexed by JobKind.
211: const SKILL_COUNT: int = 12
212: const SKILL_KEEP: int = 10
213: ## JobKind.RESERVED_3 carries no XP and no level (§5.1).
214: const SKILL_RESERVED_INDEX: int = 3
215: 
216: const SKILL_LEVEL_MAX: int = 10
217: ## GDD §5.3: level = min(10, floor_sqrt(floor(xp/5000))), i.e. level L starts at 5000*L*L XP.
218: const SKILL_XP_PER_LEVEL_SQUARE: int = 5000
219: 
220: # --- initial settlement, GDD §5.1 -----------------------------------------------------------
221: 
222: ## "12 adults (6 mice, 2 moles, 2 otters, 2 squirrels); IDs 1-12" in the order written.
223: const INITIAL_SPECIES: Array[StringName] = [
224: 	&"mouse", &"mouse", &"mouse", &"mouse", &"mouse", &"mouse",
225: 	&"mole", &"mole", &"otter", &"otter", &"squirrel", &"squirrel",
```

```gdscript
280: const SURROGATE_MAX: int = 0xdfff
281: 
282: ## The three strict-UTF-8 width boundaries, so `utf8_byte_length_of()` is arithmetic rather than
283: ## an encode into a throwaway buffer.
284: const UTF8_ONE_BYTE_MAX: int = 0x7f
285: const UTF8_TWO_BYTE_MAX: int = 0x7ff
286: const UTF8_THREE_BYTE_MAX: int = 0xffff
287: 
288: const REFUSE_NONE: StringName = &""
289: const REFUSE_INVALID_SLOT: StringName = &"INVALID_SLOT"
290: const REFUSE_NOT_PRESENT: StringName = &"RESIDENT_NOT_PRESENT"
291: const REFUSE_UNKNOWN_SPECIES: StringName = &"UNKNOWN_SPECIES"
292: const REFUSE_INVALID_ROLE: StringName = &"INVALID_ROLE"
293: const REFUSE_INVALID_SKILL: StringName = &"INVALID_SKILL"
294: const REFUSE_INVALID_XP: StringName = &"INVALID_XP"
295: const REFUSE_INVALID_COUNT: StringName = &"INVALID_COUNT"
296: ## NAME-R02's five name refusals. Five codes and not one, because a load report that said only
297: ## "bad name" could not tell an over-long alias from a corrupted flag/string pair.
298: const REFUSE_NAME_BYTES: StringName = &"NAME_OVER_BYTE_CAP"
299: const REFUSE_NAME_SCALARS: StringName = &"NAME_SCALAR_COUNT"
300: const REFUSE_NAME_CONTROL: StringName = &"NAME_CONTROL_CHARACTER"
301: const REFUSE_NAME_NOT_UTF8: StringName = &"NAME_NOT_STRICT_UTF8"
302: ## The occupancy half of the table: a named row cannot be empty, an anonymous row cannot hide a
303: ## name, and a free row can carry neither.
304: const REFUSE_NAMED_ROW_EMPTY: StringName = &"NAMED_ROW_EMPTY_NAME"
305: const REFUSE_ANONYMOUS_ROW_NAMED: StringName = &"ANONYMOUS_ROW_HAS_NAME"
306: const REFUSE_FREE_ROW_NAMED: StringName = &"FREE_ROW_HAS_NAME"
307: const REFUSE_RESERVED_SKILL: StringName = &"RESERVED_SKILL_INDEX"
308: const REFUSE_SETTLEMENT_NOT_EMPTY: StringName = &"SETTLEMENT_NOT_EMPTY"
309: const REFUSE_NO_LIVING_RESIDENTS: StringName = &"NO_LIVING_RESIDENTS"
310: const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
311: const REFUSE_SPECIES_CATALOG: StringName = &"SPECIES_CATALOG_INVALID"
312: const REFUSE_NO_EQUIPPED_TOOL: StringName = &"NO_EQUIPPED_TOOL"
313: const REFUSE_TOOL_ALREADY_EQUIPPED: StringName = &"TOOL_ALREADY_EQUIPPED"
314: const REFUSE_INVALID_ITEM_ID: StringName = &"INVALID_ITEM_ID"
315: const REFUSE_INVALID_DURABILITY: StringName = &"INVALID_DURABILITY"
316: const REFUSE_INVALID_CONTAINER: StringName = &"INVALID_CONTAINER"
317: ## MOVE-DEP-R02: a stage outside 0..2. Refused, never clamped to ADULT.
318: const REFUSE_INVALID_LIFE_STAGE: StringName = &"INVALID_LIFE_STAGE"
319: ## A `(slot, generation)` pair the DIRECTORY no longer validates, or one of the wrong kind.
320: const REFUSE_STALE_REF: StringName = &"STALE_RESIDENT_REF"
321: ## A malformed reference: a non-null pair whose slot is negative or whose generation is <= 0.
322: const REFUSE_INVALID_REF: StringName = &"INVALID_REF"
323: ## MOVE-DEP-R03: no `(species, life_stage)` rig variant is authored for a non-adult stage.
324: const REFUSE_RIG_STAGE_UNBOUND: StringName = &"RIG_STAGE_VARIANT_UNBOUND"
325: ## The RigDefinition domain failed to compile, so no rig identity can be answered at all.
326: const REFUSE_RIG_CATALOG: StringName = &"RIG_CATALOG_INVALID"
327: ## The key is not one of the sixteen compiled rig identities.
328: const REFUSE_UNKNOWN_RIG: StringName = &"UNKNOWN_RIG"
329: 
330: ## GDD §4.2 `Equipment`: four of its five I32 columns at length 512 (`clothing_tier` stays in
331: ## `needs.gd`; see the header). Re-derived by `equipment_payload_bytes()`.
332: const EQUIPMENT_MIRROR_COLUMNS: int = 4
333: const EQUIPMENT_MIRROR_BYTES: int = 4 * EQUIPMENT_MIRROR_COLUMNS * RESIDENT_CAPACITY
334: ## "No tool equipped". A cleared column value, never a refusal channel: `has_equipped_tool()`
335: ## answers the question and every reader is an explicit `_into`/OpResult form.
336: const NO_TOOL_ITEM: int = -1
337: 
338: 
339: class OpResult:
340: 	"""Outcome of one residents operation: success flag, refusal code, value and reference.
```

```gdscript
1738: #
1739: # `_name_key` IS NOT HERE, AND ITS ABSENCE IS THE CONTRACT. The registry assigns it to §14
1740: # NAME_POOL, while §4 owns the `_named` flag beside it. `restore_columns()` therefore installs
1741: # `_named` and empties every name, and §14 completes each present row through the ONE name entry
1742: # point decision 0112 published, `restore_name()`, which takes both halves and refuses their
1743: # disagreement. There is no second name path here. Between the two sections a restored named row
1744: # holds a flag with no string; `unresolved_name_row_count()` counts exactly those rows, so a load
1745: # that never ran §14 is observable rather than silent.
1746: #
1747: # `_selected` IS NOT HERE EITHER: ARCH-HASH-001 excludes selection by name and the registry
1748: # classifies it category 3.
1749: #
1750: # GENERATION NAMESPACES, WHICH ARE NOT ONE NAMESPACE. `_ref_*`, `_home_*` and `_bed_*` are
1751: # DIRECTORY generations and are validated as such. `_equip_satchel_generation` is an
1752: # `inventory.gd` CONTAINER generation and is checked for shape only -- this store holds no
1753: # inventory, so validating it against the directory would accept a stale handle whose two
1754: # integers happen to match a live directory slot. Lot and route generations do not appear here.
1755: 
1756: const COLUMN_TYPE_U8: int = 0
1757: const COLUMN_TYPE_I32: int = 2
1758: const COLUMN_TYPE_I64: int = 4
1759: 
1760: ## The nineteen §4 category-1 columns in the registry's declared ordinal order.
1761: const COLUMN_COUNT: int = 19
1762: const COLUMN_KEYS: Array[StringName] = [
1763: 	&"_present", &"_species", &"_size_class", &"_named", &"_life_stage", &"_arrival_tick",
1764: 	&"_role", &"_home_slot", &"_home_generation", &"_bed_slot", &"_bed_generation",
1765: 	&"_ref_slot", &"_ref_generation", &"_equip_tool_item_id", &"_equip_tool_durability",
1766: 	&"_equip_satchel_slot", &"_equip_satchel_generation", &"_skill_xp", &"_skill_level",
1767: ]
1768: const COLUMN_TYPE_CODES: Array[int] = [
1769: 	COLUMN_TYPE_U8, COLUMN_TYPE_I32, COLUMN_TYPE_U8, COLUMN_TYPE_U8, COLUMN_TYPE_U8,
1770: 	COLUMN_TYPE_I64, COLUMN_TYPE_U8, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
1771: 	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
1772: 	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I64, COLUMN_TYPE_I32,
1773: ]
1774: const COLUMN_EXTENTS: Array[int] = [
1775: 	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
1776: 	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
1777: 	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
1778: 	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
1779: 	RESIDENT_CAPACITY, RESIDENT_CAPACITY * SKILL_COUNT, RESIDENT_CAPACITY * SKILL_COUNT,
1780: ]
1781: 
1782: ## Bulk column refusals, read through `last_column_refusal()` and never through an OpResult.
1783: ## Every code is prefixed `COLUMN_`, so a load can never clobber the reason a `spawn()` or a
1784: ## `set_name()` was refused before its caller read it, and no code value is shared with those.
1785: const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
1786: const REFUSE_COLUMN_CATALOG: StringName = &"COLUMN_SPECIES_CATALOG"
1787: const REFUSE_COLUMN_PRESENT_BYTE: StringName = &"COLUMN_PRESENT_BYTE"
1788: const REFUSE_COLUMN_NAMED_BYTE: StringName = &"COLUMN_NAMED_BYTE"
1789: const REFUSE_COLUMN_ENUM_BYTE: StringName = &"COLUMN_ENUM_BYTE"
1790: const REFUSE_COLUMN_SPECIES: StringName = &"COLUMN_SPECIES"
1791: const REFUSE_COLUMN_SIZE_CLASS: StringName = &"COLUMN_SIZE_CLASS_MISMATCH"
1792: const REFUSE_COLUMN_ARRIVAL_TICK: StringName = &"COLUMN_ARRIVAL_TICK"
1793: const REFUSE_COLUMN_REF_SHAPE: StringName = &"COLUMN_REF_SHAPE"
1794: const REFUSE_COLUMN_DIRECTORY_REF: StringName = &"COLUMN_DIRECTORY_REF"
1795: const REFUSE_COLUMN_EQUIPMENT: StringName = &"COLUMN_EQUIPMENT"
1796: const REFUSE_COLUMN_SKILL_XP: StringName = &"COLUMN_SKILL_XP"
1797: const REFUSE_COLUMN_SKILL_LEVEL: StringName = &"COLUMN_SKILL_LEVEL"
1798: const REFUSE_COLUMN_RESERVED_SKILL: StringName = &"COLUMN_RESERVED_SKILL"
1799: const REFUSE_COLUMN_FREE_ROW: StringName = &"COLUMN_FREE_ROW"
1800: const REFUSE_COLUMN_LIVING_CAP: StringName = &"COLUMN_LIVING_CAP"
1801: 
```

Additional capacity/preload/null declarations:
```gdscript
107: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
108: const NeedsScript := preload("res://scripts/core/needs.gd")
109: const Catalog := preload("res://scripts/core/catalog.gd")
110: 
111: ## Resident typed rows, GDD §4.1: storage 512, living population never above 256.
112: const RESIDENT_CAPACITY: int = 512
113: const RESIDENT_LIVING_CAP: int = 256
114: 
230: ## is stored verbatim rather than as an invented key id.
231: const WARDEN_INDEX: int = 0
232: const WARDEN_NAME: StringName = &"Warden Rowan"
233: 
234: ## "Warden KEEP XP=45000; other active initial skills XP=20000; reserved index 3 XP=0."
235: const INITIAL_ACTIVE_SKILL_XP: int = 20000
236: const WARDEN_KEEP_XP: int = 45000
237: 
238: ## Starters exist from the first tick; GDD §5.1 puts tick 0 at 06:00 on day 1.
239: const INITIAL_ARRIVAL_TICK: int = 0
240: 
241: const NO_NAME_KEY: StringName = &""
242: const NULL_REF: Vector2i = EntityDirectory.NULL_REF
243: 
244: # --- personal names, NAME-R02 (2026-09-12) --------------------------------------------------
245: 
246: ## NAME-R02 corrects SAVE-R09-002. The whole occupancy/name table, which is what makes a live
```
