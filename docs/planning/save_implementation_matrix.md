# Save implementation matrix

`PLAN-SAVE-COVERAGE`, 2026-09-15, against merged master `50e78ce`.

**`release_save_ready` is `false` and nothing here changes that.** This document exists because
`SAVE-CAPTURE` was a single umbrella task that could have dispatched with most of its body
missing. Astra named that risk directly: *"do not mark the planning task done while this broad
umbrella could dispatch with missing bodies."* What follows is the body.

Every row was read off the source at `50e78ce`, not off a checklist.

## 2026-09-19 source reconciliation

The tables below are the historical `50e78ce` inventory. Later source evidence supersedes these particular blocker descriptions:

- D2: the public directory cursor reader, section 1 capture/codec and atomic `restore_columns_and_cursor()` already exist. SAVE-D2-R02 and decision 0152 define the new stateless `save_identity_restore.gd` caller joining the decoded section 3 columns and section 1 cursor under a held load barrier. Its bounded acceptance requires round-trip, spent-ID, exhausted-cursor and refusal tests plus independent review. It does not complete disk loading or world replacement.
- W1: `SimClock.restore_runtime()` and GameManager's load barrier/clock restoration APIs already exist. SAVE-W1-R02 / decision 0153 defines their joint decoded WorldRuntime/RNG install adapter, with exact header/tombstone checks and bounded prior-RNG recovery. Acceptance is tracked in its evidence folder and queue entry. Connecting it to the full coordinator remains work; the missing API claim below is historical.
- I1: PR #137 added the canonical inventory bulk API. The other five named inventory owners and the complete section 7 live adapter remain open.

- P2: allocation order can differ from canonical command order even without a partial drain. SAVE-P2-R02 / decision0154 specifies exact offset/highwater restoration, economic load-barrier guards and checked two-owner recovery. Implementation acceptance remains attached to its queue/evidence.
- Economic allocator exhaustion: runtime high4294967296/low0 cannot fit schema2's u32 pair. SAVE-SEQ-R01 / decision0155 defines the schema3 widened-high-word implementation merged in PR145. Full save orchestration/capture now depends on it; P2 alone cannot close this format gap.

- Header/replay binding: SAVE-REPLAY-R01 version2 / decision0156 resolves the old scalar gap with outer format2/header264 and a redundant high/low next-admission checkpoint, validated against section12 and section1 tick. SAVE-HEADER-REPLAY-FORMAT is integrated in PR146 and remains an explicit prerequisite of full orchestration/capture. The full coordinator must invoke the binding validator on the same decoded file; no coordinator or replay recorder is supplied by the header codec. PLAN-REPLAY-STREAM-CONTRACT retains the separate task09.4 log/append/branch contract.

`release_save_ready` remains **false**. The full coordinator must bind the correct world's clock and directory, verify all sections and implement the approved disk-backed rollback; this adapter alone supplies none of those guarantees.

---

## 1. The fifteen sections, as they actually stand

`capture_into` reads a live store into a Record. `apply` writes a Record back. A section with a
codec but neither is a **byte format with no way in or out of the running game**.

| § | Name | Module | Encodes | `capture_into` | `apply` | Live blocker |
|---|---|---|:-:|:-:|:-:|---|
| 1 | WORLD | `save_section_01` | yes | yes | **no** | W1 |
| 2 | CATALOG_IDS | — | **no** | — | — | non-record; catalog identity covers it |
| 3 | ENTITY_DIRECTORY | `save_section_directory` | yes | yes | yes | D2 |
| 4 | COMPONENT_COLUMNS | — | **no** | — | — | no codec at all; 18 owners |
| 5 | CHILD_ARENAS | — | **no** | — | — | no codec at all; 5 owners |
| 6 | ECOLOGY/DISPATCH | — | **no** | — | — | no codec at all; 3 owners |
| 7 | INVENTORIES | `save_section_inventories` | yes | **no** | **no** | I1 |
| 8 | JOB_INDEXES | `save_section_job_indexes` | yes | yes | yes | J2 |
| 9 | NAVIGATION | `save_section_navigation` | yes | **no** | **no** | N1 |
| 10 | RNG | `save_section_rng` | yes | yes | yes | — |
| 11 | EVENT_SCHEDULE | — | **no** | — | — | store exists, codec does not |
| 12 | PENDING_COMMANDS | `save_section_pending_commands` | yes | yes | yes | P2 |
| 13 | CHRONICLE | — | **no** | — | — | no codec at all |
| 14 | NAME_POOL | `save_section_name_pool` | yes | yes | yes | — |
| 15 | STATE_DIGEST | `canonical_state_hash` | walker | n/a | n/a | — |

**Nine modules for fifteen sections. Two sections round-trip cleanly** — §10 and §14. Section 3
round-trips but carries D2; §8 and §12 round-trip but carry J2 and P2.

## 2. The dominant blocker is one thing wearing three names

