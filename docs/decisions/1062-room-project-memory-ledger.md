# 1062 — Reconcile room project state and declaration memory
Date: 2026-10-02 · Status: Accepted

## Decision

Include decision 1053's eleven `RoomProjects` packed columns and decision 1060's
additional canonical declaration data in the current architecture memory ledger.
Keep the decimal 100,000,000-byte simulation gate and 8,388,608-byte allocator
reserve unchanged. This is source arithmetic, not a RAM measurement or completion
of UG16/17 memory and save qualification.

## Source proof

At integration `bb557d1b6bc3a97fe8bd566dbc114a8dbf0965fc`,
`room_projects.gd::_allocate_columns` allocates:

| Columns | Capacity | Bytes |
|---|---:|---:|
| Three byte columns: presence, pause reasons, revision state | 82944 | 248832 |
| Four int32 columns: project reference pair, room type, revision epoch | 82944 | 1327104 |
| Four int32 columns: Job reference pair and its project reference pair | 8192 | 131072 |
| Total mutable packed payload | | **1707008** |

The capacities alias the existing `Construction.CONSTRUCTION_CAPACITY` and
`Jobs.JOB_CAPACITY`. These are additional adapter allocations: neither
Construction's `paused` byte nor its paid ledger is removed or credited back.
All eleven columns also appear in canonical owner `room_projects`; no field is
reclassified or omitted to satisfy the memory check.

`canonical_state_hash.gd::Declaration` has four int32 buffers per owner and
three byte buffers, one int64 buffer and one int32 buffer per declared field.
Its numeric payload is therefore 16 bytes per owner and 15 per field. The two
key arrays hold logical UTF-8 text in addition. The current census is 53 owners,
623 declared fields, 615 hashed records, 566 persisted packed source fields and
9236 UTF-8 key bytes: `53*16 + 623*15 + 9236 = 19429` bytes. The preceding
declaration row was 19077 bytes; the increase is exactly 352:
`1*16 + 11*15 + 171`. It is shared once, including in the rejected two-world
comparison. String and object headers, native storage and allocator behavior
are excluded from this logical payload and still require measurement.

| Current declared quantity | Before | After |
|---|---:|---:|
| Auxiliary payload | 25595632 | 27302640 |
| Shared canonical declaration | 19077 | 19429 |
| Planned allocated payload | 70961952 | 72669312 |
| One world plus reserve | 79350560 | 81057920 |
| Arithmetic headroom below 100 MB | 20649440 | 18942080 |
| Additional candidate mutable state | 64716755 | 66423763 |
| Rejected two-world peak plus reserve | 144067315 | 147481683 |

The net declared increase is 1707360 bytes. The rejected two-world peak rises by
3414368: two copies of 1707008 mutable bytes plus 352 shared declaration bytes.
The whole modular underground composition remains unqualified; future site and
space owners, RoomLayout, geometry caches and their peak lifetimes need their
own accounting and runtime evidence.

## Proof-chain repairs

The running trail stopped at decision 0996 although the allocation total
already included decisions 1022/1023's 231564 bytes. Restore that omitted trail
row without adding its bytes again. Retain all historical steps. The earlier
printed auxiliary subtotal 20144096 likewise remains as labeled history; the
current auxiliary total now names the sum of every numeric §3 row.

`ready07_arithmetic.py` reads the actual RoomProjects declarations, allocation
expressions and aliased source constants, compares their types/capacities to the
canonical owner, and requires the three exact printed ledger rows. It also
requires the running trail's final payload/reserve pair and printed auxiliary
subtotal to match the independently summed allocations. Existing row arithmetic,
double-budget, historical increment and budget checks remain intact. Future
growth still fails until its source and ledger are reconciled.

Future arithmetic reports label the original READY_07 revision as historical,
record the current input hashes and expose both new byte totals. Existing
historical reports and runtime measurements are unchanged.

## Validation

Before this correction, all 32 commands from the CI **Specification contracts**
job were run independently: 31 passed, and the memory arithmetic failed on its
old 52-owner/612-field/9065-key-byte pin. After correction, all **32 commands
passed**. The arithmetic summary reports `PASS`, 145 fixed-field rows, 40
allocation rows, 8224 scheduler bytes, 130 checked local links,
`payload_bytes: 72669312`, `room_projects_packed_bytes: 1707008` and
`canonical_declaration_bytes: 19429`; runtime tests remain `NOT_RUN`.
`merge_gate: PASS -- ledger only, 0 problem(s)`.

Seven in-memory negative probes all refuse: a missing final trail step, stale
auxiliary subtotal, wrong named ledger column, changed source width, wrong
allocation capacity, changed capacity alias, and duplicate canonical source
member. They alter no files. The specification run includes all existing
validator self-tests; no Godot run or full-suite duplication is needed for this
source/doc-only change. Independent review approved the three-file diff before
commit. No GDScript, canonical registry, generated table, budget or frozen
integration checkout was changed by this lane.

Source SHA-256 values for the reviewed checkpoint:

- `room_projects.gd`: `523b29d4e0801dba6273ff3a0f15b7eb354ba715f7c83168ac6414321a98a184`
- `construction.gd`: `b75ad52b8e689af28b78db19625b776c65136a0d1267d41889ed3636618f3bfd`
- `jobs.gd`: `d8cd5fc96ab00748f16fe0b5b29f2a4ae943ed53f6fa48fbd1790ae98d4b171b`
- `canonical_state_hash.gd`: `63a3073def463303c5beb868e99fe20ed9ec2a272cc74081f6c7aa179ca44733`
- `canonical_state_registry.json`: `c09bca2ef44df176424664483b02eeab0c60b54a639e01c25c2613c9218e5c93`

## Authority

AGENTS.md integer/SoA requirements; `systems_architecture.md` ARCH-MEM-006/010;
decisions 1053 and 1060; the unchanged RoomProjects source allocations and
canonical declaration. The user's complete underground build authorization
requires accounting for the new state without claiming an unmeasured budget.
