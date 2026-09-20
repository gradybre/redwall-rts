# Architecture excerpts

**ARCH-ID-002.** Both directory and typed-row allocators use preallocated indexed min-heaps of free indices. Pop the lowest free slot, initialize all columns and children explicitly, then publish `active=1` at lifecycle commit. Initial generation is 1 `[NEW]`; increment on reuse, not on destroy, matching `[crowd §4.1]`. Generation 2147483647 may be used once; after its destruction retire the slot permanently rather than wrapping. Persistent ID exhaustion at 2147483647 refuses further creation and offers saving/continuation of the existing world; it never wraps or resets on load. `[NEW overflow disposition]`

**ARCH-ID-003.** All command, job, reservation, target, ownership, UI lookup, event, and save-load access SHALL validate this predicate before reading target columns:

```text
valid(ref, expected_kind) :=
    0 <= ref.slot < directory_capacity
    AND identity.active[ref.slot] == 1
    AND identity.generation[ref.slot] == ref.generation
    AND (expected_kind == ANY OR identity.kind[ref.slot] == expected_kind)
    AND 0 <= directory.typed_row[ref.slot] < kind_capacity[identity.kind[ref.slot]]
    AND typed_owner_slot[kind][typed_row] == ref.slot
```

`ANY` is a validator mode, not a saved kind. Validation of a null optional reference returns absent; it is never dereferenced. A stale mandatory reference cancels the dependent job through the normal release pipeline, emitting one grouped notice. `[GDD §4.1–4.2, §5.8; NEW reverse-owner consistency check]`

**ARCH-ID-004.** Creation is a transaction: reserve every required typed row, directory row, child row, inventory slot, and command-output slot; if any pool is full, release the temporary allocator reservations and refuse the operation with `CAPACITY_<STORE>`. Do not spend materials or evict a living resident, job, reservation, or resource. Eligible lot merging may be attempted first under the fixed GDD merge rule. Refused nonessential production remains disabled with an explanation; essential capacity failure pauses with a diagnostic if continuation would lose state. `[GDD §4.2, §5.8 REQ-SET-120; crowd CR-009; NEW error codes]`

**ARCH-ID-005.** At death/departure, stop new work, release reservations, transfer or drop real inventory under the cause's rules, record chronicle/memories, copy render corpse data if used, invalidate bed assignment and relationship indexes, then clear active and return the row at end-of-tick commit. Deferred create/destroy operations sort by command execution order and then persistent ID. No swap-removal changes a live authoritative slot; only active index arrays and render batches compact. `[GDD §5.2–5.3; crowd §4.1, §6.2]`

### 8.1 Command and save byte formats

**ARCH-SAVE-001.** All saved integers use explicit little-endian encoding and two's-complement bit representation; strings use length-prefixed UTF-8 without object serialization. No engine Resource serializer, Dictionary order, RID, NodePath, or machine-native memory dump is the canonical format. The layout below is `[NEW]`, keeping `[crowd §6.4]` byte-order/hash conventions.

| Command offset | Type | Field | Bytes |
|---:|---|---|---:|
| 0 | i64 | execute_tick | 8 |
| 8 | i32 | player_id | 4 |
| 12 | u32 bits | sequence_low | 4 |
| 16 | u32 bits | sequence_high | 4 |
| 20 | i32 | kind | 4 |
| 24 | i32 | target_slot | 4 |
| 28 | i32 | target_generation | 4 |
| 32 | i32 | goal_x | 4 |
| 36 | i32 | goal_z | 4 |
| 40 | i32 | arg0 | 4 |
| 44 | i32 | arg1 | 4 |
| 48 | i32 | payload_offset | 4 |
| 52 | i32 | payload_length | 4 |
| 56 | i32 | flags | 4 |
| 60 | i32 | reserved_zero | 4 |

Command stride is 64 bytes `[DERIVED sum]`. Variable payloads contain full selection ID lists, schedule bytes, zone tiles, recipe orders, or sanitized aliases; the payload schema is selected by the command kind. **The individual per-kind schemas are not stated here.** The six kinds with an implemented owning store take theirs from decision 0043, which prints the envelope-field and payload layout of DESIGNATE_ZONE, SET_POLICY, SET_JOB_PRIORITIES, SET_ACTIVITY_SCHEDULE, NAME_RESIDENT and CANCEL_JOB; the other eighteen have none, and `godot/scripts/core/command_dispatch.gd` refuses them with an explicit unsupported-feature result rather than inventing one `[NEW; decision 0043]`. Use an append-only replay stream and a 4096-command in-memory queue plus a 1048576-byte payload arena `[NEW]`. Queue overflow refuses additional edits with an explicit UI error; accepted commands are never dropped. Settlement ticks use int64, unlike the crowd's 48-byte command record with int32 tick; direct binary reinterpretation is prohibited.

