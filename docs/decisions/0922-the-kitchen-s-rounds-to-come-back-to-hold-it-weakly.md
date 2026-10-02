# 0922 — The kitchen's rounds to come back to hold the kitchen weakly: the Restart leak the scale test suspected
Date: 2026-10-01 · Status: Accepted

## Decision

A cook's round or a drawer's trip kept to come back to (`kitchen.gd unfinished_of`) is now built on a small
`RoundBack` that holds the kitchen's take-back as a **method Callable**. Before, the job was built on the kitchen's
method directly.

A method Callable does not keep its object alive (`unfinished_job.gd` says so), but the job keeps its take-back's
object, which is now the RoundBack and not the kitchen. Once the kitchen is gone the Callable is no longer valid, so
the round is stale: it gives nothing back and is dropped. That is the effect of `kitchen_task.gd`'s own WeakRef, and
the method name stays compile-checked.

## Why

The scale test (decision 0561) saw "N resources still in use at exit" once the kitchen had cooked, and asked whether
Restart demo leaks a whole cast. The soak test's restart watch (decision 0921) measured exactly that. At 25 residents,
a Restart after the first supper left **110 objects of the old village unreachable**:
- all 25 brains and their RandomNumberGenerators;
- the kitchen and its store, takes, nourishment and places;
- the pantry;
- the cast's space, nav, grids and routing desk;
- the tunnel network, the rooms and the water crossings;
- the notices, the incidents and the calendar.

The cycle:
1. `unfinished_job.gd` keeps its take-back's object alive (`_owner`, on purpose: a tunnel job's task would otherwise
   be freed).
2. The kitchen built the job from `_take_back_cook` / `_take_back_draw`, so the job held the kitchen.
3. A brain keeps the job (`_unfinished`) from the moment its cook's or drawer's round is interrupted (an order, the
   night).
4. The kitchen holds every brain (`_brains`).

So brain → job → kitchen → brain, with everything any of them reaches behind it.

A weak holder breaks the one edge that should never have been strong. The other job owners were checked:
- `DigBack`, the night's `WorkBack` and the order list's entries hold ints or WeakRefs;
- the farm, woods and spoil crews hold the cast as a Node.

Clearing `_brains` in `shut_down` was considered and not chosen. It only helps when `shut_down` runs, and the cycle
would still hold between a round's interruption and the scene's exit.

## Consequences

- After the fix, all of these left **0 unreachable**:
  - the 25-resident Restart after supper;
  - five daily Restarts at 9 residents;
  - eleven 6-hourly Restarts at 9 residents;
  - ten 2-hourly Restarts under `--verbose`. Their exit report was empty.
- A round still comes back while the kitchen lives. That is `test_demo_kitchen.gd`'s
  `test_the_cook_called_away_mid_batch_comes_back_to_it`, unchanged and passing.
- `test_demo_kitchen_round_back.gd` covers the rest:
  - a kitchen holding a brain that keeps the round is freed with it;
  - a round does not keep its kitchen, and outliving it is stale;
  - a drawer's trip calls the draw take-back;
  - a live round asks its kitchen.
- The first version held the kitchen in a WeakRef and called a method named by a string. The review (decision 0921's
  change) pointed out that a misspelt name would pass every test, so it now holds the Callable.
- Later runs printed "N resources still in use at exit" now and then (3, 13, 21). Under `--verbose` these are the
  ambient sounds still playing as the process quits (`amb_stream_01.ogg`, `amb_wind_01.wav` and their playbacks), not
  a cycle. The soak now frees the village before quitting (decision 0921 §7), and its exit report is then empty.

## Source

The soak test's restart watch (decision 0921); decision 0561's open defect; decision 0205 (the resume list) and 0381
(the kitchen).
