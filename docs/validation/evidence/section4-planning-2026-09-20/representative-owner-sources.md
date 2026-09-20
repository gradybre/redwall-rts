
# godot/scripts/core/buildings.gd
85: ##     integration owner.
86: 
87: const Catalog := preload("res://scripts/core/catalog.gd")
88: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
89: const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
90: const Milestones := preload("res://scripts/core/milestones.gd")
91: 
92: ## systems_architecture.md §2.2 and entity_directory.gd's KIND_CAPACITY, which must agree.
93: const BUILDING_CAPACITY: int = 1024
94: const ROOM_CAPACITY: int = 16384
95: const FURNITURE_CAPACITY: int = 81920
99: ## columns this module owns (`resource_nodes.gd` owns `resource_slot` and left these two to
100: ## "the stores that will").
101: const MAP_TILES_X: int = 128
102: const MAP_TILES_Z: int = 128
103: const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z
104: 
105: ## `systems_architecture.md` §3's `RoomTileLinks`: "Nonoverlapping room tiles", 16384 entries.
106: const ROOM_TILE_LINK_CAPACITY: int = 16384
107: 
108: ## GDD §4.2: "Up to 16 rooms/managed building".
109: const MAX_ROOMS_PER_BUILDING: int = 16
110: 
111: ## GDD §4.2: "rotation 0-3"; §5.9: "rotation in 90 degree steps".
112: const ROTATION_COUNT: int = 4
113: 
114: ## The nine FurnitureDefinition kinds, for the per-kind live counters.
115: const FURNITURE_KIND_COUNT: int = BuildingDefinitions.FURNITURE_DEFINITION_COUNT
119: ## and "Interior 6x6", and "Hall interior origin is exterior origin+(1,1)". `_assert_interiors()`
120: ## re-derives §4.1's room_tiles (80/48/36) from this inset so a drifting table fails loudly.
121: const INTERIOR_INSET_TILES: int = 1
123: ## Internal absence marker for a typed row index, mirroring the directory's NULL_SLOT. It is
124: ## never returned by a public function: every public refusal carries a code instead.
125: const NO_ROW: int = EntityDirectory.NULL_SLOT
126: 
127: ## Empty value of the intrusive chain links and the two tile maps.
128: const NO_LINK: int = -1
129: 
130: const NULL_REF: Vector2i = EntityDirectory.NULL_REF
131: 
132: ## GDD §4.2: "empty catalog IDs are -1". Used for `interior_id` when no indoor kit is bound.
133: const NO_INTERIOR: int = Catalog.EMPTY_CATALOG_ID
134: 
135: const INT32_MIN: int = -2147483648
136: const INT32_MAX: int = 2147483647
138: ## GDD §4.3's protected BuildingState and RoomType ordinals, read from their owner so this
139: ## module holds no second copy of a number §4.3 states.
140: const STATE_BLUEPRINT: int = Catalog.BUILDING_STATE["BLUEPRINT"]
141: const STATE_COUNT: int = 6
142: const ROOM_TYPE_DORMITORY: int = Catalog.ROOM_TYPE["DORMITORY"]
143: const ROOM_TYPE_PRIVATE_ROOM: int = Catalog.ROOM_TYPE["PRIVATE_ROOM"]
144: const ROOM_TYPE_KITCHEN: int = Catalog.ROOM_TYPE["KITCHEN"]
145: const ROOM_TYPE_DINING: int = Catalog.ROOM_TYPE["DINING"]
146: const ROOM_TYPE_COMMON: int = Catalog.ROOM_TYPE["COMMON"]
147: const ROOM_TYPE_INFIRMARY: int = Catalog.ROOM_TYPE["INFIRMARY"]
148: const ROOM_TYPE_PANTRY: int = Catalog.ROOM_TYPE["PANTRY"]
149: const ROOM_TYPE_CORRIDOR: int = Catalog.ROOM_TYPE["CORRIDOR"]
150: const ROOM_TYPE_COUNT: int = 8
154: ## tiles,>=1 bench,>=1 hearth"; "common>=8 tiles,>=4 seats"; "infirmary>=3 tiles/patient
155: ## bed,>=1 bed,>=1 shelf"; "pantry>=4 tiles,>=1 shelf".
156: const TILES_PER_BED: int = 3
157: const PRIVATE_ROOM_MIN_TILES: int = 6
158: const PRIVATE_ROOM_BEDS: int = 1
159: const TILES_PER_SEAT: int = 2
160: const DINING_MIN_SEATS: int = 4
161: const KITCHEN_MIN_TILES: int = 6
162: const COMMON_MIN_TILES: int = 8
163: const COMMON_MIN_SEATS: int = 4
164: const TILES_PER_PATIENT_BED: int = 3
165: const PANTRY_MIN_TILES: int = 4
166: 
167: const REFUSE_NONE: StringName = &""
168: const REFUSE_UNKNOWN_BUILDING_TYPE: StringName = &"UNKNOWN_BUILDING_TYPE"
169: const REFUSE_UNKNOWN_FURNITURE_TYPE: StringName = &"UNKNOWN_FURNITURE_TYPE"
170: const REFUSE_UNKNOWN_ROOM_TYPE: StringName = &"UNKNOWN_ROOM_TYPE"
171: const REFUSE_UNKNOWN_BUILDING_STATE: StringName = &"UNKNOWN_BUILDING_STATE"
172: const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
173: const REFUSE_INVALID_ROTATION: StringName = &"INVALID_ROTATION"
174: const REFUSE_INVALID_TIER: StringName = &"INVALID_TIER"
175: const REFUSE_INVALID_CONDITION: StringName = &"INVALID_CONDITION"
176: const REFUSE_INVALID_INTERIOR_ID: StringName = &"INVALID_INTERIOR_ID"
177: const REFUSE_INVALID_OCCUPANTS: StringName = &"INVALID_OCCUPANTS"
178: const REFUSE_INVALID_TEMPERATURE: StringName = &"INVALID_TEMPERATURE"
179: const REFUSE_FOOTPRINT_OFF_GRID: StringName = &"FOOTPRINT_OFF_GRID"
180: const REFUSE_FOOTPRINT_OCCUPIED: StringName = &"FOOTPRINT_OCCUPIED"
181: const REFUSE_LOCKED_BY_MILESTONE: StringName = &"LOCKED_BY_MILESTONE"
182: const REFUSE_STALE_BUILDING_REF: StringName = &"STALE_BUILDING_REF"
183: const REFUSE_STALE_ROOM_REF: StringName = &"STALE_ROOM_REF"
184: const REFUSE_STALE_FURNITURE_REF: StringName = &"STALE_FURNITURE_REF"
185: const REFUSE_STALE_USER_REF: StringName = &"STALE_USER_REF"
186: const REFUSE_STALE_CONSTRUCTION_REF: StringName = &"STALE_CONSTRUCTION_REF"
187: const REFUSE_NOT_MANAGED_INTERIOR: StringName = &"NOT_MANAGED_INTERIOR"
188: const REFUSE_ROOM_LIMIT: StringName = &"ROOM_LIMIT_PER_BUILDING"
189: const REFUSE_EMPTY_TILE_LIST: StringName = &"EMPTY_TILE_LIST"
190: const REFUSE_DUPLICATE_TILE: StringName = &"DUPLICATE_TILE"
191: const REFUSE_TILE_OUTSIDE_INTERIOR: StringName = &"TILE_OUTSIDE_INTERIOR"
192: const REFUSE_TILE_IN_OTHER_ROOM: StringName = &"TILE_IN_OTHER_ROOM"
193: const REFUSE_TILE_LINK_ARENA_FULL: StringName = &"CAPACITY_ROOM_TILE_LINKS"
194: const REFUSE_TILE_NOT_IN_ROOM: StringName = &"TILE_NOT_IN_ROOM"
195: const REFUSE_FURNITURE_OVERLAP: StringName = &"FURNITURE_OVERLAP"
196: const REFUSE_BUILDING_HAS_ROOMS: StringName = &"BUILDING_HAS_ROOMS"
197: const REFUSE_ROOM_HAS_FURNITURE: StringName = &"ROOM_HAS_FURNITURE"
198: const REFUSE_FURNITURE_IN_USE: StringName = &"FURNITURE_IN_USE"
199: const REFUSE_NOT_A_PANTRY: StringName = &"NOT_A_PANTRY_ROOM"
200: const REFUSE_NOT_A_KITCHEN: StringName = &"NOT_A_KITCHEN_ROOM"
201: const REFUSE_ROOM_NOT_VALID: StringName = &"ROOM_NOT_VALID"
202: const REFUSE_UNKNOWN_STATION: StringName = &"UNKNOWN_STATION"
203: const REFUSE_MASK_MISMATCH: StringName = &"ROOM_FURNITURE_MASK_MISMATCH"
204: const REFUSE_SAME_ROOM: StringName = &"FURNITURE_ALREADY_IN_ROOM"
205: const REFUSE_DIFFERENT_BUILDING: StringName = &"DIFFERENT_BUILDING"
229: # --- collaborators ------------------------------------------------------------------------------
230: 
231: var _directory: EntityDirectory = null
232: var _owns_directory: bool = false
233: var _definitions: BuildingDefinitions = null
235: # --- Building columns (GDD §4.2, architecture §2.2) ---------------------------------------------
236: 
237: var _b_type_id: PackedInt32Array = PackedInt32Array()
238: var _b_tier: PackedInt32Array = PackedInt32Array()
239: var _b_origin_tile: PackedInt32Array = PackedInt32Array()
240: var _b_rotation: PackedInt32Array = PackedInt32Array()
241: var _b_state: PackedInt32Array = PackedInt32Array()
242: var _b_condition: PackedInt32Array = PackedInt32Array()
243: var _b_construction_slot: PackedInt32Array = PackedInt32Array()
244: var _b_construction_generation: PackedInt32Array = PackedInt32Array()
245: var _b_interior_id: PackedInt32Array = PackedInt32Array()
246: 
247: ## Occupancy, the owning directory reference, and the per-building room chain.
248: var _b_present: PackedByteArray = PackedByteArray()
249: var _b_ref_slot: PackedInt32Array = PackedInt32Array()
250: var _b_ref_generation: PackedInt32Array = PackedInt32Array()
251: var _b_room_head: PackedInt32Array = PackedInt32Array()
252: var _b_room_count: PackedInt32Array = PackedInt32Array()
254: # --- Room columns (GDD §4.2, architecture §2.2) --------------------------------------------------
255: 
256: var _r_type: PackedInt32Array = PackedInt32Array()
257: var _r_building_slot: PackedInt32Array = PackedInt32Array()
258: var _r_building_generation: PackedInt32Array = PackedInt32Array()
259: var _r_tile_offset: PackedInt32Array = PackedInt32Array()
260: var _r_tile_count: PackedInt32Array = PackedInt32Array()
261: var _r_temperature_tenths: PackedInt32Array = PackedInt32Array()
262: var _r_furniture_mask: PackedInt32Array = PackedInt32Array()
263: var _r_occupants: PackedInt32Array = PackedInt32Array()
264: var _r_valid: PackedByteArray = PackedByteArray()
265: 
266: ## Occupancy, the owning directory reference, the building chain links and the furniture chain.
267: var _r_present: PackedByteArray = PackedByteArray()
268: var _r_ref_slot: PackedInt32Array = PackedInt32Array()
269: var _r_ref_generation: PackedInt32Array = PackedInt32Array()
270: var _r_building_next: PackedInt32Array = PackedInt32Array()
271: var _r_building_prev: PackedInt32Array = PackedInt32Array()
272: var _r_furniture_head: PackedInt32Array = PackedInt32Array()
273: var _r_furniture_count: PackedInt32Array = PackedInt32Array()
275: # --- Furniture columns (GDD §4.2, architecture §2.2) ---------------------------------------------
276: 
277: var _f_type_id: PackedInt32Array = PackedInt32Array()
278: var _f_room_slot: PackedInt32Array = PackedInt32Array()
279: var _f_room_generation: PackedInt32Array = PackedInt32Array()
280: var _f_origin_tile: PackedInt32Array = PackedInt32Array()
281: var _f_rotation: PackedInt32Array = PackedInt32Array()
282: var _f_user_slot: PackedInt32Array = PackedInt32Array()
283: var _f_user_generation: PackedInt32Array = PackedInt32Array()
284: var _f_condition: PackedInt32Array = PackedInt32Array()
285: 
286: ## Occupancy, the owning directory reference, and the room chain links.
287: var _f_present: PackedByteArray = PackedByteArray()
288: var _f_ref_slot: PackedInt32Array = PackedInt32Array()
289: var _f_ref_generation: PackedInt32Array = PackedInt32Array()
290: var _f_room_next: PackedInt32Array = PackedInt32Array()
291: var _f_room_prev: PackedInt32Array = PackedInt32Array()
296: ## furniture floor occupancy, which GDD §5.9's "furniture cannot overlap" needs and which no
297: ## existing table carries.
298: var _building_slot: PackedInt32Array = PackedInt32Array()
299: var _room_slot: PackedInt32Array = PackedInt32Array()
300: var _furniture_slot: PackedInt32Array = PackedInt32Array()
304: ## room is removed, so the arena never fragments and no free-run table is allocated; every live
305: ## room's `tile_offset` is corrected in the same call.
306: var _room_tile_id: PackedInt32Array = PackedInt32Array()
307: 
308: ## Live per-kind furniture counts, so a HUD bed counter costs a lookup and not an 81920 scan.
309: var _f_kind_count: PackedInt32Array = PackedInt32Array()
310: 
311: var _b_live_count: int = 0
312: var _r_live_count: int = 0
313: var _f_live_count: int = 0
314: var _room_tile_used: int = 0
351: 
352: 
353: func _allocate_columns() -> void:
354: 	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once, never per tick)."""
355: 	_b_type_id.resize(BUILDING_CAPACITY)
356: 	_b_tier.resize(BUILDING_CAPACITY)
357: 	_b_origin_tile.resize(BUILDING_CAPACITY)
358: 	_b_rotation.resize(BUILDING_CAPACITY)
359: 	_b_state.resize(BUILDING_CAPACITY)
360: 	_b_condition.resize(BUILDING_CAPACITY)
361: 	_b_construction_slot.resize(BUILDING_CAPACITY)
362: 	_b_construction_generation.resize(BUILDING_CAPACITY)
363: 	_b_interior_id.resize(BUILDING_CAPACITY)
364: 	_b_present.resize(BUILDING_CAPACITY)
365: 	_b_ref_slot.resize(BUILDING_CAPACITY)
366: 	_b_ref_generation.resize(BUILDING_CAPACITY)
367: 	_b_room_head.resize(BUILDING_CAPACITY)
368: 	_b_room_count.resize(BUILDING_CAPACITY)
369: 	_allocate_room_columns()
370: 	_allocate_furniture_columns()
371: 
372: 
373: func _allocate_room_columns() -> void:
374: 	"""Size the Room columns, the room chain links and the three tile maps."""
375: 	_r_type.resize(ROOM_CAPACITY)
376: 	_r_building_slot.resize(ROOM_CAPACITY)
377: 	_r_building_generation.resize(ROOM_CAPACITY)
378: 	_r_tile_offset.resize(ROOM_CAPACITY)
379: 	_r_tile_count.resize(ROOM_CAPACITY)
380: 	_r_temperature_tenths.resize(ROOM_CAPACITY)
381: 	_r_furniture_mask.resize(ROOM_CAPACITY)
382: 	_r_occupants.resize(ROOM_CAPACITY)
383: 	_r_valid.resize(ROOM_CAPACITY)
384: 	_r_present.resize(ROOM_CAPACITY)
385: 	_r_ref_slot.resize(ROOM_CAPACITY)
386: 	_r_ref_generation.resize(ROOM_CAPACITY)
387: 	_r_building_next.resize(ROOM_CAPACITY)
388: 	_r_building_prev.resize(ROOM_CAPACITY)
389: 	_r_furniture_head.resize(ROOM_CAPACITY)
390: 	_r_furniture_count.resize(ROOM_CAPACITY)
391: 	_building_slot.resize(TILE_COUNT)
392: 	_room_slot.resize(TILE_COUNT)
393: 	_furniture_slot.resize(TILE_COUNT)
394: 	_room_tile_id.resize(ROOM_TILE_LINK_CAPACITY)
395: 
396: 
397: func _allocate_furniture_columns() -> void:
398: 	"""Size the Furniture columns, its chain links and the per-kind live counters."""
399: 	_f_type_id.resize(FURNITURE_CAPACITY)
400: 	_f_room_slot.resize(FURNITURE_CAPACITY)
401: 	_f_room_generation.resize(FURNITURE_CAPACITY)
402: 	_f_origin_tile.resize(FURNITURE_CAPACITY)
403: 	_f_rotation.resize(FURNITURE_CAPACITY)
404: 	_f_user_slot.resize(FURNITURE_CAPACITY)
405: 	_f_user_generation.resize(FURNITURE_CAPACITY)
406: 	_f_condition.resize(FURNITURE_CAPACITY)
407: 	_f_present.resize(FURNITURE_CAPACITY)
408: 	_f_ref_slot.resize(FURNITURE_CAPACITY)
409: 	_f_ref_generation.resize(FURNITURE_CAPACITY)
410: 	_f_room_next.resize(FURNITURE_CAPACITY)
411: 	_f_room_prev.resize(FURNITURE_CAPACITY)
412: 	_f_kind_count.resize(FURNITURE_KIND_COUNT)
413: 
414: 
415: func clear() -> void:
416: 	"""Return every column to its empty state without reallocating one of them."""
417: 	_release_live_rows()
418: 	_clear_building_columns()
419: 	_clear_room_columns()
420: 	_clear_furniture_columns()
421: 	_building_slot.fill(NO_LINK)
422: 	_room_slot.fill(NO_LINK)
423: 	_furniture_slot.fill(NO_LINK)
424: 	_room_tile_id.fill(NO_LINK)
425: 	_f_kind_count.fill(0)
426: 	_b_live_count = 0
427: 	_r_live_count = 0
428: 	_f_live_count = 0
429: 	_room_tile_used = 0
430: 	if _owns_directory:
431: 		_directory.clear()
432: 
433: 
445: 
446: 
447: func _clear_building_columns() -> void:
448: 	"""Zero the Building columns and reset its references and room chain heads."""
449: 	_b_type_id.fill(0)
450: 	_b_tier.fill(0)
451: 	_b_origin_tile.fill(NO_LINK)
452: 	_b_rotation.fill(0)
453: 	_b_state.fill(0)
454: 	_b_condition.fill(0)
455: 	_b_construction_slot.fill(EntityDirectory.NULL_SLOT)
456: 	_b_construction_generation.fill(EntityDirectory.NULL_GENERATION)
457: 	_b_interior_id.fill(NO_INTERIOR)
458: 	_b_present.fill(0)
459: 	_b_ref_slot.fill(EntityDirectory.NULL_SLOT)
460: 	_b_ref_generation.fill(EntityDirectory.NULL_GENERATION)
461: 	_b_room_head.fill(NO_LINK)
462: 	_b_room_count.fill(0)
463: 
464: 
465: func _clear_room_columns() -> void:
466: 	"""Zero the Room columns, its references and both of its chains."""
467: 	_r_type.fill(0)
468: 	_r_building_slot.fill(EntityDirectory.NULL_SLOT)
469: 	_r_building_generation.fill(EntityDirectory.NULL_GENERATION)
470: 	_r_tile_offset.fill(0)
471: 	_r_tile_count.fill(0)
472: 	_r_temperature_tenths.fill(0)
473: 	_r_furniture_mask.fill(0)
474: 	_r_occupants.fill(0)
475: 	_r_valid.fill(0)
476: 	_r_present.fill(0)
477: 	_r_ref_slot.fill(EntityDirectory.NULL_SLOT)
478: 	_r_ref_generation.fill(EntityDirectory.NULL_GENERATION)
479: 	_r_building_next.fill(NO_LINK)
480: 	_r_building_prev.fill(NO_LINK)
481: 	_r_furniture_head.fill(NO_LINK)
482: 	_r_furniture_count.fill(0)
483: 
484: 
485: func _clear_furniture_columns() -> void:
486: 	"""Zero the Furniture columns, its references and its room chain links."""
487: 	_f_type_id.fill(0)
488: 	_f_room_slot.fill(EntityDirectory.NULL_SLOT)
489: 	_f_room_generation.fill(EntityDirectory.NULL_GENERATION)
490: 	_f_origin_tile.fill(NO_LINK)
491: 	_f_rotation.fill(0)
492: 	_f_user_slot.fill(EntityDirectory.NULL_SLOT)
493: 	_f_user_generation.fill(EntityDirectory.NULL_GENERATION)
494: 	_f_condition.fill(0)
495: 	_f_present.fill(0)
496: 	_f_ref_slot.fill(EntityDirectory.NULL_SLOT)
497: 	_f_ref_generation.fill(EntityDirectory.NULL_GENERATION)
498: 	_f_room_next.fill(NO_LINK)
499: 	_f_room_prev.fill(NO_LINK)
500: 
501: 
629: 
630: 
631: func _clear_footprint(row: int) -> void:
632: 	"""Release every `building_slot` tile this structure holds, the inverse of `_stamp_footprint`."""
633: 	var type_id: int = _b_type_id[row]
634: 	var origin_tile: int = _b_origin_tile[row]
635: 	var rotation: int = _b_rotation[row]
636: 	var size_x: int = _definitions.footprint_x_of(type_id)
637: 	var size_z: int = _definitions.footprint_z_of(type_id)
638: 	for offset_z: int in extent_z_of(size_x, size_z, rotation):
639: 		for offset_x: int in extent_x_of(size_x, size_z, rotation):
640: 			_building_slot[_tile_at(origin_tile, offset_x, offset_z)] = NO_LINK
641: 
642: 
1752: 
1753: ## Section 1's owner key, schema version and declared primary row extent for this block.
1754: const SECTION_1_OWNER_KEY: String = "buildings"
1755: const SECTION_1_OWNER_SCHEMA_VERSION: int = 1
1756: const SECTION_1_PRIMARY_COUNT: int = TILE_COUNT
1757: 
1758: const COLUMN_REFUSE_NONE: StringName = &""
1759: const COLUMN_REFUSE_SHAPE: StringName = &"S1_BUILDINGS_COLUMN_SHAPE"
1760: const COLUMN_REFUSE_ROW_RANGE: StringName = &"S1_BUILDINGS_ROW_RANGE"
1761: const COLUMN_REFUSE_NO_COMPONENT: StringName = &"S1_BUILDINGS_NO_COMPONENT"
1762: const COLUMN_REFUSE_STALE_IDENTITY: StringName = &"S1_BUILDINGS_STALE_IDENTITY"
1763: const COLUMN_REFUSE_FOOTPRINT: StringName = &"S1_BUILDINGS_FOOTPRINT_MISMATCH"
1764: const COLUMN_REFUSE_STRAY_TILE: StringName = &"S1_BUILDINGS_STRAY_TILE"
1765: 
1766: ## Detail behind the most recent §1 column refusal. Empty after an accepted call.
1767: var _section_1_detail: String = ""
1773: 
1774: 
1775: func copy_section_1_columns_into(out_building_slot: PackedInt32Array,
1776: 		out_room_slot: PackedInt32Array, out_furniture_slot: PackedInt32Array) -> bool:
1777: 	"""Snapshot the three tile maps into caller-owned buffers already TILE_COUNT long."""
1778: 	if not _section_1_sized(_building_slot, _room_slot, _furniture_slot, "the live tile maps"):
1779: 		return false
1780: 	if not _section_1_sized(out_building_slot, out_room_slot, out_furniture_slot,
1781: 			"the destination buffers"):
1782: 		return false
1783: 	out_building_slot.clear()
1784: 	out_building_slot.append_array(_building_slot)
1785: 	out_room_slot.clear()
1786: 	out_room_slot.append_array(_room_slot)
1787: 	out_furniture_slot.clear()
1788: 	out_furniture_slot.append_array(_furniture_slot)
1789: 	_section_1_detail = ""
1790: 	return true
1791: 
1792: 
1957: 
1958: 
1959: func restore_section_1_columns(building_slot: PackedInt32Array, room_slot: PackedInt32Array,
1960: 		furniture_slot: PackedInt32Array) -> bool:
1961: 	"""Install three validated tile maps. Validates first, so a refusal changes nothing."""
1962: 	if section_1_local_refusal(building_slot, room_slot, furniture_slot) != COLUMN_REFUSE_NONE:
1963: 		return false
1964: 	_building_slot = building_slot.duplicate()
1965: 	_room_slot = room_slot.duplicate()
1966: 	_furniture_slot = furniture_slot.duplicate()
1967: 	_section_1_detail = ""
1968: 	return true
1969: 
1970: 

# godot/scripts/core/field_policy.gd
228: ## encodings, checked by explicit predicates, never returned to signal a failure.
229: 
230: const IntMath := preload("res://scripts/core/int_math.gd")
231: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
232: const FarmingScript := preload("res://scripts/core/farming.gd")
233: const ForageScript := preload("res://scripts/core/forage.gd")
234: const JobsScript := preload("res://scripts/core/jobs.gd")
235: const SimClock := preload("res://scripts/core/sim_clock.gd")
240: ## row and the capacity is read from forage.gd rather than restated. systems_architecture.md §2.2
241: ## budgets FieldPolicy at exactly these 128 rows.
242: const FIELD_CAPACITY: int = ForageScript.HARVEST_ZONE_CAPACITY
243: ## §4.2's `rotation_ids: int32[3]`, and §5.6's "explicit three-entry cycle".
244: const ROTATION_LENGTH: int = 3
245: ## The enrolment ledger's owner class: farming.gd's own FarmPlot capacity, read, not restated.
246: const PLOT_CAPACITY: int = FarmingScript.FARM_PLOT_CAPACITY
250: ## §4.2 and the ruling: "grain/beans/roots". §5.6 states the same cycle: "default cycle
251: ## grain->beans->roots". The ids are farming.gd's, which are catalog.gd's (decision 0018).
252: const DEFAULT_ROTATION: Array[int] = [
254: ]
255: ## §4.2 and the ruling: "cursor 0".
256: const DEFAULT_ROTATION_CURSOR: int = 0
257: ## §4.2 and the ruling: "auto false". Load-bearing -- see the header.
258: const DEFAULT_AUTO_ROTATION: bool = false
259: ## §4.2 and the ruling: "reserve true".
260: const DEFAULT_SEED_RESERVE: bool = true
263: 
264: ## No cycle has been opened on this field. Cycle ordinals start at 1, so 0 names none.
265: const NO_CYCLE: int = 0
266: ## The first cycle opened on a field row.
267: const FIRST_CYCLE: int = 1
268: ## int32's maximum. `open_cycle()` REFUSES at the cap; the ordinal never wraps onto a live stamp.
269: const MAX_CYCLE: int = IntMath.INT32_MAX
270: ## §4.2: "empty catalog IDs are -1". An unconfigured rotation entry carries farming.gd's own value.
271: const NO_CROP: int = FarmingScript.CROP_NONE
272: ## An unenrolled plot names no field. §4.1's null slot, checked explicitly, never returned as a
273: ## failure signal.
274: const NO_FIELD: int = EntityDirectory.NULL_SLOT
277: 
278: ## No cycle is open and none has closed on this row since it was created.
279: const CYCLE_IDLE: int = 0
280: ## A planting cycle is in progress: participants may enrol, resolve or withdraw.
281: const CYCLE_OPEN: int = 1
282: ## The cycle finished. `_close_reason` says how, and the advance decision has already been taken.
283: const CYCLE_CLOSED: int = 2
284: const CYCLE_STATE_COUNT: int = 3
287: 
288: ## No cycle has closed on this row.
289: const CLOSE_NONE: int = 0
290: ## Every participating plot finished harvesting or clearing. The ONLY reason that may advance.
291: const CLOSE_COMPLETED: int = 1
292: ## `cancel_cycle()` closed an unresolved cycle. Recorded as a cancellation, never as a completion.
293: const CLOSE_CANCELLED: int = 2
294: ## Every participant was withdrawn, so nothing was left that could ever resolve. No advance.
295: const CLOSE_ABANDONED: int = 3
296: const CLOSE_REASON_COUNT: int = 4
299: 
300: ## Enrolled and still working, or never enrolled in the stamped cycle.
301: const OUTCOME_UNRESOLVED: int = 0
302: ## REQ-SET-074's successful harvest.
303: const OUTCOME_HARVESTED: int = 1
304: ## REQ-SET-085's withered clearing. The ruling's "finished harvesting/CLEARING".
305: const OUTCOME_CLEARED: int = 2
306: ## The tile was erased or undesignated. NOT a resolution and NOT a successful harvest.
307: const OUTCOME_WITHDRAWN: int = 3
308: const OUTCOME_COUNT: int = 4
312: ## No request stands. The state after an `auto_rotation = false` completion, and the state a
313: ## player edit never leaves.
314: const REQUEST_NONE: int = 0
315: ## The requested crop's planting window admits it today.
316: const REQUEST_READY: int = 1
317: ## "If its legal window is future, retain the request."
318: const REQUEST_WINDOW_FUTURE: int = 2
319: ## "If missed, show the existing warning and wait for its next legal window or a player edit."
320: const REQUEST_WINDOW_MISSED: int = 3
321: ## The rotation entry at the cursor is `NO_CROP`. NOT skipped and NOT substituted.
322: const REQUEST_ENTRY_NOT_CONFIGURED: int = 4
323: ## The crop names no legal planting day in the whole year. Unreachable through §5.6's table; kept
324: ## for a save/load path that cannot be trusted to be well formed.
325: const REQUEST_NO_LEGAL_WINDOW: int = 5
326: const REQUEST_STATE_COUNT: int = 6
329: 
330: ## "This policy declares no such requirement": the reserve is off.
331: const SEED_GATE_NOT_REQUIRED: int = JobsScript.GATE_NOT_REQUIRED
332: ## Decision 0023's "a missing subsystem must never silently read as satisfied": the reserve is on
333: ## and no reservation path exists to satisfy it. NEVER `GATE_SATISFIED`.
334: const SEED_GATE_UNAVAILABLE: int = JobsScript.GATE_UNAVAILABLE
336: # --- refusal codes ------------------------------------------------------------------------------
337: 
338: const REFUSE_NONE: StringName = &""
339: const REFUSE_INVALID_FIELD_SLOT: StringName = &"INVALID_FIELD_SLOT"
340: const REFUSE_INVALID_PLOT_SLOT: StringName = &"INVALID_PLOT_SLOT"
341: const REFUSE_INVALID_INDEX: StringName = &"INVALID_ROTATION_INDEX"
342: const REFUSE_INVALID_CURSOR: StringName = &"INVALID_ROTATION_CURSOR"
343: const REFUSE_INVALID_CROP: StringName = &"INVALID_CROP"
344: const REFUSE_INVALID_OUTCOME: StringName = &"INVALID_PLOT_OUTCOME"
345: const REFUSE_INVALID_REQUEST_STATE: StringName = &"INVALID_REQUEST_STATE"
346: const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
347: const REFUSE_INVALID_TILE_COUNT: StringName = &"INVALID_TILE_COUNT"
348: const REFUSE_ZONE_NOT_PRESENT: StringName = &"ZONE_NOT_PRESENT"
349: const REFUSE_ZONE_TYPE_MISMATCH: StringName = &"ZONE_TYPE_MISMATCH"
350: const REFUSE_POLICY_EXISTS: StringName = &"FIELD_POLICY_EXISTS"
351: const REFUSE_NO_POLICY: StringName = &"NO_FIELD_POLICY"
352: const REFUSE_CYCLE_OPEN: StringName = &"FIELD_CYCLE_ALREADY_OPEN"
353: const REFUSE_NO_OPEN_CYCLE: StringName = &"NO_OPEN_FIELD_CYCLE"
354: const REFUSE_CYCLE_OVERFLOW: StringName = &"FIELD_CYCLE_OVERFLOW"
355: const REFUSE_PLOT_NOT_PRESENT: StringName = &"PLOT_NOT_PRESENT"
356: const REFUSE_PLOT_ENROLLED: StringName = &"PLOT_ALREADY_ENROLLED"
357: const REFUSE_PLOT_NOT_ENROLLED: StringName = &"PLOT_NOT_ENROLLED"
358: const REFUSE_PLOT_RESOLVED: StringName = &"PLOT_ALREADY_RESOLVED"
359: const REFUSE_PLOT_WITHDRAWN: StringName = &"PLOT_WITHDRAWN"
360: const REFUSE_SEED_RESERVE: StringName = &"SEED_RESERVE_UNANSWERABLE"
361: const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
363: # --- REQ-SET-077's blocked reason codes ----------------------------------------------------------
364: 
365: const BLOCKED_WINDOW_FUTURE: StringName = &"PLANT_WINDOW_IS_FUTURE"
366: const BLOCKED_WINDOW_MISSED: StringName = &"PLANT_WINDOW_MISSED"
367: const BLOCKED_ENTRY_NOT_CONFIGURED: StringName = &"ROTATION_ENTRY_NOT_CONFIGURED"
368: const BLOCKED_NO_LEGAL_WINDOW: StringName = &"CROP_HAS_NO_LEGAL_WINDOW"
371: ## request is not blocked at all. ONE mapping, so the byte kept on the row and the code shown to
372: ## the player cannot drift. Indexed by REQUEST_*.
373: const REQUEST_BLOCKED_REASONS: Array[StringName] = [
398: # --- collaborating stores -----------------------------------------------------------------------
399: 
400: var _farming: FarmingScript = null
401: var _forage: ForageScript = null
405: ## §4.2's `zone: EntityRef`, both halves. A HarvestZone row is reused after a destroy, so a policy
406: ## that recorded only the row index would be inherited by whatever zone lands there next.
407: var _zone_slot: PackedInt32Array = PackedInt32Array()
408: var _zone_generation: PackedInt32Array = PackedInt32Array()
409: ## §4.2's `rotation_ids: int32[3]`, owner-major: `field * ROTATION_LENGTH + index`.
410: var _rotation_ids: PackedInt32Array = PackedInt32Array()
411: ## §4.2's `rotation_cursor`: which of the three entries is current. Wraps; counts nothing.
412: var _rotation_cursor: PackedInt32Array = PackedInt32Array()
413: ## §4.2's `auto_rotation`. Read at cycle close and nowhere else.
414: var _auto_rotation: PackedByteArray = PackedByteArray()
415: ## §4.2's `seed_reserve`. REQ-SET-088's policy flag; its gate is unsatisfiable in this build.
416: var _seed_reserve: PackedByteArray = PackedByteArray()
419: 
420: ## 1 while this row holds a policy. §4.2 gives no presence column; a store needs one.
421: var _field_present: PackedByteArray = PackedByteArray()
422: ## The per-field monotonic ordinal that stamps an enrolment. NOT decision 0040's per-plot cursor.
423: var _cycle_ordinal: PackedInt32Array = PackedInt32Array()
424: ## Enrolled and not withdrawn. The "all participating plots" the ruling's advance waits for.
425: var _participants: PackedInt32Array = PackedInt32Array()
426: ## Participants that finished harvesting or clearing. Never incremented by a withdrawal.
427: var _resolved: PackedInt32Array = PackedInt32Array()
428: ## Participants withdrawn by an erase. Durable, so an ABANDONED close can be explained.
429: var _withdrawn: PackedInt32Array = PackedInt32Array()
430: ## Durable count of cycles that closed COMPLETED. Completion history the ruling forbids discarding.
431: var _completed_cycles: PackedInt32Array = PackedInt32Array()
432: ## Durable count of cycles closed by an explicit cancellation. Kept separately from the above so a
433: ## cancellation can never be read back as a completion.
434: var _cancelled_cycles: PackedInt32Array = PackedInt32Array()
435: ## The crop the advance requested and retained. `NO_CROP` when no request stands.
436: var _requested_crop: PackedInt32Array = PackedInt32Array()
437: ## CYCLE_IDLE / CYCLE_OPEN / CYCLE_CLOSED.
438: var _cycle_state: PackedByteArray = PackedByteArray()
439: ## How the last cycle on this row closed.
440: var _close_reason: PackedByteArray = PackedByteArray()
441: ## The request's state, which is also REQ-SET-077's blocked reason.
442: var _request_state: PackedByteArray = PackedByteArray()
445: 
446: ## The field row this plot is enrolled in, or NO_FIELD. Meaningful only with a matching stamp.
447: var _plot_field_slot: PackedInt32Array = PackedInt32Array()
448: ## The field cycle ordinal the enrolment was stamped with. A stamp that no longer matches the
449: ## field's current ordinal is stale, and a stale enrolment can resolve nothing.
450: var _plot_cycle: PackedInt32Array = PackedInt32Array()
451: ## OUTCOME_UNRESOLVED / HARVESTED / CLEARED / WITHDRAWN.
452: var _plot_outcome: PackedByteArray = PackedByteArray()
454: # --- observable counters ------------------------------------------------------------------------
455: 
456: var _policy_count: int = 0
457: var _opened_count: int = 0
458: var _completed_count: int = 0
459: var _cancelled_count: int = 0
460: var _abandoned_count: int = 0
461: var _advance_count: int = 0
462: var _resolved_plot_count: int = 0
463: var _withdrawn_plot_count: int = 0
464: var _retained_request_count: int = 0
465: var _missed_request_count: int = 0
467: # --- scratch (not simulation state) --------------------------------------------------------------
468: 
469: var _math: IntMath.IntResult = IntMath.IntResult.new()
470: ## One owned Calendar, re-decoded through `SimClock.calendar_at_into()`. Every field is read into
471: ## a local before anything else can touch it, so no two live values share this instance.
472: var _calendar: SimClock.Calendar = SimClock.Calendar.new()
502: 
503: 
504: func _allocate_columns() -> void:
505: 	"""Size every packed column exactly once. Nothing outside this function calls resize().
506: 
507: 	Each column is resized BY NAME. A loop over an `Array` of packed columns would resize COPIES:
508: 	`PackedInt32Array` is a value type, so binding one to a loop variable duplicates it and the
509: 	member arrays would stay empty.
510: 	"""
511: 	_zone_slot.resize(FIELD_CAPACITY)
512: 	_zone_generation.resize(FIELD_CAPACITY)
513: 	_rotation_ids.resize(FIELD_CAPACITY * ROTATION_LENGTH)
514: 	_rotation_cursor.resize(FIELD_CAPACITY)
515: 	_auto_rotation.resize(FIELD_CAPACITY)
516: 	_seed_reserve.resize(FIELD_CAPACITY)
517: 	_field_present.resize(FIELD_CAPACITY)
518: 	_cycle_ordinal.resize(FIELD_CAPACITY)
519: 	_participants.resize(FIELD_CAPACITY)
520: 	_resolved.resize(FIELD_CAPACITY)
521: 	_withdrawn.resize(FIELD_CAPACITY)
522: 	_completed_cycles.resize(FIELD_CAPACITY)
523: 	_cancelled_cycles.resize(FIELD_CAPACITY)
524: 	_requested_crop.resize(FIELD_CAPACITY)
525: 	_cycle_state.resize(FIELD_CAPACITY)
526: 	_close_reason.resize(FIELD_CAPACITY)
527: 	_request_state.resize(FIELD_CAPACITY)
528: 	_allocate_enrolment_ledger()
529: 
530: 
531: func _allocate_enrolment_ledger() -> void:
532: 	"""Size decision 0045's plot-major enrolment ledger once, over farming.gd's 4096 FarmPlots."""
533: 	_plot_field_slot.resize(PLOT_CAPACITY)
534: 	_plot_cycle.resize(PLOT_CAPACITY)
535: 	_plot_outcome.resize(PLOT_CAPACITY)
536: 
537: 
538: func clear() -> void:
539: 	"""Refill every existing buffer to the empty store. Allocates nothing and resizes nothing."""
540: 	_zone_slot.fill(EntityDirectory.NULL_SLOT)
541: 	_zone_generation.fill(EntityDirectory.NULL_GENERATION)
542: 	_rotation_ids.fill(NO_CROP)
543: 	_rotation_cursor.fill(DEFAULT_ROTATION_CURSOR)
544: 	_auto_rotation.fill(1 if DEFAULT_AUTO_ROTATION else 0)
545: 	_seed_reserve.fill(1 if DEFAULT_SEED_RESERVE else 0)
546: 	_field_present.fill(0)
547: 	_cycle_ordinal.fill(NO_CYCLE)
548: 	_participants.fill(0)
549: 	_resolved.fill(0)
550: 	_withdrawn.fill(0)
551: 	_completed_cycles.fill(0)
552: 	_cancelled_cycles.fill(0)
553: 	_requested_crop.fill(NO_CROP)
554: 	_cycle_state.fill(CYCLE_IDLE)
555: 	_close_reason.fill(CLOSE_NONE)
556: 	_request_state.fill(REQUEST_NONE)
557: 	_plot_field_slot.fill(NO_FIELD)
558: 	_plot_cycle.fill(NO_CYCLE)
559: 	_plot_outcome.fill(OUTCOME_UNRESOLVED)
560: 	_reset_counters()
561: 
562: 
663: # --- creation and destruction --------------------------------------------------------------------
664: 
665: func create_policy(zone_ref: Vector2i) -> OpResult:
666: 	"""Bind one FieldPolicy to a live FARM-type zone, with §4.2's four defaults. Returns its row.
667: 
668: 	The row index IS the zone's typed row, which is what "one per FARM zone" means with a
669: 	128-row policy table over a 128-row zone table; no allocator is needed and none is added.
670: 	`_cycle_ordinal` is deliberately NOT reset, so a row reused by a different zone cannot
671: 	inherit a stale enrolment stamp.
672: 	"""
673: 	if not _forage.zone_slot_of_into(zone_ref, _math):
674: 		return _refuse(REFUSE_ZONE_NOT_PRESENT)
675: 	var slot: int = _math.value
676: 	var zone_type: IntMath.IntResult = _forage.zone_type_of(slot)
677: 	if not zone_type.ok:
678: 		return _refuse(REFUSE_ZONE_NOT_PRESENT)
679: 	if zone_type.value != ForageScript.ZONE_TYPE_FARM:
680: 		return _refuse(REFUSE_ZONE_TYPE_MISMATCH)
681: 	if _field_present[slot] == 1:
682: 		if zone_is_live(slot):
683: 			return _refuse(REFUSE_POLICY_EXISTS)
684: 		_reclaim_stale_policy(slot)
685: 	_write_default_policy(slot, zone_ref)
686: 	return _succeed(slot, zone_ref)
687: 
688: 
722: 
723: 
724: func destroy_policy(zone_ref: Vector2i) -> OpResult:
725: 	"""Retire the policy bound to a zone. Any open cycle's enrolments go stale, never inherited.
726: 
727: 	The enrolment ledger is NOT walked: `_cycle_ordinal` stays where it is and is never reset, so
728: 	every stamp written under this policy fails the ordinal check for whatever policy occupies the
729: 	row next. That is the same generation-validation discipline §4.1 applies to EntityRefs.
730: 	"""
731: 	var field_slot: int = _resolve(zone_ref)
732: 	if field_slot == NO_FIELD:
733: 		return _refuse(StringName(_math.error))
734: 	_zone_slot[field_slot] = EntityDirectory.NULL_SLOT
735: 	_zone_generation[field_slot] = EntityDirectory.NULL_GENERATION
736: 	_cycle_state[field_slot] = CYCLE_IDLE
737: 	_request_state[field_slot] = REQUEST_NONE
738: 	_requested_crop[field_slot] = NO_CROP
739: 	_participants[field_slot] = 0
740: 	_resolved[field_slot] = 0
741: 	_field_present[field_slot] = 0
742: 	_policy_count -= 1
743: 	return _succeed(field_slot, zone_ref)
744: 
745: 
746: # --- §4.2's policy columns: the player edit path (blocker U2) --------------------------------------
747: 

# godot/scripts/core/fishing.gd
239: ##     each habitat type on the map whether or not the player has designated a zone over it.
240: 
241: const IntMath := preload("res://scripts/core/int_math.gd")
242: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
243: const Catalog := preload("res://scripts/core/catalog.gd")
244: const SimClock := preload("res://scripts/core/sim_clock.gd")
245: const ForageScript := preload("res://scripts/core/forage.gd")
246: const JobsScript := preload("res://scripts/core/jobs.gd")
249: 
250: ## GDD §4.2: "One per marked water basin; up to 32".
251: const FISH_HABITAT_CAPACITY: int = 32
252: ## GDD §4.2: "3 stocks/habitat".
253: const SPECIES_PER_HABITAT: int = 3
254: ## systems_architecture.md §2.2 FishStock length: 96 == 32 * 3.
255: const FISH_STOCK_CAPACITY: int = FISH_HABITAT_CAPACITY * SPECIES_PER_HABITAT
258: ## entity_directory.gd's KIND_EXPEDITION capacity and never a number of its own. `_init()` asserts
259: ## the two agree.
260: const FISHING_EFFORT_CLAIM_CAPACITY: int = 512
262: ## FISH-ID-R01: the section 7 `fishing` owner schema. Appending the stored Expedition slot at
263: ## ordinal 7 advances it 1 -> 2; the codec reads it here as it reads Inventory's version.
264: const CANONICAL_OWNER_SCHEMA_VERSION: int = 2
265: 
266: ## §4.3 ZoneType.FISH, read from catalog.gd's protected table (decision 0018), never mirrored.
267: const ZONE_TYPE_FISH: int = Catalog.ZONE_TYPE["FISH"]
269: ## Packed payload accounting, so the byte figures reported below are measured off the real column
270: ## sizes instead of being restated by hand (R05-QUOTA-024's rule, applied here too).
271: const BYTES_PER_INT32: int = 4
272: const BYTES_PER_INT64: int = 8
273: const BYTES_PER_BYTE_COLUMN: int = 1
275: # --- GDD §4.3 Season, read from catalog.gd's protected table (decision 0018) ----------------------
276: 
277: const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
278: const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
279: const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
280: const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
281: const SEASON_COUNT: int = 4
284: ## §5.4's windows ("Spring days 5-7") are days WITHIN a season, which is what Calendar.season_day
285: ## reports, numbered from 1.
286: const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
287: const FIRST_SEASON_DAY: int = 1
291: ## Read from catalog.gd, never mirrored: `Catalog.HABITAT_TYPE[...]` is a constant expression, so
292: ## there is exactly one copy of each id (GDD §4.2's closing paragraph via decision 0018's rule).
293: const HABITAT_TYPE_DOMAIN: String = Catalog.HABITAT_TYPE_DOMAIN
294: const HABITAT_COAST: int = Catalog.HABITAT_TYPE["COAST"]
295: const HABITAT_LAKE: int = Catalog.HABITAT_TYPE["LAKE"]
296: const HABITAT_RIVER: int = Catalog.HABITAT_TYPE["RIVER"]
297: const HABITAT_TYPE_COUNT: int = 3
300: ## so a caller can never supply a slot count that disagrees with the specification. _init()
301: ## asserts each entry against its named habitat, so this literal cannot drift out of that order.
302: const RIVER_EFFORT_SLOTS: int = 4
303: const LAKE_EFFORT_SLOTS: int = 6
304: const COAST_EFFORT_SLOTS: int = 6
305: const EFFORT_SLOTS_BY_TYPE: Array[int] = [
313: ## order so that a later compiled domain, which GDD §4.2's closing paragraph would number the same
314: ## way, cannot disagree with them.
315: const GEAR_BOAT: int = 0
316: const GEAR_HAND_NET: int = 1
317: const GEAR_ICE_KIT: int = 2
318: const GEAR_TRAP: int = 3
319: const GEAR_WEIR: int = 4
320: const GEAR_COUNT: int = 5
321: const GEAR_KEYS: Array[StringName] = [&"boat", &"hand_net", &"ice_kit", &"trap", &"weir"]
325: ## net/trap/ice kit; two for weir/boat", and `_init()` asserts each entry against its NAMED gear
326: ## rather than a bare position.
327: const BASIC_GEAR_EFFORT_SLOTS: int = 1
328: const HEAVY_GEAR_EFFORT_SLOTS: int = 2
329: const GEAR_EFFORT_SLOTS: Array[int] = [
336: ## §5.4's nine table rows in the document's printed order. These are TABLE ROWS, not habitat ids
337: ## and not catalog ids: HABITAT_SPECIES_ROWS binds a habitat to its three rows explicitly.
338: const SPECIES_TROUT: int = 0
339: const SPECIES_DACE: int = 1
340: const SPECIES_SALMON: int = 2
341: const SPECIES_PERCH: int = 3
342: const SPECIES_CARP: int = 4
343: const SPECIES_WHITEFISH: int = 5
344: const SPECIES_HERRING: int = 6
345: const SPECIES_MACKEREL: int = 7
346: const SPECIES_MUSSEL: int = 8
347: const SPECIES_COUNT: int = HABITAT_TYPE_COUNT * SPECIES_PER_HABITAT
352: ## Indexing a TABLE by a compiled id is not the same as COMPUTING identity from one -- see the
353: ## header -- and _init() asserts this table and SPECIES_HABITAT_TYPE are mutual inverses.
354: const HABITAT_SPECIES_ROWS: Array[int] = [
359: 
360: ## The same binding read backwards: §5.4's nine rows in printed order, each naming its habitat.
361: const SPECIES_HABITAT_TYPE: Array[int] = [
371: ## below is subscripted by these row numbers. This is NOT the habitat-major order
372: ## `create_habitat()` takes -- see the header.
373: const SPECIES_KEYS: Array[StringName] = [
378: 
379: ## §5.4's "Capacity U" column, whole units.
380: const SPECIES_CAPACITY_U: Array[int] = [600, 900, 600, 900, 700, 600, 1200, 900, 1000]
383: ## Mackerel's winter 0 IS §5.4's "No winter harvest"; salmon's three zeroes are its autumn-only
384: ## run. Herring's spring 1200 is overridden to 1500 on days 1-4 by its special window.
385: const SPECIES_AVAILABILITY_PER_1000: Array[int] = [
396: 
397: ## §5.4's "Daily recovery r/1000" column, the `r` of the midnight recovery formula.
398: const SPECIES_RECOVERY_PER_1000: Array[int] = [80, 120, 100, 100, 80, 90, 120, 100, 60]
401: 
402: ## "River | trout | Spring days 5-7 spawning closure".
403: const TROUT_CLOSURE_FIRST_DAY: int = 5
404: const TROUT_CLOSURE_LAST_DAY: int = 7
405: ## "River | salmon | Autumn days 1-4 harvest run; days 5-8 spawning closure".
406: const SALMON_RUN_FIRST_DAY: int = 1
407: const SALMON_RUN_LAST_DAY: int = 4
408: const SALMON_CLOSURE_FIRST_DAY: int = 5
409: const SALMON_CLOSURE_LAST_DAY: int = 8
410: ## "Lake | carp | Spring days 8-10 closure". See the header: not labelled a SPAWNING closure.
411: const CARP_CLOSURE_FIRST_DAY: int = 8
412: const CARP_CLOSURE_LAST_DAY: int = 10
413: ## "Coast | herring | Spring days 1-4 multiplier 1500 instead of 1200".
414: const HERRING_RUN_FIRST_DAY: int = 1
415: const HERRING_RUN_LAST_DAY: int = 4
416: const HERRING_RUN_PER_1000: int = 1500
417: ## "Salmon additionally receive 300 U at autumn day 1, capped at K."
418: const SALMON_AUTUMN_RESTOCK_U: int = 300
421: 
422: ## AGENTS.md: "Quantities are quantity_milli:int64 (1000 = one unit)."
423: const MILLI_PER_UNIT: int = 1000
424: 
425: ## §5.4: "Initial stocks are 80% of capacity."
426: const INITIAL_STOCK_NUMERATOR: int = 8
427: const INITIAL_STOCK_DENOMINATOR: int = 10
429: ## §5.4: "At midnight `P'=min(K,P+floor(r*P*(K-P)/(1000*K))+floor(K/200))`". The 1000 is r's
430: ## denominator; the 200 is external recruitment's, "not reproduction from nothing".
431: const RECOVERY_DENOMINATOR: int = 1000
432: const RECRUITMENT_DIVISOR: int = 200
434: ## §5.4: "A habitat's sustainable daily quota is `floor(K_total_milli/40)` milli-U across
435: ## species (2.5% of capacity)."
436: const DAILY_QUOTA_DIVISOR: int = 40
437: 
438: ## §5.4 conservation defaults and floors.
439: const MIN_STOCK_PERCENT: int = 30
440: const HARD_FLOOR_PERCENT: int = 10
441: const HABITAT_REFUGE_PERCENT: int = 25
442: const PERCENT_DENOMINATOR: int = 100
444: ## REQ-SET-048's two stated thresholds. Numerically 30 matches the minimum stock above, but it
445: ## is a different sentence in a different requirement and is kept separate on purpose.
446: const DEPLETION_WARNING_PERCENT: int = 30
447: const RESTOCK_RECOVERY_PERCENT: int = 40
449: ## §5.4: "Catch for species i is `floor(base_catch_milli*(1000+50*skill)*A*S/1000000000)`, where
450: ## `A=clamp(floor(1000*P/K),200,1000)`".
451: const CATCH_BASE_TERM: int = 1000
452: const CATCH_SKILL_TERM: int = 50
453: const CATCH_DENOMINATOR: int = 1000000000
454: const ABUNDANCE_SCALE: int = 1000
455: const ABUNDANCE_MIN: int = 200
456: const ABUNDANCE_MAX: int = 1000
457: 
458: ## §5.3: "Level=`min(10,floor_sqrt(floor(xp/5000)))`" -- skills are 0..10, not 0..20.
459: const SKILL_LEVEL_MIN: int = 0
460: const SKILL_LEVEL_MAX: int = 10
461: 
462: ## §5.4: "danger 0-3".
463: const DANGER_MIN: int = 0
464: const DANGER_MAX: int = 3
466: ## §4.3 JobState.CANCELLED, read from catalog.gd's protected table, never mirrored. It is the one
467: ## Job state this store consults: ruling §5's "completion, cancellation and stale calls".
468: const JOB_STATE_CANCELLED: int = Catalog.JOB_STATE["CANCELLED"]
469: 
470: const NULL_REF: Vector2i = EntityDirectory.NULL_REF
472: # --- refusal codes ---------------------------------------------------------------------------------
473: 
474: const REFUSE_NONE: StringName = &""
475: const REFUSE_HABITAT_NOT_PRESENT: StringName = &"HABITAT_NOT_PRESENT"
476: const REFUSE_STOCK_NOT_PRESENT: StringName = &"STOCK_NOT_PRESENT"
477: const REFUSE_INVALID_HABITAT_TYPE: StringName = &"INVALID_HABITAT_TYPE"
478: const REFUSE_INVALID_ZONE_REF: StringName = &"INVALID_ZONE_REF"
479: const REFUSE_INVALID_POLLUTION: StringName = &"INVALID_POLLUTION"
480: const REFUSE_INVALID_DANGER: StringName = &"INVALID_DANGER"
481: const REFUSE_INVALID_PROTECTED_FRACTION: StringName = &"INVALID_PROTECTED_FRACTION"
482: const REFUSE_SPECIES_SET_SIZE: StringName = &"SPECIES_SET_SIZE"
483: const REFUSE_INVALID_SPECIES_ID: StringName = &"INVALID_SPECIES_ID"
484: const REFUSE_DUPLICATE_SPECIES_ID: StringName = &"DUPLICATE_SPECIES_ID"
485: const REFUSE_INVALID_SPECIES: StringName = &"INVALID_SPECIES"
486: const REFUSE_INVALID_SPECIES_INDEX: StringName = &"INVALID_SPECIES_INDEX"
487: const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
488: const REFUSE_INVALID_SEASON_DAY: StringName = &"INVALID_SEASON_DAY"
489: const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
490: const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
491: const REFUSE_INVALID_BASE_CATCH: StringName = &"INVALID_BASE_CATCH"
492: const REFUSE_INVALID_INDEX: StringName = &"INVALID_INDEX"
493: const REFUSE_SPECIES_CLOSED: StringName = &"SPECIES_CLOSED"
494: const REFUSE_SPECIES_UNAVAILABLE: StringName = &"SPECIES_UNAVAILABLE"
495: const REFUSE_RESTOCKING: StringName = &"RESTOCKING"
496: const REFUSE_BELOW_STOCK_FLOOR: StringName = &"BELOW_STOCK_FLOOR"
497: const REFUSE_QUOTA_REACHED: StringName = &"QUOTA_REACHED"
498: const REFUSE_EFFORT_SLOTS_FULL: StringName = &"EFFORT_SLOTS_FULL"
499: const REFUSE_EFFORT_SLOTS_RESERVED: StringName = &"EFFORT_SLOTS_RESERVED"
500: const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
501: const REFUSE_INVALID_GEAR: StringName = &"INVALID_GEAR"
502: const REFUSE_INVALID_SLOT_COUNT: StringName = &"INVALID_SLOT_COUNT"
503: const REFUSE_NO_JOB_STORE: StringName = &"NO_JOB_STORE"
504: const REFUSE_NO_ZONE_STORE: StringName = &"NO_ZONE_STORE"
505: const REFUSE_JOB_NOT_PRESENT: StringName = &"JOB_NOT_PRESENT"
506: const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_MEMBER"
507: const REFUSE_EXPEDITION_NOT_PRESENT: StringName = &"EXPEDITION_NOT_PRESENT"
508: const REFUSE_EFFORT_CLAIM_PRESENT: StringName = &"EFFORT_CLAIM_ALREADY_PRESENT"
509: const REFUSE_EFFORT_CLAIM_STALE: StringName = &"EFFORT_CLAIM_STALE"
510: const REFUSE_NO_EFFORT_CLAIM: StringName = &"NO_EFFORT_CLAIM"
511: const REFUSE_AGGREGATE_MISMATCH: StringName = &"EFFORT_AGGREGATE_MISMATCH"
512: const REFUSE_ZONE_NOT_FISH: StringName = &"ZONE_NOT_FISH"
513: const REFUSE_ZONE_ALREADY_BOUND: StringName = &"ZONE_ALREADY_BOUND"
514: const REFUSE_BASIN_CHAIN: StringName = &"BASIN_CHAIN"
515: const REFUSE_NO_HABITAT_FOR_BASIN: StringName = &"NO_HABITAT_FOR_BASIN"
516: const REFUSE_DUPLICATE_HABITAT_FOR_BASIN: StringName = &"DUPLICATE_HABITAT_FOR_BASIN"
517: const REFUSE_ESTUARY_PRESENT: StringName = &"ESTUARY_ALREADY_PRESENT"
539: # --- collaborators ---------------------------------------------------------------------------------
540: 
541: var _directory: EntityDirectory = null
542: var _owns_directory: bool = false
544: ## owns §4.2's zone row; `_jobs` is jobs.gd, which owns decision 0017's coordinator/member link.
545: ## Every operation that needs one refuses explicitly when it is absent (see the header).
546: var _zones: ForageScript = null
547: var _jobs: JobsScript = null
549: # --- FishHabitat columns (ARCH-MEM-001: packed, allocated once) --------------------------------------
550: 
551: var _habitat_present: PackedByteArray = PackedByteArray()
552: var _habitat_type: PackedInt32Array = PackedInt32Array()
553: var _habitat_zone_slot: PackedInt32Array = PackedInt32Array()
554: var _habitat_zone_generation: PackedInt32Array = PackedInt32Array()
555: var _habitat_effort_slots: PackedInt32Array = PackedInt32Array()
556: var _habitat_pollution: PackedInt32Array = PackedInt32Array()
557: var _habitat_danger: PackedInt32Array = PackedInt32Array()
558: var _habitat_protected_fraction: PackedInt32Array = PackedInt32Array()
559: var _habitat_capacity_milli: PackedInt64Array = PackedInt64Array()
560: 
561: ## The directory reference owning each habitat row, so a row can hand back a validatable ref.
562: var _habitat_ref_slot: PackedInt32Array = PackedInt32Array()
563: var _habitat_ref_generation: PackedInt32Array = PackedInt32Array()
565: ## ADDED COLUMNS, see the header. Occupancy against §4.2's `effort_slots` capacity, and §5.4's
566: ## "explicitly visible" intensive-harvest policy.
567: var _habitat_effort_used: PackedInt32Array = PackedInt32Array()
568: var _habitat_intensive: PackedByteArray = PackedByteArray()
569: 
570: ## Ascending list of live habitat rows, so a daily sweep iterates habitats and not all 32 slots.
571: var _live_habitat_slots: PackedInt32Array = PackedInt32Array()
572: var _live_habitat_count: int = 0
574: # --- FishStock columns, owner-major at `habitat_slot * 3 + species_index` ------------------------------
575: 
576: var _stock_present: PackedByteArray = PackedByteArray()
577: var _stock_habitat_slot: PackedInt32Array = PackedInt32Array()
578: var _stock_habitat_generation: PackedInt32Array = PackedInt32Array()
579: var _stock_species_id: PackedInt32Array = PackedInt32Array()
580: var _stock_population_milli: PackedInt64Array = PackedInt64Array()
581: var _stock_capacity_milli: PackedInt64Array = PackedInt64Array()
582: var _stock_harvested_today_milli: PackedInt64Array = PackedInt64Array()
583: var _stock_closed: PackedByteArray = PackedByteArray()
584: ## ADDED COLUMN, see the header: REQ-SET-048's 30-down/40-up hysteresis needs one bit of memory.
585: var _stock_restocking: PackedByteArray = PackedByteArray()
587: # --- FishingEffortClaim columns, indexed by EXPEDITION TYPED ROW (ruling §5) --------------------------
588: 
589: var _effort_claim_active: PackedByteArray = PackedByteArray()
590: var _effort_claim_expedition_generation: PackedInt32Array = PackedInt32Array()
591: ## FISH-ID-R01: the OWNER'S Directory slot, stored beside its generation so a typed row reused by
592: ## a later Expedition can never alias this claim. Blank -1; never rebuilt from the reverse map.
593: var _effort_claim_expedition_slot: PackedInt32Array = PackedInt32Array()
594: var _effort_claim_habitat_slot: PackedInt32Array = PackedInt32Array()
595: var _effort_claim_habitat_generation: PackedInt32Array = PackedInt32Array()
596: var _effort_claim_job_slot: PackedInt32Array = PackedInt32Array()
597: var _effort_claim_job_generation: PackedInt32Array = PackedInt32Array()
598: var _effort_claim_slot_count: PackedInt32Array = PackedInt32Array()
599: var _effort_claim_count: int = 0
603: ## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
604: ## signal, so no public operation can re-enter while it holds a live value.
605: var _math: IntMath.IntResult = IntMath.IntResult.new()
606: ## A second scratch for the paths that need a live value while computing another.
607: var _math_b: IntMath.IntResult = IntMath.IntResult.new()
608: ## A third, held by the hysteresis latch alone, so it can run inside a harvest that is already
609: ## using both of the others.
610: var _math_c: IntMath.IntResult = IntMath.IntResult.new()
612: ## the 14848-byte claim payload: it exists so the load path can total every claim BEFORE it
613: ## overwrites the authoritative column (decision 0059's allocate-before-consume).
614: var _effort_total_scratch: PackedInt32Array = PackedInt32Array()
615: ## Resolved rows carried from a refusal check to the commit that immediately follows it. Nothing
616: ## between the two calls can re-enter this store.
617: var _pending_claim_row: int = -1
618: var _pending_habitat_slot: int = -1
702: 
703: 
704: func _allocate_columns() -> void:
705: 	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
706: 	_allocate_habitat_columns()
707: 	_allocate_stock_columns()
708: 	_allocate_effort_claim_columns()
709: 
710: 
711: func _allocate_effort_claim_columns() -> void:
712: 	"""Size ruling §5's claim slice at one row per Expedition, plus its 32-entry total scratch."""
713: 	_effort_claim_active.resize(FISHING_EFFORT_CLAIM_CAPACITY)
714: 	_effort_claim_expedition_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
715: 	_effort_claim_expedition_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
716: 	_effort_claim_habitat_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
717: 	_effort_claim_habitat_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
718: 	_effort_claim_job_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
719: 	_effort_claim_job_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
720: 	_effort_claim_slot_count.resize(FISHING_EFFORT_CLAIM_CAPACITY)
721: 	_effort_total_scratch.resize(FISH_HABITAT_CAPACITY)
722: 
723: 
724: func _allocate_habitat_columns() -> void:
725: 	"""Size the FishHabitat columns and the live-habitat index at 32 rows."""
726: 	_habitat_present.resize(FISH_HABITAT_CAPACITY)
727: 	_habitat_type.resize(FISH_HABITAT_CAPACITY)
728: 	_habitat_zone_slot.resize(FISH_HABITAT_CAPACITY)
729: 	_habitat_zone_generation.resize(FISH_HABITAT_CAPACITY)
730: 	_habitat_effort_slots.resize(FISH_HABITAT_CAPACITY)
731: 	_habitat_pollution.resize(FISH_HABITAT_CAPACITY)
732: 	_habitat_danger.resize(FISH_HABITAT_CAPACITY)
733: 	_habitat_protected_fraction.resize(FISH_HABITAT_CAPACITY)
734: 	_habitat_capacity_milli.resize(FISH_HABITAT_CAPACITY)
735: 	_habitat_ref_slot.resize(FISH_HABITAT_CAPACITY)
736: 	_habitat_ref_generation.resize(FISH_HABITAT_CAPACITY)
737: 	_habitat_effort_used.resize(FISH_HABITAT_CAPACITY)
738: 	_habitat_intensive.resize(FISH_HABITAT_CAPACITY)
739: 	_live_habitat_slots.resize(FISH_HABITAT_CAPACITY)
740: 
741: 
742: func _allocate_stock_columns() -> void:
743: 	"""Size the FishStock columns at 96 rows (32 habitats x 3 species)."""
744: 	_stock_present.resize(FISH_STOCK_CAPACITY)
745: 	_stock_habitat_slot.resize(FISH_STOCK_CAPACITY)
746: 	_stock_habitat_generation.resize(FISH_STOCK_CAPACITY)
747: 	_stock_species_id.resize(FISH_STOCK_CAPACITY)
748: 	_stock_population_milli.resize(FISH_STOCK_CAPACITY)
749: 	_stock_capacity_milli.resize(FISH_STOCK_CAPACITY)
750: 	_stock_harvested_today_milli.resize(FISH_STOCK_CAPACITY)
751: 	_stock_closed.resize(FISH_STOCK_CAPACITY)
752: 	_stock_restocking.resize(FISH_STOCK_CAPACITY)
753: 
754: 
755: func clear() -> void:
756: 	"""Return every column to its empty state without reallocating one of them.
757: 
758: 	Every live habitat's directory slot is released first, so dropping this store cannot strand
759: 	allocated slots in a directory it does not own.
760: 	"""
761: 	_release_live_habitats()
762: 	_clear_habitat_columns()
763: 	_clear_stock_columns()
764: 	_clear_effort_claim_columns()
765: 	if _owns_directory:
766: 		_directory.clear()
767: 
768: 
769: func _clear_effort_claim_columns() -> void:
770: 	"""Null and zero every claim row (ruling §5: "Null/zero unused rows")."""
771: 	_effort_claim_active.fill(0)
772: 	_effort_claim_expedition_generation.fill(EntityDirectory.NULL_GENERATION)
773: 	_effort_claim_expedition_slot.fill(EntityDirectory.NULL_SLOT)
774: 	_effort_claim_habitat_slot.fill(EntityDirectory.NULL_SLOT)
775: 	_effort_claim_habitat_generation.fill(EntityDirectory.NULL_GENERATION)
776: 	_effort_claim_job_slot.fill(EntityDirectory.NULL_SLOT)
777: 	_effort_claim_job_generation.fill(EntityDirectory.NULL_GENERATION)
778: 	_effort_claim_slot_count.fill(0)
779: 	_effort_total_scratch.fill(0)
780: 	_effort_claim_count = 0
781: 	_pending_claim_row = -1
782: 	_pending_habitat_slot = -1
783: 
784: 
792: 
793: 
794: func _clear_habitat_columns() -> void:
795: 	"""Refill every FishHabitat column with its empty value (§4.2: refs (-1,0), counters 0)."""
796: 	_habitat_present.fill(0)
797: 	_habitat_type.fill(0)
798: 	_habitat_zone_slot.fill(EntityDirectory.NULL_SLOT)
799: 	_habitat_zone_generation.fill(EntityDirectory.NULL_GENERATION)
800: 	_habitat_effort_slots.fill(0)
801: 	_habitat_pollution.fill(0)
802: 	_habitat_danger.fill(0)
803: 	_habitat_protected_fraction.fill(0)
804: 	_habitat_capacity_milli.fill(0)
805: 	_habitat_ref_slot.fill(EntityDirectory.NULL_SLOT)
806: 	_habitat_ref_generation.fill(EntityDirectory.NULL_GENERATION)
807: 	_habitat_effort_used.fill(0)
808: 	_habitat_intensive.fill(0)
809: 	_live_habitat_slots.fill(EntityDirectory.NULL_SLOT)
810: 	_live_habitat_count = 0
811: 
812: 
813: func _clear_stock_columns() -> void:
814: 	"""Refill every FishStock column with its empty value."""
815: 	_stock_present.fill(0)
816: 	_stock_habitat_slot.fill(EntityDirectory.NULL_SLOT)
817: 	_stock_habitat_generation.fill(EntityDirectory.NULL_GENERATION)
818: 	_stock_species_id.fill(-1)
819: 	_stock_population_milli.fill(0)
820: 	_stock_capacity_milli.fill(0)
821: 	_stock_harvested_today_milli.fill(0)
822: 	_stock_closed.fill(0)
823: 	_stock_restocking.fill(0)
824: 
825: 
941: # --- FishHabitat lifecycle ---------------------------------------------------------------------------
942: 
943: func create_habitat(habitat_type: int, zone_ref: Vector2i, species_ids: PackedInt32Array,
944: 		pollution: int, danger: int, protected_fraction: int) -> OpResult:
945: 	"""Create one §5.4 habitat together with its three §4.2 stocks, at §5.4's 80% of capacity.
946: 
947: 	The habitat and its stocks are created in one operation because `capacity_milli` is
948: 	`K_total_milli` -- the sum of the three species capacities -- so a habitat without its
949: 	stocks would carry a quota basis nothing backs. `effort_slots` and every capacity come from
950: 	§5.4's table, never from the caller. Everything is validated before the directory is
951: 	touched, so a refusal allocates nothing.
952: 	"""
953: 	var code: StringName = _refuse_habitat_fields(habitat_type, zone_ref, pollution, danger,
954: 		protected_fraction)
955: 	if code == REFUSE_NONE:
956: 		code = _refuse_species_ids(species_ids)
957: 	if code != REFUSE_NONE:
958: 		return _refuse(code)
959: 	var ref: Vector2i = _directory.create(EntityDirectory.KIND_FISH_HABITAT)
960: 	if ref == NULL_REF:
961: 		return _refuse(_directory.last_refusal())
962: 	var slot: int = _directory.get_typed_row(ref)
963: 	_write_created_habitat(slot, ref, habitat_type, zone_ref, pollution, danger,
964: 		protected_fraction)
965: 	_write_created_stocks(slot, ref, habitat_type, species_ids)
966: 	return _succeed(slot, ref)
967: 
968: 
1048: 
1049: 
1050: func destroy_habitat(ref: Vector2i) -> OpResult:
1051: 	"""Remove one habitat and its three stocks, and free its directory slot.
1052: 
1053: 	Returns the number of stock rows released. Refuses while an effort slot is still reserved --
1054: 	destroying the habitat under a live reservation would strand it -- and refuses a stale or
1055: 	wrong-kind reference rather than clearing whatever row it points at.
1056: 	"""
1057: 	if not habitat_slot_of_into(ref, _math):
1058: 		return _refuse(StringName(_math.error))
1059: 	var slot: int = _math.value
1060: 	if _habitat_effort_used[slot] > 0:
1061: 		return _refuse(REFUSE_EFFORT_SLOTS_RESERVED)
1062: 	var released: int = _release_habitat_stocks(slot)
1063: 	_habitat_present[slot] = 0
1064: 	_habitat_ref_slot[slot] = EntityDirectory.NULL_SLOT
1065: 	_habitat_ref_generation[slot] = EntityDirectory.NULL_GENERATION
1066: 	_habitat_zone_slot[slot] = EntityDirectory.NULL_SLOT
1067: 	_habitat_zone_generation[slot] = EntityDirectory.NULL_GENERATION
1068: 	_habitat_capacity_milli[slot] = 0
1069: 	_habitat_intensive[slot] = 0
1070: 	_remove_live_habitat(slot)
1071: 	_directory.destroy(ref)
1072: 	return _succeed(released, NULL_REF)
1073: 
1074: 
1538: 
1539: 
1540: func _clear_effort_claim_row(row: int) -> void:
1541: 	"""Return one claim row to the null/zero state unused rows carry."""
1542: 	_effort_claim_active[row] = 0
1543: 	_effort_claim_expedition_generation[row] = EntityDirectory.NULL_GENERATION
1544: 	_effort_claim_expedition_slot[row] = EntityDirectory.NULL_SLOT
1545: 	_effort_claim_habitat_slot[row] = EntityDirectory.NULL_SLOT
1546: 	_effort_claim_habitat_generation[row] = EntityDirectory.NULL_GENERATION
1547: 	_effort_claim_job_slot[row] = EntityDirectory.NULL_SLOT
1548: 	_effort_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
1549: 	_effort_claim_slot_count[row] = 0
1550: 	_effort_claim_count -= 1
1551: 
1552: 
1686: 
1687: 
1688: func restore_effort_claim(expedition_ref: Vector2i, job_ref: Vector2i, habitat_ref: Vector2i,
1689: 		slot_count: int) -> OpResult:
1690: 	"""Write one saved claim WITHOUT touching the derived occupancy column. Returns its row.
1691: 
1692: 	Legacy-only load helper from ruling §5; never call it from SAVE-CLAIMS-R01.
1693: 	The historical loader design restores claim records and then calls
1694: 	rebuild_effort_aggregates() before any cycle resumes, which is why this deliberately leaves
1695: 	`effort_used` alone: a stored total cannot prove ownership, so it is recomputed rather than
1696: 	trusted. Every reference and the slot count ARE validated, because a save that fails them
1697: 	must be refused rather than loaded.
1698: 	"""
1699: 	var code: StringName = _refuse_effort_owner(expedition_ref, job_ref)
1700: 	if code != REFUSE_NONE:
1701: 		return _refuse(code)
1702: 	if not habitat_slot_of_into(habitat_ref, _math):
1703: 		return _refuse(StringName(_math.error))
1704: 	if slot_count <= 0 or slot_count > _habitat_effort_slots[_math.value]:
1705: 		return _refuse(REFUSE_INVALID_SLOT_COUNT)
1706: 	_write_effort_claim(_pending_claim_row, expedition_ref, job_ref, habitat_ref, slot_count)
1707: 	return _succeed(_pending_claim_row, habitat_ref)
1708: 
1709: 
1724: 
1725: 
1726: func validate_effort_aggregates() -> OpResult:
1727: 	"""Check the stored occupancy against the live claims, changing nothing. Returns the claims.
1728: 
1729: 	The read-only half of the same contract: a loader that wants to know whether a snapshot is
1730: 	self-consistent asks this, and a total that no claim accounts for refuses.
1731: 	"""
1732: 	var code: StringName = _accumulate_effort_totals()
1733: 	if code != REFUSE_NONE:
1734: 		return _refuse(code)
1735: 	for slot: int in FISH_HABITAT_CAPACITY:
1736: 		if _habitat_effort_used[slot] != _effort_total_scratch[slot]:
1737: 			return _refuse(REFUSE_AGGREGATE_MISMATCH)
1738: 	return _succeed(_effort_claim_count, NULL_REF)
1739: 
1740: 
2775: # --- SAVE-CLAIMS-R01 v2: the FishingEffortClaim column block -------------------------------------
2776: 
2777: const COLUMN_FISH_CLAIM_SHAPE: StringName = &"COLUMN_FISH_CLAIM_SHAPE"
2778: const COLUMN_FISH_CLAIM_OCCUPANCY: StringName = &"COLUMN_FISH_CLAIM_OCCUPANCY"
2779: const COLUMN_FISH_CLAIM_BLANK: StringName = &"COLUMN_FISH_CLAIM_BLANK"
2780: const COLUMN_FISH_CLAIM_REF: StringName = &"COLUMN_FISH_CLAIM_REF"
2781: const COLUMN_FISH_CLAIM_SLOT_COUNT: StringName = &"COLUMN_FISH_CLAIM_SLOT_COUNT"
2782: const COLUMN_FISH_CLAIM_SOURCE_COUNT: StringName = &"COLUMN_FISH_CLAIM_SOURCE_COUNT"
2783: 
2784: ## The exact blank a released claim row carries, spelled from the directory's own empty values.
2785: const CLAIM_COLUMN_BLANK_SLOT: int = EntityDirectory.NULL_SLOT
2786: const CLAIM_COLUMN_BLANK_GENERATION: int = EntityDirectory.NULL_GENERATION
2787: const CLAIM_COLUMN_BLANK_SLOT_COUNT: int = 0
2790: ## the directory's own capacity. The row index itself is the Expedition's typed row and is never
2791: ## looked up or reconstructed here.
2792: const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1
2794: ## Code of the most recent claim-column refusal. Set only on refusal, cleared only on success,
2795: ## and separate from every existing diagnostic in this module.
2796: var _last_claim_column_refusal: StringName = REFUSE_NONE
2848: 
2849: 
2850: func copy_effort_claim_columns_into(out: EffortClaimColumns) -> bool:
2851: 	"""Publish eight independent duplicates of the live claim table, or refuse touching nothing.
2852: 
2853: 	Order is deterministic and the first gate wins: caller null or any caller/live array length
2854: 	mismatch; the whole table's active bytes; ascending rows; and only THEN the native count
2855: 	against the rows actually counted. The source is read-only apart from this diagnostic.
2856: 	"""
2857: 	if out == null:
2858: 		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
2859: 	if not _effort_claim_record_shape_ok(out) or not _effort_claim_live_shape_ok():
2860: 		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
2861: 	var tally: EffortClaimTally = EffortClaimTally.new()
2862: 	var code: StringName = _effort_claim_payload_code(_effort_claim_active,
2863: 		_effort_claim_expedition_generation, _effort_claim_expedition_slot,
2864: 		_effort_claim_habitat_slot, _effort_claim_habitat_generation, _effort_claim_job_slot,
2865: 		_effort_claim_job_generation, _effort_claim_slot_count, tally)
2866: 	if code != REFUSE_NONE:
2867: 		return _refuse_claim_column(code)
2868: 	if _effort_claim_count != tally.active_rows:
2869: 		return _refuse_claim_column(COLUMN_FISH_CLAIM_SOURCE_COUNT)
2870: 	out.effort_claim_active = _effort_claim_active.duplicate()
2871: 	out.effort_claim_expedition_generation = _effort_claim_expedition_generation.duplicate()
2872: 	out.effort_claim_expedition_slot = _effort_claim_expedition_slot.duplicate()
2873: 	out.effort_claim_habitat_slot = _effort_claim_habitat_slot.duplicate()
2874: 	out.effort_claim_habitat_generation = _effort_claim_habitat_generation.duplicate()
2875: 	out.effort_claim_job_slot = _effort_claim_job_slot.duplicate()
2876: 	out.effort_claim_job_generation = _effort_claim_job_generation.duplicate()
2877: 	out.effort_claim_slot_count = _effort_claim_slot_count.duplicate()
2878: 	_last_claim_column_refusal = REFUSE_NONE
2879: 	return true
2880: 
2881: 
2882: func restore_effort_claim_columns(columns: EffortClaimColumns) -> bool:
2883: 	"""Install a validated claim table and its derived count, or refuse changing nothing.
2884: 
2885: 	The prior payload and the prior count are IGNORED: only the live array shapes are required.
2886: 	Every generation pair and row index is preserved verbatim, including stale ones; nothing is
2887: 	sorted, compacted, clamped or repaired. All eight arrays are duplicated privately first, so
2888: 	no fallible work remains once publication begins and a later mutation of the input cannot
2889: 	leak across this boundary.
2890: 	"""
2891: 	if columns == null:
2892: 		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
2893: 	if not _effort_claim_record_shape_ok(columns) or not _effort_claim_live_shape_ok():
2894: 		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
2895: 	var tally: EffortClaimTally = EffortClaimTally.new()
2896: 	var code: StringName = _effort_claim_payload_code(columns.effort_claim_active,
2897: 		columns.effort_claim_expedition_generation, columns.effort_claim_expedition_slot,
2898: 		columns.effort_claim_habitat_slot, columns.effort_claim_habitat_generation,
2899: 		columns.effort_claim_job_slot, columns.effort_claim_job_generation,
2900: 		columns.effort_claim_slot_count, tally)
2901: 	if code != REFUSE_NONE:
2902: 		return _refuse_claim_column(code)
2903: 	var active: PackedByteArray = columns.effort_claim_active.duplicate()
2904: 	var expedition_generation: PackedInt32Array = \
2905: 		columns.effort_claim_expedition_generation.duplicate()
2906: 	var expedition_slot: PackedInt32Array = columns.effort_claim_expedition_slot.duplicate()
2907: 	var habitat_slot: PackedInt32Array = columns.effort_claim_habitat_slot.duplicate()
2908: 	var habitat_generation: PackedInt32Array = columns.effort_claim_habitat_generation.duplicate()
2909: 	var job_slot: PackedInt32Array = columns.effort_claim_job_slot.duplicate()
2910: 	var job_generation: PackedInt32Array = columns.effort_claim_job_generation.duplicate()
2911: 	var slot_count: PackedInt32Array = columns.effort_claim_slot_count.duplicate()
2912: 	_effort_claim_active = active
2913: 	_effort_claim_expedition_generation = expedition_generation
2914: 	_effort_claim_expedition_slot = expedition_slot
2915: 	_effort_claim_habitat_slot = habitat_slot
2916: 	_effort_claim_habitat_generation = habitat_generation
2917: 	_effort_claim_job_slot = job_slot
2918: 	_effort_claim_job_generation = job_generation
2919: 	_effort_claim_slot_count = slot_count
2920: 	_effort_claim_count = tally.active_rows
2921: 	_last_claim_column_refusal = REFUSE_NONE
2922: 	return true
2923: 
2924: 