I1, J2 and N1 are the same sentence about different owners:

> no owner publishes a bulk column reader or writer, so there is no `capture_into(store)`.

That is the wall decision 0105 broke for `entity_directory.gd` (closing D1) and decision 0132
broke for `needs`, `residents` and `jobs`. It has not been broken for anyone else.

So the largest single lever in the whole save effort is **extending the bulk column API to the
remaining owners** — and the matrix below counts exactly how many that is, rather than saying
"the rest".

| Blocker | Owner that must publish columns | Sections it unblocks |
|---|---|---|
| I1 | `inventory`, `gear`, `reservations`, `stock_age`, `fishing`, `forage` | §7 |
| J2 | `job_planner` | §8 |
| N1 | `navigation`, `movement` | §9 |

`gear` and `reservations` rows are **bare indices with no generation** and cannot be compacted,
which is a real constraint on any column API written for them and is why they are named
separately rather than folded into "inventory".

## 3. Blockers that are not the column API

| Blocker | Statement | Owner |
|---|---|---|
| D2 | the §3 allocator cursor is installed but nothing writes it yet | §3 / world identity |
| W1 | `world_runtime` is captured, validated and carried but never **published** | §1 |
| P2 | `commands.gd` has no arena-base restore, so a split drain refuses | §12 |
| N2 | *not a blocker* — a note that §9 persisting closes no movement gate | — |

**D1, J1 and W2 are CLOSED** and are recorded as such in source.

## 4. Named prerequisites with no owner at all

These are not blockers on an existing module; they are work nobody has been assigned.

1. **§4 COMPONENT_COLUMNS codec.** 18 owners. The single largest missing artifact in the save
   system, and `SAVE-CAPTURE` silently assumed it.
2. **§5 CHILD_ARENAS codec.** 5 owners, including `jobs`, whose §4 and §5 halves must restore in
   **one call** — a half-applied pair is not a state the store can hold.
3. **§6, §11, §13 codecs.** `event_schedule` has a store and no codec; `chronicle` has neither.
4. **§1's publication path** (W1) and the 44-byte provenance prefix, which has no value producer
   under SAVE-R09-003.
5. **`farming._tile_orchard_row` has no population writer anywhere.** Its reverse map is an
   integration prerequisite, and `section_1_cross_check_refusal()` deliberately asserts none.
6. **A save orchestrator.** Nothing sequences the fifteen sections, enforces the load order
   (§3 before `residents`, §3 **and** `residents` before `jobs`, §14 after §4 for names), or owns
   the disk-backed rollback checkpoint ARCH-MEM-006 selected.

## 5. What `SAVE-CAPTURE` actually depends on

Its dependency list named four tasks. The true set is the six items in §4 plus the three column-API
extensions in §2 plus the four open blockers in §3 — **thirteen prerequisites, of which its
original list covered four.**

That is the finding this task exists to produce: the umbrella was not merely optimistic, it was
under-specified by a factor of three.

## 6. Bounded tasks this materialises

Each is one owner, one deliverable, and independently dispatchable. They enter `work_queue.json`
with `SAVE-CAPTURE` depending on all of them.

| Task | Deliverable |
|---|---|
| `SAVE-COLUMNS-INVENTORY` | bulk column API on `inventory`, `gear`, `reservations`, `stock_age`, `fishing`, `forage`; closes I1 |
| `SAVE-COLUMNS-JOBPLANNER` | bulk column API on `job_planner`; closes J2 |
| `SAVE-COLUMNS-NAVIGATION` | bulk column API on `navigation` and `movement`; closes N1 |
| `SAVE-S4-CODEC` | §4 COMPONENT_COLUMNS codec across 18 owners |
| `SAVE-S5-CODEC` | §5 CHILD_ARENAS codec; `jobs` §4+§5 restore atomically |
| `SAVE-S6-CODEC` | §6 codec for `command_dispatch`, `crop_weather`, `ecology` |
| `SAVE-S11-CODEC` | §11 codec over the existing `event_schedule` store |
| `SAVE-S13-CODEC` | §13 CHRONICLE codec; owner and store both absent |
| `SAVE-W1-PUBLISH` | publish `world_runtime`; closes W1 |
| `SAVE-P2-ARENA-RESTORE` | arena-base restore in `commands.gd`; closes P2 |
| `SAVE-D2-CURSOR-WRITER` | write the §3 allocator cursor; closes D2 |
| `SAVE-ORCHESTRATOR` | section sequencing, load order, rollback checkpoint |
| `SAVE-PROVENANCE-PRODUCER` | the 44-byte prefix under SAVE-R09-003 |

## 7. What this task does not claim

No codec is written here. No blocker is closed. `release_save_ready` stays `false`, and it stays
false until every row in §6 lands **and** a full-world round trip is demonstrated on a real
generated world — which, per REQ-SET-009, does not yet contain a hall, furniture, stockpiles or
tools to round-trip.
