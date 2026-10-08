# 1225 — A lost entry crew is replaced and the entry resumes (DEC-056; amends ADR 1168 and ADR 1223)

Date: 2026-10-07 · Status: Accepted (Brendan's decision, DEC-056); implemented for the walk and every cut phase.
Resuming a paid installation is not built (see the last section).

## Brendan's decision

> Crew loss → pick a replacement: choose another eligible mole to walk in (G5 arrival path) and resume the entry
> where it stopped; the lost mole is removed from the underground movement system.

This answers ADR 1223's first open question. ADR 1223 kept the entry's Jobs with the dispatcher and stopped the
chain.

## 1. Routes unregisters a lost actor (amends ADR 1168)

ADR 1168 forbids unregister-and-readmit, so that a moving actor can never be silently reset. This amendment allows
exactly one exception: **`Routes.unregister_lost_actor(worker)` removes a registered actor whose resident is dead or
has left** (its Directory reference is stale). A living resident is refused (`ROUTE_UNREGISTER_LIVING`), so the
unregister-and-readmit ban stands for anyone who can still move.

The removal:
- returns the actor's queued links to the free list (`_release_route`);
- drops it from the occupancy index;
- writes the allocator's blank row into every resident column.

A span the actor was on is released with its row, because span retention is the row's `R_EDGE_*` pair. After the
removal, every occupancy proof, `_held_edge`, the ADR 1221 codec and its load validation see the row as never
registered. The ADR 1221 wire is unchanged: an unregistered row has always been the blank row, so persistence
needs nothing new.

This was needed, not just convenient. A dead registered actor makes `read_actor_into` refuse, so the next
`refresh_occupancy` and every later actor edit would fail.

## 2. The foreman releases the lost crew

`Foreman.release_lost_crew()` runs on the tick the runtime detects the loss. The crew is lost when its row is dead,
or when its Directory reference no longer names it (it left).

1. **Haul.** An admitted haul is cancelled through `Delivery.cancel`, which releases its claims and Planner grams.
   Its HAUL Job is retired. The hauler's trips and haul Work so far are folded into the foreman's ledgers.
2. **Phase Job.** After the paid START (START, EARN, RECOVER, REST), Sites' own departure path
   (`Sites.release_worker`) releases the Job and the tool claim and keeps the paid progress. Before START, only the
   tool claim and the Job are released.
3. **Routes.** The lost actor is unregistered (§1).
4. **Crew.** The crew's worker and tool become null, and the foreman waits in `STAGE_RESUME`.

Nothing is rolled back:
- paid progress and consumed inputs stay;
- the step's BUILD Job stays parked and is still the dispatcher's (ADR 1223);
- the lost mole's tool stays with it, or in M's container if it was put down to haul;
- a unit it was carrying stays in its satchel (Delivery: "carried goods survive … a released worker").

## 3. The replacement walks in and the step resumes

The runtime chooses the first living, idle, tooled adult mole (`_tooled_mole`, the same rule as the first crew).
It sets that mole as the crew's worker and tool, and starts ADR 1219's surface walk to H.

- The Jobs reservation follows automatically, because ADR 1223 derives it from the crew.
- With no idle tooled mole, the loss tick raises **`ENTRY_CREW_NO_REPLACEMENT`** (G6) and the entry waits. It
  retries on every JobSelector interval (30 ticks). It never stops.
- The loss itself raises its exact code once (`STEP1_RESIDENT_DEAD` or `ENTRY_CREW_LOST`, G6). The chain keeps
  running.

On arrival, `_resume` treats the replacement exactly as a first arrival: it is unregistered and stands on H.

- **Step not yet opened:** the foreman returns to `STAGE_OPEN`.
- **Step opened, before START:** the foreman hauls what M still lacks (re-derived from M's free stock, so nothing
  is counted twice), or takes the parked Job and travels to the station from H, by H's authored retreat.
- **Step past START:** at the station, `_start` finds the step's Project already WORKING (or WORK_DONE). It binds the
  replacement (`Sites.bind_worker`) and resumes the funded work (`Sites.resume_phase_work`) instead of paying
  again. Finished work goes straight to recovery and settlement.

### Rebinding a paid entry phase (amends decision 1122's entry worker rule)

`underground_entry_world_bindings.gd` only let a worker prove contact before Sites registered it when that worker
was unfunded and READY. Paid work kept its exact stage, so a replacement on a WORKING phase was refused
`CONNECTOR_CONTACT_WORKER`. The first live run showed this.

`_entry_rebinding_worker` admits exactly one more case, prospectively and as contact-only. The replacement must:
- not be registered with Sites itself;
- stand on an unpaused, paid (`work_begun`) phase;
- find that phase's face with no registered worker at all.

Its productive ticks still require Sites' registration and the full paid stage. The surface excavation path already
rebinds a worker this way after a pause (`test_paused_paid_phase_resumes_with_same_wip_after_real_worker_rebind`).

## Persistence

- No new field. The crew's null worker and tool while waiting are written by the existing ADR 1218 crew block.
- `STAGE_RESUME` (10) widens the foreman's stage range. A waiting foreman skips the crew re-proof, because it has no
  crew.
- The record format, `MAX_WIRE_BYTES` and the canonical registry are unchanged.
- The test `test_with_no_spare_the_entry_waits_restores_and_takes_the_next_tooled_mole` round-trips the waiting
  record and resumes from the restored runtime.

## Evidence (`test_underground_host.gd`, `test_underground_routes.gd`)

- **Lost mid-haul.** The crew dies after its first trip. The loss tick:
  - cancels the admitted second unit;
  - unregisters the dead actor and parks the BUILD Job;
  - sends the spare mole in.

  The entry reaches the same next gap with the same ledgers as the uninterrupted run: 36,000 mWU and six units.
- **Lost mid-CUT, after START.** The replacement is bound to the same phase and resumes it. The final Work is
  unchanged (36,000 mWU), so nothing is paid twice or lost.
- **No spare.** The entry raises `ENTRY_CREW_NO_REPLACEMENT` and waits; the waiting record round-trips; the next mole
  equipped is sent within one interval.
- **Left on its walk.** The entry waits, and the departed row is reserved by nobody.
- **Lost during the paid installation:** `ENTRY_CREW_LOST_INSTALLING` (below).
- **Routes:** a living actor is refused. A dead actor mid-span with a queued route is unregistered: blank row, no
  held span, and the image round-trips.

## Amendment: installations (DEC-057, re-handle in place)

The `ENTRY_CREW_LOST_INSTALLING` stop is gone. A crew lost in any installation stage is replaced, and the
installation resumes.

- **Release** (`Installer.release_lost_crew`):
  - an admitted haul is cancelled through Delivery, and its HAUL Job retired (`Hauler.release_lost`, now shared
    with the foreman);
  - the order's Job and tool claim are released from the lost crew;
  - a funded order's assigned count drops to 0.

  The piece, its Region, the paid inputs and every accepted Work mWU stay. The installation waits in
  `STAGE_RESUME` (12).
- **Walk-in.** When the replacement arrives, the foreman registers it on H on H's own profile. It leaves by the
  authored retreat and walks to M, all through the hauler's legs. With nothing to haul (a funded order, or M
  already stocked), the hauler walks under the order's own Job with an empty queue, and that Job is all it carries.
  From M the installation continues as an arrival there.
