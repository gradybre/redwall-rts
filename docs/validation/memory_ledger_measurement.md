# ARCH-MEM-010 measured against the code — first measurement

Date: 2026-09-11 · Status: Evidence. **Nothing in `systems_architecture.md` is changed by
this document.** Every divergence below is reported for hand reconciliation, per
[ADR 0067](../decisions/0067-the-memory-ledger-is-measured-not-asserted.md).

Harness: `godot/tools/memory_ledger_probe.gd`, `godot/tools/memory_ledger_rows.gd`,
`godot/tools/measure_memory_ledger.gd`. Reproduce with:

```
godot --headless --path godot --script tools/measure_memory_ledger.gd
```

Engine: Godot 4.7.2.stable.official.ed1daf0bf, macOS arm64. Every ledger figure below is
stable across repeated runs; the two absolute static-memory lines move by a few kilobytes
run to run, which is why they are reported as a labelled delta and not as a row.

Measured after merging `origin/master` at `a34afb0` (which brought decision 0062's state
registry and a `world_init.gd` change; neither moved any figure here).

## 0. What "measured" means here, and what it does not

**Allocated, not resident.** Every figure in the per-row table is the payload a store's
packed arrays were *sized to hold*, read from each array's own `size()` after `_init()`
returned. It is not resident set size. Godot's `CowData` prefixes every buffer with a
reference count and a size field, the allocator rounds, and the OS maps pages lazily; none
of that is in the ledger's rows either, which is exactly why the comparison is apples to
apples. §2.3's separate 8388608-byte "Allocator/object reserve" row is what the document
sets aside for that difference, and it is reported separately below.

**Bytes per element are measured, not assumed.** The ledger's arithmetic rests on "a
`PackedInt32Array` of N costs 4N". The harness does not take that on trust: it allocates
2097152 elements of each packed type and divides the process's own
`OS.get_static_memory_usage()` delta by the element count.

| Container | §2.3 assumes | Measured | Raw delta for 2097152 elements |
|---|---:|---:|---:|
| `PackedByteArray` | 1 | **1** | 2097208 |
| `PackedInt32Array` | 4 | **4** | 8388664 |
| `PackedInt64Array` | 8 | **8** | 16777272 |
| `PackedFloat32Array` | 4 | **4** | 8388664 |
| `PackedFloat64Array` | 8 | **8** | 16777272 |
| `PackedVector2Array` | 8 | **8** | 16777272 |
| `PackedVector3Array` | 12 | **12** | 25165880 |
| `PackedColorArray` | 16 | **16** | 33554488 |
| `Array[StringName]` | 8 | **24** | 50331672 |

The 56-byte residue in each delta is the fixed `CowData` header. The packed model is
confirmed. The `Array` assumption is not — see row 14.

**One world, not one instance per store.** Most stores build a private collaborator when
handed `null` (`jobs.gd` builds its own Residents; `ecology.gd` its own directory). A list
of `new()` calls would silently have measured four `EntityDirectory` instances. The harness
wires one composition explicitly, then walks the object graph and dedupes by
`Object.get_instance_id()`. Measured duplicate instances: **none**.

## 1. Per-row: declared vs measured

24 rows, transcribed verbatim from §2.3. The transcription's own sum reproduces §2.3's
printed **60821078** exactly, so the rows below are the document's rows and not a variant
of them.

