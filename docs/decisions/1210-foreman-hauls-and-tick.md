# 1210 — Foreman hauling and the fixed-tick hookup (ADR 1197 G4 and G7)

Date: 2026-10-06 · Status: G7 implemented. G4 (foreman hauling) is **blocked on a Routes rule** and waits for
Brendan's choice (see "G4 blocker" below).

## Built

### Inputs come from the storage container's own stock

`Foreman.Crew` no longer carries caller-chosen lots (`lot_keys`/`lots` are gone). Every cut input line and
every installation bill line is claimed by `Installer.claim_stock`: it walks the Site's storage container (M)
in list order and claims exactly the bill of that compiled item from free stock, in one `claim_batch`. If M holds
less free stock of the item than the bill, nothing is claimed and the step refuses `ENTRY_FOREMAN_INPUT_LOT`
(the G4 alert). The foreman's `Owners` gains `items` to resolve the authored input keys.

Why: hauled goods arrive at M as new lots, one per trip, so a fixed caller lot can never describe them; and the
live runtime has no lot to name (G6 asks for real stock). With stock pre-placed at M, as every existing fixture
does, the claims are byte-for-byte the same lots and quantities as before.

### The live chain plans the foreman, and `run_tick` advances it (G7)

`underground_entry_runtime.gd`:

- After crew selection the runtime plans the whole prefix (L0 cuts, L0, T0 cuts, T0) from the mounted Frontier
  and the one live entry Placement, then enters `STEP_RUNNING`. The old `ENTRY_INPUTS_NOT_DELIVERED` check is
  removed: a missing input is now the foreman's own refusal at the phase that needs it.
- **G5 is checked, not faked.** The simulation never walks a resident from the surface, so planning refuses
  `ENTRY_SURFACE_ARRIVAL_MISSING` unless the crew mole's Transform is exactly on the first planned station.
- **Crew activity.** Job eligibility reads the mole's *resolved* activity, and the JobSelector resolves an idle
  resident only on its 30-tick stagger. `advance` therefore does not call the foreman until the crew mole's
  activity is resolved. The wait is bounded by that stagger, so it is not a silent stall. After that, a busy
  mole (`JOB_AGENT_BUSY`) or a non-work hour (`STEP2_ACTIVITY_FORBIDS_WORK`) is a refusal with a G6 alert.

`settlement_system.gd`: `_run_stages` calls `_advance_underground_entry(tick)` right after ProductiveWork. The
foreman's BUILD Jobs resolve to no removal Project, so `_tick_one_activity` never ticks them, and their Work is
earned exactly once, by the foreman. A foreman refusal stops the chain, raises its alert once
(`UIManager.push_refusal(code)` then `UIManager.push_alert(gap_of(code))`), and never fails the settlement tick.
A refusal from `begin_underground_entry` raises the same alert.

**Evidence.** `test_underground_host.gd::test_fixed_ticks_drive_the_live_foreman_until_the_haul_gap`, on a real
generated settlement: the G11 stand-in equips one basic tool, wood 7,000 and stone 2,000 are staged as lots in
R's ground-staging container, and the G5 stand-in places the mole on the first station. Then only
`run_tick` runs. The mole is admitted as a real route actor and enters WORK on the station. The BRACE START then
refuses `ENTRY_FOREMAN_INPUT_LOT`, which maps to G4. No Work is earned, and the staged lots stay at R
unclaimed. The existing chain test now meets G5 after G11.

## G4 blocker: one worker cannot both cut and haul

The plan (ADR 1203 "Open") had one tooled mole unequip at M, haul each 1,000-milli unit through Delivery
tool-free, then re-equip. A probe on the real work area showed that Routes refuses this:

| Profile rows (content 6) | Selection policy |
|---|---|
| 0–1 (tooled stand/walk), 30–31 (tool-free stand/walk), 32–41 (wood and stone CARRY, lift, set-down) | AUTOMATIC |
| 2–12 (travel), 13–28 (WORK), 29 (handling) | source-clocked (READY, SHORT, CANONICAL_GROUND, SOURCE_WORK, ASSEMBLY) |

- A cutter is source-clocked from its first admission (`admit_work_actor` or `admit_travel_actor`).
- `Routes._source_refresh_refusal` (ADR 1168, "Initial enrollment and handoffs") refuses a source-clocked actor
  any automatic row: `refresh_actor(…, MODE_WALK, …)` at M after unequipping returned
  `ROUTE_SOURCE_HANDOFF_REQUIRED`.
- `refresh_travel_actor` refuses automatic rows outright: row 31 returned `ROUTE_SOURCE_PROFILE`.
- The reverse is also refused. A fresh automatic actor, with its tool re-equipped, cannot select the cut
  stations' travel row 12 (`ROUTE_SOURCE_HANDOFF_REQUIRED`).
- Routes has no unregister call, and ADR 1168 forbids "unregistered and readmitted" on purpose.

So the tool-free haul rows are usable only by an actor that has never been source-clocked, and that actor can
never cut. No foreman code can work around this without changing a certified Routes rule.

### Options (Brendan)

1. **A ready handoff between policy families (recommended).** A source-clocked actor, stationary at READY on a
   live endpoint, may switch to an automatic row, and an idle automatic actor on an endpoint may switch to a
   source row at READY. Either switch reruns the full fresh-admission proof (`_qualify_actor_at`: Resident,
   Transform, tool and cargo, Job, endpoint, support, body and occupancy) and then resets the clock. This amends
   ADR 1168's explicit refusal. The single-worker plan then works as written. **G11 needs this anyway:** a mole
   that walks tool-free to the stores and takes a tool must become source-clocked before it can cut.
2. **A two-mole crew.** A tool-free hauler mole is admitted fresh as an automatic actor (at R) and only ever
   hauls; the tooled cutter only ever cuts. No rule changes. It needs a second adult mole, G5 placement for the
   hauler too, and occupancy proof that the hauler's stands and edges coexist with the cutter's routes. It does
   not solve the G11 tools-from-stores case.
3. **Re-author the tool-free rows as source rows** (content 7): walk as canonical ground, and lift and set-down
   as source WORK. This means republication, renewed pins and new proofs. It is the most work, and it still
   needs option 1 or a stores-side answer for G11.

### Whole-unit trips leave a remainder at M (any option)

The prefix bills are 6,500 wood and 1,500 stone, in 250-milli brace lines (4,000 for L0 and 1,000 for T0).
Delivery carries exactly 1,000 milli per trip, and a 500-milli trip is refused (ADR 1203). Hauling just in time,
whole units only, moves 7,000 wood and 2,000 stone and leaves 500 of each at M after T0. The requested
"wood 0, stone 0" ledger therefore holds only for consumption (6,500 and 1,500 spent exactly) and for the
staged lots at R (fully hauled), not for M. This is a consequence of Brendan's whole-unit decision (ADR 1144),
not a new choice.

## Not measured

Route and Location check peaks for a hauled prefix were not measured: the hauled prefix cannot run until G4
is unblocked. The G7 host test publishes nothing beyond the existing work area.

## Rejected

- **Claiming the staged lots at R in place**, and **moving them to M without a haul**: either one fakes G4.
- **Mapping every foreman refusal to one generic row**: each code keeps its own gap row, and an unknown code
  stays "unclassified".
- **Resolving the mole's schedule from the runtime**: the JobSelector owns that stage. The runtime waits for it
  instead.
