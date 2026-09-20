# Immutable architecture ledger excerpts
| FishStock | closed | B8 | 1 | 1 | 96 | 96 | [GDD §4.2; 32*3] |
| FishHabitat | effort_used | I32 | 4 | 1 | 32 | 128 | [decision 0027, ratified by ruling §5 2026-09-09] §4.2 gives `effort_slots` as a capacity with nowhere to record occupancy, which REQ-SET-044/050 require |
| FishStock | restocking | B8 | 1 | 1 | 96 | 96 | [decision 0027, ratified by ruling §5] REQ-SET-048's 30-down/40-up band needs one bit population alone cannot supply. Transitions are strict: enter `100*P<30*K`, clear `100*P>40*K` |
| FishHabitat | intensive_harvest | B8 | 1 | 1 | 32 | 32 | [decision 0027, ratified by ruling §5] §5.4's "explicitly visible intensive harvest" policy flag; the store's single setter, which is what makes "never by auto-fallback" structural. The three rows above total **256 bytes** |
| FishingEffortClaim | expedition_generation, habitat_slot, habitat_generation, job_slot, job_generation, slot_count | I32 | 4 | 6 | 512 | 12288 | [decision 0037, ruling §5] `claim_row = owning Expedition typed row`; no allocator and no child heap. The Expedition's directory slot is NOT stored — it comes back from `EntityDirectory.owner_slot_of_typed_row()`, which reads ARCH-ID-003's existing reverse map |
| FishingEffortClaim | active | B8 | 1 | 1 | 512 | 512 | [decision 0037, ruling §5] Claim publication and the `effort_used` change are one committed step; the aggregate is rebuilt from live claims on load, never trusted. Slice total **12800 bytes** |
| HarvestZone | type, danger | I32 | 4 | 2 | 128 | 1024 | [GDD §4.2; lengths ARCH-MEM-002–004] |

