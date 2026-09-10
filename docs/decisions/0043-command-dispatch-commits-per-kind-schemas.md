# 0043 — Command dispatch owns the per-kind payload schemas, and ARCH-SYS-002 is wired once
Date: 2026-09-10 · Status: Accepted

## Decision

`godot/scripts/core/command_dispatch.gd` implements ARCH-SYS-002 CommandCommit:
it drains `commands.gd`'s ordered next-tick queue and commits each record into
the real store that owns it. `settlement_system.gd` runs it as the first stage of
every tick, which takes the running §5 stages from five of twenty-three to six.

Eight things are settled here.

1. **Admission and commit are different validations, and commit revalidates the
   target.** A target checked against the directory at submission is checked
   again at commit: a destroyed target refuses `COMMAND_TARGET_STALE`, a live
   reference of the wrong kind refuses `COMMAND_TARGET_KIND`, and a kind that
   needs a target and was handed the null reference refuses
   `COMMAND_TARGET_REQUIRED`.
2. **Six of ARCH-CMD-003's 24 kinds are implemented — the six whose owning store
   exists** — and the other **eighteen refuse `COMMAND_UNSUPPORTED_FEATURE` and
   name their missing owner** through `unsupported_reason()`. None of the
   eighteen can silently succeed; a test walks all 24 and asserts it.
3. **The per-kind payload schemas are settled here**, because §8.1 states none
   and `commands.gd` explicitly left all 24 to 04.2. They are printed below.
4. **Result codes are a 21-entry ASCII-sorted domain whose INDEX is the stored
   id**, proven sorted and unique by an `_init` assertion, exactly as
   `catalog.gd` proves its compiled domains. The originating store's own refusal
   StringName is retained per row alongside the id.
5. **Whole commands are atomic.** Every arm that writes more than once
   preflights every write. `DESIGNATE_ZONE` is the one arm that cannot preflight
   to certainty, because it creates the zone it then edits, so a residual store
   refusal **destroys the zone it created** through `forage.destroy_zone()`.
6. **Nothing writes `JOB_STATE_WORK`.** A committed DESIGNATE_ZONE produces a
   `QUEUED` FORAGE Job and leaves it queued; movement has no owner.
7. **`SET_POLICY` carries an explicit policy selector**, not a bare value.
8. **The ledger grows by 245764 bytes**, and while adding it a **437632-byte
   discrepancy between §2.3's carried total and its own row sum** was found and
   recorded as ARCH-MEM-010 rather than silently corrected.

## The per-kind payload schemas

`docs/systems_architecture.md` §8.1 says only that payloads "contain full
selection ID lists, schedule bytes, zone tiles, recipe orders, or sanitized
aliases; the payload schema is selected by the command kind". It names none of
the 24. `commands.gd`'s header records that it therefore validated only the
payload SPAN and left the schemas to task 04.2. These six are that work.

| Kind | Target | `arg0` | `arg1` | Payload |
|---|---|---|---|---|
| `DESIGNATE_ZONE` | the ecology **basin** | ZoneType | §5.5 danger band 0–3 | i32 tile count, then that many ascending i32 tile indices |
| `SET_POLICY` | the harvest zone | policy selector | that policy's value | none |
| `SET_JOB_PRIORITIES` | the resident | auto-fallback toggle | dangerous-work toggle | i32 row count, then `(job_kind, priority)` i32 pairs in ascending kind order |
| `SET_ACTIVITY_SCHEDULE` | the resident | — | — | exactly 24 Activity bytes, one per hour |
| `NAME_RESIDENT` | the resident | — | — | the alias as UTF-8 bytes |
| `CANCEL_JOB` | the Job | — | — | none; a nonempty payload refuses |

Four points of that table are not free choices:

* **`DESIGNATE_ZONE` targets the BASIN, not the new zone.** `job_planner.gd`'s
  `_designation_blocker()` requires "a valid FORAGE designation BOUND TO AN
  EXISTING BASIN" and says in terms that "world-generation basin creation alone
  produces no demand, structurally: the only way to pass this gate is to have
  been bound to a basin through `forage.set_basin()`". A command that created a
  self-owned zone would therefore create a zone that can never produce work.
  So the command creates the zone, binds it to the targeted basin, links its
  tiles and enables the demand — one player intent, one command.
* **Only `ZONE_TYPE_FORAGE` is accepted, and every other ZoneType refuses
  `COMMAND_UNSUPPORTED_FEATURE`.** FORAGE is the only zone type with an
  implemented demand producer. Accepting a FARM designation would create a real
  zone that nothing consumes, which is precisely the silent success task 04.2
  exists to prevent.