- **At the station:**
  - **Funded, piece still pending handling:** Router `resume_work` revalidates the replacement at handling READY,
    and handling starts again where the piece stands. Handling earns no Work, so nothing is paid twice.
  - **Piece already handled:** the replacement selects INSTALL directly. Once its source works, `resume_work`
    revalidates it, or, if the fastening was already finished, the retained zero-work Job reads COMPLETE again.
  - **Unfunded:** the ordinary FUND.

Owner rules amended, each excusing exactly the order's own live piece and nothing else:
- `WorldRoutes._assembly_admission` and `Routes._assembly_admission_leaf` use the funded physical proof
  (`AssemblyPhysical.refusal`, which excuses that piece) once the piece is live.
- `Contacts._assembly_rehandling_worker` revalidates a replacement at handling READY, as at START, while a funded,
  unpaused order's piece is pending. The start-geometry pass excuses that piece's Region, but never under a foot.
- `Contacts._assembly_start` no longer applies to an already handled piece; that case revalidates at INSTALL WORK.

**Persistence.** No field is added.
- `STAGE_RESUME` widens the installer's stage range.
- The installer's Job handle is written whenever an order exists. That is the same bytes as before for every
  existing stage.
- A hauler's queue may now be empty.

**Evidence** (`test_underground_host.gd`). The crew dies in each stage it can rest in:
- L0's haul;
- L0's station approach;
- L0's handling;
- L0's INSTALL entry;
- L0's fastening;
- L0's recovery;
- T0's split-landing arrival.

Every run reaches the same next gap with L0 `INSTALLED` once and 32,000 mWU of fastening. A loss mid-handling also
runs with the whole runtime restored every 7 ticks and is byte-identical.