| # | Row | Declared | Measured | Delta | Basis |
|---:|---|---:|---:|---:|---|
| 1 | Fixed registry payload | 25028962 | *see residual* | — | see §2 |
| 2 | Auxiliary payload | 17232732 | *see residual* | — | see §2 |
| 3 | Static navigation map | 3670016 | 3670016 | **0** | 5 columns of `spatial_world.gd` |
| 4 | Active A* builder | 5505024 | 5505024 | **0** | 6 columns of `navigation.gd` |
| 5 | Route cell arena | 4194304 | 4194304 | **0** | `navigation._arena` |
| 6 | Route descriptors | 16384 | 16384 | **0** | 16 `_d_*` columns of `navigation.gd` |
| 7 | Path request records | 524288 | 524288 | **0** | 16 `_r_*` columns of `navigation.gd` |
| 8 | Spatial heads | 65536 | **0** | **−65536** | no column exists anywhere |
| 9 | Resident motion/separation scratch | 32768 | 32768 | **0** | 16 motion columns of `movement.gd` |
| 10 | Command queue | 262144 | 262144 | **0** | 15 record columns of `commands.gd` |
| 11 | Command queue order index | 16384 | 16384 | **0** | `commands._order` |
| 12 | Command payload arena | 1048576 | 1048576 | **0** | `commands._payload` |
| 13 | Command result ledger | 147456 | 147456 | **0** | 8 `_result_*` columns of `command_dispatch.gd` |
| 14 | Command result store codes | 32768 | **98304** | **+65536** | 4096 `Array` elements at a measured 24 bytes |
| 15 | Command payload decode scratch | 65540 | 65540 | **0** | `command_dispatch._payload` |
| 16 | Command dispatch source-intent ledger | 2048 | 2048 | **0** | 4 `_intent_*` columns |
| 17 | Tick event ring | 262144 | **UNATTRIBUTED** | — | no allocating code found |
| 18 | Read-only catalog/lookup budget | 2097152 | **UNATTRIBUTED** | — | no allocating code found |
| 19 | I/O streaming buffers | 262144 | **UNATTRIBUTED** | — | no allocating code found |
| 20 | UI numeric snapshots | 131072 | **UNATTRIBUTED** | — | no allocating code found |
| 21 | Timing samples | 55200 | **168** | **−55032** | 3 columns of `settlement_system.gd` |
| 22 | World generation map masks and tree plan | 159968 | 159968 | **0** | 15 columns of `world_init.gd` |
| 23 | Scheduler event queue and control header | 8224 | **8192** | **−32** | 7 columns of `scheduler_events.gd` |
| 24 | ARCH-SYS-023 presentation snapshot | 244 | 244 | **0** | 4 columns of `presentation_extract.gd` |

**Sixteen of the twenty-two measurable rows are exactly right, to the byte.** Where the
ledger describes a subsystem that exists, its arithmetic is almost always correct — and it
is correct in both directions, including awkward figures like 65540 and 244.

### The six that are not

**Row 8 — Spatial heads, 65536 declared, 0 allocated.** No column of 16384 `i32` heads
exists in `movement.gd`, `spatial_world.gd` or anywhere else. `movement.gd` allocates the
per-resident links (`_grid_cell`, `_grid_next`, 512 rows each) that would index such a
table, but not the table. The cause is stated in `movement.gd`'s own header: "NO
SEPARATION. `correction_x`/`correction_z` stay zero; bounded soft separation needs the
domain-local Jacobi pass and body radii that the MOVE-G01 parameter pack has not
supplied." This is a *not yet*, not an error in the row.

**Row 14 — Command result store codes, 32768 declared, 98304 allocated.** The only row
where the ledger **understates by a factor of three**. Its derivation reasons that
"assigning an interned name is a reference copy, not an allocation", and budgets 8 bytes
per element. `command_dispatch.gd` holds these in `var _result_store_code: Array[StringName]`,
and a GDScript `Array` is a vector of `Variant`, not of references: measured at 24 bytes
per element (50331672 bytes for 2097152 elements). 4096 × 24 = 98304. The reasoning about
interning is correct — the *name* is not copied — but the slot that holds it is a Variant.
This figure is also **not** inside the 44254212 measured total below, which counts packed
columns only; it is reported separately as `array_container_bytes_excluded_from_total`.

**Row 21 — Timing samples, 55200 declared, 168 allocated.** §2.3 sizes this as 6900 i64
samples across 23 stages. `settlement_system.gd` allocates `_stage_usec`,
`_stage_usec_total` and `_stage_measured` at 7 entries each — 168 bytes, which is what the
ARCH-SYS-023 row's own note says sits inside this row. There are 7 stages instrumented,
not 23, and one sample per stage rather than 300. The row is a plan; the code is a
seventh of it.

**Row 23 — Scheduler event queue, 8224 declared, 8192 measured.** The 8192 bytes of
records match exactly. The remaining 32 bytes are the queue control header, which
`scheduler_events.gd` keeps as ordinary scalar members (`_head`, `_count`, sequence halves,
last-drained boundary, last-applied sequence halves), not as a packed buffer. **This row's
last 32 bytes cannot be measured by this method** and are reported as such rather than as a
shortfall: they are real state, they are simply not a packed allocation. Note that in a
GDScript object each such member occupies a `Variant` slot, so the header's true cost is
nearer 7 × 24 bytes than 32 — the ledger's C-struct model does not describe GDScript here.