* **The tile bound is `forage.is_tile_index()`, and `goal_x`/`goal_z` are not
  read by any arm.** Decision 0042 records that §8.1 types those two fields i32
  and names no unit, so no map bound can be sourced for them. A tile index has
  an owning store with its own 128×128 predicate, so the spatial payload uses
  one and asserts no invented bound.
* **The alias rule is ARCH-SAVE-005's, quoted**: "Player aliases are 2–32
  Unicode characters with control characters rejected", and malformed UTF-8 is
  rejected. Length is measured in CHARACTERS, not bytes. Godot's UTF-8 decoder
  substitutes replacement characters instead of failing, so malformed input is
  detected by **re-encoding the decoded string and comparing byte counts** —
  which also catches an embedded NUL and an overlong encoding.

`SET_POLICY`'s selector is `0 = forage quota mode`, `1 = forage zone enabled`.
A single unlabelled integer would make two policies indistinguishable in a saved
command, and §8.1 gives no field to distinguish them. Both selectors edit
`forage.gd`; selector 1 also moves `job_planner.gd`'s standing demand, because
the zone's `enabled` flag and the planner's demand are two records of one player
intent and leaving them disagreeing is how a disabled zone keeps producing work.
A refused demand change restores the flag it had already written.

`SET_JOB_PRIORITIES`' two toggles are `-1` unchanged, `0` off, `1` on, so a
priority edit is not forced to restate an unrelated dangerous-work consent.

## Why the eighteen refuse, and what is missing

`SET_MANUAL_TASK` and `CANCEL_MANUAL` refuse `NO_MANUAL_TASK_STORE_BLOCKER_U6`.
**There is no ManualTask store.** §3.1's blocker table records that "owner-major
indexing for the 8-per-resident store is unspecified", `jobs.gd` and
`schedule.gd` both state it in their own headers, and `JobAgent.manual_until` is
a reserved always-zero column. Inventing the index formula here would invent the
contract U6 exists to protect.

`EQUIP` is the one refusal whose store DOES exist: `gear.gd` is implemented.
Its reason is therefore `EQUIP_CONTRACT_OWNED_BY_TASK_06`, not a claim that
nothing is there. Who may equip what and when is task 06's contract.

The other fifteen name an absent store: no Building, Room, Furniture,
Construction, ProductionOrder, Feast, Door, FieldPolicy, candidate,
warden-appointment, relief-seed or building-item filter/minimum store exists.

## ARCH-SYS-002: what is now wired, and what is not

