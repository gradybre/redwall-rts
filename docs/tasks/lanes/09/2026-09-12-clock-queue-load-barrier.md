# Clock/queue load barrier — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


RESTORE-R01's "a GameManager-only check is insufficient while mutable raw access
exists" is now implemented inside the two objects `game_manager.clock()` and
`game_manager.scheduler_events()` hand out. See
[decision 0104](../decisions/0104-the-load-barrier-is-a-token-the-clock-holds.md).

- `SimClock.acquire_load_barrier()` returns a held token; the raised/lowered bit
  lives in that token, and the clock exposes no call that lowers it. A second
  concurrent grant refuses. `SchedulerEvents` reads the same barrier through its
  bound clock and owns no barrier state, so there is one barrier per world.
- Barred while held, each changing nothing at all: `set_speed`, `set_pause`,
  `advance`, `acknowledge_without_catchup`, `apply_overload`,
  `apply_overload_target`, `note_overload_step`, every `submit_*`,
  `admit_stamped_into`, `pump_into`/`pump`, `clear`, `rebind_clock`,
  `begin_host_frame` and `advance_frame`.
- Passing through, because the barrier is raised *for* them: `restore_runtime`,
  `restore_extension`, `restore_sequence`.
- The barrier is never a pause bit, is never serialized, and lowering it never
  clears a saved `LOAD` hold.

**Still open, and not claimed here.** `game_manager.gd` does not yet acquire or
release this token, so the running game raises only its own `_loading` flag and
the raw-access hole remains open in production until that file's owner adds the
three lines decision 0104 §"What is still owed" names. 09.3 acceptance remains
open on its own terms: this is one named half of RESTORE-R01, and the
disk-backed checkpoint, file rotation and I/O fault injection belong to another
owner. No save parity, full-colony, movement-gate or Windows evidence is implied.