Fixed-field payload sum = **25028962 bytes** (advanced 2026-09-11, decision 0055: +16 for Weather's two I64 absolute-season columns, taking that row from 32 to 48 and the printed field rows from 140 to **141**; reconciled 2026-09-11, decision 0050: the prior carried subtotal24555474 omitted437632 bytes already in the printed rows; the following are historical carried values: 24514514 before decision 0045 added the 40960-byte FieldPolicy cycle and enrolment ledger, 24501202 before decision 0041 added the 13312-byte JobPlanner forage-demand ledger, 24288210 before decision 0040 added the 212992-byte JobPlanner sowing-request ledger, 24161234 before decision 0039 added the 126976-byte JobPlanner pending-service ledger, 24148434 before decision 0037 added the 12800-byte `FishingEffortClaim` slice, and 24146898 before decision 0021 added the 1536-byte `Schedule.latch` group, which took the Schedule packed payload from 16384 to 12288+4096+1536=**17920** bytes). The table includes selected_P for allocation but excludes it from canonical hashing. All zero-capacity TransferManifest fields remain declared in the schema and codec; enabling the adapter requires a versioned capacity/budget revision. The chronicle total is unbounded on disk; the row is only its two resident pages. `[DERIVED]`

### 2.3 Complete allocation ledger

All allocations beyond GDD field payload/derived map dimensions are `[NEW]` capacity decisions, not engine measurements. Shared immutable maps/catalogs exist once across transactional loads.

| Allocation | Count | Bytes/element | Bytes | Lifetime | Derivation |
|---|---|---|---|---|---|
| Fixed registry payload | 25036642 | 1 | 25036642 | mutable | Sum §2.2 (+1536 decision 0021; +306304 decisions 0026/0030; +131072 claim-ordering cache, declared separately per R05-QUOTA-024; +256 decision 0027, ratified; +12800 decision 0037; +126976 decision 0039; +212992 decision 0040; +13312 decision 0041; +40960 decision 0045 FieldPolicy); +35840 decision 0051 hive-service slice; +16 decision 0055 Weather absolute-season identity; +512 decision 0095 Resident life stage) |
| Auxiliary payload | 25293280 | 1 | 25293280 | mutable | Sum §3 (+786436 decision 0019, +158816 ARCH-STATE-005, +65536 READY_06 §7, +212996 ARCH-STATE-007, +49152 ARCH-STATE-008, +520192 decision 0053) |
| Static navigation map | 262144 | 14 | 3670016 | shared immutable | walkability/layer bytes + terrain/height/clearance i32 |
| Active A* builder | 262144 | 21 | 5505024 | mutable | g,parent,heap,heap_position,stamp i32 + state byte |
| Route cell arena | 1048576 | 4 | 4194304 | mutable | ARCH-PATH-005 cells |
| Route descriptors | 256 | 64 | 16384 | mutable | 16 i32: ID,generation,key fields,offset,count,refcount,use tick low/high,flags |
| Path request records | 8192 | 64 | 524288 | mutable | 16 i32 fields; job/source/goal/phase/queue linkage and tick halves |
| Spatial heads | 16384 | 4 | 65536 | mutable | 128*128 heads |
| Resident motion/separation scratch | 512 | 64 | 32768 | mutable | 16 i32; velocities/remainders/next positions/corrections/grid links |
| Command queue | 4096 | 64 | 262144 | mutable | ARCH-CMD-001 stride |
| Command queue order index | 4096 | 4 | 16384 | mutable | [decision 0042] One i32 per record: ARCH-CMD-001's `(execute_tick,player_id,sequence_high_unsigned,sequence_low_unsigned)` order as a ring of positions over the fixed rows above, always a permutation of 0..4095 so the unqueued entries are the free list. Derived and rebuildable from the saved records |
| Command payload arena | 1048576 | 1 | 1048576 | mutable | ARCH-SAVE-001 |
| Command result ledger | 4096 | 36 | 147456 | mutable | [decision 0043] One outcome per queued command, so a tick that drains a full queue loses none: `execute_tick` i64 plus seven i32 (both sequence halves, kind, deterministic result id, produced value, target slot and generation). Presentation reads it through a copy; ARCH-SYS-002 writes it |
| Command result store codes | 4096 | 8 | 32768 | mutable | [decision 0043] One interned StringName reference per result row, holding the ORIGINATING store's own refusal code so `COMMAND_STORE_REFUSED` is never the whole story shown to a player. Assigning an interned name is a reference copy, not an allocation |
| Command payload decode scratch | 65540 | 1 | 65540 | mutable | [decision 0043] The one buffer every per-kind payload is decoded into, so no dispatch arm resizes anything per tick. Sized by the largest schema: a 4-byte count plus `forage.gd`'s own 16384-link ceiling of i32 tile indices |
| Tick event ring | 8192 | 32 | 262144 | mutable | crowd §12.1 stride; NEW settlement ring allocation |
| Read-only catalog/lookup budget | 1048576 | 2 | 2097152 | shared immutable | NEW two 1 MiB arenas; reject overbudget catalogs |
| I/O streaming buffers | 65536 | 4 | 262144 | temporary | NEW input/output/CRC/UTF8 chunks |
| UI numeric snapshots | 512 | 256 | 131072 | presentation counted conservatively | NEW two 128-byte resident summaries |
| Timing samples | 6900 | 8 | 55200 | diagnostic counted conservatively | NEW 23 stages, i64 timing samples |
| World generation map masks and tree plan | 159968 | 1 | 159968 | mutable | [decision 0048] REQ-SET-009's authored estuary in `godot/scripts/core/world_init.gd`: NINE 16384-byte exterior-tile byte columns -- published and staged terrain, soil, ecology basin and clearing, plus the staging occupancy mask -- FOUR 7-entry i32 basin columns (published and staged §5.5 danger, basin HarvestZone slot and generation), the 3000-entry tree-centre plan and the 100-entry guaranteed-grove plan. Staged and published columns are two allocations made once; publishing SWAPS them, so a refused generation cannot have touched the live map and no `resize()` runs outside `_init()`. §5.1's basin geometry lives here rather than as ~6267 `HarvestZone` tile links, which would consume 9252 of §4.2's 16384 total zone links before the player designates anything. `FaunaStockReserved`'s 15360 bytes are NOT added here: §2.2 already carries that row and this module is the allocation it describes |
| Command dispatch source-intent ledger | 128 | 16 | 2048 | mutable | [decision 0049] Task 04.4's "Record source intent/job identity so repeated evaluation cannot duplicate a job": four i32 per `forage.gd` HarvestZone row -- ARCH-CMD-001's `(player_id, sequence_high, sequence_low)` plus the produced zone's generation. Indexed BY the zone row it describes rather than by a window over command history, so it is bounded by §4.2's own 128 designations and cannot forget an intent whose designation is still alive. `command_dispatch.gd` writes it on a committed DESIGNATE_ZONE and reads it in that kind's preflight |
| Scheduler event queue and control header | 1 | 8224 | 8224 | mutable | [decision 0054] R07-SCHED-001's ARCH-CMD-002 speed/pause queue in `godot/scripts/core/scheduler_events.gd`: 256 records of 32 bytes (one i64 `boundary_tick` plus six i32 -- `sequence_low`, `sequence_high`, `kind`, `reason`, `value`, `reserved`) = 8192, plus the 32-byte queue control header (`head`, `count`, `next_sequence_low/high`, `last_drained_boundary` i64, `last_applied_sequence_low/high`). Counted as one 8224-byte allocation rather than 257 x 32 because the control header is not a record. SEPARATE from the "Command queue" row above: economic commands keep their own 4096 x 64 records, their own arena and their own sequence space, and ARCH-CMD-003's 24 kind ids are not renumbered. The tail derives from head and count, so there is NO order-index row here of the kind decision 0042 needed for the economic ring |
| ARCH-SYS-023 presentation snapshot | 1 | 244 | 244 | presentation counted conservatively | [decision 0049] `godot/scripts/core/presentation_extract.gd`: TWO i64 frames of 14 committed fields (224 bytes) plus one availability byte per field and one visibility byte per layer (20 bytes). Two frames because a render interpolates between the last two COMMITTED ticks. Separate from the "UI numeric snapshots" row above, which budgets per-resident summaries this stage does not produce. The per-stage microsecond and measurement columns `settlement_system.gd` keeps (3 x 7 i64 = 168 bytes) sit inside the "Timing samples" diagnostic row and add nothing here |
| §15 canonical declaration table | 1 | 18825 | 18825 | presentation counted conservatively | [decision 0127; corrected by decision 0142] `canonical_state_hash.gd`'s `_production` Declaration, compiled from REG-R01's checked-in registry and built ONCE: 52 owners x 4 i32 = 832, 604 fields x 3 u8 = 1812, 604 i64 declared counts = 4832, 604 i32 UTF-8 caps = 2416 (9892 fixed) plus 8933 bytes of key text in two PackedStringArrays. The row read 50/590/18384 from decision 0127 and was never re-derived as owners and fields were added, so it UNDER-budgeted by 441 bytes; recomputed here from the registry rather than adjusted to match a label. Counted conservatively because it is RESIDENT -- unlike every save_section_* codec's Record, which exists only between a capture and an apply and takes no row. It is build-time constant data rather than simulation state, so losing it on reload changes no outcome; it is budgeted anyway rather than argued out. The 65536-byte Emitter chunk is per-walk scratch, not resident |
| Demolition owner-scan pairs | 202752 | 4 | 811008 | presentation counted conservatively | [decision 0145] `settlement_system.gd`'s `_demolition_pairs` PackedInt32Array, sized once in `_init()` from `inventory.owner_query_cells()` = 101376 x 2. Cold path: written only by `request_demolition()`, never by a tick. `godot/scripts/systems` is outside `state_registry_coverage.py`'s glob, so no registry row is owed |
| Demolition container de-duplication | 101376 | 1 | 101376 | presentation counted conservatively | [decision 0145] `_demolition_seen` PackedByteArray at one byte per container cell. Without it a lot reachable through both a room and its furniture counts twice, and a double count is a refusal for a building that is actually clear |
| Demolition report lot identity | 32768 | 4 | 131072 | presentation counted conservatively | [decision 0145] `DemolitionReport._lot_slot` and `_lot_generation`, 2 x 16384 x 4. Generation-checked identity, not bare slots: a report naming a slot whose row has since been reused would name the wrong goods |
| UI roster row identity | 12 | 12 | 144 | presentation counted conservatively | [decision 0114] `godot/scripts/systems/ui_manager.gd`: three `PackedInt32Array` columns -- `_roster_ref_slot`, `_roster_ref_generation`, `_roster_persistent_id` -- at `UiShell.ROSTER_POOL` = 12, resized once in `_init()` rather than `_ready()` because the suite builds this router off-tree. This is a FULL +144, not a net +96: the `_roster_slots` PackedInt32Array it replaces was never ledgered, so removing it frees no counted byte. `_roster_count` is a scalar and owes no column row. `state_registry_coverage.py` globs `godot/scripts/core` only and never inspected this file |
| Resident crowd instance buffer | 512 | 100 | 51200 | presentation counted conservatively | [decision 0130] `godot/scripts/presentation/resident_crowd.gd`: `_buffer` PackedFloat32Array at INSTANCE_CAPACITY*FLOATS_PER_INSTANCE = 512*12 = 6144 floats (24576 B) plus `_instance_slot` PackedInt32Array at 512 (2048 B), both resized once in `_init()`, plus the RenderingServer's own 512*12-float TRANSFORM_3D instance buffer (24576 B) counted here rather than assumed free. 48+4+48 = 100 B per resident row. Sized on the 512-ROW capacity, not GDD 4.1's 256 living cap, because a dead row keeps its slot; `visible_instance_count` is what follows the living. `state_registry_coverage.py` globs `godot/scripts/core` only and never inspects this directory |
| Load rollback checkpoint | 1 | 80 | 80 | mutable | [decision 0092] RESTORE-R01's pre-load checkpoint in `godot/scripts/systems/game_manager.gd`: `_checkpoint: PackedInt64Array`, `CHECKPOINT_FIELDS` = 10 elements x 8 bytes, allocated once in `_init()` and overwritten in place so a rollback allocates nothing at its worst moment. Holds the clock's ten runtime scalars in `restore_runtime()` argument order. It is NOT a second WorldRuntime store, which RESTORE-R01 forbids: it duplicates no clock, is never serialized, and is reinstalled through the same validated `restore_runtime()` boundary rather than by writing clock fields directly. `state_registry_coverage.py` scans `godot/scripts/core` only and so cannot see this column -- a checker-scope gap, not an exemption |
| Load barrier token reference | 1 | 8 | 8 | mutable | [decision 0104] `_load_barrier: LoadBarrier` in `godot/scripts/core/sim_clock.gd`: one object reference, null while no load is open. Transient -- never serialized, never in the canonical digest, and never a pause bit; RESTORE-R01's barrier is deliberately NOT the pause mask |
| Load barrier token | 1 | 1 | 1 | mutable | [decision 0104] One `LoadBarrier` RefCounted holding a single bool, allocated by `acquire_load_barrier()` at a load boundary and released with it. Cold path: one per load, never per frame or per tick. Counted at its maximum of one, since a second concurrent grant refuses and mints no token. `scheduler_events.gd` adds no field and its 8224-byte row is unchanged |