**ARCH-CMD-003.** Command kinds `[NEW sorted ASCII domain]` are ACCEPT_CANDIDATES, APPOINT_WARDEN, ASSIGN_BED, CANCEL_JOB, CANCEL_MANUAL, CONFIRM_FEAST, DEMOLISH, DESIGNATE_ROOM, DESIGNATE_ZONE, EDIT_ORDER, EQUIP, NAME_RESIDENT, PLACE_BLUEPRINT, PLACE_FURNITURE, REQUEST_RELIEF_SEEDS, SET_ACTIVITY_SCHEDULE, SET_DOOR_OPEN, SET_FIELD_ROTATION, SET_JOB_PRIORITIES, SET_MANUAL_TASK, SET_POLICY, SET_STORE_FILTER, SET_STORE_MINIMUM, UPGRADE. Compile IDs from this exact list; reject unknown kinds. Kind-specific payloads use the original component field types, count first followed by owner-ID-sorted rows; all IDs must validate before committing any member of a group. `[GDD §4.2; UI §5; NEW command domain]`

*Implementation note 2026-09-10 (decision 0042).* The domain is compiled in `godot/scripts/core/catalog.gd` as `CommandKind` and is therefore carried by `godot/data/catalog_ids.json`, whose canonical bytes moved from 2588 to 3064 and whose SHA-256 moved from `73d34d26af1f690261957ef27c0e5a14a5462d5d57b2f55a84b69e5fa900a3bd` to `00e3ffd5c98b5f5da050cc13be91895b85744eb3b3f3cfb5e50dde85a598cbf1`. That is an intentional catalog/schema change, not a parity result. ARCH-CMD-002's speed/pause events are still absent from the domain, as task 04.1 requires. The 24 ids are `ACCEPT_CANDIDATES=0 ... UPGRADE=23` in the printed order, which is already the ASCII order. The queue itself is `godot/scripts/core/commands.gd`; the per-kind payload schemas are NOT specified anywhere and are not implemented there.

| Save header offset | Encoding | Meaning | Bytes |
|---:|---|---|---:|
| 0 | ASCII | Magic RWLSET01 | 8 |
| 8 | u32 | Format version 2 (SAVE-REPLAY-R01) | 4 |
| 12 | u32 | Header bytes 264 | 4 |
| 16 | u32 | Endian sentinel 16909060 | 4 |
| 20 | u32 | Section count | 4 |
| 24 | u64 | Total file bytes | 8 |
| 32 | i64 | Completed tick | 8 |
| 40 | SHA-256 bytes | Rules hash | 32 |
| 72 | SHA-256 bytes | Catalog hash | 32 |
| 104 | SHA-256 bytes | Map hash | 32 |
| 136 | SHA-256 bytes | Integer lookup-table hash | 32 |
| 168 | SHA-256 bytes | Engine patch/build identity hash | 32 |
| 200 | u64 | Section table offset, always 264 | 8 |
| 208 | u64 | Chronicle record count | 8 |
| 216 | u32 | Next economic admission sequence low word | 4 |
| 220 | u32 | Reserved zero | 4 |
| 224 | u64 | Next economic admission sequence high word | 8 |
| 232 | SHA-256 bytes | Body digest over table plus section bytes | 32 |

SAVE-REPLAY-R01 ([contract](planning/replay_checkpoint_contract.md), decision0156) defines the header pair as a redundant next-admission checkpoint, exactly equal to section12, including exhausted high4294967296/low0. The header is264bytes; body/table SHA-256 begins264 and does not protect the header pair. Before world mutation, cross-check it against section12 and completed tick against section1, then require canonical verification. Format1 refuses without migration. This new header change supersedes the earlier outer1 rule, not the rejected scheduler-only version2 proposal. Full-file orchestration remains incomplete.

Each section descriptor is 64 bytes: `section_id:u32, schema_version:u32, offset:u64, byte_length:u64, row_count:u64, crc32:u32, flags:u32, reserved_zero:24 bytes` `[NEW]`. CRC is CRC-32/ISO-HDLC: polynomial reversed 3988292384, initial register 4294967295, reflected bytes, final XOR 4294967295; check vector ASCII `123456789` gives 3421780262 `[NEW codec choice]`. SHA-256 protects the complete canonical body; CRC localizes corruption. The body checksum does not protect header bytes. Validate header structure and identity bindings separately; cross-check its completed tick with section1 and its checkpoint pair with section12. Their authoritative values enter canonical state through those owners, not through a duplicate header record. Full canonical verification is still required before publication.