**Rows 17–20 — 2752512 declared bytes with no implementing code at all.** Tick event ring
(262144), read-only catalog/lookup arenas (2097152), I/O streaming buffers (262144) and UI
numeric snapshots (131072). All four are marked `[NEW]` in §2.3 and none has been built.
`catalog.gd` holds `const Dictionary` enum tables and allocates no arena;
`item_definitions.gd` reaches its capacity lazily on load and allocates **zero** bytes in
`_init()`. These are reported as UNATTRIBUTED, never as measured zero: "no store allocates
this" and "this store allocates nothing" are different findings.

## 2. Rows 1 and 2: what cannot be measured separately, and why

"Fixed registry payload" (25028962) is the mechanical sum of §2.2's 141 field rows;
"Auxiliary payload" (17232732) is the sum of §3's 37 tables. Together, **42261694**.

They cannot be measured apart. **No column in the codebase is marked with the section that
budgets it.** `jobs.gd` holds §2.2's `Job` fields and §3's `JobRuntime`, `JobPresence`,
`JobDirectoryRef`, `JobSelection`, `JobLiveIndex` and `JobAgentRuntime` in one flat set of
48 members with no separator. The docstring citations that do exist are uneven: measured on
2026-09-11, 19 of the 36 scripts in `godot/scripts/core/` mention either section at all,
`ecology.gd` and `crop_weather.gd` among those that do not. Splitting the residual between
the two rows would therefore be a guess, and it is not made here.

Measured together:

| | Bytes |
|---|---:|
| Declared (rows 1 + 2) | 42261694 |
| Measured residual (all packed payload not claimed by rows 3–24) | **28600708** |
| Delta | **−13660986** |

The residual is **32.3% short** of the two rows. That is not a ledger error: it is
unbuilt schema. Spot checks confirm the direction in both senses —

| Declared component | Declared | Measured | Verdict |
|---|---:|---:|---|
| §2.2 `EntityIdentity` (`entity_directory.gd`) | 4581434 | 4581434 | exact |
| §2.2 `Transform` + §3 `TransformBinding` (`transforms.gd`) | 3151872 | 3151872 | exact |
| §3 `TileHistory` (`farming.gd` `_tile_*`) | 737280 | 737280 | exact |
| §3 `PathRequestContact` (`navigation.gd` `_c_*`) | 163840 | 163840 | exact |
| §3 `ResidentRouteCursor` (`movement.gd` `_cursor_*`) | 6144 | 6144 | exact |
| §3 `DirectoryIndex` (`entity_directory.gd`) | 9162868 | 5991322 | **short 3171546** |

`DirectoryIndex` declares `transform_row`, `active_index` (2 × 352418 i32) and a `dirty`
byte column that `entity_directory.gd` does not allocate — 3171762 bytes — while allocating
216 bytes of per-kind bookkeeping (`_kind_base`, `_kind_free_count`, `_kind_live_count`,
18 entries each) that the row does not declare. Net −3171546.

## 3. Per-store measured payload

Raw evidence for hand reconciliation. `claimed` is the part a §2.3 subsystem row accounts
for; `unclaimed` is what falls into the rows 1+2 residual.

| Script | Columns | Allocated | Claimed by rows 3–24 | Unclaimed |
|---|---:|---:|---:|---:|
| `core/command_dispatch.gd` | 13 | 215044 | 215044 | 0 |
| `core/commands.gd` | 18 | 1327104 | 1327104 | 0 |
| `core/crop_weather.gd` | 0 | 0 | 0 | 0 |
| `core/ecology.gd` | 0 | 0 | 0 | 0 |
| `core/entity_directory.gd` | 12 | 10572756 | 0 | 10572756 |
| `core/farming.gd` | 26 | 1019904 | 0 | 1019904 |
| `core/field_policy.gd` | 20 | 44288 | 0 | 44288 |
| `core/fishing.gd` | 31 | 18400 | 0 | 18400 |
| `core/forage.gd` | 40 | 794240 | 0 | 794240 |
| `core/gear.gd` | 13 | 753664 | 0 | 753664 |
| `core/inventory.gd` | 37 | 7981312 | 0 | 7981312 |
| `core/item_definitions.gd` | 6 | 0 | 0 | 0 |
| `core/job_planner.gd` | 35 | 389120 | 0 | 389120 |
| `core/jobs.gd` | 48 | 884344 | 0 | 884344 |
| `core/movement.gd` | 19 | 38912 | 32768 | 6144 |
| `core/navigation.gd` | 44 | 10403840 | 10240000 | 163840 |
| `core/needs.gd` | 21 | 56896 | 0 | 56896 |
| `core/orchard_hive.gd` | 33 | 356472 | 0 | 356472 |
| `core/presentation_extract.gd` | 4 | 244 | 244 | 0 |
| `core/priorities.gd` | 4 | 7680 | 0 | 7680 |
| `core/reservations.gd` | 15 | 1966080 | 0 | 1966080 |
| `core/residents.gd` | 18 | 96832 | 0 | 96832 |
| `core/resource_catalog_binding.gd` | 0 | 0 | 0 | 0 |
| `core/resource_nodes.gd` | 15 | 254144 | 0 | 254144 |
| `core/rng.gd` | 2 | 108 | 0 | 108 |
| `core/schedule.gd` | 7 | 17992 | 0 | 17992 |
| `core/scheduler_events.gd` | 7 | 8192 | 8192 | 0 |
| `core/sim_clock.gd` | 0 | 0 | 0 | 0 |
| `core/spatial_world.gd` | 5 | 3670016 | 3670016 | 0 |
| `core/transforms.gd` | 9 | 3151872 | 0 | 3151872 |
| `core/weather.gd` | 2 | 48 | 0 | 48 |
| `core/work.gd` | 10 | 47104 | 0 | 47104 |
| `core/world_init.gd` | 25 | 175364 | 159968 | 15396 |
| `systems/settlement_system.gd` | 5 | 2240 | 168 | 2072 |