| Metric | Bytes | Arithmetic / meaning |
|---|---|---|
| Planned allocated payload | 70003020 | Mechanical sum of printed allocation rows; decision 0050 reconciliation, +16 decision 0055, +8224 decision 0054, **−3151872 decision 0138** (the presentation-private pose scaffold row is deleted, not moved: §2.2's `Transform` 2801664 and §3's `TransformBinding` 350208 already budget the one directory-bound store `settlement_system.gd` now composes, and 2801664+350208=3151872 exactly) |
| Allocator/object reserve | 8388608 | [NEW] 8*1048576 |
| One live world plus reserve | 78391628 | Payload + reserve |
| Headroom below decimal 100 MB | 21608372 | 100000000 − live total |
| Additional candidate mutable state | 63787436 | Second mutable world during transactional load: payload − 3670016 navigation map − 2097152 catalog arenas − 262144 I/O − 131072 UI snapshots − 55200 timing |
| Transactional peak plus same reserve | 142179064 | Live total + candidate mutable state |
| Transactional headroom | -42179064 | 100000000 − transactional peak |

**ARCH-MEM-010 (reconciled 2026-09-11, decision 0050; advanced 2026-09-11 by decisions 0055,
0054 and 0066).** Current planned payload is
**60823126**, the sum of the 24 printed allocation rows; fixed registry payload is
**25028962**, the sum of the 141 printed field rows. R07-SCHED-001's queue is an
allocation row only -- a control block, not per-entity columns -- so no field row moves
|---|---|---:|---:|---:|
| Baseline as generated | — | — | 57713254 | 66101862 |
| Schedule latch columns | decision 0021 | +1536 | 57714790 | 66103398 |
| Reservation pool indexing | decision 0019 | +786436 | 58501226 | 66889834 |
| Job/JobAgent runtime columns | ARCH-STATE-005 | +158816 | 58660042 | 67048650 |
| TileHistory family-streak column | READY_06 §7 | +65536 | 58725578 | 67114186 |
| FishingEffortClaim rows | decision 0037 | +12800 | 58738378 | 67126986 |
| GearInstance allocator and exclusive claim | ARCH-STATE-007 (decision 0038) | +212996 | 58951374 | 67339982 |
| JobPlanner pending-service ledger | decision 0039 | +126976 | 59078350 | 67466958 |
| JobPlanner sowing-request ledger | decision 0040 | +212992 | 59291342 | 67679950 |
| JobPlanner forage-demand ledger | decision 0041 | +13312 | 59304654 | 67693262 |
| Command queue order index | decision 0042 | +16384 | 59321038 | 67709646 |
| HivePollinationLinks orchard recipients | ARCH-STATE-008 (decision 0044) | +49152 | 59370190 | 67758798 |
| FieldPolicy cycle and enrolment ledger | decision 0045 | +40960 | 59411150 | 67799758 |
| Command dispatch result ledger, store codes and payload scratch | decision 0043 | +245764 | 59656914 | 68045522 |
| World generation map masks and tree plan | decision 0048 | +159968 | 59816882 | 68205490 |
| Command dispatch source-intent ledger and ARCH-SYS-023 presentation snapshot | decision 0049 | +2292 | 59819174 | 68207782 |
| Historical fixed-field omission reconciled, no new allocation | decision 0050 | +437632 | 60256806 | 68645414 |
| HiveService slice on a third owner class | decision 0051 | +35840 | 60292646 | 68681254 |
| Movement ground slice identity, contact-owner and route-cursor rows | decision 0053 | +520192 | 60812838 | 69201446 |
| Weather absolute-season identity (two I64 columns) | decision 0055 | +16 | 60812854 | 69201462 |
| Scheduler event queue and control header | decision 0054 | +8224 | 60821078 | 69209686 |
| ResidentRouteCursor owner-persistent-id column | decision 0066 | +2048 | 60823126 | 69211734 |
| Packed Building, Room and Furniture index tables | decision 0080 | +1885220 | 62708346 | 71096954 |
| Travel admission and starter ground profiles | decision 0083 | +10336 | 62718682 | 71107290 |
| StockAge container declarations and sweep order | decision 0085 | +1013760 | 63732442 | 72121050 |
| GameManager load rollback checkpoint | decision 0092 | +80 | 63732522 | 72121130 |
| Resident life stage column | decision 0095 | +512 | 63733034 | 72121642 |
| Clock load barrier token and its reference | decision 0104 | +9 | 63733043 | 72121651 |
| Injury columns, net of the Injury component rows already in §2.2 | decision 0109 | +7168 | 63740211 | 72128819 |
| ProductiveWork tool settlement, less wear_remainder's old I64 budget | decision 0110 | +6656 | 63746867 | 72135475 |
| UI roster row generation-checked identity | decision 0114 | +144 | 63747011 | 72135619 |
| §15 canonical declaration table | decision 0127 | +18384 | 63765395 | 72154003 |
| Resident crowd MultiMesh and its presentation-private pose scaffold | decision 0130 | +3203072 | 66968467 | 75357075 |
| Construction project lifecycle | decision 0131 | +5142528 | 72110995 | 80499603 |
| Presentation-private pose scaffold deleted; the settlement composes ARCH-SYS-001 and INIT-POSE-R01 places the cohort into it | decision 0138 | -3151872 | 68959123 | 77347731 |
| §15 declaration table re-derived from the registry it compiles, correcting a stale 50/590 row | decision 0142 | +441 | 68959564 | 77348172 |
| Demolition owner scan, de-duplication and generation-checked report identity | decision 0145 | +1043456 | 70003020 | 78391628 |