**ARCH-SAVE-002.** Section IDs are assigned in this exact order `[NEW]`: 1 WORLD, 2 CATALOG_IDS, 3 ENTITY_DIRECTORY, 4 COMPONENT_COLUMNS, 5 CHILD_ARENAS, 6 AUXILIARY_STATE, 7 INVENTORIES_AND_LEASE_INDEXES, 8 JOB_INDEXES, 9 NAVIGATION, 10 RNG, 11 EVENT_SCHEDULE, 12 PENDING_COMMANDS, 13 CHRONICLE, 14 NAME_POOL, 15 STATE_DIGEST. For each store serialize its occupancy and explicitly persisted fields COLUMN-MAJOR: declared field order outside,
ascending physical slot inside, using [SAVE-LAYOUT-R01](rulings/2026-09-12_clock_restore_and_layout_followup.md)
for sections3/4/5/10 framing and explicit fixed-record exceptions. Where that store owns generations, preserve all of them including free/retired slots; directory mirrors validate against their owner. Inventory container, inventory lot and navigation route generations remain distinct from directory generations. Index-addressed gear/reservation rows preserve slots and holes without invented generations or compaction (decision 0063). Encode each field's DECLARED canonical unused value (including-1 null slots),
not blanket zeroes; preserve generations and allocator-retirement state. Child arrays use owner ascending then child index; explicit variable lengths precede data. Save allocator heaps or rebuild them deterministically from occupancy and retired masks; active lists are rebuilt ascending.

**ARCH-SAVE-007 (2026-09-11, classification ruling).** Completed command-dispatch
outcomes/ring cursors are transient presentation output: omit them from section 6
and canonical state. Source-intent deduplication remains persisted/hashed section 6
state. `InventoryContainer.reachable` is persisted/hashed in section 7; no current
rebuild owner exists. Section 1 also persists host debt and the six recorded clock
counters as nonnegative I64 host-continuation/evidence metadata. These fields are
excluded from ARCH-HASH-001 but included in section CRC and body SHA-256. Reset
host timestamps at load; restore owed debt unchanged. Persistence, canonical
hash inclusion and cross-speed gameplay projections are distinct dimensions;
[the G1–G3 ruling](rulings/2026-09-11_ready07_save_ui_addendum.md) owns their exact
membership and acceptance. This assigns section ownership; task 09.2 still owns
its explicit field byte offsets/schema. A memory allocation row alone does not
make a field persisted or canonical; apply the explicit owning contracts.

**ARCH-SAVE-009 (2026-09-14, [R-WORLD-S1-001](rulings/2026-09-14_world_section_owner_encoders.md)).**
Section 1 WORLD carries EXACTLY NINE owner blocks in strict ASCII key order -- `buildings`,
`entity_directory`, `farming`, `forage`, `resource_nodes`, `spatial_world`, `weather`,
`world_init`, `world_runtime` -- and a missing block is not a permitted variant. The section is a
44-byte map-provenance prefix, `store_count:u32 = 9`, then blocks tiling the remainder with no gap,
overlap or trailing byte; each wrapper occupies `24 + len(owner_key)` bytes. Seven owners use the
ordinary payload form `element_count:u64` then `element_count * type_width` value bytes per field in
declared ordinal order, with an explicit `element_count = 1` on every scalar; `entity_directory`
(4 bytes) and `world_runtime` (80 bytes) keep their existing fixed formats and carry no count
prefixes. Count prefixes are structural bytes and produce no canonical field record. Payloads total
3752409 bytes, wrappers 311, section length **3752768**, first body offset **1224**, section 2 at
**3753992** (SAVE-REPLAY-R01 relocates file positions by8; body bytes unchanged), and the section descriptor's `row_count` is the checked SUM of the nine block primary
counts, **344067** -- not a population, a field count or a canonical record count. `world_init`
declares primary_count 16384 and `spatial_world` 262144 despite their scalar fields; `weather`
declares 1 for its one aggregate row of eight i32 and two i64 values.

The same activation reclassifies `resource_nodes._deposit_tiles`, `._deposit_ref_slot` and
`._deposit_ref_generation` as CATEGORY-3 operation scratch: they describe one placement in progress,
not a deposit registry, so they contribute no save payload and no canonical field record.
`resource_nodes` therefore takes owner schema **2** and section 1 takes schema **3**; the other
eight §1 owner versions stay 1 and no other section's block owned by the same module changes. Older