# godot/scripts/core/forage.gd
247: ##     range only: an int32 column cannot prove a catalog, and decision 0052 records who does.
248: 
249: const IntMath := preload("res://scripts/core/int_math.gd")
250: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
251: const Catalog := preload("res://scripts/core/catalog.gd")
252: const Rng := preload("res://scripts/core/rng.gd")
253: const SimClock := preload("res://scripts/core/sim_clock.gd")
254: const JobsScript := preload("res://scripts/core/jobs.gd")
257: 
258: ## GDD §4.2: "Up to 128".
259: const HARVEST_ZONE_CAPACITY: int = 128
260: ## GDD §4.2: "tile membership max 16384 total zone links".
261: const ZONE_LINK_CAPACITY: int = 16384
262: ## GDD §4.2: "5 patches/forest zone".
263: const PATCHES_PER_ZONE: int = 5
264: ## systems_architecture.md §2.2 ForagePatch length: 640 == 128 * 5.
265: const FORAGE_PATCH_CAPACITY: int = HARVEST_ZONE_CAPACITY * PATCHES_PER_ZONE
266: ## decision 0030 §4.7: `claim_row = owning_job_typed_row` inside the existing 8192 Job rows.
267: ## `_init()` asserts this equals the directory's own KIND_JOB capacity rather than restating it.
268: const FORAGE_CLAIM_CAPACITY: int = 8192
269: 
270: ## GDD §5.1 exterior grid: index `z*128+x`, 16384 tiles, matching WorldTileMaps' row count.
271: const MAP_TILES_X: int = 128
272: const MAP_TILES_Z: int = 128
273: const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z
275: # --- GDD §4.3 ZoneType, read from catalog.gd's protected table (decision 0018) --------------------
276: 
277: const ZONE_TYPE_FISH: int = Catalog.ZONE_TYPE["FISH"]
278: ## SET-AMEND-001 §3: the retired hunting zone. Creation is rejected, the value is never reused.
279: const ZONE_TYPE_RESERVED_1: int = Catalog.ZONE_TYPE["RESERVED_1"]
280: const ZONE_TYPE_FORAGE: int = Catalog.ZONE_TYPE["FORAGE"]
281: const ZONE_TYPE_FARM: int = Catalog.ZONE_TYPE["FARM"]
282: const ZONE_TYPE_ORCHARD: int = Catalog.ZONE_TYPE["ORCHARD"]
283: const ZONE_TYPE_FORESTRY: int = Catalog.ZONE_TYPE["FORESTRY"]
284: const ZONE_TYPE_QUARRY: int = Catalog.ZONE_TYPE["QUARRY"]
285: const ZONE_TYPE_STOCKPILE: int = Catalog.ZONE_TYPE["STOCKPILE"]
286: const ZONE_TYPE_CONSERVATION: int = Catalog.ZONE_TYPE["CONSERVATION"]
287: const ZONE_TYPE_COUNT: int = 9
289: # --- GDD §4.3 Season, likewise from the protected table ------------------------------------------
290: 
291: const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
292: const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
293: const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
294: const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
295: const SEASON_COUNT: int = 4
297: # --- GDD §5.5 forage table, row for row ----------------------------------------------------------
298: 
299: const PATCH_BERRIES: int = 0
300: const PATCH_NUTS: int = 1
301: const PATCH_MUSHROOMS: int = 2
302: const PATCH_HERB: int = 3
303: const PATCH_ROOTS: int = 4
306: ## are compiled elsewhere: `resource_catalog_binding.gd` resolves this array against the catalog
307: ## and must preserve its order, so these keys are never re-typed or re-sorted anywhere else.
308: const PATCH_KEYS: Array[StringName] = [&"berries", &"nuts", &"mushrooms", &"herb", &"roots"]
309: 
310: ## §5.5 "Patch capacity U" column, whole units.
311: const PATCH_CAPACITY_U: Array[int] = [300, 240, 180, 160, 300]
312: ## §5.5 "Base work WU/U" column.
313: const PATCH_BASE_WORK_WU: Array[int] = [4, 5, 5, 8, 6]
314: ## §5.5 "Daily regrowth fraction/1000" column, the `r` of the regrowth formula.
315: const PATCH_REGROWTH_PER_1000: Array[int] = [120, 60, 100, 80, 70]
316: ## §5.5's Spring/Summer/Autumn/Winter availability columns, flattened as `kind*4 + season`.
317: ## Zeroes are §5.5's dormant seasons: "unavailable patches become dormant, not destroyed".
318: const PATCH_AVAILABILITY_PER_1000: Array[int] = [
325: 
326: ## AGENTS.md: "Quantities are quantity_milli:int64 (1000 = one unit)."
327: const MILLI_PER_UNIT: int = 1000
328: 
329: ## GDD §5.1: "forage stocks are floor(0.8xcapacity), including dormant stocks."
330: const INITIAL_STOCK_NUMERATOR: int = 8
331: const INITIAL_STOCK_DENOMINATOR: int = 10
332: 
333: ## §5.5: "Sustainable floor 20%K; intensive floor 5%K."
334: const SUSTAINABLE_FLOOR_PERCENT: int = 20
335: const INTENSIVE_FLOOR_PERCENT: int = 5
336: const PERCENT_DENOMINATOR: int = 100
338: ## §5.5: "Daily regrowth=floor((K-P)*r*season/1000000) plus a minimum 1 U when season>0 and P<K."
339: ## Ruling §8A reads "plus" as ADDITIVE and caps the sum at the room left below K (see the header).
340: const REGROWTH_DENOMINATOR: int = 1000000
341: const REGROWTH_MINIMUM_MILLI: int = MILLI_PER_UNIT
342: 
343: ## §5.5: "Work per U=ceil(base_work*1000000/((1000+40*FORAGE_level)*(1000+100*natural_danger)))".
344: const WORK_NUMERATOR_SCALE: int = 1000000
345: const WORK_BASE_TERM: int = 1000
346: const WORK_SKILL_TERM: int = 40
347: const WORK_DANGER_TERM: int = 100
349: ## §5.5: "Danger zones:0 inside 32 m of any staffed lookout;1 remaining land within 64 m of the
350: ## central hall;2 at 64-96 m;3 beyond 96 m."
351: const DANGER_MIN: int = 0
352: const DANGER_MAX: int = 3
353: ## REQ-SET-067: "While a forage zone has danger 2 or 3".
354: const DANGEROUS_WORK_DANGER: int = 2
355: ## ARCH-RNG-002: rolls happen only "in natural danger>=1".
356: const INJURY_ROLL_MIN_DANGER: int = 1
358: ## REQ-SET-068: "When a forager completes 60 WU in danger>=1, the system shall roll injury chance
359: ## `max(1,8*danger-FORAGE_level)` per 10000, causing 10 health loss and severity 1 injury".
360: const EXPOSURE_SEGMENT_WU: int = 60
361: const INJURY_ROLL_DENOMINATOR: int = 10000
362: const INJURY_DANGER_FACTOR: int = 8
363: const INJURY_CHANCE_MINIMUM: int = 1
364: const INJURY_HEALTH_LOSS: int = 10
365: const INJURY_SEVERITY: int = 1
369: ## The domain name compile_domain() is called with in `_init()`. NOT a PROTECTED_ENUM_DOMAIN:
370: ## GDD §4.3 numbers no quota mode, so there is nothing specified here to protect (see the header).
371: const QUOTA_MODE_DOMAIN: String = "ForageQuotaMode"
373: ## exactly this order. `_init()` runs the compiler and asserts that, so no second numbering
374: ## scheme exists and none can drift.
375: const QUOTA_MODE_KEYS: Array[StringName] = [&"automatic", &"inherit", &"manual"]
376: ## Ruling §4.6: Automatic is a BASIN mode, Inherit is a DESIGNATION mode, Manual is either.
377: const QUOTA_MODE_AUTOMATIC: int = 0
378: const QUOTA_MODE_INHERIT: int = 1
379: const QUOTA_MODE_MANUAL: int = 2
380: const QUOTA_MODE_COUNT: int = 3
381: 
382: ## Ruling §4.6: "This policy uses an 80% stock management target", as `floor(800 * K / 1000)`.
383: const AUTOMATIC_TARGET_PER_1000: int = 800
384: const AUTOMATIC_TARGET_DENOMINATOR: int = 1000
385: ## `floor((K - target) * r * S / 1000000) + 1000`, the existing additive 1 U regrowth term.
386: const AUTOMATIC_ALLOWANCE_DENOMINATOR: int = 1000000
387: const AUTOMATIC_ALLOWANCE_TERM_MILLI: int = MILLI_PER_UNIT
389: ## Ruling §4.6: "Minimum is zero: no unlimited sentinel is supported. Maximum is `sum(K_i)` across
390: ## the basin's five patches: currently 1180000 milli-U/day." `_init()` asserts the sum.
391: const MANUAL_QUOTA_MIN_MILLI: int = 0
392: const MANUAL_QUOTA_MAX_MILLI: int = 1180000
394: # --- packed payload accounting (ruling §4.7 / R05-QUOTA-024) --------------------------------------
395: 
396: const BYTES_PER_BYTE_COLUMN: int = 1
397: const BYTES_PER_INT32: int = 4
398: const BYTES_PER_INT64: int = 8
399: 
400: ## Empty value of `WorldTileMaps.zone_link_head` and of every link cursor.
401: const NO_LINK: int = -1
402: ## Empty value of every claim cursor and of "no claim row selected".
403: const NO_CLAIM: int = -1
404: const NULL_REF: Vector2i = EntityDirectory.NULL_REF
406: # --- refusal codes -------------------------------------------------------------------------------
407: 
408: const REFUSE_NONE: StringName = &""
409: const REFUSE_ZONE_NOT_PRESENT: StringName = &"ZONE_NOT_PRESENT"
410: const REFUSE_INVALID_ZONE_TYPE: StringName = &"INVALID_ZONE_TYPE"
411: const REFUSE_RESERVED_ZONE_TYPE: StringName = &"RESERVED_ZONE_TYPE"
412: const REFUSE_ZONE_TYPE_MISMATCH: StringName = &"ZONE_TYPE_MISMATCH"
413: const REFUSE_INVALID_DANGER: StringName = &"INVALID_DANGER"
414: const REFUSE_INVALID_QUOTA: StringName = &"INVALID_QUOTA"
415: const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
416: const REFUSE_INVALID_TILE_COORDINATE: StringName = &"INVALID_TILE_COORDINATE"
417: const REFUSE_TILE_ALREADY_LINKED: StringName = &"TILE_ALREADY_LINKED"
418: const REFUSE_TILE_NOT_LINKED: StringName = &"TILE_NOT_LINKED"
419: const REFUSE_ZONE_LINK_CAPACITY: StringName = &"CAPACITY_ZONE_LINK"
420: const REFUSE_INVALID_PATCH_KIND: StringName = &"INVALID_PATCH_KIND"
421: const REFUSE_INVALID_ITEM_ID: StringName = &"INVALID_ITEM_ID"
422: const REFUSE_PATCH_PRESENT: StringName = &"PATCH_ALREADY_PRESENT"
423: const REFUSE_PATCH_NOT_PRESENT: StringName = &"PATCH_NOT_PRESENT"
424: const REFUSE_STOCK_ABOVE_CAPACITY: StringName = &"STOCK_ABOVE_CAPACITY"
425: const REFUSE_PATCH_SET_SIZE: StringName = &"PATCH_SET_SIZE"
426: const REFUSE_PATCH_DORMANT: StringName = &"PATCH_DORMANT"
427: const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
428: const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
429: const REFUSE_BELOW_HARVEST_FLOOR: StringName = &"BELOW_HARVEST_FLOOR"
430: const REFUSE_QUOTA_REACHED: StringName = &"QUOTA_REACHED"
431: const REFUSE_ZONE_DISABLED: StringName = &"ZONE_DISABLED"
432: const REFUSE_ZONE_PROTECTED: StringName = &"ZONE_PROTECTED"
433: const REFUSE_DANGEROUS_WORK_REFUSED: StringName = &"DANGEROUS_WORK_REFUSED"
434: const REFUSE_BASIN_CHAIN: StringName = &"BASIN_CHAIN"
435: const REFUSE_BASIN_HAS_OWN_PATCHES: StringName = &"BASIN_HAS_OWN_PATCHES"
436: const REFUSE_ZONE_IS_BOUND: StringName = &"ZONE_IS_BOUND"
437: const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
438: const REFUSE_INVALID_WORK: StringName = &"INVALID_WORK"
439: const REFUSE_NO_RNG: StringName = &"NO_RNG"
440: const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
441: const REFUSE_INVALID_QUOTA_MODE: StringName = &"INVALID_QUOTA_MODE"
442: const REFUSE_QUOTA_MODE_NOT_VALID_HERE: StringName = &"QUOTA_MODE_NOT_VALID_HERE"
443: const REFUSE_NO_JOB_STORE: StringName = &"NO_JOB_STORE"
444: const REFUSE_JOB_NOT_PRESENT: StringName = &"JOB_NOT_PRESENT"
445: const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_MEMBER"
446: const REFUSE_CLAIM_PRESENT: StringName = &"CLAIM_ALREADY_PRESENT"
447: const REFUSE_CLAIM_NOT_PRESENT: StringName = &"CLAIM_NOT_PRESENT"
448: const REFUSE_CLAIM_STALE_JOB: StringName = &"CLAIM_STALE_JOB"
449: const REFUSE_STOCK_RESERVED: StringName = &"STOCK_RESERVED"
450: const REFUSE_NOT_DAY_BOUNDARY: StringName = &"NOT_DAY_BOUNDARY"
451: const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
473: # --- collaborators -------------------------------------------------------------------------------
474: 
475: var _directory: EntityDirectory = null
476: var _owns_directory: bool = false
477: ## The Job store every claim is owned by. Optional: a store built without one holds no claims and
478: ## refuses every claim operation with REFUSE_NO_JOB_STORE rather than inventing an owner.
479: var _jobs: JobsScript = null
481: # --- HarvestZone columns (ARCH-MEM-001: packed, allocated once) -----------------------------------
482: 
483: var _zone_present: PackedByteArray = PackedByteArray()
484: var _zone_type: PackedInt32Array = PackedInt32Array()
485: var _zone_danger: PackedInt32Array = PackedInt32Array()
486: var _zone_quota_milli: PackedInt64Array = PackedInt64Array()
487: var _zone_protected: PackedByteArray = PackedByteArray()
488: var _zone_enabled: PackedByteArray = PackedByteArray()
489: 
490: ## The directory reference owning each zone row, so a row can hand back a validatable ref.
491: var _zone_ref_slot: PackedInt32Array = PackedInt32Array()
492: var _zone_ref_generation: PackedInt32Array = PackedInt32Array()
493: 
494: ## GDD §5.1's "Player harvest zones reference basin IDs". A new zone is its own basin.
495: var _zone_basin_slot: PackedInt32Array = PackedInt32Array()
496: var _zone_basin_generation: PackedInt32Array = PackedInt32Array()
499: ## `quota_reserved_milli` is a DERIVED CACHE, maintained atomically and rebuilt from active claims
500: ## by rebuild_reservation_aggregates().
501: var _zone_harvested_today_milli: PackedInt64Array = PackedInt64Array()
502: var _zone_quota_reserved_milli: PackedInt64Array = PackedInt64Array()
503: var _zone_quota_mode: PackedByteArray = PackedByteArray()
504: 
505: ## Head of each zone's own tile-link list, and the length of that list.
506: var _zone_link_head: PackedInt32Array = PackedInt32Array()
507: var _zone_tile_count: PackedInt32Array = PackedInt32Array()
508: ## Number of live ForagePatch rows in this zone's five-row block.
509: var _zone_patch_count: PackedInt32Array = PackedInt32Array()
510: 
511: ## Ascending list of live zone rows, so a daily sweep iterates zones and not all 128 slots.
512: var _live_zone_slots: PackedInt32Array = PackedInt32Array()
513: var _live_zone_count: int = 0
515: # --- HarvestZone.tiles: the 16384-link arena, threaded into two lists per link --------------------
516: 
517: var _link_tile: PackedInt32Array = PackedInt32Array()
518: var _link_zone: PackedInt32Array = PackedInt32Array()
519: var _link_tile_next: PackedInt32Array = PackedInt32Array()
520: var _link_zone_next: PackedInt32Array = PackedInt32Array()
522: ## `WorldTileMaps.zone_link_head` (systems_architecture.md §2): one int32 per exterior tile.
523: ## A tile carries a LIST, not a slot, because §5.1's overlapping zones must all reach it.
524: var _tile_link_head: PackedInt32Array = PackedInt32Array()
526: ## Bump allocator plus free list: `_link_bump` links have ever been handed out, and released
527: ## links are recycled through `_link_free_head`. Neither ever resizes a column.
528: var _link_bump: int = 0
529: var _link_free_head: int = NO_LINK
530: var _link_used: int = 0
532: # --- ForagePatch columns, owner-major at `zone_slot * 5 + kind` -----------------------------------
533: 
534: var _patch_present: PackedByteArray = PackedByteArray()
535: var _patch_item_id: PackedInt32Array = PackedInt32Array()
536: var _patch_zone_slot: PackedInt32Array = PackedInt32Array()
537: var _patch_zone_generation: PackedInt32Array = PackedInt32Array()
538: var _patch_stock_milli: PackedInt64Array = PackedInt64Array()
539: var _patch_capacity_milli: PackedInt64Array = PackedInt64Array()
540: var _patch_harvested_year_milli: PackedInt64Array = PackedInt64Array()
542: # --- ForageClaim columns, indexed by OWNING JOB TYPED ROW (decision 0030 §4.7) ---------------------
543: 
544: var _claim_active: PackedByteArray = PackedByteArray()
545: var _claim_job_slot: PackedInt32Array = PackedInt32Array()
546: var _claim_job_generation: PackedInt32Array = PackedInt32Array()
547: var _claim_designation_slot: PackedInt32Array = PackedInt32Array()
548: var _claim_designation_generation: PackedInt32Array = PackedInt32Array()
549: var _claim_basin_slot: PackedInt32Array = PackedInt32Array()
550: var _claim_basin_generation: PackedInt32Array = PackedInt32Array()
551: var _claim_patch_kind: PackedInt32Array = PackedInt32Array()
552: var _claim_remaining_milli: PackedInt64Array = PackedInt64Array()
554: ## The §4.5 release order key, cached from the owning Job at claim time. EXTRA to the ruling's
555: ## 305280-byte payload and counted separately -- see the header and extra_ordering_buffer_bytes().
556: var _claim_created_tick: PackedInt64Array = PackedInt64Array()
557: var _claim_persistent_id: PackedInt64Array = PackedInt64Array()
558: 
559: ## Live claim total. A scalar counter, not an index: no per-claim list is allocated.
560: var _claim_count: int = 0
564: ## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
565: ## signal, so no public operation can re-enter while it holds a live value.
566: var _math: IntMath.IntResult = IntMath.IntResult.new()
567: ## A second scratch for the two places that need a live value while computing another.
568: var _math_b: IntMath.IntResult = IntMath.IntResult.new()
569: ## A third scratch, owned exclusively by the quota/claim paths so they can nest inside a caller
570: ## that is already holding `_math` or `_math_b`.
571: var _math_c: IntMath.IntResult = IntMath.IntResult.new()
573: ## Rows resolved by the last claim preflight, consumed by the commit that immediately follows it.
574: ## Plain ints, written and read inside one public call with no callback in between.
575: var _pending_designation_slot: int = EntityDirectory.NULL_SLOT
576: var _pending_basin_slot: int = EntityDirectory.NULL_SLOT
577: var _pending_patch_row: int = -1
634: 
635: 
636: func _allocate_columns() -> void:
637: 	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
638: 	_allocate_zone_columns()
639: 	_allocate_link_columns()
640: 	_allocate_patch_columns()
641: 	_allocate_claim_columns()
642: 
643: 
644: func _allocate_claim_columns() -> void:
645: 	"""Size the eleven ForageClaim columns at one row per Job row (decision 0030 §4.7)."""
646: 	_claim_active.resize(FORAGE_CLAIM_CAPACITY)
647: 	_claim_job_slot.resize(FORAGE_CLAIM_CAPACITY)
648: 	_claim_job_generation.resize(FORAGE_CLAIM_CAPACITY)
649: 	_claim_designation_slot.resize(FORAGE_CLAIM_CAPACITY)
650: 	_claim_designation_generation.resize(FORAGE_CLAIM_CAPACITY)
651: 	_claim_basin_slot.resize(FORAGE_CLAIM_CAPACITY)
652: 	_claim_basin_generation.resize(FORAGE_CLAIM_CAPACITY)
653: 	_claim_patch_kind.resize(FORAGE_CLAIM_CAPACITY)
654: 	_claim_remaining_milli.resize(FORAGE_CLAIM_CAPACITY)
655: 	_claim_created_tick.resize(FORAGE_CLAIM_CAPACITY)
656: 	_claim_persistent_id.resize(FORAGE_CLAIM_CAPACITY)
657: 
658: 
659: func _allocate_zone_columns() -> void:
660: 	"""Size the fifteen HarvestZone columns and the live-zone index at 128 rows."""
661: 	_zone_present.resize(HARVEST_ZONE_CAPACITY)
662: 	_zone_type.resize(HARVEST_ZONE_CAPACITY)
663: 	_zone_danger.resize(HARVEST_ZONE_CAPACITY)
664: 	_zone_quota_milli.resize(HARVEST_ZONE_CAPACITY)
665: 	_zone_protected.resize(HARVEST_ZONE_CAPACITY)
666: 	_zone_enabled.resize(HARVEST_ZONE_CAPACITY)
667: 	_zone_ref_slot.resize(HARVEST_ZONE_CAPACITY)
668: 	_zone_ref_generation.resize(HARVEST_ZONE_CAPACITY)
669: 	_zone_basin_slot.resize(HARVEST_ZONE_CAPACITY)
670: 	_zone_basin_generation.resize(HARVEST_ZONE_CAPACITY)
671: 	_zone_harvested_today_milli.resize(HARVEST_ZONE_CAPACITY)
672: 	_zone_quota_reserved_milli.resize(HARVEST_ZONE_CAPACITY)
673: 	_zone_quota_mode.resize(HARVEST_ZONE_CAPACITY)
674: 	_zone_link_head.resize(HARVEST_ZONE_CAPACITY)
675: 	_zone_tile_count.resize(HARVEST_ZONE_CAPACITY)
676: 	_zone_patch_count.resize(HARVEST_ZONE_CAPACITY)
677: 	_live_zone_slots.resize(HARVEST_ZONE_CAPACITY)
678: 
679: 
680: func _allocate_link_columns() -> void:
681: 	"""Size the 16384-entry link arena and the per-tile head column."""
682: 	_link_tile.resize(ZONE_LINK_CAPACITY)
683: 	_link_zone.resize(ZONE_LINK_CAPACITY)
684: 	_link_tile_next.resize(ZONE_LINK_CAPACITY)
685: 	_link_zone_next.resize(ZONE_LINK_CAPACITY)
686: 	_tile_link_head.resize(TILE_COUNT)
687: 
688: 
689: func _allocate_patch_columns() -> void:
690: 	"""Size the seven ForagePatch columns at 640 rows (128 zones x 5 patches)."""
691: 	_patch_present.resize(FORAGE_PATCH_CAPACITY)
692: 	_patch_item_id.resize(FORAGE_PATCH_CAPACITY)
693: 	_patch_zone_slot.resize(FORAGE_PATCH_CAPACITY)
694: 	_patch_zone_generation.resize(FORAGE_PATCH_CAPACITY)
695: 	_patch_stock_milli.resize(FORAGE_PATCH_CAPACITY)
696: 	_patch_capacity_milli.resize(FORAGE_PATCH_CAPACITY)
697: 	_patch_harvested_year_milli.resize(FORAGE_PATCH_CAPACITY)
698: 
699: 
700: func clear() -> void:
701: 	"""Return every column to its empty state without reallocating one of them.
702: 
703: 	Every live zone's directory slot is released first, so dropping this store cannot strand
704: 	allocated slots in a directory it does not own.
705: 	"""
706: 	_release_live_zones()
707: 	_clear_zone_columns()
708: 	_clear_link_columns()
709: 	_clear_patch_columns()
710: 	_clear_claim_columns()
711: 	if _owns_directory:
712: 		_directory.clear()
713: 
714: 
715: func _clear_claim_columns() -> void:
716: 	"""Refill every ForageClaim column with its empty value and drop the live count."""
717: 	_claim_active.fill(0)
718: 	_claim_job_slot.fill(EntityDirectory.NULL_SLOT)
719: 	_claim_job_generation.fill(EntityDirectory.NULL_GENERATION)
720: 	_claim_designation_slot.fill(EntityDirectory.NULL_SLOT)
721: 	_claim_designation_generation.fill(EntityDirectory.NULL_GENERATION)
722: 	_claim_basin_slot.fill(EntityDirectory.NULL_SLOT)
723: 	_claim_basin_generation.fill(EntityDirectory.NULL_GENERATION)
724: 	_claim_patch_kind.fill(-1)
725: 	_claim_remaining_milli.fill(0)
726: 	_claim_created_tick.fill(0)
727: 	_claim_persistent_id.fill(0)
728: 	_claim_count = 0
729: 
730: 
738: 
739: 
740: func _clear_zone_columns() -> void:
741: 	"""Refill every HarvestZone column with its empty value."""
742: 	_zone_present.fill(0)
743: 	_zone_type.fill(0)
744: 	_zone_danger.fill(0)
745: 	_zone_quota_milli.fill(0)
746: 	_zone_protected.fill(0)
747: 	_zone_enabled.fill(0)
748: 	_zone_ref_slot.fill(EntityDirectory.NULL_SLOT)
749: 	_zone_ref_generation.fill(EntityDirectory.NULL_GENERATION)
750: 	_zone_basin_slot.fill(EntityDirectory.NULL_SLOT)
751: 	_zone_basin_generation.fill(EntityDirectory.NULL_GENERATION)
752: 	_zone_harvested_today_milli.fill(0)
753: 	_zone_quota_reserved_milli.fill(0)
754: 	_zone_quota_mode.fill(QUOTA_MODE_AUTOMATIC)
755: 	_zone_link_head.fill(NO_LINK)
756: 	_zone_tile_count.fill(0)
757: 	_zone_patch_count.fill(0)
758: 	_live_zone_slots.fill(EntityDirectory.NULL_SLOT)
759: 	_live_zone_count = 0
760: 
761: 
762: func _clear_link_columns() -> void:
763: 	"""Empty the link arena. The bump allocator makes this O(columns), not O(16384) writes."""
764: 	_link_tile.fill(NO_LINK)
765: 	_link_zone.fill(EntityDirectory.NULL_SLOT)
766: 	_link_tile_next.fill(NO_LINK)
767: 	_link_zone_next.fill(NO_LINK)
768: 	_tile_link_head.fill(NO_LINK)
769: 	_link_bump = 0
770: 	_link_free_head = NO_LINK
771: 	_link_used = 0
772: 
773: 
774: func _clear_patch_columns() -> void:
775: 	"""Refill every ForagePatch column with its empty value."""
776: 	_patch_present.fill(0)
777: 	_patch_item_id.fill(-1)
778: 	_patch_zone_slot.fill(EntityDirectory.NULL_SLOT)
779: 	_patch_zone_generation.fill(EntityDirectory.NULL_GENERATION)
780: 	_patch_stock_milli.fill(0)
781: 	_patch_capacity_milli.fill(0)
782: 	_patch_harvested_year_milli.fill(0)
783: 
784: 
816: # --- zone lifecycle ---------------------------------------------------------------------------------
817: 
818: func create_zone(zone_type: int, danger: int, quota_milli: int, is_protected: bool,
819: 		is_enabled: bool) -> OpResult:
820: 	"""Designate one HarvestZone with no tiles and no patches, owning itself as its basin.
821: 
822: 	REQ-SET-060 and SET-AMEND-001 §3: a RESERVED_1 zone is refused "before allocating a job or
823: 	changing the world", so the type is checked before the directory is touched. Refuses -- and
824: 	allocates nothing -- on an unknown type, a danger outside §5.5's 0..3 bands, or a negative
825: 	quota.
826: 	"""
827: 	var code: StringName = _refuse_create_zone(zone_type, danger, quota_milli)
828: 	if code != REFUSE_NONE:
829: 		return _refuse(code)
830: 	var ref: Vector2i = _directory.create(EntityDirectory.KIND_HARVEST_ZONE)
831: 	if ref == NULL_REF:
832: 		return _refuse(_directory.last_refusal())
833: 	var slot: int = _directory.get_typed_row(ref)
834: 	_write_created_zone(slot, ref, zone_type, danger, quota_milli, is_protected, is_enabled)
835: 	return _succeed(slot, ref)
836: 
837: 
876: 
877: 
878: func destroy_zone(ref: Vector2i) -> OpResult:
879: 	"""Remove one zone, release every tile link and patch it owns, and free its directory slot.
880: 
881: 	Returns the number of tile links released. Refuses a stale or wrong-kind reference rather
882: 	than clearing whatever row it points at, which is what makes a reused slot safe.
883: 
884: 	Ruling §4.5: deleting a designation "releases its outstanding claims first" and does not reset
885: 	the basin's usage. Only THIS row's daily totals are cleared; the basin it drew from keeps its
886: 	collected total, its own claims and its annual patch counters.
887: 	"""
888: 	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
889: 		return _refuse(REFUSE_ZONE_NOT_PRESENT)
890: 	var slot: int = _directory.get_typed_row(ref)
891: 	if not is_zone_present(slot):
892: 		return _refuse(REFUSE_ZONE_NOT_PRESENT)
893: 	_release_claims_of_zone_slot(slot)
894: 	var released: int = _release_zone_links(slot)
895: 	_release_zone_patches(slot)
896: 	_zone_harvested_today_milli[slot] = 0
897: 	_zone_quota_reserved_milli[slot] = 0
898: 	_zone_quota_mode[slot] = QUOTA_MODE_AUTOMATIC
899: 	_zone_present[slot] = 0
900: 	_zone_ref_slot[slot] = EntityDirectory.NULL_SLOT
901: 	_zone_ref_generation[slot] = EntityDirectory.NULL_GENERATION
902: 	_zone_basin_slot[slot] = EntityDirectory.NULL_SLOT
903: 	_zone_basin_generation[slot] = EntityDirectory.NULL_GENERATION
904: 	_remove_live_zone(slot)
905: 	_directory.destroy(ref)
906: 	return _succeed(released, NULL_REF)
907: 
908: 
1126: 
1127: 
1128: func _free_link(link: int) -> void:
1129: 	"""Return one link to the free list, clearing every field it carried."""
1130: 	_link_tile[link] = NO_LINK
1131: 	_link_zone[link] = EntityDirectory.NULL_SLOT
1132: 	_link_zone_next[link] = NO_LINK
1133: 	_link_tile_next[link] = _link_free_head
1134: 	_link_free_head = link
1135: 	_link_used -= 1
1136: 
1137: 
1321: # --- ForagePatch lifecycle ----------------------------------------------------------------------------
1322: 
1323: func create_patch(ref: Vector2i, kind: int, item_id: int) -> OpResult:
1324: 	"""Create one of a forage basin's five §5.5 patches, full to GDD §5.1's 80% of capacity.
1325: 
1326: 	Returns the patch row. Capacity and kind come from §5.5's table, never from the caller.
1327: 	Refuses a non-FORAGE zone, a zone bound to another basin, a kind outside 0..4, a negative
1328: 	item id, and a second patch of the same kind.
1329: 	"""
1330: 	if not zone_slot_of_into(ref, _math):
1331: 		return _refuse(StringName(_math.error))
1332: 	var slot: int = _math.value
1333: 	var code: StringName = _refuse_create_patch(slot, kind, item_id)
1334: 	if code != REFUSE_NONE:
1335: 		return _refuse(code)
1336: 	var row: int = slot * PATCHES_PER_ZONE + kind
1337: 	var capacity: int = PATCH_CAPACITY_U[kind] * MILLI_PER_UNIT
1338: 	_patch_present[row] = 1
1339: 	_patch_item_id[row] = item_id
1340: 	_patch_zone_slot[row] = ref.x
1341: 	_patch_zone_generation[row] = ref.y
1342: 	_patch_capacity_milli[row] = capacity
1343: 	_patch_stock_milli[row] = capacity * INITIAL_STOCK_NUMERATOR / INITIAL_STOCK_DENOMINATOR
1344: 	_patch_harvested_year_milli[row] = 0
1345: 	_zone_patch_count[slot] += 1
1346: 	return _succeed(row, ref)
1347: 
1348: 
1362: 
1363: 
1364: func create_patch_set(ref: Vector2i, item_ids: PackedInt32Array) -> OpResult:
1365: 	"""Create all five §5.5 patches of a forage basin at once, in PATCH_KEYS order.
1366: 
1367: 	All or nothing: every kind is validated before the first is written, so a refusal leaves the
1368: 	basin with the patches it already had. Returns the number of patches created.
1369: 	"""
1370: 	if item_ids.size() != PATCHES_PER_ZONE:
1371: 		return _refuse(REFUSE_PATCH_SET_SIZE)
1372: 	if not zone_slot_of_into(ref, _math):
1373: 		return _refuse(StringName(_math.error))
1374: 	var slot: int = _math.value
1375: 	for kind: int in PATCHES_PER_ZONE:
1376: 		var code: StringName = _refuse_create_patch(slot, kind, item_ids[kind])
1377: 		if code != REFUSE_NONE:
1378: 			return _refuse(code)
1379: 	for kind: int in PATCHES_PER_ZONE:
1380: 		var created: OpResult = create_patch(ref, kind, item_ids[kind])
1381: 		if not created.ok:
1382: 			return created
1383: 	return _succeed(PATCHES_PER_ZONE, ref)
1384: 
1385: 
2433: 
2434: 
2435: func _clear_claim_row(row: int) -> void:
2436: 	"""Return one claim row to exactly the state _clear_claim_columns() produces."""
2437: 	_claim_active[row] = 0
2438: 	_claim_job_slot[row] = EntityDirectory.NULL_SLOT
2439: 	_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
2440: 	_claim_designation_slot[row] = EntityDirectory.NULL_SLOT
2441: 	_claim_designation_generation[row] = EntityDirectory.NULL_GENERATION
2442: 	_claim_basin_slot[row] = EntityDirectory.NULL_SLOT
2443: 	_claim_basin_generation[row] = EntityDirectory.NULL_GENERATION
2444: 	_claim_patch_kind[row] = -1
2445: 	_claim_remaining_milli[row] = 0
2446: 	_claim_created_tick[row] = 0
2447: 	_claim_persistent_id[row] = 0
2448: 
2449: 
2713: # --- decision 0030 §4.7: the load path and its derived aggregates ----------------------------------
2714: 
2715: func restore_claim(job_ref: Vector2i, designation_ref: Vector2i, kind: int,
2716: 		remaining_milli: int) -> OpResult:
2717: 	"""Write one saved claim record WITHOUT touching the derived reservation totals.
2718: 
2719: 	Legacy-only R05-QUOTA-022 helper; never call it from SAVE-CLAIMS-R01.
2720: 	The historical loader design restores claim records and then calls
2721: 	rebuild_reservation_aggregates() before any admission or collection resumes; that is why this
2722: 	deliberately leaves `quota_reserved_milli` alone rather than maintaining it. It performs NO
2723: 	quota or stock preflight either: the world being restored already committed those. References,
2724: 	the patch kind and a positive quantity ARE validated, because a save that fails them must be
2725: 	refused rather than loaded.
2726: 	"""
2727: 	if _jobs == null:
2728: 		return _refuse(REFUSE_NO_JOB_STORE)
2729: 	if remaining_milli <= 0 or remaining_milli > MANUAL_QUOTA_MAX_MILLI:
2730: 		return _refuse(REFUSE_INVALID_AMOUNT)
2731: 	var owner_code: StringName = _check_claim_owner(job_ref)
2732: 	if owner_code != REFUSE_NONE:
2733: 		return _refuse(owner_code)
2734: 	if not is_patch_kind(kind):
2735: 		return _refuse(REFUSE_INVALID_PATCH_KIND)
2736: 	if not zone_slot_of_into(designation_ref, _math):
2737: 		return _refuse(StringName(_math.error))
2738: 	_pending_designation_slot = _math.value
2739: 	if not patch_row_for_zone_into(designation_ref, kind, _math):
2740: 		return _refuse(StringName(_math.error))
2741: 	_pending_patch_row = _math.value
2742: 	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
2743: 	var row: int = _directory.get_typed_row(job_ref)
2744: 	_write_claim(row, job_ref, designation_ref, kind, remaining_milli)
2745: 	return _succeed(row, job_ref)
2746: 
2747: 
2997: 
2998: ## Section 1's owner key, schema version and declared primary row extent for this block.
2999: const SECTION_1_OWNER_KEY: String = "forage"
3000: const SECTION_1_OWNER_SCHEMA_VERSION: int = 1
3001: const SECTION_1_PRIMARY_COUNT: int = TILE_COUNT
3002: 
3003: const COLUMN_REFUSE_NONE: StringName = &""
3004: const COLUMN_REFUSE_SHAPE: StringName = &"S1_FORAGE_COLUMN_SHAPE"
3005: const COLUMN_REFUSE_HEAD_RANGE: StringName = &"S1_FORAGE_HEAD_RANGE"
3006: const COLUMN_REFUSE_UNALLOCATED: StringName = &"S1_FORAGE_LINK_UNALLOCATED"
3007: const COLUMN_REFUSE_WRONG_TILE: StringName = &"S1_FORAGE_LINK_WRONG_TILE"
3008: const COLUMN_REFUSE_CYCLE: StringName = &"S1_FORAGE_LINK_CYCLE"
3009: const COLUMN_REFUSE_DEAD_ZONE: StringName = &"S1_FORAGE_LINK_DEAD_ZONE"
3010: const COLUMN_REFUSE_STALE_IDENTITY: StringName = &"S1_FORAGE_STALE_IDENTITY"
3011: const COLUMN_REFUSE_CHAIN_DISAGREES: StringName = &"S1_FORAGE_CHAINS_DISAGREE"
3012: const COLUMN_REFUSE_UNREACHABLE: StringName = &"S1_FORAGE_LINK_UNREACHABLE"
3013: 
3014: ## Code and detail behind the most recent §1 column refusal. Both empty after an accepted call.
3015: var _section_1_code: StringName = COLUMN_REFUSE_NONE
3016: var _section_1_detail: String = ""
3027: 
3028: 
3029: func copy_section_1_columns_into(out_tile_link_head: PackedInt32Array) -> bool:
3030: 	"""Snapshot `_tile_link_head` into a caller-owned buffer that is already TILE_COUNT long."""
3031: 	if _tile_link_head.size() != TILE_COUNT:
3032: 		return _refuse_section_1(COLUMN_REFUSE_SHAPE,
3033: 			"the live head column is %d entries, not %d" % [_tile_link_head.size(), TILE_COUNT])
3034: 	if out_tile_link_head.size() != TILE_COUNT:
3035: 		return _refuse_section_1(COLUMN_REFUSE_SHAPE,
3036: 			"the destination buffer is %d entries, not %d"
3037: 				% [out_tile_link_head.size(), TILE_COUNT])
3038: 	out_tile_link_head.clear()
3039: 	out_tile_link_head.append_array(_tile_link_head)
3040: 	_section_1_accept()
3041: 	return true
3042: 
3043: 
3152: 
3153: 
3154: func restore_section_1_columns(tile_link_head: PackedInt32Array) -> bool:
3155: 	"""Install a validated head column verbatim. Validates first, so a refusal changes nothing."""
3156: 	if section_1_local_refusal(tile_link_head) != COLUMN_REFUSE_NONE:
3157: 		return false
3158: 	_tile_link_head = tile_link_head.duplicate()
3159: 	_section_1_accept()
3160: 	return true
3161: 
3162: 
3201: # --- SAVE-CLAIMS-R01 v2: the ForageClaim column block --------------------------------------------
3202: 
3203: const COLUMN_FORAGE_CLAIM_SHAPE: StringName = &"COLUMN_FORAGE_CLAIM_SHAPE"
3204: const COLUMN_FORAGE_CLAIM_OCCUPANCY: StringName = &"COLUMN_FORAGE_CLAIM_OCCUPANCY"
3205: const COLUMN_FORAGE_CLAIM_BLANK: StringName = &"COLUMN_FORAGE_CLAIM_BLANK"
3206: const COLUMN_FORAGE_CLAIM_REF: StringName = &"COLUMN_FORAGE_CLAIM_REF"
3207: const COLUMN_FORAGE_CLAIM_KIND: StringName = &"COLUMN_FORAGE_CLAIM_KIND"
3208: const COLUMN_FORAGE_CLAIM_QUANTITY: StringName = &"COLUMN_FORAGE_CLAIM_QUANTITY"
3209: const COLUMN_FORAGE_CLAIM_ORDER_KEY: StringName = &"COLUMN_FORAGE_CLAIM_ORDER_KEY"
3210: const COLUMN_FORAGE_CLAIM_SOURCE_COUNT: StringName = &"COLUMN_FORAGE_CLAIM_SOURCE_COUNT"
3211: 
3212: ## The exact blank a released claim row carries.
3213: const CLAIM_COLUMN_BLANK_SLOT: int = EntityDirectory.NULL_SLOT
3214: const CLAIM_COLUMN_BLANK_GENERATION: int = EntityDirectory.NULL_GENERATION
3215: const CLAIM_COLUMN_BLANK_KIND: int = -1
3216: const CLAIM_COLUMN_BLANK_I64: int = 0
3218: ## Each stored zone reference is a DIRECTORY slot, not a claim row and not a typed zone row; the
3219: ## row index itself is the owning Job's typed row, so the stored Job slot is NOT equal to it.
3220: const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1
3222: ## Code of the most recent claim-column refusal. Set only on refusal, cleared only on success,
3223: ## and deliberately separate from this module's existing section 1 diagnostic.
3224: var _last_claim_column_refusal: StringName = REFUSE_NONE
3284: 
3285: 
3286: func copy_forage_claim_columns_into(out: ForageClaimColumns) -> bool:
3287: 	"""Publish eleven independent duplicates of the live claim table, or refuse touching nothing.
3288: 
3289: 	Order is deterministic and the first gate wins: caller null or any caller/live array length
3290: 	mismatch; the whole table's active bytes; ascending rows; and only THEN the native count
3291: 	against the rows actually counted. The source is read-only apart from this diagnostic.
3292: 	"""
3293: 	if out == null:
3294: 		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
3295: 	if not _forage_claim_record_shape_ok(out) or not _forage_claim_live_shape_ok():
3296: 		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
3297: 	var tally: ForageClaimTally = ForageClaimTally.new()
3298: 	var code: StringName = _forage_claim_payload_code(_claim_active, _claim_job_slot,
3299: 		_claim_job_generation, _claim_designation_slot, _claim_designation_generation,
3300: 		_claim_basin_slot, _claim_basin_generation, _claim_patch_kind, _claim_remaining_milli,
3301: 		_claim_created_tick, _claim_persistent_id, tally)
3302: 	if code != REFUSE_NONE:
3303: 		return _refuse_claim_column(code)
3304: 	if _claim_count != tally.active_rows:
3305: 		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SOURCE_COUNT)
3306: 	out.claim_active = _claim_active.duplicate()
3307: 	out.claim_job_slot = _claim_job_slot.duplicate()
3308: 	out.claim_job_generation = _claim_job_generation.duplicate()
3309: 	out.claim_designation_slot = _claim_designation_slot.duplicate()
3310: 	out.claim_designation_generation = _claim_designation_generation.duplicate()
3311: 	out.claim_basin_slot = _claim_basin_slot.duplicate()
3312: 	out.claim_basin_generation = _claim_basin_generation.duplicate()
3313: 	out.claim_patch_kind = _claim_patch_kind.duplicate()
3314: 	out.claim_remaining_milli = _claim_remaining_milli.duplicate()
3315: 	out.claim_created_tick = _claim_created_tick.duplicate()
3316: 	out.claim_persistent_id = _claim_persistent_id.duplicate()
3317: 	_last_claim_column_refusal = REFUSE_NONE
3318: 	return true
3319: 
3320: 
3321: func restore_forage_claim_columns(cols: ForageClaimColumns) -> bool:
3322: 	"""Install a validated claim table and its derived count, or refuse changing nothing.
3323: 
3324: 	The prior payload and the prior count are IGNORED: only the live array shapes are required.
3325: 	Every generation pair, row index and ordering key is preserved verbatim, including stale
3326: 	generations and a zero created tick or persistent id; nothing is sorted, compacted, clamped,
3327: 	masked or repaired, and no reservation aggregate or order key is rewritten. All eleven arrays
3328: 	are duplicated privately first, so no fallible work remains once publication begins and a
3329: 	later mutation of the input cannot leak across this boundary.
3330: 	"""
3331: 	if cols == null:
3332: 		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
3333: 	if not _forage_claim_record_shape_ok(cols) or not _forage_claim_live_shape_ok():
3334: 		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
3335: 	var tally: ForageClaimTally = ForageClaimTally.new()
3336: 	var code: StringName = _forage_claim_payload_code(cols.claim_active, cols.claim_job_slot,
3337: 		cols.claim_job_generation, cols.claim_designation_slot,
3338: 		cols.claim_designation_generation, cols.claim_basin_slot, cols.claim_basin_generation,
3339: 		cols.claim_patch_kind, cols.claim_remaining_milli, cols.claim_created_tick,
3340: 		cols.claim_persistent_id, tally)
3341: 	if code != REFUSE_NONE:
3342: 		return _refuse_claim_column(code)
3343: 	var active: PackedByteArray = cols.claim_active.duplicate()
3344: 	var job_slot: PackedInt32Array = cols.claim_job_slot.duplicate()
3345: 	var job_generation: PackedInt32Array = cols.claim_job_generation.duplicate()
3346: 	var designation_slot: PackedInt32Array = cols.claim_designation_slot.duplicate()
3347: 	var designation_generation: PackedInt32Array = cols.claim_designation_generation.duplicate()
3348: 	var basin_slot: PackedInt32Array = cols.claim_basin_slot.duplicate()
3349: 	var basin_generation: PackedInt32Array = cols.claim_basin_generation.duplicate()
3350: 	var patch_kind: PackedInt32Array = cols.claim_patch_kind.duplicate()
3351: 	var remaining_milli: PackedInt64Array = cols.claim_remaining_milli.duplicate()
3352: 	var created_tick: PackedInt64Array = cols.claim_created_tick.duplicate()
3353: 	var persistent_id: PackedInt64Array = cols.claim_persistent_id.duplicate()
3354: 	_claim_active = active
3355: 	_claim_job_slot = job_slot
3356: 	_claim_job_generation = job_generation
3357: 	_claim_designation_slot = designation_slot
3358: 	_claim_designation_generation = designation_generation
3359: 	_claim_basin_slot = basin_slot
3360: 	_claim_basin_generation = basin_generation
3361: 	_claim_patch_kind = patch_kind
3362: 	_claim_remaining_milli = remaining_milli
3363: 	_claim_created_tick = created_tick
3364: 	_claim_persistent_id = persistent_id
3365: 	_claim_count = tally.active_rows
3366: 	_last_claim_column_refusal = REFUSE_NONE
3367: 	return true
3368: 
3369: 