The 66103398 figure recorded in decision 0021 is confirmed: it is the baseline plus the latch and nothing else, and it is superseded here only because further decisions are folded in on top of it. Coordinator bookkeeping (decision 0017) and the expanded movement scope (decision 0020) are **not** in any line above; see §3.1.

**ARCH-MEM-006.** The current calculated two-world peak is 123819276 bytes, exceeding the gate by 23819276 bytes (decision 0054; decisions 0050/0053/0055 and the earlier calculations remain in the historical trail). Therefore the selected release architecture SHALL use a transactional **disk-backed rollback checkpoint**, not two resident mutable worlds: validate the entire incoming file and construct it in a separate inactive on-disk checkpoint, retain the old world's validated checkpoint, then reuse the old world's mutable allocations to decode the already validated incoming snapshot. On decode/I/O failure restore the validated old checkpoint before exposing any world. This avoids the second 54607542-byte mutable world and adds loading I/O. The original world remains logically unchanged on failure; UI remains in LOAD pause until rollback completes. If rollback itself encounters an I/O fault, keep both files and expose the load error without exposing a partially decoded world. `[NEW selected design; DERIVED ledger; GDD REQ-SET-161]`
**ARCH-MEM-007.** The allocator reserve is a budget to measure, not a claim that Godot headers occupy exactly that amount. Count all live packed capacities and engine-owned copies separately. A measured reserve overrun fails qualification. The main planned payload contributors are directory bookkeeping, fixed field stores, A* scratch, and route cells; active resident fields are a small fraction. Avoid copying packed arrays into temporary local Variants during hot updates. `[NEW instrumentation; crowd §4.2, §7]`

**ARCH-MEM-008.** The fixed record payloads in the ledger expand in this order `[NEW]`: