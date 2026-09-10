# First playable checkpoint — evidence checklist

2026-09-09 · **PLANNED, not executed.** Owner: integration lead; technical QA
and player QA verify independently. This is an intermediate task-05 checkpoint,
not complete movement, colony survival or release acceptance.

## Required prerequisites

Task 04's real initializer/commands/pending UI; task 03's live resource/forage
producer; task 05's compatible contacts/navigation/motion; actual work factors,
source/output/cargo reservations and legal starter storage from task 06's
pulled-forward slice. Use the approved refuge baseline at seed 20260905; do not
spawn free jobs/resources or treat visual stand-ins as production art evidence.
Read REQ-SET-002–009, §5.3 job rules, §5.7–5.8 inventory/WU rules, BAL-WORK-001,
ARCH-CMD/TICK/JOB/INV, MOVE-REQ-001/005–008/013/018/019 and UI registry behavior.

Prefer a player-enabled safe roots forage zone for the opening/tutorial contract.
Record the exact existing patch/basin/contact and authoritative recipe/yield/work
fixture selected before the run. If that producer remains blocked, report this
checkpoint blocked; a separate tree-extraction diagnostic is not the same fixture.
Do not invent a harvest amount or completion tick. Derive expected totals from
catalog quantities, quota, worker factors, path length and carried capacity, and
store the calculation beside the recorded outcome. Synthetic microfixtures are
separate from the unmodified production start.

## Observable loop and failure cases

| ID | Action / trigger | Required evidence |
|---|---|---|
| FP-01 | Start a new refuge | Correct 12 residents, legal beds/services/starter lots, 24 total tools, empty starting orders, 06:00 tick zero and initially paused UI; hashes/initializer assertions |
| FP-02 | Designate safe roots zone while paused | Visible pending preview; no stock/WU/need/deadline mutation; command due next tick, selection/camera remain usable |
| FP-03 | Resume | One producer creates the required unique job; queue/claims and target references identify the real intent; preview becomes committed or explains refusal |
| FP-04 | Worker approaches and begins work | Visible compatible travel/contact; no WU in travel; correct TRAVEL/WORK boundary, load and capability checked; no teleport or direct state injection |
| FP-05 | Work produces and delivers | Exact catalog/quota debit, work/XP remainder, atomic output into real cargo then reachable filtered storage; no output counted at both worker and store |
| FP-06 | Repeat with resource/destination contested | All-or-nothing claims; one output, no negative stock or duplicate delivery; full destination leaves recoverable goods and a visible reason |
| FP-07 | Cancel at preview, RESERVED, travel, WORK and hauling | Exact owner-contract effects for each phase; no unsupported refund or disappearing cargo; occupied traversal reaches a legal safe cancellation boundary |
| FP-08 | Route pending versus occupied versus unreachable | Distinct text and non-color cue; renew while planning/waiting, no false unreachable timeout; confirmed-unreachable retry follows 300/900 tick rules |
| FP-09 | Destroy/reuse target; change topology or load | Stale ref rejects; future route revalidates; no work through walls/floors; deletion of occupied access/only exit refuses |
| FP-10 | Needs interruption and return | Reachable consumption/rest and legal work resumption with preserved WIP/XP; if service runtime is absent, mark blocked rather than credit floor sleep |
| FP-11 | Repeat same commands at 1×/2×/4× and different views | Equal-tick canonical state agreement over all participating stores; pause freezes authority; layer/LOD/UI actions do not alter RNG or routes |
| FP-12 | Use keyboard/trackpad and narrow layout | No hidden focused controls or swallowed world input; understandable selection/order/cancel/blocked feedback; actual Mac screenshots and player-impact report |

## Required record and truthful completion

Store a manifest under `docs/validation/evidence/first-playable/` when executed:
source revision/dirty diff digest, engine/export/PCK/catalog/scenario hashes,
hardware, exact launch/test commands, seed, tick-indexed commands, initial state,
expected versus actual WU/XP/quantities/quota, per-case pass/fail/blocked,
screenshots/video paths, raw logs and first-divergence data. This is a proposed
evidence location, not an existing result. Preserve test-runner summary counts.

Check item conservation with explicit STARTER/extracted/transformed/spoiled/
consumed/discarded quantities and inventories/cargo/WIP; reservations are claims,
not additional goods. Each transaction's ledger must balance in milli-U; ecology
stock/quota tracks its own debit. Test source/sink transformations by recipe,
not by requiring different item IDs to be conserved individually.

Canonical serializers may be built incrementally, but state scope must be exact.
Until the production codec/save owner exists, independently compare every field
of participating stores each tick and label the result **checkpoint-local
repeatability**, not full replay/save parity. Test pending save/load and active
routes later through task 09; never use in-memory cloning as that evidence.

FP-01–12 must pass for this checkpoint, or the result is partial with named
blockers. Production save parity and complete connected-domain tests are
additional gates, not hidden prerequisites for observing the basic loop. The
checkpoint does not close MOVE-G01–05, establish all families/scenarios, winter
survival, finished art/audio or reference-hardware performance. Next work follows
task 05's remaining movement increments alongside tasks 06–08 dependencies.