# godot/scripts/core/jobs.gd
266: ## silently widening a budgeted allocation is exactly what this note exists to prevent.
267: 
268: const IntMath := preload("res://scripts/core/int_math.gd")
269: const Catalog := preload("res://scripts/core/catalog.gd")
270: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
271: const NeedsScript := preload("res://scripts/core/needs.gd")
272: const ResidentsScript := preload("res://scripts/core/residents.gd")
273: const PrioritiesScript := preload("res://scripts/core/priorities.gd")
274: const ScheduleScript := preload("res://scripts/core/schedule.gd")
278: ## GDD §4.2 "At most 8192 active/queued jobs"; `_init()` asserts this equals the directory's own
279: ## KIND_JOB capacity rather than restating an independent number.
280: const JOB_CAPACITY: int = 8192
281: ## One JobAgent row per RESIDENT typed row; `_init()` asserts this equals needs.gd's capacity.
282: const AGENT_CAPACITY: int = 512
283: 
284: const NULL_REF: Vector2i = EntityDirectory.NULL_REF
286: # --- GDD §4.3 JobKind, read from catalog.gd's protected table (decision 0018) ----------------
287: 
288: const JOB_KIND_COUNT: int = 12
289: const JOB_KIND_HAUL: int = Catalog.JOB_KIND["HAUL"]
290: const JOB_KIND_BUILD: int = Catalog.JOB_KIND["BUILD"]
291: const JOB_KIND_FISH: int = Catalog.JOB_KIND["FISH"]
292: const JOB_KIND_FORAGE: int = Catalog.JOB_KIND["FORAGE"]
293: const JOB_KIND_FARM: int = Catalog.JOB_KIND["FARM"]
294: const JOB_KIND_COOK: int = Catalog.JOB_KIND["COOK"]
295: const JOB_KIND_PRESERVE: int = Catalog.JOB_KIND["PRESERVE"]
296: const JOB_KIND_CRAFT: int = Catalog.JOB_KIND["CRAFT"]
297: const JOB_KIND_TEND: int = Catalog.JOB_KIND["TEND"]
298: const JOB_KIND_KEEP: int = Catalog.JOB_KIND["KEEP"]
299: const JOB_KIND_HEAL: int = Catalog.JOB_KIND["HEAL"]
300: ## `setting_rules_amendment.md` renamed HUNT=3 to RESERVED_3=3 with assignment prohibited, so no
301: ## Job row may ever carry it; the physical 12-wide stride is preserved either way.
302: const JOB_KIND_RESERVED_INDEX: int = Catalog.JOB_KIND["RESERVED_3"]
304: # --- GDD §4.3 JobState, read from catalog.gd's protected table (decision 0018) ---------------
305: 
306: const JOB_STATE_QUEUED: int = Catalog.JOB_STATE["QUEUED"]
307: const JOB_STATE_RESERVED: int = Catalog.JOB_STATE["RESERVED"]
308: const JOB_STATE_TRAVEL: int = Catalog.JOB_STATE["TRAVEL"]
309: const JOB_STATE_WORK: int = Catalog.JOB_STATE["WORK"]
310: const JOB_STATE_HAUL_OUTPUT: int = Catalog.JOB_STATE["HAUL_OUTPUT"]
311: const JOB_STATE_COMPLETE: int = Catalog.JOB_STATE["COMPLETE"]
312: const JOB_STATE_BLOCKED: int = Catalog.JOB_STATE["BLOCKED"]
313: const JOB_STATE_CANCELLED: int = Catalog.JOB_STATE["CANCELLED"]
314: ## JobState is contiguous 0..7, which `_init()` proves before any range check relies on it.
315: const JOB_STATE_COUNT: int = 8
320: ## is the flexible hour, and the "Flexible is all ANYTHING" template would never work at all if
321: ## it did not permit work. SLEEP and SOCIAL do not.
322: const ACTIVITY_WORK: int = ScheduleScript.ACTIVITY_WORK
323: const ACTIVITY_ANYTHING: int = ScheduleScript.ACTIVITY_ANYTHING
326: 
327: ## "0 rescue/feeding an incapacitated resident".
328: const URGENCY_RESCUE: int = 0
329: ## "1 personal critical needs".
330: const URGENCY_PERSONAL_CRITICAL: int = 1
333: ## ordinary work otherwise. The condition is a world state, not a property of the job, so it
334: ## cannot be baked into the stored value -- see `set_food_reserve_below_two_days()`.
335: const URGENCY_FOOD_FUEL: int = 2
336: ## "3 ordinary production/construction". The default for a newly created job.
337: const URGENCY_ORDINARY: int = 3
338: ## "4 cosmetic upkeep".
339: const URGENCY_COSMETIC: int = 4
340: const URGENCY_COUNT: int = 5
358: ## destroyed. It refuses, like GATE_BLOCKED, but with its own code so "cannot say" is never
359: ## mistaken for "no". Both GATE_BLOCKED and GATE_UNAVAILABLE make a job ineligible.
360: const GATE_NOT_REQUIRED: int = 0
361: const GATE_SATISFIED: int = 1
362: const GATE_BLOCKED: int = 2
363: const GATE_UNAVAILABLE: int = 3
364: const GATE_COUNT: int = 4
367: 
368: ## "Reevaluate idle residents every 30 ticks, staggered by resident ID mod 30."
369: const REEVALUATION_INTERVAL_TICKS: int = 30
370: const STAGGER_MODULUS: int = 30
371: ## "A worker evaluates at most 32 indexed candidate jobs per pass."
372: const CANDIDATE_BUDGET_PER_PASS: int = 32
374: # --- REQ-SET-015 hazard latch thresholds (borrowed from needs.gd, never restated) -------------
375: 
376: const REST_COLLAPSE_THRESHOLD: int = NeedsScript.REST_COLLAPSE_THRESHOLD
377: const REST_HAZARD_CLEAR_THRESHOLD: int = NeedsScript.REST_HAZARD_CLEAR_THRESHOLD
379: # --- skill level bounds ----------------------------------------------------------------------
380: 
381: const SKILL_LEVEL_MIN: int = 0
382: const SKILL_LEVEL_MAX: int = ResidentsScript.SKILL_LEVEL_MAX
384: # --- refusal codes ---------------------------------------------------------------------------
385: 
386: const REFUSE_NONE: StringName = &""
387: const REFUSE_INVALID_JOB_SLOT: StringName = &"INVALID_JOB_SLOT"
388: const REFUSE_JOB_NOT_PRESENT: StringName = &"JOB_NOT_PRESENT"
389: const REFUSE_INVALID_RESIDENT_SLOT: StringName = &"INVALID_RESIDENT_SLOT"
390: const REFUSE_AGENT_NOT_PRESENT: StringName = &"JOB_AGENT_NOT_PRESENT"
391: const REFUSE_AGENT_ALREADY_PRESENT: StringName = &"JOB_AGENT_ALREADY_PRESENT"
392: const REFUSE_RESIDENT_NOT_PRESENT: StringName = &"RESIDENT_NOT_PRESENT"
393: const REFUSE_INVALID_JOB_KIND: StringName = &"INVALID_JOB_KIND"
394: const REFUSE_RESERVED_JOB_KIND: StringName = &"RESERVED_JOB_KIND"
395: const REFUSE_INVALID_JOB_STATE: StringName = &"INVALID_JOB_STATE"
396: const REFUSE_INVALID_PRIORITY: StringName = &"INVALID_JOB_PRIORITY"
397: const REFUSE_INVALID_REQUIRED_SKILL: StringName = &"INVALID_REQUIRED_SKILL"
398: const REFUSE_INVALID_MWU: StringName = &"INVALID_REMAINING_MWU"
399: const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
400: const REFUSE_INVALID_URGENCY: StringName = &"INVALID_URGENCY"
401: const REFUSE_INVALID_GATE: StringName = &"INVALID_GATE"
402: const REFUSE_INVALID_REFERENCE: StringName = &"INVALID_REFERENCE"
403: const REFUSE_JOB_HAS_WORKER: StringName = &"JOB_HAS_WORKER"
404: const REFUSE_JOB_NOT_QUEUED: StringName = &"JOB_NOT_QUEUED"
405: const REFUSE_AGENT_BUSY: StringName = &"JOB_AGENT_BUSY"
406: const REFUSE_AGENT_IDLE: StringName = &"JOB_AGENT_IDLE"
407: const REFUSE_NOT_DUE_THIS_TICK: StringName = &"NOT_DUE_THIS_TICK"
408: const REFUSE_NO_ELIGIBLE_JOB: StringName = &"NO_ELIGIBLE_JOB"
409: 
410: # Eligibility step refusals: one code per rule, in §5.3's own order.
411: const REFUSE_RESIDENT_DEAD: StringName = &"STEP1_RESIDENT_DEAD"
412: const REFUSE_RESIDENT_INCAPACITATED: StringName = &"STEP1_RESIDENT_INCAPACITATED"
413: const REFUSE_REST_COLLAPSED: StringName = &"STEP1_REST_COLLAPSED"
414: const REFUSE_ACTIVITY_UNRESOLVED: StringName = &"STEP2_ACTIVITY_UNRESOLVED"
415: const REFUSE_ACTIVITY_FORBIDS_WORK: StringName = &"STEP2_ACTIVITY_FORBIDS_WORK"
416: const REFUSE_KIND_PRIORITY_FORBIDDEN: StringName = &"STEP3_KIND_PRIORITY_FORBIDDEN"
417: const REFUSE_STATION_BLOCKED: StringName = &"STEP4_STATION_BLOCKED"
418: const REFUSE_TOOL_BLOCKED: StringName = &"STEP4_TOOL_BLOCKED"
419: const REFUSE_SKILL_TOO_LOW: StringName = &"STEP4_SKILL_TOO_LOW"
420: const REFUSE_UNLOCK_BLOCKED: StringName = &"STEP4_UNLOCK_BLOCKED"
421: const REFUSE_DANGEROUS_CONSENT: StringName = &"STEP5_DANGEROUS_CONSENT"
422: const REFUSE_HAZARD_LOCKED: StringName = &"STEP5_HAZARD_LOCKED"
423: const REFUSE_INPUTS_INCOMPLETE: StringName = &"STEP6_INPUTS_INCOMPLETE"
424: # Decision 0023: a declared requirement whose owning system cannot answer refuses as UNAVAILABLE,
425: # never as satisfied. One code per gate, so "cannot say" never reads as "no".
426: const REFUSE_STATION_UNAVAILABLE: StringName = &"STEP4_STATION_UNAVAILABLE"
427: const REFUSE_TOOL_UNAVAILABLE: StringName = &"STEP4_TOOL_UNAVAILABLE"
428: const REFUSE_UNLOCK_UNAVAILABLE: StringName = &"STEP4_UNLOCK_UNAVAILABLE"
429: const REFUSE_INPUTS_UNAVAILABLE: StringName = &"STEP6_INPUTS_UNAVAILABLE"
430: const REFUSE_NEEDS_UNAVAILABLE: StringName = &"NEEDS_ROW_UNAVAILABLE"
431: # Decision 0017 coordinator refusals.
432: const REFUSE_COORDINATOR_JOB: StringName = &"COORDINATOR_JOB_NOT_SELECTABLE"
433: const REFUSE_NOT_A_COORDINATOR: StringName = &"JOB_IS_NOT_A_COORDINATOR"
434: const REFUSE_ALREADY_A_COORDINATOR: StringName = &"JOB_IS_ALREADY_A_COORDINATOR"
435: const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_A_PARTY_MEMBER"
436: const REFUSE_JOB_NOT_MEMBER: StringName = &"JOB_IS_NOT_A_PARTY_MEMBER"
437: const REFUSE_COORDINATOR_HAS_MEMBERS: StringName = &"COORDINATOR_STILL_HAS_MEMBERS"
438: const REFUSE_MEMBER_HOLDS_PROGRESS: StringName = &"MEMBER_MAY_NOT_HOLD_SHARED_PROGRESS"
439: const REFUSE_SELF_COORDINATION: StringName = &"JOB_MAY_NOT_COORDINATE_ITSELF"
440: const REFUSE_NO_MEMBERS: StringName = &"COORDINATOR_HAS_NO_MEMBERS"
441: const REFUSE_END_OF_MEMBERS: StringName = &"END_OF_MEMBER_LIST"
442: const REFUSE_MWU_UNDERFLOW: StringName = &"REMAINING_MWU_UNDERFLOW"
443: const REFUSE_PRIORITIES_UNAVAILABLE: StringName = &"PRIORITIES_ROW_UNAVAILABLE"
444: const REFUSE_SKILLS_UNAVAILABLE: StringName = &"SKILLS_ROW_UNAVAILABLE"
466: # --- collaborating stores ---------------------------------------------------------------------
467: 
468: var _residents: ResidentsScript = null
469: var _directory: EntityDirectory = null
470: var _needs: NeedsScript = null
471: var _priorities: PrioritiesScript = null
472: var _schedule: ScheduleScript = null
474: # --- Job columns (ARCH-MEM-001: packed, allocated once) ---------------------------------------
475: 
476: var _kind: PackedInt32Array = PackedInt32Array()
477: var _requester_slot: PackedInt32Array = PackedInt32Array()
478: var _requester_generation: PackedInt32Array = PackedInt32Array()
479: var _destination_slot: PackedInt32Array = PackedInt32Array()
480: var _destination_generation: PackedInt32Array = PackedInt32Array()
481: var _source_slot: PackedInt32Array = PackedInt32Array()
482: var _source_generation: PackedInt32Array = PackedInt32Array()
483: var _priority: PackedInt32Array = PackedInt32Array()
484: var _required_skill: PackedInt32Array = PackedInt32Array()
485: var _state: PackedInt32Array = PackedInt32Array()
486: var _worker_slot: PackedInt32Array = PackedInt32Array()
487: var _worker_generation: PackedInt32Array = PackedInt32Array()
488: var _remaining_mwu: PackedInt64Array = PackedInt64Array()
489: var _created_tick: PackedInt64Array = PackedInt64Array()
490: 
491: # Ledger delta, listed in the header.
492: var _job_present: PackedByteArray = PackedByteArray()
493: var _job_ref_slot: PackedInt32Array = PackedInt32Array()
494: var _job_ref_generation: PackedInt32Array = PackedInt32Array()
495: var _urgency: PackedByteArray = PackedByteArray()
496: var _dangerous: PackedByteArray = PackedByteArray()
497: var _station_gate: PackedByteArray = PackedByteArray()
498: var _tool_gate: PackedByteArray = PackedByteArray()
499: var _unlock_gate: PackedByteArray = PackedByteArray()
500: var _inputs_gate: PackedByteArray = PackedByteArray()
503: ## each member's EntityRef back to it; `_member_head` and `_member_next` are the intrusive list
504: ## that enumerates a coordinator's members without allocating.
505: var _is_coordinator: PackedByteArray = PackedByteArray()
506: var _coordinator_slot: PackedInt32Array = PackedInt32Array()
507: var _coordinator_generation: PackedInt32Array = PackedInt32Array()
508: var _member_head: PackedInt32Array = PackedInt32Array()
509: var _member_next: PackedInt32Array = PackedInt32Array()
510: ## The live-job index, ordered by declared urgency and then by ascending persistent ID.
511: var _live_slots: PackedInt32Array = PackedInt32Array()
512: ## Cache of the directory's never-reused persistent ID, so the ordered index and the candidate
513: ## loop compare integers out of a packed column instead of calling back into the directory.
514: var _job_persistent_id: PackedInt32Array = PackedInt32Array()
515: 
516: var _live_count: int = 0
518: ## Half-open bounds of each declared-urgency run inside `_live_slots`: bucket u occupies
519: ## [_bucket_begin[u], _bucket_begin[u + 1]). URGENCY_COUNT + 1 entries, the last one _live_count.
520: var _bucket_begin: PackedInt32Array = PackedInt32Array()
522: # --- JobAgent columns, one row per resident slot ------------------------------------------------
523: 
524: var _agent_job_slot: PackedInt32Array = PackedInt32Array()
525: var _agent_job_generation: PackedInt32Array = PackedInt32Array()
526: var _agent_phase: PackedInt32Array = PackedInt32Array()
527: var _agent_target_slot: PackedInt32Array = PackedInt32Array()
528: var _agent_target_generation: PackedInt32Array = PackedInt32Array()
529: ## Reserved allocation only: no pathfinder exists, so these are 0 and never written (GAPS).
530: var _agent_path_id: PackedInt32Array = PackedInt32Array()
531: var _agent_path_cursor: PackedInt32Array = PackedInt32Array()
532: ## Reserved allocation only: REQ-SET-032/033 lease bookkeeping is not implemented (GAPS).
533: var _agent_lease_expiry: PackedInt64Array = PackedInt64Array()
534: var _agent_blocked_tick: PackedInt64Array = PackedInt64Array()
535: ## Reserved allocation only: ManualTask is blocked by U6 (GAPS).
536: var _agent_manual_until: PackedInt64Array = PackedInt64Array()
537: 
538: # Ledger delta, listed in the header.
539: var _agent_present: PackedByteArray = PackedByteArray()
540: var _agent_hazard_locked: PackedByteArray = PackedByteArray()
541: var _agent_persistent_id: PackedInt32Array = PackedInt32Array()
545: ## `ResidentRuntime.job_scan_cursor` from `systems_architecture.md` §3, realised here because no
546: ## ResidentRuntime store exists yet -- not a second buffer for the same logical state.
547: var _job_scan_cursor: PackedInt32Array = PackedInt32Array()
548: ## The bucket half of the same key. One byte per resident; see the header for why it cannot be
549: ## folded into the int32 above.
550: var _continuation_bucket: PackedByteArray = PackedByteArray()
556: ## high, which is safe because a too-high bound only costs one wasted walk, never a missed
557: ## invalidation.
558: var _deepest_continuation_bucket: int = -1
559: 
560: var _agent_count: int = 0
565: ## food-days figure and the inventory, not by any job, so it arrives as an explicit input with an
566: ## honest default of false. No projection is computed here.
567: var _food_reserve_below_two_days: bool = false
573: ## consumed before that pass returns; nothing here invokes a callback, so no public operation can
574: ## re-enter while they hold a live value.
575: var _skill_scratch: PackedInt32Array = PackedInt32Array()
576: var _priority_scratch: PackedInt32Array = PackedInt32Array()
577: var _dangerous_consent_scratch: bool = false
578: var _hazard_locked_scratch: bool = false
579: ## Caller-owned reader output for internal eligibility paths. Values are consumed before reuse;
580: ## no callback or signal can re-enter this module while one is live.
581: var _math: IntMath.IntResult = IntMath.IntResult.new()
583: ## The incumbent best candidate of the pass in progress. `_best_slot` is -1 only while no
584: ## candidate has been offered; it is internal scratch and never leaves this module as a value.
585: var _best_slot: int = -1
586: var _best_bucket: int = 0
587: var _best_player_priority: int = 0
588: var _best_job_priority: int = 0
589: var _best_skill_level: int = 0
590: var _best_created_tick: int = 0
591: var _best_job_id: int = 0
595: ## merged by ascending persistent ID so a bucket still enumerates in one total order. Plain
596: ## members rather than a returned iterator, so a pass allocates nothing.
597: var _walk_primary_index: int = 0
598: var _walk_primary_end: int = 0
599: var _walk_merged_index: int = 0
600: var _walk_merged_end: int = 0
601: var _walk_slot: int = 0
602: var _walk_job_id: int = 0
603: ## The persistent ID a suspended pass resumes after: the last candidate examined in the bucket it
604: ## was suspended in, or the ID it entered that bucket at when it examined none.
605: var _walk_last_examined_id: int = 0
607: ## persisted, and excluded from `state_bytes()` so a refusal cannot alter the image that proves
608: ## it changed nothing.
609: var _last_column_refusal: StringName = REFUSE_NONE
658: 
659: 
660: func _allocate_columns() -> void:
661: 	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
662: 	for column: PackedInt32Array in [_kind, _requester_slot, _requester_generation,
663: 			_destination_slot, _destination_generation, _source_slot, _source_generation,
664: 			_priority, _required_skill, _state, _worker_slot, _worker_generation,
665: 			_job_ref_slot, _job_ref_generation, _live_slots, _job_persistent_id,
666: 			_coordinator_slot, _coordinator_generation, _member_head, _member_next]:
667: 		column.resize(JOB_CAPACITY)
668: 	for column: PackedInt64Array in [_remaining_mwu, _created_tick]:
669: 		column.resize(JOB_CAPACITY)
670: 	for column: PackedByteArray in [_job_present, _urgency, _dangerous, _station_gate,
671: 			_tool_gate, _unlock_gate, _inputs_gate, _is_coordinator]:
672: 		column.resize(JOB_CAPACITY)
673: 	_bucket_begin.resize(URGENCY_COUNT + 1)
674: 	_allocate_agent_columns()
675: 	_skill_scratch.resize(JOB_KIND_COUNT)
676: 	_priority_scratch.resize(JOB_KIND_COUNT)
677: 
678: 
679: func _allocate_agent_columns() -> void:
680: 	"""Size every JobAgent column exactly once. Split out to keep each function under 30 lines."""
681: 	for column: PackedInt32Array in [_agent_job_slot, _agent_job_generation, _agent_phase,
682: 			_agent_target_slot, _agent_target_generation, _agent_path_id, _agent_path_cursor,
683: 			_job_scan_cursor, _agent_persistent_id]:
684: 		column.resize(AGENT_CAPACITY)
685: 	for column: PackedInt64Array in [_agent_lease_expiry, _agent_blocked_tick,
686: 			_agent_manual_until]:
687: 		column.resize(AGENT_CAPACITY)
688: 	for column: PackedByteArray in [_agent_present, _agent_hazard_locked, _continuation_bucket]:
689: 		column.resize(AGENT_CAPACITY)
690: 
691: 
692: func clear() -> void:
693: 	"""Return every Job and JobAgent row to the empty state without reallocating a column."""
694: 	_clear_job_columns()
695: 	_clear_job_references()
696: 	_clear_agents()
697: 	_food_reserve_below_two_days = false
698: 	_reset_best()
699: 
700: 
701: func _clear_job_columns() -> void:
702: 	"""Refill every scalar Job column with its empty-row default. Split out to stay under 30."""
703: 	_kind.fill(JOB_KIND_HAUL)
704: 	_priority.fill(0)
705: 	_required_skill.fill(0)
706: 	_state.fill(JOB_STATE_QUEUED)
707: 	_remaining_mwu.fill(0)
708: 	_created_tick.fill(0)
709: 	_job_present.fill(0)
710: 	_urgency.fill(URGENCY_ORDINARY)
711: 	_dangerous.fill(0)
712: 	_station_gate.fill(GATE_NOT_REQUIRED)
713: 	_tool_gate.fill(GATE_NOT_REQUIRED)
714: 	_unlock_gate.fill(GATE_NOT_REQUIRED)
715: 	_inputs_gate.fill(GATE_NOT_REQUIRED)
716: 	_is_coordinator.fill(0)
717: 	_member_head.fill(EntityDirectory.NULL_SLOT)
718: 	_member_next.fill(EntityDirectory.NULL_SLOT)
719: 	_live_slots.fill(0)
720: 	_job_persistent_id.fill(0)
721: 	_bucket_begin.fill(0)
722: 	_live_count = 0
723: 
724: 
725: func _clear_job_references() -> void:
726: 	"""Refill every Job EntityRef column pair with the null reference."""
727: 	for column: PackedInt32Array in [_requester_slot, _destination_slot, _source_slot,
728: 			_worker_slot, _job_ref_slot, _coordinator_slot]:
729: 		column.fill(EntityDirectory.NULL_SLOT)
730: 	for column: PackedInt32Array in [_requester_generation, _destination_generation,
731: 			_source_generation, _worker_generation, _job_ref_generation,
732: 			_coordinator_generation]:
733: 		column.fill(EntityDirectory.NULL_GENERATION)
734: 
735: 
736: func _clear_agents() -> void:
737: 	"""Return every JobAgent row to the empty state, refilling the existing buffers."""
738: 	for column: PackedInt32Array in [_agent_job_slot, _agent_target_slot]:
739: 		column.fill(EntityDirectory.NULL_SLOT)
740: 	for column: PackedInt32Array in [_agent_job_generation, _agent_target_generation]:
741: 		column.fill(EntityDirectory.NULL_GENERATION)
742: 	for column: PackedInt32Array in [_agent_phase, _agent_path_id, _agent_path_cursor,
743: 			_job_scan_cursor, _agent_persistent_id]:
744: 		column.fill(0)
745: 	for column: PackedInt64Array in [_agent_lease_expiry, _agent_blocked_tick,
746: 			_agent_manual_until]:
747: 		column.fill(0)
748: 	_agent_present.fill(0)
749: 	_agent_hazard_locked.fill(0)
750: 	_continuation_bucket.fill(0)
751: 	_deepest_continuation_bucket = -1
752: 	_agent_count = 0
753: 
754: 
755: # --- results ----------------------------------------------------------------------------------
756: 
833: # --- Job lifecycle -------------------------------------------------------------------------------
834: 
835: func create_job(kind: int, priority: int, required_skill: int, remaining_mwu: int,
836: 		created_tick: int) -> OpResult:
837: 	"""Allocate one Job row through the directory's KIND_JOB arena and write its §4.2 defaults.
838: 
839: 	`required_skill` is the minimum skill LEVEL 0-10 in the job's own kind (decision 0022).
840: 	Refuses without allocating anything on an unknown or reserved kind, an out-of-int32 priority,
841: 	a level outside 0-10, a negative work total or a negative creation tick, and passes a
842: 	directory refusal through with its own ARCH-ID-004 code. Nothing is clamped: an invalid job
843: 	definition is refused, so no row can exist carrying one.
844: 	"""
845: 	var code: StringName = _check_create_arguments(kind, priority, required_skill,
846: 		remaining_mwu, created_tick)
847: 	if code != REFUSE_NONE:
848: 		return _refuse(code)
849: 	var ref: Vector2i = _directory.create(EntityDirectory.KIND_JOB)
850: 	if ref == NULL_REF:
851: 		return _refuse(_directory.last_refusal())
852: 	var job_slot: int = _directory.get_typed_row(ref)
853: 	_write_new_job_row(job_slot, ref, kind, priority, required_skill)
854: 	_remaining_mwu[job_slot] = remaining_mwu
855: 	_created_tick[job_slot] = created_tick
856: 	_insert_live_slot(job_slot)
857: 	_admit(job_slot)
858: 	return _succeed(job_slot, ref)
859: 
860: 
912: 
913: 
914: func destroy_job(job_slot: int) -> OpResult:
915: 	"""Release one Job row and its directory slot. Refuses while a worker still holds it.
916: 
917: 	Refusing rather than silently unbinding is deliberate: decision 0017 gives worker departure
918: 	and job cancellation separate paths, and a destroy that quietly detached a worker would
919: 	merge them. Call `release_worker()` first.
920: 
921: 	A coordinator that still has members is refused for the same reason: releasing it would
922: 	leave every member Job pointing at a dead row, and 0017 requires shared progress and batch
923: 	data to survive a departure, not to be deleted out from under the party. A member is
924: 	unlinked from its coordinator here, which is the only structural change a destroy makes.
925: 	"""
926: 	var code: StringName = _check_job_slot(job_slot)
927: 	if code != REFUSE_NONE:
928: 		return _refuse(code)
929: 	if _worker_slot[job_slot] != EntityDirectory.NULL_SLOT:
930: 		return _refuse(REFUSE_JOB_HAS_WORKER)
931: 	if _member_head[job_slot] != EntityDirectory.NULL_SLOT:
932: 		return _refuse(REFUSE_COORDINATOR_HAS_MEMBERS)
933: 	if _coordinator_slot[job_slot] != EntityDirectory.NULL_SLOT:
934: 		_unlink_member(job_slot)
935: 	var ref: Vector2i = ref_of(job_slot)
936: 	_directory.destroy(ref)
937: 	_remove_live_slot(job_slot)
938: 	_job_present[job_slot] = 0
939: 	_clear_job_row(job_slot)
940: 	return _succeed(job_slot, NULL_REF)
941: 
942: 
943: func _clear_job_row(job_slot: int) -> void:
944: 	"""Return one released Job row to exactly the state clear() produces.
945: 
946: 	Two logically identical worlds must serialize to identical columns, so a destroyed job
947: 	leaves no residue that would change a canonical hash.
948: 	"""
949: 	_kind[job_slot] = JOB_KIND_HAUL
950: 	_priority[job_slot] = 0
951: 	_required_skill[job_slot] = 0
952: 	_state[job_slot] = JOB_STATE_QUEUED
953: 	_remaining_mwu[job_slot] = 0
954: 	_created_tick[job_slot] = 0
955: 	_job_persistent_id[job_slot] = 0
956: 	_urgency[job_slot] = URGENCY_ORDINARY
957: 	_dangerous[job_slot] = 0
958: 	_station_gate[job_slot] = GATE_NOT_REQUIRED
959: 	_tool_gate[job_slot] = GATE_NOT_REQUIRED
960: 	_unlock_gate[job_slot] = GATE_NOT_REQUIRED
961: 	_inputs_gate[job_slot] = GATE_NOT_REQUIRED
962: 	_is_coordinator[job_slot] = 0
963: 	_member_head[job_slot] = EntityDirectory.NULL_SLOT
964: 	_member_next[job_slot] = EntityDirectory.NULL_SLOT
965: 	_set_ref_columns(job_slot, NULL_REF, _coordinator_slot, _coordinator_generation)
966: 	_set_ref_columns(job_slot, NULL_REF, _job_ref_slot, _job_ref_generation)
967: 	_set_ref_columns(job_slot, NULL_REF, _requester_slot, _requester_generation)
968: 	_set_ref_columns(job_slot, NULL_REF, _destination_slot, _destination_generation)
969: 	_set_ref_columns(job_slot, NULL_REF, _source_slot, _source_generation)
970: 	_set_ref_columns(job_slot, NULL_REF, _worker_slot, _worker_generation)
971: 
972: 
1080: 
1081: 
1082: func validate_job_definition(kind: int, required_skill: int) -> OpResult:
1083: 	"""Decision 0022's definition check, without allocating a row: kind and minimum level.
1084: 
1085: 	`required_skill` outside 0-10 is an INVALID JOB DEFINITION and any job of kind RESERVED_3 is
1086: 	an invalid productive job kind. Both are refused, never clamped, here and in `create_job()`,
1087: 	which runs exactly these tests.
1088: 	"""
1089: 	if kind < 0 or kind >= JOB_KIND_COUNT:
1090: 		return _refuse(REFUSE_INVALID_JOB_KIND)
1091: 	if kind == JOB_KIND_RESERVED_INDEX:
1092: 		return _refuse(REFUSE_RESERVED_JOB_KIND)
1093: 	if required_skill < SKILL_LEVEL_MIN or required_skill > SKILL_LEVEL_MAX:
1094: 		return _refuse(REFUSE_INVALID_REQUIRED_SKILL)
1095: 	return _succeed(required_skill, NULL_REF)
1096: 
1097: 
1718: 
1719: 
1720: func _clear_agent_row(resident_slot: int) -> void:
1721: 	"""Reset one JobAgent row: job, phase, target, reserved columns, continuation and hazard latch."""
1722: 	_set_ref_columns(resident_slot, NULL_REF, _agent_job_slot, _agent_job_generation)
1723: 	_set_ref_columns(resident_slot, NULL_REF, _agent_target_slot, _agent_target_generation)
1724: 	_agent_phase[resident_slot] = 0
1725: 	_agent_path_id[resident_slot] = 0
1726: 	_agent_path_cursor[resident_slot] = 0
1727: 	_agent_lease_expiry[resident_slot] = 0
1728: 	_agent_blocked_tick[resident_slot] = 0
1729: 	_agent_manual_until[resident_slot] = 0
1730: 	_job_scan_cursor[resident_slot] = 0
1731: 	_continuation_bucket[resident_slot] = 0
1732: 	_agent_hazard_locked[resident_slot] = 0
1733: 
1734: 
1735: # --- JobAgent readers -----------------------------------------------------------------------------
1736: 
2389: # handle, so none of the other three namespaces appears in any column here.
2390: 
2391: const COLUMN_TYPE_U8: int = 0
2392: const COLUMN_TYPE_I32: int = 2
2393: const COLUMN_TYPE_I64: int = 4
2394: 
2395: ## The thirty-eight §4 COMPONENT_COLUMNS category-1 columns, in the registry's ordinal order.
2396: const SECTION4_COLUMN_COUNT: int = 38
2397: const SECTION4_COLUMN_KEYS: Array[StringName] = [
2407: 	&"_continuation_bucket",
2408: ]
2409: const SECTION4_COLUMN_TYPE_CODES: Array[int] = [
2419: 	COLUMN_TYPE_U8,
2420: ]
2421: const SECTION4_COLUMN_EXTENTS: Array[int] = [
2433: 
2434: ## The four §5 CHILD_ARENAS category-1 columns, in that section's own ordinal order.
2435: const SECTION5_COLUMN_COUNT: int = 4
2436: const SECTION5_COLUMN_KEYS: Array[StringName] = [
2437: 	&"_coordinator_slot", &"_coordinator_generation", &"_member_head", &"_member_next",
2438: ]
2439: const SECTION5_COLUMN_TYPE_CODES: Array[int] = [
2440: 	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
2441: ]
2442: const SECTION5_COLUMN_EXTENTS: Array[int] = [
2447: ## Every code is prefixed `COLUMN_`, so a load cannot clobber the reason a `create_job()` or an
2448: ## `assign_worker()` was refused before its caller read it, and no value is shared with those.
2449: const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
2450: const REFUSE_COLUMN_PRESENT_BYTE: StringName = &"COLUMN_PRESENT_BYTE"
2451: const REFUSE_COLUMN_FLAG_BYTE: StringName = &"COLUMN_FLAG_BYTE"
2452: const REFUSE_COLUMN_URGENCY: StringName = &"COLUMN_URGENCY"
2453: const REFUSE_COLUMN_GATE: StringName = &"COLUMN_GATE"
2454: const REFUSE_COLUMN_JOB_DEFINITION: StringName = &"COLUMN_JOB_DEFINITION"
2455: const REFUSE_COLUMN_JOB_STATE: StringName = &"COLUMN_JOB_STATE"
2456: const REFUSE_COLUMN_NEGATIVE_MWU: StringName = &"COLUMN_NEGATIVE_MWU"
2457: const REFUSE_COLUMN_NEGATIVE_TICK: StringName = &"COLUMN_NEGATIVE_TICK"
2458: const REFUSE_COLUMN_REF_SHAPE: StringName = &"COLUMN_REF_SHAPE"
2459: const REFUSE_COLUMN_DIRECTORY_REF: StringName = &"COLUMN_DIRECTORY_REF"
2460: const REFUSE_COLUMN_FREE_JOB_ROW: StringName = &"COLUMN_FREE_JOB_ROW"
2461: const REFUSE_COLUMN_FREE_AGENT_ROW: StringName = &"COLUMN_FREE_AGENT_ROW"
2462: const REFUSE_COLUMN_AGENT_RESIDENT: StringName = &"COLUMN_AGENT_RESIDENT"
2463: const REFUSE_COLUMN_RESERVED_NONZERO: StringName = &"COLUMN_RESERVED_NONZERO"
2464: const REFUSE_COLUMN_CONTINUATION: StringName = &"COLUMN_CONTINUATION"
2465: const REFUSE_COLUMN_WORKER_BINDING: StringName = &"COLUMN_WORKER_BINDING"
2466: const REFUSE_COLUMN_COORDINATOR: StringName = &"COLUMN_COORDINATOR"
2467: const REFUSE_COLUMN_MEMBER_CHAIN: StringName = &"COLUMN_MEMBER_CHAIN"
2622: 
2623: 
2624: func copy_columns_into(out: Columns) -> bool:
2625: 	"""Copy the forty-two §4 and §5 category-1 columns into caller-owned buffers. False refuses.
2626: 
2627: 	The capture step for both sections, and the ONLY way to read a released Job or JobAgent row's
2628: 	retained bytes: every reader here refuses a row whose occupancy byte is 0.
2629: 
2630: 	The copies are snapshots; mutating `out` afterwards cannot reach a column.
2631: 	"""
2632: 	if not _columns_are_capacity_sized(out):
2633: 		_last_column_refusal = REFUSE_COLUMN_SHAPE
2634: 		return false
2635: 	_copy_job_columns_into(out)
2636: 	_copy_agent_columns_into(out)
2637: 	_refill_i32(out.coordinator_slot, _coordinator_slot)
2638: 	_refill_i32(out.coordinator_generation, _coordinator_generation)
2639: 	_refill_i32(out.member_head, _member_head)
2640: 	_refill_i32(out.member_next, _member_next)
2641: 	_last_column_refusal = REFUSE_NONE
2642: 	return true
2643: 
2644: 
2689: 
2690: 
2691: func restore_columns(columns: Columns) -> bool:
2692: 	"""Replace all forty-two columns and rebuild every derived index. False refuses.
2693: 
2694: 	The apply step for sections 4 and 5 together. The store becomes the world these columns
2695: 	describe; a job slot taken before the call belongs to a different world.
2696: 
2697: 	REBUILT, NEVER READ FROM THE CALLER: `_job_persistent_id` and `_agent_persistent_id` come back
2698: 	from §3 through the directory and the resident store, `_live_slots` and `_bucket_begin` are
2699: 	refilled in declared-urgency runs ordered by ascending persistent ID exactly as
2700: 	`_insert_live_slot()` keeps them, and `_live_count`, `_agent_count` and
2701: 	`_deepest_continuation_bucket` are recounted.
2702: 
2703: 	THE REBUILD IS A VALIDATOR, not a repair. A live Job row's `(_job_ref_slot,
2704: 	_job_ref_generation)` must resolve through the directory to a live KIND_JOB slot whose typed
2705: 	row is this row: a directory slot owns exactly one typed row, so two Job rows claiming one
2706: 	slot cannot both satisfy it and neither can a row the directory has forgotten. The worker
2707: 	binding is checked in BOTH directions, because a job naming a worker who does not hold it and
2708: 	an agent holding a job that does not name it are different corruptions and one does not imply
2709: 	the other.
2710: 
2711: 	Allocate before consume (decision 0059): every rule is checked before the first write, so a
2712: 	refusal leaves the store byte-identical and `state_bytes()` proves it by comparison.
2713: 	"""
2714: 	var refusal: StringName = _restore_column_refusal(columns)
2715: 	if refusal != REFUSE_NONE:
2716: 		_last_column_refusal = refusal
2717: 		return false
2718: 	_install_columns(columns)
2719: 	_rebuild_indexes()
2720: 	_last_column_refusal = REFUSE_NONE
2721: 	return true
2722: 
2723: 
2851: 
2852: 
2853: func _free_job_row_is_clear(columns: Columns, slot: int) -> bool:
2854: 	"""True when one released Job row holds no residue of the job that last occupied it."""
2855: 	if columns.kind[slot] != JOB_KIND_HAUL or columns.priority[slot] != 0:
2856: 		return false
2857: 	if columns.required_skill[slot] != 0 or columns.state[slot] != JOB_STATE_QUEUED:
2858: 		return false
2859: 	if columns.remaining_mwu[slot] != 0 or columns.created_tick[slot] != 0:
2860: 		return false
2861: 	if columns.urgency[slot] != URGENCY_ORDINARY or columns.dangerous[slot] != 0:
2862: 		return false
2863: 	if columns.station_gate[slot] != GATE_NOT_REQUIRED:
2864: 		return false
2865: 	if columns.tool_gate[slot] != GATE_NOT_REQUIRED:
2866: 		return false
2867: 	if columns.unlock_gate[slot] != GATE_NOT_REQUIRED:
2868: 		return false
2869: 	if columns.inputs_gate[slot] != GATE_NOT_REQUIRED:
2870: 		return false
2871: 	if columns.is_coordinator[slot] != 0:
2872: 		return false
2873: 	if columns.member_head[slot] != EntityDirectory.NULL_SLOT:
2874: 		return false
2875: 	if columns.member_next[slot] != EntityDirectory.NULL_SLOT:
2876: 		return false
2877: 	return _free_job_references_are_null(columns, slot)
2878: 
2879: 
2880: func _free_job_references_are_null(columns: Columns, slot: int) -> bool:
2881: 	"""True when all six of a released Job row's reference pairs are the §4.1 null pair."""
2882: 	if columns.coordinator_slot[slot] != EntityDirectory.NULL_SLOT:
2883: 		return false
2884: 	if columns.coordinator_generation[slot] != EntityDirectory.NULL_GENERATION:
2885: 		return false
2886: 	if columns.job_ref_slot[slot] != EntityDirectory.NULL_SLOT:
2887: 		return false
2888: 	if columns.job_ref_generation[slot] != EntityDirectory.NULL_GENERATION:
2889: 		return false
2890: 	if columns.requester_slot[slot] != EntityDirectory.NULL_SLOT:
2891: 		return false
2892: 	if columns.destination_slot[slot] != EntityDirectory.NULL_SLOT:
2893: 		return false
2894: 	if columns.source_slot[slot] != EntityDirectory.NULL_SLOT:
2895: 		return false
2896: 	return columns.worker_slot[slot] == EntityDirectory.NULL_SLOT
2897: 
2898: 
2991: 
2992: 
2993: func _free_agent_row_is_clear(columns: Columns, slot: int) -> bool:
2994: 	"""True when one released JobAgent row holds exactly what `_clear_agent_row()` leaves."""
2995: 	if columns.agent_job_slot[slot] != EntityDirectory.NULL_SLOT:
2996: 		return false
2997: 	if columns.agent_job_generation[slot] != EntityDirectory.NULL_GENERATION:
2998: 		return false
2999: 	if columns.agent_target_slot[slot] != EntityDirectory.NULL_SLOT:
3000: 		return false
3001: 	if columns.agent_target_generation[slot] != EntityDirectory.NULL_GENERATION:
3002: 		return false
3003: 	if columns.agent_phase[slot] != 0 or columns.agent_path_id[slot] != 0:
3004: 		return false
3005: 	if columns.agent_path_cursor[slot] != 0 or columns.agent_lease_expiry[slot] != 0:
3006: 		return false
3007: 	if columns.agent_blocked_tick[slot] != 0 or columns.agent_manual_until[slot] != 0:
3008: 		return false
3009: 	if columns.job_scan_cursor[slot] != 0 or columns.continuation_bucket[slot] != 0:
3010: 		return false
3011: 	return columns.agent_hazard_locked[slot] == 0
3012: 
3013: 

# godot/scripts/core/orchard_hive.gd
170: ##     cross-process round trip is blocked on that work, exactly as in `gear.gd`.
171: 
172: const IntMath := preload("res://scripts/core/int_math.gd")
173: const Catalog := preload("res://scripts/core/catalog.gd")
174: const SimClock := preload("res://scripts/core/sim_clock.gd")
175: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
176: const Farming := preload("res://scripts/core/farming.gd")
177: const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")
179: # --- GDD §4.3 enums, read from catalog.gd's protected table (decision 0018) ----------------------
180: 
181: const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
182: const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
183: const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
184: const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
185: const SEASON_COUNT: int = 4
187: # --- calendar, from sim_clock.gd rather than mirrored -------------------------------------------
188: 
189: const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
190: const DAYS_PER_YEAR: int = SimClock.DAYS_PER_YEAR
191: const SEASONS_PER_YEAR: int = SimClock.SEASONS_PER_YEAR
192: const TICKS_PER_DAY: int = SimClock.TICKS_PER_DAY
193: const FIRST_SEASON_DAY: int = 1
194: const FIRST_YEAR: int = 1
195: ## §5.1 starts the calendar at day 1, so day 0 names no day and is refused, not stored.
196: const MIN_CALENDAR_DAY: int = 1
198: # --- exterior grid geometry, from resource_nodes.gd rather than mirrored ------------------------
199: 
200: const MAP_TILES_X: int = ResourceNodes.MAP_TILES_X
201: const MAP_TILES_Z: int = ResourceNodes.MAP_TILES_Z
202: const TILE_SIZE_UNITS: int = ResourceNodes.TILE_SIZE_UNITS
203: ## Ruling §3's `(min + max + 1) * 1024`: half a tile, and GDD §5.1's own centre offset.
204: const TILE_HALF_UNITS: int = ResourceNodes.TILE_CENTER_OFFSET_UNITS
205: ## Largest footprint-centre coordinate the 128x128 grid can produce, `(127 + 127 + 1) * 1024`.
206: const MAX_CENTER_UNITS: int = (2 * (MAP_TILES_X - 1) + 1) * TILE_HALF_UNITS
209: 
210: ## GDD §4.2 "One per 4x4 farm-tile orchard block"; ARCH-MEM-003 "Orchard blocks <= 16384/16=1024".
211: const ORCHARD_CAPACITY: int = 1024
212: ## GDD §4.2 "One per apiary".
213: const HIVE_CAPACITY: int = 1024
214: 
215: const NULL_SLOT: int = EntityDirectory.NULL_SLOT
216: const NULL_GENERATION: int = EntityDirectory.NULL_GENERATION
217: const NULL_REF: Vector2i = EntityDirectory.NULL_REF
218: const NO_ROW: int = EntityDirectory.NULL_SLOT
219: ## §4.2: "empty catalog IDs are -1".
220: const SPECIES_NONE: int = -1
221: ## Day 0 names no day, so it is "never serviced".
222: const NO_SERVICE_DAY: int = 0
226: ## §4.3's ASCII-key rule numbers this domain: apple 0, pear 1. `_init()` compiles the keys through
227: ## catalog.gd rather than trusting the ordinals written here.
228: const SPECIES_KEYS: Array[StringName] = [&"apple", &"pear"]
229: const SPECIES_APPLE: int = 0
230: const SPECIES_PEAR: int = 1
231: const SPECIES_COUNT: int = 2
232: const SPECIES_DOMAIN: String = "OrchardSpecies"
233: 
234: ## §5.6: "Block | 4x4 tiles" for both species.
235: const BLOCK_SIZE: int = 4
236: const BLOCK_TILE_COUNT: int = BLOCK_SIZE * BLOCK_SIZE
237: ## §5.6's "Maturity" column: apple 96 days, pear 144 days.
238: const SPECIES_MATURITY_DAYS: Array[int] = [96, 144]
239: ## §5.6's "Yield/mature tree/year" column in milli-units: apple 80 fruit U, pear 110 fruit U.
240: const SPECIES_YIELD_MILLI: Array[int] = [80000, 110000]
241: ## §5.6's "Harvest" column: apple Autumn 1-6, pear Autumn 3-8. Inclusive season-local days.
242: const SPECIES_HARVEST_SEASON: int = SEASON_AUTUMN
243: const SPECIES_HARVEST_FIRST_DAY: Array[int] = [1, 3]
244: const SPECIES_HARVEST_LAST_DAY: Array[int] = [6, 8]
245: ## §5.6's "Plant cost/block" column: sapling_apple/sapling_pear 1, compost 4.
246: const SPECIES_SAPLING_ITEM_KEYS: Array[StringName] = [&"sapling_apple", &"sapling_pear"]
247: const PLANT_SAPLING_MILLI: int = 1000
248: const PLANT_COMPOST_MILLI: int = 4000
249: ## §5.6's "Care" column: "20 WU/day in spring/summer; water 2 U/day during drought", both species.
250: const CARE_WORK_MILLI_WU: int = 20000
251: const CARE_DROUGHT_WATER_MILLI: int = 2000
252: ## §5.6: "Untended spring/summer days remove 100 health; tended days restore 50, max 10000."
253: const UNTENDED_HEALTH_LOSS: int = 100
254: const TENDED_HEALTH_GAIN: int = 50
255: ## The 0-10000 scale `farming.gd` already carries for crop health, read from it, not copied.
256: const HEALTH_MIN: int = Farming.HEALTH_MIN
257: const HEALTH_MAX: int = Farming.HEALTH_MAX
258: const HEALTH_FACTOR_DENOMINATOR: int = Farming.HEALTH_MAX
259: ## §5.6: "Winter chill counter increments per day with temperature<=5degC; fewer than 6 chill days
260: ## in the previous winter gives 75% yield." Tenths, because that is what §4.2 stores.
261: const CHILL_TEMPERATURE_MAX_TENTHS: int = 50
262: const CHILL_DAYS_REQUIRED: int = 6
263: const CHILL_FACTOR_FULL: int = 100
264: const CHILL_FACTOR_LOW: int = 75
265: const CHILL_FACTOR_DENOMINATOR: int = 100
266: ## §5.6: "Orchard removal yields wood 8 and no refunded sapling."
267: const REMOVAL_WOOD_MILLI: int = 8000
268: ## §5.6: "Saplings are propagated at a nursery for fruit 4 + compost 2 + water 2, 120 WU plus
269: ## 12-day wait". Transcribed; the nursery RECIPE belongs to §5.7 production, not to this store.
270: const NURSERY_FRUIT_MILLI: int = 4000
271: const NURSERY_COMPOST_MILLI: int = 2000
272: const NURSERY_WATER_MILLI: int = 2000
273: const NURSERY_WORK_MILLI_WU: int = 120000
274: const NURSERY_WAIT_DAYS: int = 12
275: ## §5.6: "the first two saplings of each type arrive with milestone M3". Progression is §5.12's.
276: const MILESTONE_STARTER_SAPLINGS: int = 2
279: 
280: ## "Hive strength starts 8000, healthy>=5000." The 0..10000 clamp is an interpretation; see header.
281: const HIVE_INITIAL_STRENGTH: int = 8000
282: const HIVE_HEALTHY_STRENGTH: int = 5000
283: const HIVE_STRENGTH_MIN: int = 0
284: const HIVE_STRENGTH_MAX: int = 10000
285: const HIVE_STRENGTH_DENOMINATOR: int = 10000
286: ## "a tended hive produces honey 2 U + wax 0.25 U/day x strength/10000; service is 20 WU/day".
287: const HIVE_HONEY_MILLI_PER_DAY: int = 2000
288: const HIVE_WAX_MILLI_PER_DAY: int = 250
289: const HIVE_SERVICE_WORK_MILLI_WU: int = 20000
290: ## "Winter produces 0 and consumes honey 0.5 U/day. Missing winter feed removes 500 strength/day".
291: const HIVE_WINTER_FEED_MILLI_PER_DAY: int = 500
292: const HIVE_MISSING_FEED_STRENGTH_LOSS: int = 500
293: ## "a missed service day in spring/summer/autumn removes 200 strength and produces no honey/wax".
294: const HIVE_MISSED_SERVICE_STRENGTH_LOSS: int = 200
295: ## "tended spring days with strength>0 restore 300 after production".
296: const HIVE_TENDED_SPRING_STRENGTH_GAIN: int = 300
297: ## "can be recolonized in spring with honey 4, wood 2, 60 WU and a 3-day wait".
298: const HIVE_RECOLONIZE_HONEY_MILLI: int = 4000
299: const HIVE_RECOLONIZE_WOOD_MILLI: int = 2000
300: const HIVE_RECOLONIZE_WORK_MILLI_WU: int = 60000
301: const HIVE_RECOLONIZE_WAIT_DAYS: int = 3
302: ## Item keys §5.6 names for hive produce and feed. Compiled ids are `item_definitions.gd`'s.
303: const HONEY_ITEM_KEY: StringName = &"honey"
304: const WAX_ITEM_KEY: StringName = &"wax"
305: const FRUIT_ITEM_KEY: StringName = &"fruit"
306: const WOOD_ITEM_KEY: StringName = &"wood"
307: const COMPOST_ITEM_KEY: StringName = &"compost"
308: const WATER_ITEM_KEY: StringName = &"water"
311: 
312: ## `recipient_index(FarmPlot typed row p) = p`, so the farm block is exactly FarmPlot's capacity.
313: const FARM_RECIPIENT_CAPACITY: int = Farming.FARM_PLOT_CAPACITY
314: ## `recipient_index(OrchardPlot typed row o) = 4096 + o`.
315: const ORCHARD_RECIPIENT_BASE: int = FARM_RECIPIENT_CAPACITY
316: const RECIPIENT_CAPACITY: int = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY
317: ## "one fixed six-reference slice per recipient".
318: const LINKS_PER_RECIPIENT: int = 6
319: const LINK_CAPACITY: int = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT
320: ## Ruling §3's stated payload: two I32 columns of 30720.
321: const LINK_COLUMN_COUNT: int = 2
322: const LINK_BYTES_PER_ENTRY: int = 4
323: const LINK_PAYLOAD_BYTES: int = LINK_CAPACITY * LINK_COLUMN_COUNT * LINK_BYTES_PER_ENTRY
324: ## The shipped table this replaces, and the delta the architecture ledger moves by.
325: const LEGACY_LINK_CAPACITY: int = 24576
326: const LEGACY_LINK_PAYLOAD_BYTES: int = 196608
327: const LINK_PAYLOAD_DELTA_BYTES: int = LINK_PAYLOAD_BYTES - LEGACY_LINK_PAYLOAD_BYTES
328: ## Ruling §3's scratch budget: I64[6] + I32[6] + I32[6] + I32[6], counted separately.
329: const CANDIDATE_SCRATCH_BYTES: int = 6 * 8 + 6 * 4 + 6 * 4 + 6 * 4
330: 
331: ## "inclusive 12 m at 1024 units/m" and its square. Both are stated; `_init()` checks they agree.
332: const POLLINATION_RANGE_UNITS: int = 12288
333: const POLLINATION_RANGE_SQUARED: int = 150994944
335: ## §5.6: "Pollination factor is 1100 for beans and orchard fruit with one healthy hive within
336: ## 12 m, 1150 with two; other crops 1000." Ruling §3: "Further hives add no yield."
337: const POLLINATION_FACTOR_NEUTRAL: int = Farming.POLLINATION_FACTOR_NEUTRAL
338: const POLLINATION_FACTOR_ONE_HIVE: int = 1100
339: const POLLINATION_FACTOR_TWO_HIVES: int = 1150
340: const POLLINATION_FACTOR_DENOMINATOR: int = 1000
341: ## The one crop §5.6 pollinates. Read from `farming.gd`'s compiled table, never re-derived here.
342: const POLLINATED_CROP_ID: int = Farming.CROP_BEANS
344: # --- refusal codes -------------------------------------------------------------------------------
345: 
346: const REFUSE_NONE: StringName = &""
347: const REFUSE_INVALID_SPECIES: StringName = &"INVALID_SPECIES"
348: const REFUSE_INVALID_DAY: StringName = &"INVALID_DAY"
349: const REFUSE_INVALID_BLOCK: StringName = &"INVALID_BLOCK"
350: const REFUSE_BLOCK_OCCUPIED: StringName = &"BLOCK_OCCUPIED"
351: const REFUSE_INVALID_FOOTPRINT: StringName = &"INVALID_FOOTPRINT"
352: const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
353: const REFUSE_INVALID_ROW: StringName = &"INVALID_ROW"
354: const REFUSE_INVALID_LINK_INDEX: StringName = &"INVALID_LINK_INDEX"
355: const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
356: const REFUSE_INVALID_CROP: StringName = &"INVALID_CROP"
357: const REFUSE_INVALID_STATE_IMAGE: StringName = &"INVALID_STATE_IMAGE"
358: const REFUSE_ORCHARD_NOT_PRESENT: StringName = &"ORCHARD_NOT_PRESENT"
359: const REFUSE_HIVE_NOT_PRESENT: StringName = &"HIVE_NOT_PRESENT"
360: const REFUSE_BUILDING_NOT_PRESENT: StringName = &"BUILDING_NOT_PRESENT"
361: const REFUSE_NOT_MATURE: StringName = &"ORCHARD_NOT_MATURE"
362: const REFUSE_OUTSIDE_HARVEST_WINDOW: StringName = &"OUTSIDE_HARVEST_WINDOW"
363: const REFUSE_ALREADY_HARVESTED_THIS_YEAR: StringName = &"ALREADY_HARVESTED_THIS_YEAR"
364: const REFUSE_HIVE_ABANDONED: StringName = &"HIVE_ABANDONED"
365: const REFUSE_HIVE_NOT_ABANDONED: StringName = &"HIVE_NOT_ABANDONED"
366: const REFUSE_NOT_SPRING: StringName = &"NOT_SPRING"
367: ## Ruling §3: a yield or UI read never repairs links, so a stale or duplicated slice refuses.
368: const REFUSE_LINKS_STALE: StringName = &"POLLINATION_LINKS_STALE"
369: const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
493: # --- collaborators --------------------------------------------------------------------------------
494: 
495: var _directory: EntityDirectory = null
496: var _owns_directory: bool = false
498: # --- §4.2 OrchardPlot columns ----------------------------------------------------------------------
499: 
500: var _o_present: PackedByteArray = PackedByteArray()
501: var _o_species_id: PackedInt32Array = PackedInt32Array()
502: var _o_age_days: PackedInt32Array = PackedInt32Array()
503: var _o_health: PackedInt32Array = PackedInt32Array()
504: var _o_chill_days: PackedInt32Array = PackedInt32Array()
505: var _o_tended_today: PackedByteArray = PackedByteArray()
506: var _o_harvested_year: PackedByteArray = PackedByteArray()
507: ## ADDED: the block's minimum tile, the inverse of TileHistory.orchard_row. See the header.
508: var _o_origin_x: PackedInt32Array = PackedInt32Array()
509: var _o_origin_z: PackedInt32Array = PackedInt32Array()
510: var _o_ref_slot: PackedInt32Array = PackedInt32Array()
511: var _o_ref_generation: PackedInt32Array = PackedInt32Array()
512: var _o_live_slots: PackedInt32Array = PackedInt32Array()
513: var _o_live_count: int = 0
515: # --- §4.2 Hive columns -----------------------------------------------------------------------------
516: 
517: var _h_present: PackedByteArray = PackedByteArray()
518: var _h_building_slot: PackedInt32Array = PackedInt32Array()
519: var _h_building_generation: PackedInt32Array = PackedInt32Array()
520: var _h_strength: PackedInt32Array = PackedInt32Array()
521: var _h_serviced_day: PackedInt32Array = PackedInt32Array()
522: var _h_feed_milli: PackedInt64Array = PackedInt64Array()
523: var _h_honey_milli: PackedInt64Array = PackedInt64Array()
524: var _h_wax_milli: PackedInt64Array = PackedInt64Array()
525: ## ADDED: the apiary footprint bounds. There is no Building store; see the header.
526: var _h_min_tile_x: PackedInt32Array = PackedInt32Array()
527: var _h_min_tile_z: PackedInt32Array = PackedInt32Array()
528: var _h_max_tile_x: PackedInt32Array = PackedInt32Array()
529: var _h_max_tile_z: PackedInt32Array = PackedInt32Array()
530: var _h_ref_slot: PackedInt32Array = PackedInt32Array()
531: var _h_ref_generation: PackedInt32Array = PackedInt32Array()
532: var _h_live_slots: PackedInt32Array = PackedInt32Array()
533: var _h_live_count: int = 0
535: # --- HivePollinationLinks columns (ruling §3) --------------------------------------------------------
536: 
537: var _link_hive_slot: PackedInt32Array = PackedInt32Array()
538: var _link_hive_generation: PackedInt32Array = PackedInt32Array()
540: # --- scratch (not simulation state; 120 bytes, ruling §3) ----------------------------------------------
541: 
542: var _cand_distance: PackedInt64Array = PackedInt64Array()
543: var _cand_persistent_id: PackedInt32Array = PackedInt32Array()
544: var _cand_slot: PackedInt32Array = PackedInt32Array()
545: var _cand_generation: PackedInt32Array = PackedInt32Array()
546: var _cand_count: int = 0
548: ## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
549: ## signal, so no public operation can re-enter while it holds a live value.
550: var _math: IntMath.IntResult = IntMath.IntResult.new()
668: 
669: 
670: func _allocate_columns() -> void:
671: 	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
672: 	_allocate_orchard_columns()
673: 	_allocate_hive_columns()
674: 	_link_hive_slot.resize(LINK_CAPACITY)
675: 	_link_hive_generation.resize(LINK_CAPACITY)
676: 	_cand_distance.resize(LINKS_PER_RECIPIENT)
677: 	_cand_persistent_id.resize(LINKS_PER_RECIPIENT)
678: 	_cand_slot.resize(LINKS_PER_RECIPIENT)
679: 	_cand_generation.resize(LINKS_PER_RECIPIENT)
680: 
681: 
682: func _allocate_orchard_columns() -> void:
683: 	"""Size §4.2's six OrchardPlot columns and the added index columns at 1024 rows."""
684: 	_o_present.resize(ORCHARD_CAPACITY)
685: 	_o_species_id.resize(ORCHARD_CAPACITY)
686: 	_o_age_days.resize(ORCHARD_CAPACITY)
687: 	_o_health.resize(ORCHARD_CAPACITY)
688: 	_o_chill_days.resize(ORCHARD_CAPACITY)
689: 	_o_tended_today.resize(ORCHARD_CAPACITY)
690: 	_o_harvested_year.resize(ORCHARD_CAPACITY)
691: 	_o_origin_x.resize(ORCHARD_CAPACITY)
692: 	_o_origin_z.resize(ORCHARD_CAPACITY)
693: 	_o_ref_slot.resize(ORCHARD_CAPACITY)
694: 	_o_ref_generation.resize(ORCHARD_CAPACITY)
695: 	_o_live_slots.resize(ORCHARD_CAPACITY)
696: 
697: 
698: func _allocate_hive_columns() -> void:
699: 	"""Size §4.2's six Hive fields, the footprint bounds and the added index columns."""
700: 	_h_present.resize(HIVE_CAPACITY)
701: 	_h_building_slot.resize(HIVE_CAPACITY)
702: 	_h_building_generation.resize(HIVE_CAPACITY)
703: 	_h_strength.resize(HIVE_CAPACITY)
704: 	_h_serviced_day.resize(HIVE_CAPACITY)
705: 	_h_feed_milli.resize(HIVE_CAPACITY)
706: 	_h_honey_milli.resize(HIVE_CAPACITY)
707: 	_h_wax_milli.resize(HIVE_CAPACITY)
708: 	_h_min_tile_x.resize(HIVE_CAPACITY)
709: 	_h_min_tile_z.resize(HIVE_CAPACITY)
710: 	_h_max_tile_x.resize(HIVE_CAPACITY)
711: 	_h_max_tile_z.resize(HIVE_CAPACITY)
712: 	_h_ref_slot.resize(HIVE_CAPACITY)
713: 	_h_ref_generation.resize(HIVE_CAPACITY)
714: 	_h_live_slots.resize(HIVE_CAPACITY)
715: 
716: 
717: func clear() -> void:
718: 	"""Return every column to its empty state without reallocating one of them.
719: 
720: 	Every live row's directory slot is released first, so a clear leaks no allocation into a
721: 	directory this store may not own.
722: 	"""
723: 	_release_live_rows()
724: 	_clear_orchard_columns()
725: 	_clear_hive_columns()
726: 	clear_all_links()
727: 	_o_live_count = 0
728: 	_h_live_count = 0
729: 	_cand_count = 0
730: 	if _owns_directory:
731: 		_directory.clear()
732: 
733: 
734: func _clear_orchard_columns() -> void:
735: 	"""Empty every §4.2 OrchardPlot column and the added index columns."""
736: 	_o_present.fill(0)
737: 	_o_species_id.fill(SPECIES_NONE)
738: 	_o_age_days.fill(0)
739: 	_o_health.fill(0)
740: 	_o_chill_days.fill(0)
741: 	_o_tended_today.fill(0)
742: 	_o_harvested_year.fill(0)
743: 	_o_origin_x.fill(NO_ROW)
744: 	_o_origin_z.fill(NO_ROW)
745: 	_o_ref_slot.fill(NULL_SLOT)
746: 	_o_ref_generation.fill(NULL_GENERATION)
747: 	_o_live_slots.fill(NULL_SLOT)
748: 
749: 
750: func _clear_hive_columns() -> void:
751: 	"""Empty every §4.2 Hive column, the footprint bounds and the added index columns."""
752: 	_h_present.fill(0)
753: 	_h_building_slot.fill(NULL_SLOT)
754: 	_h_building_generation.fill(NULL_GENERATION)
755: 	_h_strength.fill(0)
756: 	_h_serviced_day.fill(NO_SERVICE_DAY)
757: 	_h_feed_milli.fill(0)
758: 	_h_honey_milli.fill(0)
759: 	_h_wax_milli.fill(0)
760: 	_h_min_tile_x.fill(NO_ROW)
761: 	_h_min_tile_z.fill(NO_ROW)
762: 	_h_max_tile_x.fill(NO_ROW)
763: 	_h_max_tile_z.fill(NO_ROW)
764: 	_h_ref_slot.fill(NULL_SLOT)
765: 	_h_ref_generation.fill(NULL_GENERATION)
766: 	_h_live_slots.fill(NULL_SLOT)
767: 
768: 
1139: 
1140: 
1141: func _clear_slice(recipient: int) -> void:
1142: 	"""Null every entry of one recipient's slice. The empty reference is `(-1, 0)`."""
1143: 	var base: int = _link_row(recipient, 0)
1144: 	for link_index: int in LINKS_PER_RECIPIENT:
1145: 		_link_hive_slot[base + link_index] = NULL_SLOT
1146: 		_link_hive_generation[base + link_index] = NULL_GENERATION
1147: 
1148: 
1149: # --- ruling §3 refresh, synchronous and caller-committed ------------------------------------------
1150: 
1889: 
1890: 
1891: func restore_orchard_state(orchard_ref: Vector2i, age_days: int, health: int, chill_days: int,
1892: 		tended_today: bool, harvested_year: bool) -> OpResult:
1893: 	"""Write a loaded block's §4.2 state onto a live row, validating every field first.
1894: 
1895: 	The load path, and the only way this store's orchard columns are written other than by the
1896: 	stated §5.6 arithmetic. Refuses the WHOLE restore on any out-of-range field rather than
1897: 	storing a plausible-looking one, so a corrupt image cannot enter the world half-applied.
1898: 	"""
1899: 	var slot: int = _orchard_slot_of(orchard_ref)
1900: 	if slot == NO_ROW:
1901: 		return _refuse(REFUSE_ORCHARD_NOT_PRESENT)
1902: 	if age_days < 0 or not IntMath.fits_int32(age_days):
1903: 		return _refuse(REFUSE_INVALID_AMOUNT)
1904: 	if health < HEALTH_MIN or health > HEALTH_MAX:
1905: 		return _refuse(REFUSE_INVALID_AMOUNT)
1906: 	if chill_days < 0 or chill_days > DAYS_PER_SEASON:
1907: 		return _refuse(REFUSE_INVALID_AMOUNT)
1908: 	_o_age_days[slot] = age_days
1909: 	_o_health[slot] = health
1910: 	_o_chill_days[slot] = chill_days
1911: 	_o_tended_today[slot] = 1 if tended_today else 0
1912: 	_o_harvested_year[slot] = 1 if harvested_year else 0
1913: 	return _succeed(slot, orchard_ref)
1914: 
1915: 
1958: 
1959: 
1960: func create_hive(building_ref: Vector2i, min_tile_x: int, min_tile_z: int, max_tile_x: int,
1961: 		max_tile_z: int, day: int) -> OpResult:
1962: 	"""Colonise one apiary's hive at §5.6's starting strength 8000, at a committed footprint.
1963: 
1964: 	THE FOOTPRINT IS A PARAMETER, NOT A LOOKUP. `Hive.building` is an `EntityRef` to a Building
1965: 	and there is no Building store: the bounds of the committed, ROTATED footprint are supplied by
1966: 	whoever committed the placement, exactly as `farming.gd` takes `pollination_factor`. The
1967: 	building reference is validated for liveness and kind through the directory and is never
1968: 	dereferenced. Every live orchard slice is refreshed synchronously, because a new healthy hive
1969: 	changes who is eligible before anything reads a yield.
1970: 	"""
1971: 	if not _directory.is_valid_of_kind(building_ref, EntityDirectory.KIND_BUILDING):
1972: 		return _refuse(REFUSE_BUILDING_NOT_PRESENT)
1973: 	if not is_footprint(min_tile_x, min_tile_z, max_tile_x, max_tile_z):
1974: 		return _refuse(REFUSE_INVALID_FOOTPRINT)
1975: 	if not is_calendar_day(day):
1976: 		return _refuse(REFUSE_INVALID_DAY)
1977: 	var ref: Vector2i = _directory.create(EntityDirectory.KIND_HIVE)
1978: 	if ref == NULL_REF:
1979: 		return _refuse(_directory.last_refusal())
1980: 	var slot: int = _directory.get_typed_row(ref)
1981: 	_write_created_hive(slot, ref, building_ref, min_tile_x, min_tile_z, max_tile_x, max_tile_z, day)
1982: 	refresh_all_orchard_links()
1983: 	return _succeed(slot, ref)
1984: 
1985: 
2004: 
2005: 
2006: func destroy_hive(hive_ref: Vector2i) -> OpResult:
2007: 	"""Remove one hive and release its directory slot, refreshing every orchard slice after it.
2008: 
2009: 	The refresh is what makes ruling §3's "removing a cached hive discovers a previously seventh
2010: 	candidate" true for orchard recipients without a reverse index. FARM recipients are the
2011: 	caller's to refresh; see the header.
2012: 	"""
2013: 	var slot: int = _hive_slot_of(hive_ref)
2014: 	if slot == NO_ROW:
2015: 		return _refuse(REFUSE_HIVE_NOT_PRESENT)
2016: 	_h_present[slot] = 0
2017: 	_h_building_slot[slot] = NULL_SLOT
2018: 	_h_building_generation[slot] = NULL_GENERATION
2019: 	_h_strength[slot] = 0
2020: 	_h_serviced_day[slot] = NO_SERVICE_DAY
2021: 	_h_feed_milli[slot] = 0
2022: 	_h_honey_milli[slot] = 0
2023: 	_h_wax_milli[slot] = 0
2024: 	_h_min_tile_x[slot] = NO_ROW
2025: 	_h_min_tile_z[slot] = NO_ROW
2026: 	_h_max_tile_x[slot] = NO_ROW
2027: 	_h_max_tile_z[slot] = NO_ROW
2028: 	_h_ref_slot[slot] = NULL_SLOT
2029: 	_h_ref_generation[slot] = NULL_GENERATION
2030: 	_remove_live_hive(slot)
2031: 	_directory.destroy(hive_ref)
2032: 	refresh_all_orchard_links()
2033: 	return _succeed(slot, NULL_REF)
2034: 
2035: 
2389: 
2390: 
2391: func restore_hive_state(hive_ref: Vector2i, strength: int, feed_milli: int, honey_milli: int,
2392: 		wax_milli: int, serviced_day: int) -> OpResult:
2393: 	"""Write a loaded hive's §4.2 state onto a live row, validating every field first.
2394: 
2395: 	The load path, and the only writer of `strength` outside §5.6's own arithmetic. Refuses the
2396: 	WHOLE restore on any out-of-range field. An eligibility crossing refreshes the orchard slices,
2397: 	so a load cannot leave a slice describing a hive the restored strength no longer qualifies.
2398: 	"""
2399: 	var slot: int = _hive_slot_of(hive_ref)
2400: 	if slot == NO_ROW:
2401: 		return _refuse(REFUSE_HIVE_NOT_PRESENT)
2402: 	if strength < HIVE_STRENGTH_MIN or strength > HIVE_STRENGTH_MAX:
2403: 		return _refuse(REFUSE_INVALID_AMOUNT)
2404: 	if feed_milli < 0 or honey_milli < 0 or wax_milli < 0:
2405: 		return _refuse(REFUSE_INVALID_AMOUNT)
2406: 	if serviced_day < NO_SERVICE_DAY or not IntMath.fits_int32(serviced_day):
2407: 		return _refuse(REFUSE_INVALID_DAY)
2408: 	_h_feed_milli[slot] = feed_milli
2409: 	_h_honey_milli[slot] = honey_milli
2410: 	_h_wax_milli[slot] = wax_milli
2411: 	_h_serviced_day[slot] = serviced_day
2412: 	_write_hive_strength(slot, strength)
2413: 	return _succeed(_h_strength[slot], hive_ref)
2414: 
2415: 
2416: # --- ruling §3 serialization and the load-time canonical check -------------------------------------------------
2417: 
2433: 
2434: 
2435: func restore_links_from_state(state: PackedByteArray) -> OpResult:
2436: 	"""Load an image written by `link_state_bytes()` back into the link columns.
2437: 
2438: 	Structure only: the references are written as recorded and are NOT trusted. Ruling §3 requires
2439: 	them to be validated or recomputed against the canonical selection before a yield is applied,
2440: 	which is `revalidate_orchard_links_after_load()` and `revalidate_farm_links_after_load()`.
2441: 	A malformed image refuses whole and writes nothing.
2442: 	"""
2443: 	var decoded: Variant = bytes_to_var(state)
2444: 	if typeof(decoded) != TYPE_PACKED_INT32_ARRAY:
2445: 		return _refuse(REFUSE_INVALID_STATE_IMAGE)
2446: 	var image: PackedInt32Array = decoded
2447: 	if image.size() != LINK_CAPACITY * LINK_COLUMN_COUNT:
2448: 		return _refuse(REFUSE_INVALID_STATE_IMAGE)
2449: 	for row: int in LINK_CAPACITY:
2450: 		_link_hive_slot[row] = image[row * LINK_COLUMN_COUNT]
2451: 		_link_hive_generation[row] = image[row * LINK_COLUMN_COUNT + 1]
2452: 	return _succeed(LINK_CAPACITY, NULL_REF)
2453: 
2454: 

# godot/scripts/core/residents.gd
104: ## bytes these columns travel as.
105: 
106: const IntMath := preload("res://scripts/core/int_math.gd")
107: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
108: const NeedsScript := preload("res://scripts/core/needs.gd")
109: const Catalog := preload("res://scripts/core/catalog.gd")
110: 
111: ## Resident typed rows, GDD §4.1: storage 512, living population never above 256.
112: const RESIDENT_CAPACITY: int = 512
113: const RESIDENT_LIVING_CAP: int = 256
115: # --- species catalog, GDD §4.3 --------------------------------------------------------------
116: 
117: const SPECIES_DOMAIN: String = "SpeciesDefinition"
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
133: ## The whole stage domain. Fixed and bounded, never an open enum: MOVE-DEP-R02 states the
134: ## encoding is stable and that COUNT "is a bound, never a stored stage".
135: const LIFE_STAGE_ADULT: int = 0
136: const LIFE_STAGE_CHILD: int = 1
137: const LIFE_STAGE_ELDER: int = 2
138: const LIFE_STAGE_COUNT: int = 3
140: ## Display/report names, indexed by the stage value. NOT a compiled catalog domain: §4.3 numbers
141: ## this enum explicitly, so it is protected data and must never be renumbered from key order.
142: const LIFE_STAGE_KEYS: Array[StringName] = [&"ADULT", &"CHILD", &"ELDER"]
144: # --- logical rig identity, MOVE-DEP-R03 -----------------------------------------------------
145: 
146: const RIG_DOMAIN: String = "RigDefinition"
148: ## MOVE-DEP-R03's table verbatim, one logical base/adult rig key per §4.3 species key. These are
149: ## identities, not assets: none of the sixteen is claimed to have a skeleton or a clip.
150: const SPECIES_RIG_KEY: Dictionary = {
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
184: ## The large movement cap is genuinely below the medium one in the specification; it is copied,
185: ## not corrected.
186: const SIZE_CARRY_G: Array[int] = [12000, 16000, 24000]
187: const SIZE_MOVEMENT_U_PER_S: Array[int] = [3277, 4096, 3072]
190: 
191: ## GDD §4.1: "small resident requires 6000/day at baseline".
192: const BASE_NUTRITION_PER_DAY_NP: int = 6000
193: 
194: ## GDD §5.2 hunger row: "250 x size multiplier; winter x1.20". Non-winter seasons do not scale.
195: const SEASON_MULTIPLIER_WINTER: int = NeedsScript.WINTER_HUNGER_MULTIPLIER
196: const SEASON_MULTIPLIER_DEFAULT: int = NeedsScript.SEASON_DENOMINATOR
197: const SEASON_DENOMINATOR: int = NeedsScript.SEASON_DENOMINATOR
199: ## One divisor for the compound size x season multiplication, applied after both multiplies so
200: ## the §5.2 "compound multipliers are applied in int64 before division" rule holds.
201: const DEMAND_DENOMINATOR: int = SIZE_DENOMINATOR * SEASON_DENOMINATOR
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
221: 
222: ## "12 adults (6 mice, 2 moles, 2 otters, 2 squirrels); IDs 1-12" in the order written.
223: const INITIAL_SPECIES: Array[StringName] = [
225: 	&"mole", &"mole", &"otter", &"otter", &"squirrel", &"squirrel",
226: ]
227: const INITIAL_POPULATION: int = 12
229: ## "ID 1 named Warden Rowan". The localization key format is unspecified, so the authored name
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
260: 
261: ## SAVE-R09-002's S2 answer: at most 128 encoded UTF-8 bytes.
262: const NAME_MAX_UTF8_BYTES: int = 128
263: ## ARCH-SAVE-005: 2-32 UNICODE SCALAR VALUES. Not bytes and not grapheme clusters -- the three
264: ## differ, and NAME-R02 names counting either of the other two as the trap.
265: const NAME_MIN_SCALARS: int = 2
266: const NAME_MAX_SCALARS: int = 32
269: ## control-code predicate, not an unversioned call to an engine Unicode category database", so
270: ## the rule cannot change under this store when an engine upgrade reclassifies anything.
271: const CONTROL_C0_MAX: int = 0x1f
272: const CONTROL_DEL: int = 0x7f
273: const CONTROL_C1_MAX: int = 0x9f
276: ## surrogate block. A code point outside it has no strict UTF-8 encoding at all, so it can never
277: ## reach the save arena and is refused here rather than replaced.
278: const UNICODE_SCALAR_MAX: int = 0x10ffff
279: const SURROGATE_MIN: int = 0xd800
280: const SURROGATE_MAX: int = 0xdfff
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
330: ## GDD §4.2 `Equipment`: four of its five I32 columns at length 512 (`clothing_tier` stays in
331: ## `needs.gd`; see the header). Re-derived by `equipment_payload_bytes()`.
332: const EQUIPMENT_MIRROR_COLUMNS: int = 4
333: const EQUIPMENT_MIRROR_BYTES: int = 4 * EQUIPMENT_MIRROR_COLUMNS * RESIDENT_CAPACITY
334: ## "No tool equipped". A cleared column value, never a refusal channel: `has_equipped_tool()`
335: ## answers the question and every reader is an explicit `_into`/OpResult form.
336: const NO_TOOL_ITEM: int = -1
358: # --- collaborators ---------------------------------------------------------------------------
359: 
360: var _directory: EntityDirectory = null
361: var _needs: NeedsScript = null
362: var _owns_collaborators: bool = false
364: # --- compiled species catalog ----------------------------------------------------------------
365: 
366: var _species_ids: Dictionary = {}
367: var _species_key: PackedStringArray = PackedStringArray()
368: var _species_size: PackedByteArray = PackedByteArray()
369: var _catalog_error: String = ""
379: ## packed `species_id -> rig_id` column would be a third copy of a fact the constant table
380: ## already states, and a renumbering of either domain could then leave it stale.
381: var _rig_ids: Dictionary = {}
382: var _rig_key_table: Array[StringName] = []
383: var _rig_catalog_error: String = ""
385: # --- Resident columns (ARCH-MEM-001: packed, allocated once, indexed by typed row) -----------
386: 
387: var _present: PackedByteArray = PackedByteArray()
388: var _species: PackedInt32Array = PackedInt32Array()
389: var _size_class: PackedByteArray = PackedByteArray()
390: var _named: PackedByteArray = PackedByteArray()
391: ## MOVE-DEP-R02 `Resident.life_stage:B8[512]`. Assigned at creation, never mutated afterwards.
392: var _life_stage: PackedByteArray = PackedByteArray()
393: var _name_key: PackedStringArray = PackedStringArray()
394: var _arrival_tick: PackedInt64Array = PackedInt64Array()
395: var _role: PackedByteArray = PackedByteArray()
396: var _selected: PackedByteArray = PackedByteArray()
397: ## `home` and `bed` EntityRefs, split into slot/generation columns so no Vector2i array exists.
398: var _home_slot: PackedInt32Array = PackedInt32Array()
399: var _home_generation: PackedInt32Array = PackedInt32Array()
400: var _bed_slot: PackedInt32Array = PackedInt32Array()
401: var _bed_generation: PackedInt32Array = PackedInt32Array()
402: ## The directory reference that owns this row, so a row can hand back a validatable ref.
403: var _ref_slot: PackedInt32Array = PackedInt32Array()
404: var _ref_generation: PackedInt32Array = PackedInt32Array()
406: ## GDD §4.2 `Equipment`, minus `clothing_tier` (needs.gd owns it). The tool columns MIRROR the
407: ## authoritative `GearInstance` row in `gear.gd`; the satchel columns are this store's own.
408: var _equip_tool_item_id: PackedInt32Array = PackedInt32Array()
409: var _equip_tool_durability: PackedInt32Array = PackedInt32Array()
410: var _equip_satchel_slot: PackedInt32Array = PackedInt32Array()
411: var _equip_satchel_generation: PackedInt32Array = PackedInt32Array()
412: 
413: ## GDD §4.2 `Skills`: xp int64[12] and level int32[12], resident-major in one 12-wide stripe.
414: var _skill_xp: PackedInt64Array = PackedInt64Array()
415: var _skill_level: PackedInt32Array = PackedInt32Array()
416: 
417: ## Ascending list of spawned rows, so demand iterates the population and not all 512 slots.
418: var _live_slots: PackedInt32Array = PackedInt32Array()
419: var _live_count: int = 0
421: ## Rows created by the in-flight spawn_initial_settlement(), so a mid-cohort refusal can undo
422: ## exactly what that call made and nothing else. Sized once with every other column.
423: var _cohort_slots: PackedInt32Array = PackedInt32Array()
427: ## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or
428: ## signal, so no public operation can re-enter while it holds a live value.
429: var _math: IntMath.IntResult = IntMath.IntResult.new()
431: ## persisted, and excluded from `state_bytes()` so a refusal cannot alter the image that proves
432: ## it changed nothing.
433: var _last_column_refusal: StringName = REFUSE_NONE
517: 
518: 
519: func _allocate_columns() -> void:
520: 	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
521: 	_present.resize(RESIDENT_CAPACITY)
522: 	_species.resize(RESIDENT_CAPACITY)
523: 	_size_class.resize(RESIDENT_CAPACITY)
524: 	_named.resize(RESIDENT_CAPACITY)
525: 	_life_stage.resize(RESIDENT_CAPACITY)
526: 	_name_key.resize(RESIDENT_CAPACITY)
527: 	_arrival_tick.resize(RESIDENT_CAPACITY)
528: 	_role.resize(RESIDENT_CAPACITY)
529: 	_selected.resize(RESIDENT_CAPACITY)
530: 	_home_slot.resize(RESIDENT_CAPACITY)
531: 	_home_generation.resize(RESIDENT_CAPACITY)
532: 	_bed_slot.resize(RESIDENT_CAPACITY)
533: 	_bed_generation.resize(RESIDENT_CAPACITY)
534: 	_ref_slot.resize(RESIDENT_CAPACITY)
535: 	_ref_generation.resize(RESIDENT_CAPACITY)
536: 	_equip_tool_item_id.resize(RESIDENT_CAPACITY)
537: 	_equip_tool_durability.resize(RESIDENT_CAPACITY)
538: 	_equip_satchel_slot.resize(RESIDENT_CAPACITY)
539: 	_equip_satchel_generation.resize(RESIDENT_CAPACITY)
540: 	_skill_xp.resize(RESIDENT_CAPACITY * SKILL_COUNT)
541: 	_skill_level.resize(RESIDENT_CAPACITY * SKILL_COUNT)
542: 	_live_slots.resize(RESIDENT_CAPACITY)
543: 	_cohort_slots.resize(INITIAL_POPULATION)
544: 
545: 
546: func clear() -> void:
547: 	"""Return every column to its empty state without reallocating, and clear collaborators.
548: 
549: 	Only a store that built its own directory and needs clears them; a shared pair belongs to
550: 	its owner and is left alone.
551: 	"""
552: 	_clear_identity_columns()
553: 	_clear_reference_columns()
554: 	_skill_xp.fill(0)
555: 	_skill_level.fill(0)
556: 	_live_slots.fill(EntityDirectory.NULL_SLOT)
557: 	_live_count = 0
558: 	_cohort_slots.fill(EntityDirectory.NULL_SLOT)
559: 	if _owns_collaborators:
560: 		_directory.clear()
561: 		_needs.clear()
562: 
563: 
564: func _clear_identity_columns() -> void:
565: 	"""Reset the per-row identity and classification columns to their empty values.
566: 
567: 	`_life_stage` goes to ADULT because MOVE-DEP-R02 makes 0 the canonical unused value; an
568: 	empty row is still distinguished by `_present`, never by this byte.
569: 	"""
570: 	_present.fill(0)
571: 	_species.fill(0)
572: 	_size_class.fill(SIZE_SMALL)
573: 	_named.fill(0)
574: 	_life_stage.fill(LIFE_STAGE_ADULT)
575: 	_name_key.fill(String(NO_NAME_KEY))
576: 	_arrival_tick.fill(0)
577: 	_role.fill(ROLE_RESIDENT)
578: 	_selected.fill(0)
579: 
580: 
581: func _clear_reference_columns() -> void:
582: 	"""Reset every stored EntityRef pair and the Equipment mirror to null/empty."""
583: 	_home_slot.fill(EntityDirectory.NULL_SLOT)
584: 	_home_generation.fill(EntityDirectory.NULL_GENERATION)
585: 	_bed_slot.fill(EntityDirectory.NULL_SLOT)
586: 	_bed_generation.fill(EntityDirectory.NULL_GENERATION)
587: 	_ref_slot.fill(EntityDirectory.NULL_SLOT)
588: 	_ref_generation.fill(EntityDirectory.NULL_GENERATION)
589: 	_equip_tool_item_id.fill(NO_TOOL_ITEM)
590: 	_equip_tool_durability.fill(0)
591: 	_equip_satchel_slot.fill(EntityDirectory.NULL_SLOT)
592: 	_equip_satchel_generation.fill(EntityDirectory.NULL_GENERATION)
593: 
594: 
595: # --- collaborators and catalog readers -------------------------------------------------------
596: 
1379: 
1380: 
1381: func restore_name(slot: int, named: bool, name_value: StringName) -> OpResult:
1382: 	"""Install a save's `(named, name)` PAIR on one present row without deriving either half.
1383: 
1384: 	NAME-R02's ordering rule, verbatim: "apply names last must not conceal corruption".
1385: 	`set_name()` recomputes `_named` from emptiness, so a save whose section 4 flag and section 14
1386: 	string disagree would be quietly repaired into a self-consistent row and the corruption would
1387: 	never be reported. This entry point takes both halves explicitly, validates the pair against
1388: 	the occupancy table BEFORE it writes a byte, and refuses the disagreement in either
1389: 	direction.
1390: 
1391: 	Restore may install an earlier valid ANONYMOUS snapshot -- `named` false with the empty name
1392: 	-- with no operational naming trigger involved.
1393: 	"""
1394: 	if not is_present(slot):
1395: 		return _refuse(REFUSE_NOT_PRESENT)
1396: 	var invalid: StringName = name_occupancy_refusal(true, named, name_value)
1397: 	if invalid != REFUSE_NONE:
1398: 		return _refuse(invalid)
1399: 	_name_key[slot] = String(name_value)
1400: 	_named[slot] = 1 if named else 0
1401: 	return _succeed(slot, ref_of(slot))
1402: 
1403: 
1576: 
1577: 
1578: func _clear_equipment_row(slot: int) -> void:
1579: 	"""Reset one row's Equipment columns to "nothing equipped, no satchel". Caller bounds `slot`."""
1580: 	_equip_tool_item_id[slot] = NO_TOOL_ITEM
1581: 	_equip_tool_durability[slot] = 0
1582: 	_equip_satchel_slot[slot] = EntityDirectory.NULL_SLOT
1583: 	_equip_satchel_generation[slot] = EntityDirectory.NULL_GENERATION
1584: 
1585: 
1754: # integers happen to match a live directory slot. Lot and route generations do not appear here.
1755: 
1756: const COLUMN_TYPE_U8: int = 0
1757: const COLUMN_TYPE_I32: int = 2
1758: const COLUMN_TYPE_I64: int = 4
1759: 
1760: ## The nineteen §4 category-1 columns in the registry's declared ordinal order.
1761: const COLUMN_COUNT: int = 19
1762: const COLUMN_KEYS: Array[StringName] = [
1766: 	&"_equip_satchel_slot", &"_equip_satchel_generation", &"_skill_xp", &"_skill_level",
1767: ]
1768: const COLUMN_TYPE_CODES: Array[int] = [
1772: 	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I64, COLUMN_TYPE_I32,
1773: ]
1774: const COLUMN_EXTENTS: Array[int] = [
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
1907: 
1908: 
1909: func copy_columns_into(out: Columns) -> bool:
1910: 	"""Copy the nineteen §4 category-1 columns into caller-owned buffers. False refuses.
1911: 
1912: 	Section 4's capture step, and the ONLY way to read a released row's retained species, skills
1913: 	or arrival tick -- `despawn()` leaves those columns at the last tenant's values and every
1914: 	public reader refuses the row. Section 14 captures `_name_key` separately through its own
1915: 	codec; it is not duplicated here.
1916: 
1917: 	The copies are snapshots: mutating `out` afterwards cannot reach a column.
1918: 	"""
1919: 	if not _columns_are_capacity_sized(out):
1920: 		_last_column_refusal = REFUSE_COLUMN_SHAPE
1921: 		return false
1922: 	_refill_bytes(out.present, _present)
1923: 	_refill_bytes(out.size_class, _size_class)
1924: 	_refill_bytes(out.named, _named)
1925: 	_refill_bytes(out.life_stage, _life_stage)
1926: 	_refill_bytes(out.role, _role)
1927: 	_refill_i64(out.arrival_tick, _arrival_tick)
1928: 	_refill_i64(out.skill_xp, _skill_xp)
1929: 	_refill_i32(out.skill_level, _skill_level)
1930: 	_refill_i32(out.species, _species)
1931: 	_copy_reference_columns_into(out)
1932: 	_last_column_refusal = REFUSE_NONE
1933: 	return true
1934: 
1935: 
1948: 
1949: 
1950: func restore_columns(columns: Columns) -> bool:
1951: 	"""Replace the nineteen §4 columns, empty every name, and rebuild the live list. False refuses.
1952: 
1953: 	Section 4's apply step, and it requires SECTION 3 TO HAVE BEEN RESTORED FIRST. Each present
1954: 	row's `(_ref_slot, _ref_generation)` is resolved through the directory and must name a live
1955: 	KIND_RESIDENT slot whose typed row is this row. That resolution IS the rebuild's validator, in
1956: 	the same way the directory's owner map is its own: a directory slot owns exactly one typed
1957: 	row, so two resident rows claiming one slot cannot both satisfy it, and a row whose reference
1958: 	the directory does not honour is refused rather than installed.
1959: 
1960: 	`_live_slots` and `_live_count` are REBUILT ascending from the restored `_present`, never read
1961: 	from the caller. `_name_key` is emptied on every row: the names belong to §14 and a string
1962: 	left over from the previous world would be exactly the concealed corruption NAME-R02 forbids.
1963: 	`_selected` is not touched, being presentation state outside the canonical hash.
1964: 
1965: 	Allocate before consume (decision 0059): every rule is checked before the first write, so a
1966: 	refusal leaves the store byte-identical and `state_bytes()` proves it by comparison.
1967: 	"""
1968: 	var refusal: StringName = _restore_column_refusal(columns)
1969: 	if refusal != REFUSE_NONE:
1970: 		_last_column_refusal = refusal
1971: 		return false
1972: 	_install_columns(columns)
1973: 	_name_key.fill(String(NO_NAME_KEY))
1974: 	_rebuild_live_slots()
1975: 	_last_column_refusal = REFUSE_NONE
1976: 	return true
1977: 
1978: 

# godot/scripts/core/needs.gd
124: ## stays byte-unchanged. Divergences from it are marked `DIVERGENCE:` at each site.
125: 
126: const IntMath := preload("res://scripts/core/int_math.gd")
127: const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
131: ## Rows, one per RESIDENT typed row. _init() asserts this equals the directory's own capacity
132: ## for KIND_RESIDENT rather than duplicating it as an independent number.
133: const RESIDENT_CAPACITY: int = 512
134: ## Living residents never exceed this (GDD §4.1); mirrors EntityDirectory.RESIDENT_LIVING_CAP.
135: const RESIDENT_LIVING_CAP: int = 256
137: # --- fixed-step constants (GDD §5.1 REQ-SET-006) -------------------------------------------
138: 
139: const TICKS_PER_HOUR: int = 750
140: ## Milli-need-points per need point. Rates are quoted per game hour in these units.
141: const MILLI_PER_POINT: int = 1000
142: ## The §5.2 need denominator: 750 ticks/hour * 1000 milli = 750000.
143: const NEED_DENOMINATOR: int = TICKS_PER_HOUR * MILLI_PER_POINT
144: ## GDD §4.2: "health uses 750-tick hourly denominator". Health rates are whole points/hour.
145: const HEALTH_DENOMINATOR: int = TICKS_PER_HOUR
146: ## GDD §5.2: "cold_milli_hours stores 1000 per exposure-hour". Rates are milli-hours/hour.
147: const COLD_DENOMINATOR: int = TICKS_PER_HOUR
148: ## GDD §5.2: cold_hours is the floor/1000 display value of cold_milli_hours.
149: const COLD_MILLI_PER_HOUR_UNIT: int = 1000
151: # --- need identity (GDD §4.2 field order) --------------------------------------------------
152: 
153: const NEED_HUNGER: int = 0
154: const NEED_REST: int = 1
155: const NEED_COMFORT: int = 2
156: const NEED_SOCIAL: int = 3
157: const NEED_PURPOSE: int = 4
158: const NEED_COUNT: int = 5
159: const NEED_KEYS: Array[StringName] = [&"hunger", &"rest", &"comfort", &"social", &"purpose"]
160: 
161: const NEED_MIN: int = 0
162: const NEED_MAX: int = 10000
163: const HEALTH_MIN: int = 0
164: const HEALTH_MAX: int = 100
165: 
166: ## GDD §5.1 initialization contract: all five needs 7500, health 100.
167: const INITIAL_NEED_VALUE: int = 7500
168: const INITIAL_HEALTH: int = 100
171: 
172: ## Hunger 250/hour before the size and winter multipliers.
173: const HUNGER_DECAY_MILLI_PER_HOUR: int = 250 * MILLI_PER_POINT
174: ## Rest 375/hour WHILE AWAKE; §5.2 states there is no awake decay while asleep.
175: const REST_DECAY_MILLI_PER_HOUR: int = 375 * MILLI_PER_POINT
176: const COMFORT_DECAY_MILLI_PER_HOUR: int = 100 * MILLI_PER_POINT
177: const SOCIAL_DECAY_MILLI_PER_HOUR: int = 100 * MILLI_PER_POINT
178: const PURPOSE_DECAY_MILLI_PER_HOUR: int = 75 * MILLI_PER_POINT
180: # --- restoration, per game hour, in milli-need-points (GDD §5.2 table) ----------------------
181: 
182: const REST_RESTORE_BED_MILLI_PER_HOUR: int = 1200 * MILLI_PER_POINT
183: const REST_RESTORE_FLOOR_MILLI_PER_HOUR: int = 750 * MILLI_PER_POINT
184: const COMFORT_RESTORE_HEATED_ROOM_MILLI_PER_HOUR: int = 300 * MILLI_PER_POINT
185: const COMFORT_RESTORE_MILD_OUTDOORS_MILLI_PER_HOUR: int = 100 * MILLI_PER_POINT
186: const SOCIAL_RESTORE_PAIRED_MILLI_PER_HOUR: int = 1200 * MILLI_PER_POINT
187: const PURPOSE_RESTORE_LABOR_MILLI_PER_HOUR: int = 320 * MILLI_PER_POINT
188: const PURPOSE_RESTORE_MENTORING_MILLI_PER_HOUR: int = 400 * MILLI_PER_POINT
189: ## "dining+200 per shared meal" -- an event, not a rate.
190: const SOCIAL_SHARED_MEAL_POINTS: int = 200
197: ## trusting the reading, and _integrate_step() REFUSES a rate outside it rather than
198: ## integrating something it has no overflow proof for.
199: const MAX_RATE_MAGNITUDE: int = 1200 * MILLI_PER_POINT
202: 
203: ## Hunger: "Eat<=3500; urgent<=1500; starving=0".
204: const HUNGER_EAT_THRESHOLD: int = 3500
205: const HUNGER_URGENT_THRESHOLD: int = 1500
206: const HUNGER_STARVING_VALUE: int = 0
207: ## Rest: "Seek sleep<=2500; collapse<=500", and REQ-SET-015 clears hazardous work at 4000.
208: const REST_SEEK_SLEEP_THRESHOLD: int = 2500
209: const REST_COLLAPSE_THRESHOLD: int = 500
210: const REST_HAZARD_CLEAR_THRESHOLD: int = 4000
211: ## Comfort: "Low<3000; content>=6000" -- strict below, inclusive above, as written.
212: const COMFORT_LOW_THRESHOLD: int = 3000
213: const COMFORT_CONTENT_THRESHOLD: int = 6000
214: ## Social: "Lonely<2500". Purpose: "Aimless<2500". Both strict.
215: const SOCIAL_LONELY_THRESHOLD: int = 2500
216: const PURPOSE_AIMLESS_THRESHOLD: int = 2500
218: # --- size and season multipliers (GDD §5.2) -------------------------------------------------
219: 
220: const SIZE_SMALL: int = 0
221: const SIZE_MEDIUM: int = 1
222: const SIZE_LARGE: int = 2
223: const SIZE_COUNT: int = 3
224: ## "Small size multiplier 1000, medium 1200, large 1600, denominator 1000."
225: const SIZE_MULTIPLIER: Array[int] = [1000, 1200, 1600]
226: const SIZE_DENOMINATOR: int = 1000
227: ## REQ-SET-143 / §5.2 "winter x1.20", over the same 1000 denominator.
228: const WINTER_HUNGER_MULTIPLIER: int = 1200
229: const SEASON_DENOMINATOR: int = 1000
232: 
233: ## REQ-SET-014: "While hunger is 0 ... remove 4 health/hour".
234: const HEALTH_STARVATION_DRAIN_PER_HOUR: int = 4
235: ## REQ-SET-018: "after 4 exposure hours it shall remove 3 health/hour".
236: const HEALTH_COLD_DRAIN_PER_HOUR: int = 3
237: ## REQ-SET-017: "restore 2 health/hour, increased to 4/hour in an infirmary".
238: const HEALTH_RECOVERY_PER_HOUR: int = 2
239: const HEALTH_RECOVERY_INFIRMARY_PER_HOUR: int = 4
240: ## REQ-SET-017 gate: hunger and rest must both be at least this to recover.
241: const HEALTH_RECOVERY_NEED_FLOOR: int = 4000
247: ## severity 2, NOT ONE COPY PER INCIDENT", which is why the rate reads the aggregate state and
248: ## never an incident count.
249: const HEALTH_UNTREATED_INJURY_DRAIN_PER_HOUR: Array[int] = [0, 1, 4]
254: ## So it is a rate term here, not a subtracted lump somewhere else: with untreated severity 2
255: ## and nothing else the total is exactly -129/hour, HAZ-002's own fixture.
256: const HEALTH_AIRLESS_DRAIN_PER_HOUR: int = 125
259: 
260: ## §5.2: base gain is 1 exposure-hour/hour for tier 1; §5.10: tier 2 removes the -5 C baseline.
261: const COLD_GAIN_TIER1_MILLI_PER_HOUR: int = 1000
262: const COLD_GAIN_TIER2_MILLI_PER_HOUR: int = 0
264: ## tier 2", matching §5.10's "outdoor exposure accumulation x2" and "hard freeze adds 1/hour
265: ## even with that clothing".
266: const COLD_GAIN_HARD_FREEZE_TIER1_MILLI_PER_HOUR: int = 2000
267: const COLD_GAIN_HARD_FREEZE_TIER2_MILLI_PER_HOUR: int = 1000
268: ## REQ-SET-019 / §5.2: "Clearing shelter remains 2000/hour".
269: const COLD_CLEAR_SHELTER_MILLI_PER_HOUR: int = 2000
270: ## REQ-SET-018: exposure damage begins after this many whole exposure hours.
271: const COLD_DAMAGE_HOURS: int = 4
272: const CLOTHING_TIER_MIN: int = 1
273: const CLOTHING_TIER_MAX: int = 2
276: 
277: ## Mood = clamp(floor((3*hunger+2*rest+2*comfort+social+2*purpose)/10) + memories, 0, 10000).
278: const MOOD_WEIGHT: Array[int] = [3, 2, 2, 1, 2]
279: const MOOD_DIVISOR: int = 10
280: const MOOD_MIN: int = 0
281: const MOOD_MAX: int = 10000
283: ## Productivity factor bands, denominator 1000: <2000->600; 2000-3999->800; 4000-6999->1000;
284: ## 7000-8499->1100; >=8500->1150.
285: const MOOD_FACTOR_DENOMINATOR: int = 1000
286: const MOOD_FACTOR_BAND_FLOOR: Array[int] = [2000, 4000, 7000, 8500]
287: const MOOD_FACTOR_VALUE: Array[int] = [600, 800, 1000, 1100, 1150]
288: ## Health factor bands: <40->600; 40-69->850; >=70->1000.
289: const HEALTH_FACTOR_BAND_FLOOR: Array[int] = [40, 70]
290: const HEALTH_FACTOR_VALUE: Array[int] = [600, 850, 1000]
291: ## Skill factor = 1000 + 50*level, levels 0..10 (GDD §5.3 caps skill level at 10).
292: const SKILL_FACTOR_BASE: int = 1000
293: const SKILL_FACTOR_PER_LEVEL: int = 50
294: const SKILL_LEVEL_MAX: int = 10
295: ## total work factor = clamp(floor(skill*mood*health/1000000), 300, 1800).
296: const WORK_FACTOR_DIVISOR: int = 1000000
297: const WORK_FACTOR_MIN: int = 300
298: const WORK_FACTOR_MAX: int = 1800
302: ## Keys in ascending ASCII order, per BAL-CAT-001. NO numeric IDs are published: §4.3 does not
303: ## number this enum, so its members are catalog.gd's to compile. Callers look up by key.
304: const MEMORY_KEYS: Array[StringName] = [
307: ]
308: ## Mood value contributed by each key above, same order.
309: const MEMORY_VALUES: Array[int] = [-600, -600, 600, 1000, -1800, 300, 500, -400, 600, -300, -800]
311: ## treated" -- so its entry is 0 and MEMORY_UNTIL_TREATED marks it; memory_duration_hours()
312: ## REFUSES that key rather than handing back a 0 or a -1 that could be read as a duration.
313: const MEMORY_DURATION_HOURS: Array[int] = [12, 12, 8, 24, 72, 6, 24, 6, 48, 24, 0]
314: const MEMORY_UNTIL_TREATED: Array[bool] = [
316: ]
317: ## "at eight entries replace the smallest absolute value" -- the cap the deferred store needs.
318: const MEMORY_SLOTS_PER_RESIDENT: int = 8
320: # --- resident status (GDD §4.3 ResidentStatus, precedence in §5.2) --------------------------
321: 
322: const STATUS_ACTIVE: int = 0
323: const STATUS_RESTING: int = 1
324: const STATUS_INJURED: int = 2
325: const STATUS_INCAPACITATED: int = 3
326: const STATUS_LEAVING: int = 4
327: const STATUS_DEAD: int = 5
328: const STATUS_TRANSFERRED: int = 6
330: ## module already declares, in the shape ARCH-SAVE-005 asks for -- "bounds each byte against its
331: ## `*_COUNT`" -- so it fixes no new policy: TRANSFERRED = 6 remains the largest legal byte.
332: const STATUS_COUNT: int = 7
333: ## "DEAD at health=0, INCAPACITATED at health=1..15". A treated resident wakes at health>=16.
334: const HEALTH_INCAPACITATED_MAX: int = 15
337: 
338: ## Sleep location decides the rest rate. AWAKE is the unavailable-bed default.
339: const ACTIVITY_AWAKE: int = 0
340: const ACTIVITY_SLEEP_BED: int = 1
341: const ACTIVITY_SLEEP_FLOOR: int = 2
342: const ACTIVITY_COUNT: int = 3
343: 
344: ## Comfort restoration source. NONE means neither a valid heated room nor mild outdoors.
345: const COMFORT_ENV_NONE: int = 0
346: const COMFORT_ENV_HEATED_ROOM: int = 1
347: const COMFORT_ENV_MILD_OUTDOORS: int = 2
348: const COMFORT_ENV_COUNT: int = 3
349: 
350: ## Purpose restoration source (§5.2: completed useful labor, or mentoring).
351: const PURPOSE_SOURCE_NONE: int = 0
352: const PURPOSE_SOURCE_LABOR: int = 1
353: const PURPOSE_SOURCE_MENTORING: int = 2
354: const PURPOSE_SOURCE_COUNT: int = 3
355: 
356: ## Cold environment. NEUTRAL is the unavailable-rooms default: neither exposed nor clearing.
357: const COLD_ENV_NEUTRAL: int = 0
358: const COLD_ENV_EXPOSED: int = 1
359: const COLD_ENV_HEATED_SHELTER: int = 2
360: const COLD_ENV_COUNT: int = 3
362: ## Injury presence, as §5.2 itself uses it: for the INJURED status and the recovery gate.
363: ## Mapping the Injury component's severity onto these is deferred with that component.
364: const INJURY_NONE: int = 0
365: const INJURY_ACTIVE: int = 1
366: const INJURY_UNTREATED_SERIOUS: int = 2
367: const INJURY_STATE_COUNT: int = 3
369: # --- refusal codes -------------------------------------------------------------------------
370: 
371: const REFUSE_NONE: StringName = &""
372: const REFUSE_INVALID_SLOT: StringName = &"INVALID_SLOT"
373: const REFUSE_NOT_PRESENT: StringName = &"RESIDENT_NOT_PRESENT"
374: const REFUSE_ALREADY_PRESENT: StringName = &"RESIDENT_ALREADY_PRESENT"
375: const REFUSE_RESIDENT_DEAD: StringName = &"RESIDENT_DEAD"
376: const REFUSE_LIVING_CAP: StringName = &"LIVING_CAP_RESIDENT"
377: const REFUSE_INVALID_SIZE: StringName = &"INVALID_SIZE_CLASS"
378: const REFUSE_INVALID_NEED: StringName = &"INVALID_NEED"
379: const REFUSE_INVALID_ACTIVITY: StringName = &"INVALID_ACTIVITY"
380: const REFUSE_INVALID_COMFORT_ENVIRONMENT: StringName = &"INVALID_COMFORT_ENVIRONMENT"
381: const REFUSE_INVALID_PURPOSE_SOURCE: StringName = &"INVALID_PURPOSE_SOURCE"
382: const REFUSE_INVALID_COLD_ENVIRONMENT: StringName = &"INVALID_COLD_ENVIRONMENT"
383: const REFUSE_INVALID_CLOTHING_TIER: StringName = &"INVALID_CLOTHING_TIER"
384: const REFUSE_INVALID_INJURY_STATE: StringName = &"INVALID_INJURY_STATE"
385: const REFUSE_INVALID_POINTS: StringName = &"INVALID_POINTS"
386: const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
387: const REFUSE_UNKNOWN_MEMORY: StringName = &"UNKNOWN_MEMORY_KEY"
388: const REFUSE_DURATION_CONDITIONAL: StringName = &"DURATION_CONDITIONAL"
389: const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
390: ## _integrate_step() preconditions. Each one is a proof obligation for its overflow argument,
391: ## so a violation refuses instead of integrating something unproven.
392: const REFUSE_RATE_OUT_OF_RANGE: StringName = &"RATE_OUT_OF_RANGE"
393: const REFUSE_INVALID_DENOMINATOR: StringName = &"INVALID_DENOMINATOR"
394: const REFUSE_REMAINDER_INVARIANT: StringName = &"REMAINDER_INVARIANT_BROKEN"
417: ## index = slot * NEED_COUNT + need. Five equal-length columns in one buffer, not an Array
418: ## of arrays and not a per-resident Array.
419: var _need_value: PackedInt32Array = PackedInt32Array()
420: ## NeedRemainders, the same stripe. Signed, |remainder| < NEED_DENOMINATOR at all times.
421: var _need_remainder: PackedInt64Array = PackedInt64Array()
422: 
423: var _health: PackedInt32Array = PackedInt32Array()
424: ## IntegrationRemainders.health, denominator HEALTH_DENOMINATOR, signed.
425: var _health_remainder: PackedInt64Array = PackedInt64Array()
426: 
427: ## IntegrationRemainders.cold_milli_hours: 1000 per exposure-hour (§5.2).
428: var _cold_milli_hours: PackedInt64Array = PackedInt64Array()
429: ## IntegrationRemainders.cold, denominator COLD_DENOMINATOR, signed.
430: var _cold_remainder: PackedInt64Array = PackedInt64Array()
434: ## remainder, so REQ-SET-014's "one starving-hour counter/hour" needs no extra accumulator --
435: ## GDD §4.2's IntegrationRemainders row does not provide one.
436: var _starving_ticks: PackedInt64Array = PackedInt64Array()
437: 
438: ## Needs.departure_days. Reserved and explicitly zero: see the GAPS block in the header.
439: var _departure_days: PackedInt32Array = PackedInt32Array()
440: 
441: var _status: PackedByteArray = PackedByteArray()
442: var _present: PackedByteArray = PackedByteArray()
443: var _size_class: PackedByteArray = PackedByteArray()
445: # --- environment input columns (see the header) --------------------------------------------
446: 
447: var _activity: PackedByteArray = PackedByteArray()
448: var _comfort_environment: PackedByteArray = PackedByteArray()
449: var _social_paired: PackedByteArray = PackedByteArray()
450: var _purpose_source: PackedByteArray = PackedByteArray()
451: var _cold_environment: PackedByteArray = PackedByteArray()
452: var _clothing_tier: PackedByteArray = PackedByteArray()
453: var _infirmary: PackedByteArray = PackedByteArray()
454: var _injury_state: PackedByteArray = PackedByteArray()
457: ## the health RATE consequence is this module's, and 0 is the honest default of a world with
458: ## no water traversal implemented.
459: var _airless: PackedByteArray = PackedByteArray()
461: # --- world-level inputs and derived rates ---------------------------------------------------
462: 
463: var _winter: bool = false
464: var _hard_freeze: bool = false
466: ## already folded in. Recomputed only when winter changes, so the compound multiplication
467: ## happens once per season boundary and never on the per-tick path.
468: var _hunger_rate_milli: PackedInt64Array = PackedInt64Array()
469: 
470: var _present_count: int = 0
471: var _living_count: int = 0
472: var _death_count: int = 0
473: var _last_refused_slot: int = -1
475: ## above: not state, not persisted, and excluded from `state_bytes()` so a refusal cannot alter
476: ## the image that proves it changed nothing.
477: var _last_column_refusal: StringName = REFUSE_NONE
482: ## before the next call. No callback or signal is invoked anywhere in this module, so no
483: ## public operation can re-enter while it holds a live value.
484: var _math: IntMath.IntResult = IntMath.IntResult.new()
485: ## _integrate_step()'s two outputs, consumed immediately by its caller.
486: var _step_value: int = 0
487: var _step_remainder: int = 0
488: ## One tick's five need rates for one resident, refilled by _fill_need_rates() and consumed by
489: ## _integrate_needs() before the next resident is touched. Allocated once with the columns.
490: var _rate_scratch: PackedInt64Array = PackedInt64Array()
491: ## Value carried by the next OpResult, set by a `_*_checked()` helper just before it returns.
492: var _out_value: int = 0
527: 
528: 
529: func _allocate_columns() -> void:
530: 	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
531: 	_need_value.resize(RESIDENT_CAPACITY * NEED_COUNT)
532: 	_need_remainder.resize(RESIDENT_CAPACITY * NEED_COUNT)
533: 	_health.resize(RESIDENT_CAPACITY)
534: 	_health_remainder.resize(RESIDENT_CAPACITY)
535: 	_cold_milli_hours.resize(RESIDENT_CAPACITY)
536: 	_cold_remainder.resize(RESIDENT_CAPACITY)
537: 	_starving_ticks.resize(RESIDENT_CAPACITY)
538: 	_departure_days.resize(RESIDENT_CAPACITY)
539: 	_status.resize(RESIDENT_CAPACITY)
540: 	_present.resize(RESIDENT_CAPACITY)
541: 	_size_class.resize(RESIDENT_CAPACITY)
542: 	_activity.resize(RESIDENT_CAPACITY)
543: 	_comfort_environment.resize(RESIDENT_CAPACITY)
544: 	_social_paired.resize(RESIDENT_CAPACITY)
545: 	_purpose_source.resize(RESIDENT_CAPACITY)
546: 	_cold_environment.resize(RESIDENT_CAPACITY)
547: 	_clothing_tier.resize(RESIDENT_CAPACITY)
548: 	_infirmary.resize(RESIDENT_CAPACITY)
549: 	_injury_state.resize(RESIDENT_CAPACITY)
550: 	_airless.resize(RESIDENT_CAPACITY)
551: 	_hunger_rate_milli.resize(SIZE_COUNT)
552: 	_rate_scratch.resize(NEED_COUNT)
553: 
554: 
555: func clear() -> void:
556: 	"""Return every column to the empty settlement state without reallocating."""
557: 	_need_value.fill(0)
558: 	_need_remainder.fill(0)
559: 	_health.fill(0)
560: 	_health_remainder.fill(0)
561: 	_cold_milli_hours.fill(0)
562: 	_cold_remainder.fill(0)
563: 	_starving_ticks.fill(0)
564: 	_departure_days.fill(0)
565: 	_status.fill(STATUS_DEAD)
566: 	_present.fill(0)
567: 	_size_class.fill(SIZE_SMALL)
568: 	_fill_environment_defaults()
569: 	_winter = false
570: 	_hard_freeze = false
571: 	_present_count = 0
572: 	_living_count = 0
573: 	_death_count = 0
574: 	_last_refused_slot = -1
575: 	_out_value = 0
576: 	var code: StringName = _recompute_hunger_rates()
577: 	assert(code == REFUSE_NONE, "the published hunger multipliers cannot overflow int64")
578: 
579: 
1705: # generation of any namespace, because this store holds none.
1706: 
1707: const COLUMN_TYPE_U8: int = 0
1708: const COLUMN_TYPE_I32: int = 2
1709: const COLUMN_TYPE_I64: int = 4
1712: ## here is what lets a codec emit ordinals without guessing, and what lets a test refuse a
1713: ## reordering: an alphabetical or declaration-order walk produces a different list.
1714: const COLUMN_COUNT: int = 20
1715: const COLUMN_KEYS: Array[StringName] = [
1720: 	&"_injury_state", &"_airless",
1721: ]
1722: const COLUMN_TYPE_CODES: Array[int] = [
1727: 	COLUMN_TYPE_U8, COLUMN_TYPE_U8,
1728: ]
1729: const COLUMN_EXTENTS: Array[int] = [
1739: ## Every code is prefixed `COLUMN_` so it can never collide with a mutator's refusal above: a
1740: ## load must not be able to clobber the reason a `spawn()` was refused before its caller read it.
1741: const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
1742: const REFUSE_COLUMN_PRESENT_BYTE: StringName = &"COLUMN_PRESENT_BYTE"
1743: const REFUSE_COLUMN_FLAG_BYTE: StringName = &"COLUMN_FLAG_BYTE"
1744: const REFUSE_COLUMN_ENUM_BYTE: StringName = &"COLUMN_ENUM_BYTE"
1745: const REFUSE_COLUMN_CLOTHING_TIER: StringName = &"COLUMN_CLOTHING_TIER"
1746: const REFUSE_COLUMN_NEED_RANGE: StringName = &"COLUMN_NEED_RANGE"
1747: const REFUSE_COLUMN_HEALTH_RANGE: StringName = &"COLUMN_HEALTH_RANGE"
1748: const REFUSE_COLUMN_NEGATIVE_COUNTER: StringName = &"COLUMN_NEGATIVE_COUNTER"
1749: const REFUSE_COLUMN_REMAINDER: StringName = &"COLUMN_REMAINDER"
1750: const REFUSE_COLUMN_FREE_ROW: StringName = &"COLUMN_FREE_ROW"
1751: const REFUSE_COLUMN_LIVING_CAP: StringName = &"COLUMN_LIVING_CAP"
1852: 
1853: 
1854: func copy_columns_into(out: Columns) -> bool:
1855: 	"""Copy the twenty category-1 columns into caller-owned buffers. False refuses.
1856: 
1857: 	Section 4's capture step, and the ONLY way to read a FREE row's retained bytes: every other
1858: 	reader here refuses a row whose `_present` is 0, so the values a released row carries -- and
1859: 	the recomputed counts the living cap is checked against -- are otherwise unreachable.
1860: 
1861: 	The copies are snapshots. Mutating `out` afterwards cannot reach a column, and a later tick
1862: 	cannot reach `out`.
1863: 	"""
1864: 	if not _columns_are_capacity_sized(out):
1865: 		_last_column_refusal = REFUSE_COLUMN_SHAPE
1866: 		return false
1867: 	_refill_bytes(out.present, _present)
1868: 	_refill_i32(out.need_value, _need_value)
1869: 	_refill_i64(out.need_remainder, _need_remainder)
1870: 	_refill_i32(out.health, _health)
1871: 	_refill_i64(out.health_remainder, _health_remainder)
1872: 	_refill_i64(out.cold_milli_hours, _cold_milli_hours)
1873: 	_refill_i64(out.cold_remainder, _cold_remainder)
1874: 	_refill_i64(out.starving_ticks, _starving_ticks)
1875: 	_refill_i32(out.departure_days, _departure_days)
1876: 	_copy_state_bytes_into(out)
1877: 	_last_column_refusal = REFUSE_NONE
1878: 	return true
1879: 
1880: 
1894: 
1895: 
1896: func restore_columns(columns: Columns) -> bool:
1897: 	"""Replace all twenty columns and recompute both counters. False refuses; nothing is written.
1898: 
1899: 	Section 4's apply step. The store becomes the settlement these columns describe: the previous
1900: 	contents are discarded wholesale, so a slot index taken before the call belongs to a different
1901: 	world. Restore into a store you are loading over.
1902: 
1903: 	`_present_count` and `_living_count` are RECOMPUTED from the restored columns and never read
1904: 	from the caller. That recount is this store's validator: ARCH-SAVE-005's 256 living residents
1905: 	is checked against the recomputed number before a byte is installed, so a column set claiming
1906: 	more refuses rather than installing a settlement the cap forbids.
1907: 
1908: 	Allocate before consume (decision 0059): every rule -- shape, byte domains, value ranges,
1909: 	remainder magnitudes, the free-row rule and the cap -- is checked before the first write, and
1910: 	no partial write exists to roll back. A refusal leaves the store byte-identical and
1911: 	`state_bytes()` proves it by comparison rather than by eye.
1912: 
1913: 	`_winter`, `_hard_freeze` and `_death_count` are NOT touched: the first two are per-tick world
1914: 	inputs the caller restates, and the third is a diagnostic. See `last_column_refusal()`.
1915: 	"""
1916: 	var refusal: StringName = _restore_column_refusal(columns)
1917: 	if refusal != REFUSE_NONE:
1918: 		_last_column_refusal = refusal
1919: 		return false
1920: 	_install_columns(columns)
1921: 	_rebuild_counters()
1922: 	_last_column_refusal = REFUSE_NONE
1923: 	return true
1924: 
1925: 
2072: 
2073: 
2074: func _free_row_is_clear(columns: Columns, slot: int) -> bool:
2075: 	"""True when one inactive row holds the released-row values and the DEAD status."""
2076: 	if columns.status[slot] != STATUS_DEAD:
2077: 		return false
2078: 	if columns.health[slot] != 0 or columns.health_remainder[slot] != 0:
2079: 		return false
2080: 	if columns.cold_milli_hours[slot] != 0 or columns.cold_remainder[slot] != 0:
2081: 		return false
2082: 	if columns.starving_ticks[slot] != 0:
2083: 		return false
2084: 	var base: int = slot * NEED_COUNT
2085: 	for need: int in NEED_COUNT:
2086: 		if columns.need_value[base + need] != 0 or columns.need_remainder[base + need] != 0:
2087: 			return false
2088: 	return true
2089: 
2090: 
