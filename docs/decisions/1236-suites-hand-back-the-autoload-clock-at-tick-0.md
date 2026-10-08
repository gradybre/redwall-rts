# 1236 — A suite that drives the GameManager autoload hands its clock back at tick 0

Date: 2026-10-08 · Status: Accepted

## What happened

From the ADR 1228 settlement-save work on, the full suite failed three tests in `test_settlement_system.gd`
(a paused zone edit's cancellation never drained, a stamped replay refused, a SET_POLICY edit never ran) that
passed when the suite ran alone.

Cause: `SettlementSystem._ensure_command_clock()` rebinds the settlement's command queue to
`GameManager.clock()` — the **autoload's** clock — after its first drain, even for a settlement built with
`.new()` and driven by a test's private GameManager. `test_settlement_save_load`, `_parity`, `_underground` and
`test_save_installed_geometry` drive the autoload through `start_game()`/`advance_host_time()` and left it at
tick 300–1200 (their teardown only unbound, cleared the scheduler queue and dropped CRITICAL). Every later
settlement then stamped commands at that tick + 1, which a test's private clock never reaches, and
`admit_stamped_into` refused replays as TICK_IN_PAST. Alone, the autoload sat at tick 0, so the stamps fell
due at once.

## Rule

A test suite that advances the GameManager autoload's clock calls
`test/fixtures/autoload_clock_reset.gd`'s `release()` from `after_each()`. It unbinds, installs a fresh tick-0
clock through `start_game()` (the only API that does), and empties the scheduler queue, asserting the clock is
back at 0. `test_settlement_system.gd`'s `before_each()` asserts the autoload clock is at tick 0, so a future
leak fails there with a message naming this record instead of as unrelated command failures.

## Not changed

Production behaviour: in the game there is one GameManager and the settlement is bound to it, so following the
autoload clock is correct. Making the settlement follow whichever manager drives it would be a wider change to
the binding API than this leak needs.