`settlement_system.gd` runs CommandCommit first, which §5 requires ("after
snapshot, before selectors"); ARCH-SYS-001 TransformSnapshot does not exist, so
nothing precedes it. **Six of twenty-three stages now run**: 002 CommandCommit,
003 IntervalIntegrator, 008 NeedIntent (activity resolution only), 010
JobSelector, 013 ProductiveWork, and 017 CareHealth inside 003's sweep.

In that node's composition the stage reaches **four** of the six implemented
kinds — CANCEL_JOB, NAME_RESIDENT, SET_ACTIVITY_SCHEDULE, SET_JOB_PRIORITIES —
because it composes the resident-side stores. DESIGNATE_ZONE and SET_POLICY need
`forage.gd` and `job_planner.gd`, which are ARCH-SYS-005/009's stores and task
03's to compose. Until `command_dispatch.bind_ecology()` is called they refuse
`COMMAND_STORE_NOT_BOUND` — an explicit refusal, not a silent success. That
method is the **named runtime handoff with task 03**; the module supports both
kinds fully today and a test proves the whole path end to end.

**ARCH-CMD-002's speed/pause scheduler events are still not implemented.** Task
04.1 owns their separate queue and every one of its widths, enum values,
exhaustion refusals, save subsection and memory accounting, and calls them
"design deliverables, not unspecified values a coder may choose at runtime".
None is invented here, and `sim_clock.gd`'s two "BLOCKER U2 … not implemented"
comments remain accurate. **U2 is now half closed**: economic commands have a
transport and a commit stage; speed and pause do not.

**Persistence stays blocked.** There is no save module, so the pending queue and
the result ledger are in-process only. Task 09 owns the codec.

## The clock rebind

`GameManager.start_game()` REPLACES its `SimClock` instance. A queue bound once
would go on stamping `completed_tick+1` from a clock that had stopped moving, so
`commands.gd` gains `rebind_clock()`, which **refuses on a non-empty queue**:
records already accepted were stamped against the old clock's numbering, and
re-basing them would silently move when a player's edits execute.
`settlement_system.gd` checks the reference once per tick **after** the drain and
rebinds only when the queue is empty, so no accepted command is ever discarded by
it.

## The memory ledger, and a discrepancy found while adding to it

Three §2.3 rows are added, 245764 bytes:

| Row | Count | Bytes/element | Bytes |
|---|---:|---:|---:|
| Command result ledger | 4096 | 36 | 147456 |
| Command result store codes | 4096 | 8 | 32768 |
| Command payload decode scratch | 65540 | 1 | 65540 |

4096 result rows is one per queued command, so a tick that drains a full queue
loses no outcome; that is derived from §8.1's queue length, not chosen. The
store-code column is an `Array[StringName]` rather than a `PackedStringArray`
because assigning an interned StringName is a reference copy and assigning a
String is an allocation, and this column is written on a per-tick path.

Carried totals, all five identities re-checked:

| Metric | Before | After |
|---|---:|---:|
| Planned allocated payload | 59321038 | **59566802** |
| One live world plus reserve (payload + 8388608) | 67709646 | **67955410** |
| Headroom below decimal 100 MB (1e8 − live) | 32290354 | **32044590** |
| Additional candidate mutable state (payload − 6215584) | 53105454 | **53351218** |
| Transactional peak (live + candidate) | 120815100 | **121306628** |
| Transactional headroom (1e8 − peak) | −20815100 | **−21306628** |

**ARCH-MEM-010, found while doing this.** §2.3's "Planned allocated payload" is
the CARRIED total of the ARCH-MEM-009 trail, and it is **not** the sum of the
rows printed above it. Re-adding those rows as printed gives 60004434 on the new
basis — **437632 higher**. The difference is exactly `306304 + 131072 + 256`:
decisions 0026/0030's FishHabitat/HarvestZone growth, R05-QUOTA-024's separately
declared claim-ordering cache, and decision 0027's ratified 256 bytes. All three
are named inside the "Fixed registry payload" row's own derivation, so they are
inside its 24952146 figure, but none has a line in the trail, so the carried
total never picked them up. **It is recorded, not corrected**: every headroom and
conflict figure in that document derives from the carried total, and re-basing
them silently would change stated conclusions without a governing record. The
conclusion is the same on either basis — the one-world gate holds by tens of
megabytes and the two-world design is rejected.

## One line deleted because mutation testing proved it could not fail

`_group_row_count()` originally carried a `rows < 0 or rows > max_rows` clause
alongside the exact-length identity. Deleting it left the whole suite green, and
the algebra says why: once
`GROUP_COUNT_BYTES + rows * row_bytes == payload_length` holds and the upper
length guard has held, `rows <= max_rows` follows, and
`payload_length >= GROUP_COUNT_BYTES` forces `rows >= 0`. **It was removed rather
than kept as defence in depth or waved through as an equivalent mutant**, and the
derivation is written into the function's docstring so the next reader does not
re-add it. The two remaining guards are kept for reasons that are not
redundancy: the lower one stops `decode_s32(0)` reading a count out of the
PREVIOUS command's bytes in the shared scratch, and the upper one stops a tick
copying an oversized payload before finding out the count is wrong.

## Alternatives rejected

* **Composing `forage.gd` and `job_planner.gd` inside `settlement_system.gd`.**
  That would make DESIGNATE_ZONE work in the running node today, but it also
  claims ARCH-SYS-005/009, whose stages nothing advances. A designation whose
  planner never ticks would produce no job at all, which is worse than an
  explicit `COMMAND_STORE_NOT_BOUND`.
* **Deriving each kind's payload shape from the kind alone**, as `commands.gd`
  considered. That requires 24 schemas; eighteen of them have no owning store to
  be a schema OF.
* **Mapping every store refusal into one `COMMAND_STORE_REFUSED` id and
  discarding the store's own code.** Deterministic, but a player would be told
  only that something refused. The per-row StringName costs 8 bytes and keeps
  the reason.
* **Truncating an over-long alias to 32 characters.** ARCH-SAVE-005 says
  rejected, and a silently shortened name is a name the player did not choose.

## Consequences

* A player action reaches the simulation for the first time. `commands.gd`'s
  header line "NO PRODUCER IS CALLED" is no longer true of the project, though
  it stays true of that file.
* Adding a kind means adding its store, its schema, its arm and its row in
  `UNSUPPORTED_REASON`; the `_init` assertion fails if the table and the domain
  disagree.
* Adding a result code means inserting it in ASCII order and renumbering the
  ids below it. That is deliberate friction: the id is what a save would carry.
