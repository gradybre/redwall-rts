# READY_07 item 5 — memory arithmetic audit (2026-09-11)

Snapshot: revision16e1efc, before the correction recorded by ADR0050.

Scope: `AGENTS.md`; `docs/systems_architecture.md` §2.2 and its §2.3 ARCH-MEM-009/010 ledger; accepted ADRs 0042–0049. This is mechanical packed-payload arithmetic only. It does **not** claim allocator, engine, process-memory, performance, or hardware measurements. The ledger remains baseline-only for the unresolved multi-level movement scope and omits the known §3.1 allocations.

## Mechanical sum of every current §2.3 allocation row

| # | Allocation row | Bytes | Running sum |
|---:|---|---:|---:|
| 1 | Fixed registry payload | 24,993,106 | 24,993,106 |
| 2 | Auxiliary payload | 16,712,540 | 41,705,646 |
| 3 | Static navigation map | 3,670,016 | 45,375,662 |
| 4 | Active A* builder | 5,505,024 | 50,880,686 |
| 5 | Route cell arena | 4,194,304 | 55,074,990 |
| 6 | Route descriptors | 16,384 | 55,091,374 |
| 7 | Path request records | 524,288 | 55,615,662 |
| 8 | Spatial heads | 65,536 | 55,681,198 |
| 9 | Resident motion/separation scratch | 32,768 | 55,713,966 |
| 10 | Command queue | 262,144 | 55,976,110 |
| 11 | Command queue order index | 16,384 | 55,992,494 |
| 12 | Command payload arena | 1,048,576 | 57,041,070 |
| 13 | Command result ledger | 147,456 | 57,188,526 |
| 14 | Command result store codes | 32,768 | 57,221,294 |
| 15 | Command payload decode scratch | 65,540 | 57,286,834 |
| 16 | Tick event ring | 262,144 | 57,548,978 |
| 17 | Read-only catalog/lookup budget | 2,097,152 | 59,646,130 |
| 18 | I/O streaming buffers | 262,144 | 59,908,274 |
| 19 | UI numeric snapshots | 131,072 | 60,039,346 |
| 20 | Timing samples | 55,200 | 60,094,546 |
| 21 | World generation map masks and tree plan | 159,968 | 60,254,514 |
| 22 | Command dispatch source-intent ledger | 2,048 | 60,256,562 |
| 23 | ARCH-SYS-023 presentation snapshot | 244 | **60,256,806** |

Independent cross-check: all 135 §2.2 payload rows sum to **24,993,106**, exactly the current `Fixed registry payload` top row. The §2.2 prose subtotal, 24,555,474, is lower by the same 437,632-byte historical omission.

## ARCH-MEM-010 gap

`60,256,806 row sum − 59,819,174 carried ARCH-MEM-009 total = 437,632`.

| Omitted from the historical running trail, but already present inside the fixed-registry row | Exact §2.2 rows | Bytes |
|---|---|---:|
| R05-QUOTA-024 claim-ordering cache | `ForageClaim.ordering` 131,072 | 131,072 |
| Decisions 0026/0030 growth | `HarvestZone.basin_*` 1,024 + `harvested_today/quota_reserved` 2,048 + `quota_mode` 128 + `ForageClaim` core 229,376 + 65,536 + 8,192 | 306,304 |
| Decision 0027 fish state | `FishHabitat.effort_used` 128 + `FishStock.restocking` 96 + `FishHabitat.intensive_harvest` 32 | 256 |
| **Gap** | **131,072 + 306,304 + 256** | **437,632** |

Double-counting risk: do **not** add these ten §2.2 component rows as new §2.3 allocation rows, and do not add 437,632 to `Fixed registry payload`; that row already equals the full mechanical §2.2 sum. The correction belongs only in the ARCH-MEM-009 carried-total reconciliation (or in a full historical rebase). ARCH-MEM-010 also retains a stale internal reference to `24952146`; the current fixed-registry row is `24993106` after ADR 0045.

## Corrected current metrics

Shared/temporary exclusions used by the document are unchanged:

`3,670,016 + 2,097,152 + 262,144 + 131,072 + 55,200 = 6,215,584`.

| Metric | Published current carried basis | Correct mechanical row-sum basis | Correction |
|---|---:|---:|---:|
| Planned allocated payload | 59,819,174 | **60,256,806** | +437,632 |
| Allocator/object reserve | 8,388,608 | **8,388,608** | 0 |
| One live world plus reserve | 68,207,782 | **68,645,414** | +437,632 |
| Headroom below 100,000,000 | 31,792,218 | **31,354,586** | −437,632 |
| Additional candidate mutable state (`payload − 6,215,584`) | 53,603,590 | **54,041,222** | +437,632 |
| Two-world transactional peak (`live + candidate`) | 121,811,372 | **122,686,636** | +875,264 |
| Transactional headroom | −21,811,372 | **−22,686,636** | −875,264 |
| Two-world conflict/overage | 21,811,372 | **22,686,636** | +875,264 |

Derivations:

- `60,256,806 + 8,388,608 = 68,645,414`
- `100,000,000 − 68,645,414 = 31,354,586`
- `60,256,806 − 6,215,584 = 54,041,222`
- `68,645,414 + 54,041,222 = 122,686,636`
- `122,686,636 − 100,000,000 = 22,686,636`

ARCH-MEM-006 and ARCH-CONFLICT-011 contain older historical figures in addition to the newer carried-basis table. Their operative current values should be the corrected values above: one-world **68,645,414**, headroom **31,354,586**, second mutable state **54,041,222**, two-world peak **122,686,636**, and rejection overage **22,686,636**.

## Recommendation

Preserve every dated ADR delta and the existing ARCH-MEM-009 rows. Add one explicit final reconciliation step, after ADR 0049, named for the pre-0043 fixed-field trail omission: `+437,632`, taking 59,819,174 to 60,256,806 (and reserve-inclusive 68,207,782 to 68,645,414). Then update only the current metric table and the current/operative clauses of ARCH-MEM-006, ARCH-CONFLICT-011, §3.1 headroom, and the end-of-document current reconciliation. Leave historical “before/after” figures labeled as historical. Keep ARCH-MEM-007’s measurement caveat and §3.1’s unbudgeted-state caveat adjacent to any corrected gate statement.

## Provenance-text correction

The Fixed registry derivation's phrase `+16384 command-queue order index` is
misplaced: no command queue field appears in the135 §2.2 rows. The actual16384
bytes are correctly counted once in the separate §2.3 command-index allocation
and its historical trail step. Removing the phrase changes no arithmetic total.