`world_init.gd`'s 15396 unclaimed bytes are 15360 of `FaunaStockReserved` — which its §2.3
row explicitly and correctly excludes, because §2.2 already carries it — plus a 36-byte
`_staged_fish_item_ids` column that appears in neither table.

Eleven of these 33 core stores are not composed by the `SettlementSystem` autoload at all
today — `spatial_world`, `navigation`, `transforms`, `movement`, `gear`, `inventory`,
`field_policy`, `scheduler_events`, `world_init`, `resource_catalog_binding`,
`item_definitions` — and the report's `in_autoload_world` column marks them. They account
for **26227460** of the 44254212 measured bytes. The running process therefore allocates
about **18026752** bytes of settlement columns today, including `settlement_system.gd`'s
own 2240. The harness builds all of them anyway, because the ledger budgets for one whole
world and that is the thing under test.

### 3.1 Two columns the ledger has no byte model for

`residents.gd` declares two `PackedStringArray` columns. `state_registry_coverage.py`
records their element width as `var`, and §2.3's arithmetic has no row shape that can hold
a variable-width element, so they are excluded from every total above and reported here
instead.

| Column | Slots | UTF-8 content at construction | Measured cost of an empty slot |
|---|---:|---:|---:|
| `residents._species_key` | 16 | 93 | 8 bytes |
| `residents._name_key` | 512 | 0 | 8 bytes |

The empty-slot cost is measured the same way as every other width: 2097152 empty slots
against the static-memory delta, giving 8 bytes each (a pointer to the shared empty
`String`). A populated slot costs that plus its own `String` buffer.

**`_name_key` is not the shape §2.2 and §3 budget for.** §2.2's `Resident` row lists
`name_key` among eight `i32` columns — an index — and §3 budgets `NamePoolUtf8` (131072)
and `NamePoolIndex` (49152) as the arena those indices point into. The code stores the
`String` itself and has no pool. Today that is *cheaper* (4096 bytes of empty slots against
180224 budgeted), but it is a different design, and 512 live 2–32-character names would not
land on the budgeted figure either. This is reported, not resolved: it is a schema question
for §2.2 and §3, not an arithmetic error in §2.3.

### 3.2 Cross-check against the state registry

`docs/persistence_state_registry.md` (decision 0062) declares a width and a count for every
packed column group under `godot/scripts/core/`, and `state_registry_coverage.py` enforces
that the count cell quotes the module's own `resize()` expression. That is a **static** claim
about source text. This harness makes a **runtime** one: what the array's `size()` actually
is once `_init()` has returned. They are different claims and can disagree — a `resize()`
that never runs, runs twice, or runs with a different argument would pass the static check
and fail this one.

They do not disagree. Comparing the registry's declared `width x count x members` against
the measured bytes of the same members, column group by column group:

| | Rows |
|---|---:|
| Registry rows with a resolvable width and count | **214** |
| Agreeing exactly with the live arrays | **214** |
| Disagreeing | **0** |
| Rows whose count is not a resolvable number | 3 |

The three unresolvable rows are consistent with the rest of this document rather than gaps
in it: `commands.gd`'s `_no_refs` is declared "never allocated" and measures length 0, and
`item_definitions.gd`'s two "`count` runtime" rows are the lazily-loaded catalog that
allocates nothing in `_init()`. The registry independently calls the same two things
unsized that this harness independently measured at zero.