**ARCH-SAVE-008.** [SAVE-R09-001–005](rulings/2026-09-11_save_codec_contract.md)
now owns outer/section versions, u32 string prefixes, exact identity artifact
framing/producers, the gapless15-section layout and sections11/13/15 ownership.
These extend §8.1–8.2; section12 is schema2 within outer format1, with no implicit
migration. Section11 owns the already-budgeted WorldRuntime.next_event_sequence;
no duplicate scalar or extra8-byte allocation is added. Map provenance metadata
and identity artifacts require measured ledger updates by their implementation
owners. Section13 detail_key is a compiled ChronicleDetail i32 catalog ID.
The production codec, missing producers and expanded MOVE-G02 schema remain work.
STATE-COHORT-R01 removes rollback scratch from persistence; host debt/counter
persistence and digest exclusions under ARCH-SAVE-007 are unchanged.

**ARCH-ART-001.** Settlement visual authoring uses
[ART-GAP-R01–05](planning/asset_dimensions_and_budgets.md): exact building-height
ceilings, non-creature budgets and a64px nominal L0 admission threshold with cap24.
This specializes ARCH-GODOT-001 and crowd battle thresholds for settlement only.
Visual measurements never set authoritative movement clearance. All new budgets
are targets pending measurement, not minimum-hardware qualification.

## 2026-09-12 restore, layout and movement identity bindings

[RESTORE-R01 / SAVE-LAYOUT-R01](rulings/2026-09-12_clock_restore_and_layout_followup.md)
own one atomic ten-scalar clock restore, no operational setter replay, guarded
publication/rollback, explicit column-major bytes and fixed-record exceptions.
These supplement ARCH-SAVE-003/004/008 and ARCH-HASH-001; canonical unused values
follow owner schemas, including nonzero sentinels. Header/section validation and
actual production continuation remain implementation work.

[MOVE-DEP-R01–05](rulings/2026-09-12_movement_dependency_rulings.md) names the asset,
resident, rig, graph and contact owners. Required NEW packed payload deltas are
512bytes Resident.life_stage,4bytes starter-profile life_stage,6144bytes captured
destination ref/contact key:6660bytes total before separately counted transient
records or immutable catalog contents. Add them to measured ledger/registry only
with implementation, once; they do not erase earlier uncounted obligations.
Affected owner/section versions and identities change before accepting saves.
These contracts do not close full MOVE-G01/G02/G04 or task08 dependent simulation.

## Resident UI contract follow-up — 2026-09-12

NEED-RATE-R01 adds four public non-allocating rate readers, reusing existing
selector semantics for selected-resident snapshots while retaining one-pass tick
integration. No new authoritative cache or packed state is introduced. It does
not change GDD §5.2 formulas, remainder arithmetic or pause behavior.
Read [the exact ruling](rulings/2026-09-12_resident_header_and_need_rates.md).
## SET-MOVE-ECON-001 integration boundary

[The numerical amendment](underground_economy_hazard_amendment.md) supplies economic quanta, phase/refund/source semantics and hazard recovery values; it does not allocate new runtime arrays or set a save version. G02 must ledger physical quantum state, material/source claims, work-ready commit retries, tip embedded stock, support/closure readiness, contributor wear settlement, air/recovery/incident state, declared fall progress, rescued-body relationships, protected landing occupancy and care state, including all scratch/load peaks. Compose work/XP/tool acceptance atomically and integrate health rates in one owner. Do not multiply old surface memory by a floor count and claim full capacity; version actual schema/catalog changes before runtime activation.

## Cycle 1 owner-contract addendum — 2026-09-14

INIT-POSE-R01 amends ARCH-SYS-001 composition: the settlement owns the single
directory-bound Transform store; the renderer borrows it. Starter root placement
is authored in GDD §5.1. See [the complete contract](rulings/2026-09-14_initial_resident_positions.md).

R-WORLD-S1-001 completes ARCH-SAVE-002 / REG-R01's WORLD owner framing and
corrects three ResourceNodes deposit scratch fields. Its
[owner schemas and validation](rulings/2026-09-14_world_section_owner_encoders.md)
are adopted targets for atomic implementation, not evidence that the current
registry or codecs already implement them. Existing allocation ledger rows stay
in force until the allocations are actually removed. Neither ruling closes
movement gates, save completeness, performance qualification or visual acceptance.
