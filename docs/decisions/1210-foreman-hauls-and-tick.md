# 1210 — Foreman hauling and the fixed-tick hookup (ADR 1197 G4 and G7)

Date: 2026-10-06 · Status: G7 implemented. G4 implemented on 2026-10-07 after Brendan chose option 1 (see
"Brendan's decision" and "G4 built" below). The live chain now stops at a G5 gap instead.

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

## Brendan's decision (2026-10-07)

| Question | Decision |
|---|---|
| One worker cannot both cut and haul | **Option 1: allow a switch at rest.** A mole standing still on an endpoint may switch between source-clocked (tooled) rows and automatic tool-free rows, in either direction, after rerunning the full first-admission checks. This amends ADR 1168. |
| 500-milli leftovers at M | **Leave them in M** and assert them exactly. |

## The switch at rest (`underground_routes.gd`, amends ADR 1168)

`Routes._source_refresh_refusal` is the single gate every `refresh_*` passes, before and after qualification.

- **Within a family the rule is unchanged.** A source actor changes source profile only at READY.
- **Source to automatic** needs exactly the canonical idle READY word, not just READY. That excludes the
  assembly-handling clock and any other source phase.
- **Automatic to source** needs a plain `PHASE_IDLE` word.
- **Both directions also need `_at_rest`:** a live location, no edge, no route head and no dispatch tail.
  `_refresh_actor` already refuses a moving or queued actor (`ROUTE_ACTOR_BUSY`).
- **Full re-proof.** The switch then runs `_qualify_actor_at` at the actor's endpoint, the same proof a fresh
  admission runs: Resident, Transform, tool and cargo, Job, endpoint, support, body and occupancy. Only after
  that are columns written. `_reset_source_clock` starts a source family at READY (or ENTRY for WORK rows) and
  an automatic family at `PHASE_IDLE` with request tick 0.
- **There is still no unregister or readmit.** `admit_*` on a registered actor still refuses.

Tests:

- `test_underground_haul_grip.gd` on the real content-6 work area:
  - refused while moving (`ROUTE_ACTOR_BUSY`);
  - refused while still recovering on a station (`ROUTE_SOURCE_HANDOFF_REQUIRED`);
  - refused by the re-proof while the tool is held (tool-free rows), and while it is not held (tooled rows);
  - a successful switch to row 31 and back to row 12 at READY.
- Three older tests asserted the old refusal and now assert the amended rule:
  - `test_underground_routes.gd`: canonical-to-automatic at rest succeeds, and the legacy actor reaches
    canonical ground only through the switch;
  - `test_underground_room_station_planner.gd`: the v3 seam is now refused by the re-proof
    (`PROFILE_VARIANT_UNAUTHORED`) instead of by the gate.

## G4 built (`underground_entry_hauler.gd`)

When `Owners.delivery` and `Owners.gear` are bound, each cut phase and each installation hauls its own bill
before the BUILD Job takes the worker:

1. **Units.** `Hauler.units_into` gives whole 1,000-milli units per item beyond M's free stock.
2. **First HAUL Job.** It is requested and sourced by the step's Project. The worker walks to M on its tooled
   source profile: any pending retreat leg first, then the station's travel profile, or for an installation
   the last cut's walk profile. A worker not yet registered is admitted where it stands.
3. **At M.** `gear.unequip` puts the tool into M's container. Then the switch at rest selects tool-free WALK.
4. **Each trip, through Delivery:**
   - `admit` one unit from R's staging;
   - WALK to stand R and an empty turn to 16384;
   - the named lift row, 34 for wood or 39 for stone, then `begin_load`, lift Work and `load_payload`;
   - CARRY to stand M, arriving at 16384;
   - the named set-down row, 36 or 41, then set-down Work and `unload_payload`;
   - the completed HAUL Job is released and destroyed, as the JobPlanner retires a completed service.
5. **Home.** The BUILD Job takes the worker. It walks from stand M onto M tool-free and `gear.equip` returns
   the tool.
6. **Back to work.** The foreman claims the tool for work and travels to the station; the switch back to the
   tooled source profile happens at rest on M. The installer does the same and then continues exactly as an
   arrival at M.

The installer binds M at `open` (it used to do this at `fund`), because Delivery reads the Project's material
container at admission. Stall budgets reset on every haul stage and trip.

**Evidence.**
`test_underground_paid_assembly_handling.gd::test_entry_foreman_hauls_every_input_of_the_complete_prefix`.
The fixture's 6,500 wood and 1,500 stone are moved to R's staging and topped up to whole units (7,000 and
2,000). Only `Foreman.advance` runs, for 4,751 ticks, and the result is:

| Ledger | Value |
|---|---|
| INSTALLED | 2 (each group once) |
| Haul trips | 9 (7 wood, 2 stone) |
| Haul work | 36,000 mWU (9 × lift 2,000 + set-down 2,000), recorded separately |
| Excavation plus fastening work | 54,000 + 44,000 = 98,000 mWU |
| Spoil | 12,000 |
| R's staging | 0 wood, 0 stone |
| M | exactly 500 wood and 500 stone (Brendan: leave them) |
| Conservation refusals | empty |
| Audits | pass |
| Live Projects | 0 |
| Tool | equipped again |

**Measured (peaks over the hauled run, of 1,048,576):** WorldRoutes proof checks 519,060 (49.5%). SurfaceAnchor
checks 775,313 (73.9%, the last work-area create, unchanged from ADR 1207).

### Live chain (`run_tick`)

The runtime binds the Session's Delivery and Gear into the foreman. In
`test_underground_host.gd::test_fixed_ticks_drive_the_live_foreman_until_the_first_gap`, with the G11 tool
stand-in, staged stock and the G5 placement stand-in, ticks alone do the following:

- the mole walks tooled to M;
- it puts the tool into M's container;
- it switches at rest to row 31;
- Delivery's admission then refuses `ROUTE_TURN_ACTOR_UNBOUND`. Its occupancy proof needs every living
  resident's body, and the surface residents are not route actors.

That code now maps to G5: surface Movement is not composed. Also new:

- `ENTRY_HAUL_NO_STAGED_STOCK` maps to G4. Moving settlement stores to the anchor is still not built; the tests
  stage stock at R as a stand-in.
- `ENTRY_FOREMAN_INPUT_LOT` remains the G4 code when no Delivery is composed.

## Rejected

- **Claiming the staged lots at R in place**, and **moving them to M without a haul**: either one fakes G4.
- **Mapping every foreman refusal to one generic row**: each code keeps its own gap row, and an unknown code
  stays "unclassified".
- **Resolving the mole's schedule from the runtime**: the JobSelector owns that stage. The runtime waits for it
  instead.