On population, the same agreement holds: `state_registry_coverage.py` counts **541**
declared packed columns across 36 core modules; this harness measured **539** live in those
modules, plus 5 in `settlement_system.gd` which the registry's `core/`-only scope excludes.
The difference of two is exactly the `PackedStringArray` columns in §3.1, which this harness
excludes by type.

## 4. Process-level total

| Figure | Bytes | What it is |
|---|---:|---|
| Measured allocated payload | **44254212** | Sum of every packed column of one wired world |
| `Array` container bytes, excluded above | 98304 | Row 14's store codes at the measured 24 B/element |
| Static-memory delta across building the world | **44976308** | `OS.get_static_memory_usage()` before → after |
| Allocator overhead above payload | 722096 | 1.63% — `CowData` headers, allocator rounding, the 34 script instances |
| §2.3 declared payload | 60821078 | |
| Measured minus declared | **−16566866** | 27.2% under |
| §2.3 allocator/object reserve | 8388608 | |
| §2.3 one live world plus reserve | 69209686 | |
| REQ-SET-163 budget | 100000000 | |

`OS.get_static_memory_usage()` counts memory obtained through Godot's own static allocator
(`Memory::alloc_static`), which is where every packed array's buffer comes from. It does
**not** include: the engine's own static and global data, memory taken by third-party
libraries through plain `malloc`, GPU allocations, or any page the OS has not yet backed.
It is therefore the right instrument for "did the packed columns cost what we said" and the
wrong one for "how big is the process". The delta form used here — before minus after
around the world construction — is what makes it attributable at all; the absolute process
figure at the end of a run (~121 MB) is dominated by the engine and the autoloads and says
nothing about the ledger.

**The ~722000-byte overhead is the headline resident-versus-allocated result.** It varies by
a few kilobytes between runs, which is itself informative: this is allocator behaviour, not
a fixed quantity. The reserve row budgets 8388608 bytes for exactly this and over-provides
it by about 11.6x, on this platform, for the stores that exist today.

## 5. Answer: is 60821078 true?

**As arithmetic about the document, yes. As a description of the running program, no —
it is 27.2% too high, and it is too high for four separable reasons, none of which is an
arithmetic error.**

1. 2752512 bytes across four rows describe subsystems nobody has written (rows 17–20).
2. 65536 bytes describe a spatial-heads table that movement deliberately does not build,
   for a reason recorded in its own header and gated behind MOVE-G01.
3. 55032 bytes are a timing plan seven-twenty-thirds implemented.
4. 13660986 bytes are §2.2/§3 schema not yet in code — the bulk of it, and the honest
   reading is "the registry is about two-thirds built", not "the ledger is wrong".

Against that, **one row is understated**: the command result store codes cost 98304 rather
than 32768, because a GDScript `Array` element is a 24-byte `Variant` and not an 8-byte
reference. That single wrong assumption is the only case found where the ledger would
under-budget real memory, and it is the one worth acting on, because the same reasoning
would repeat wherever a future row budgets an `Array` of interned names.

Two further cautions on the same theme:

- The ledger's C-struct model of a "control header" (row 23's 32 bytes) does not describe
  GDScript scalar members either. It is small here; it would not stay small if the pattern
  were repeated per entity.
- Nothing measured here says anything about the **transactional two-world peak**
  (123815180, over budget by 23815180) beyond confirming that its inputs are the same
  arithmetic. That conflict, ARCH-CONFLICT-011, is untouched by this measurement.

The one-world gate (69209686 against 100000000) is not at risk from anything found here.
The direction of every unimplemented item is upward, so the measured 44254212 will rise
toward 60821078 as the schema is built — but the measured allocator overhead of 1.62%
means the 8388608-byte reserve remains generous at that destination too.

## 6. What could not be measured

| Item | Why |
|---|---|
| Rows 1 and 2 separately | No column in the codebase is marked §2.2 or §3; see §2 |
| Row 23's last 32 bytes | The queue control header is scalar members, not a packed buffer |
| Rows 17–20 | No implementing code exists to measure |
| Resident set size | This harness measures allocation; RSS needs an OS-level probe and a running simulation, not a construction-time delta |
| Allocator behaviour on the qualification floor | Measured on macOS arm64 with Godot 4.7.2; the 1.63% overhead figure is platform-specific |
| `PackedStringArray` payload | It has no fixed element width; only slot count and current UTF-8 content are measurable. See §3.1 |
