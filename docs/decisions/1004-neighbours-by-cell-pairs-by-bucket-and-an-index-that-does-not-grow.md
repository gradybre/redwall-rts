# 1004 — Residents by cell for the walking step, the people's pairs by bucket, and a claim index that does not grow with the village
Date: 2026-10-02 · Status: Accepted

Part of Brendan's approved "smaller fixes" after the scale test (decision 0561's hot spots 4, 6 and 7). Decision 1001
gives the context and numbering.

## Decision

1. **Residents by cell** (`demo/cast/resident_cells.gd`, `cast_space.gd` NEIGHBOURS BY CELL).
   - Each resident is kept in the bucket of the 2 m cell it stands in. It moves between buckets only when it crosses a
     cell's edge (`move_resident`).
   - `separation`, `constrain`, `standing_blocks` (and so `line_clear`) and `surface_occupied` read only the residents
     in the cells their question overlaps, and test each exactly as before.
   - Where the order matters (a sum of pushes, a sequence of them) the residents come in ascending order: the old
     order.
   - A box over more than 64 cells (a long sight line) reads everyone.
   - A resident appended to the columns without `add_resident` (one fixture does) puts the questions back on the scan
     over everyone.
   - `constrain`'s box is the step's box widened by both bodies, 8 strides and 0.5 m. A push moves the step at most
     its own distance from where it began, so a few pushes stay inside it.
   - A step pushed beyond that span is pushed again by everyone (`_pushed`, checked before and after each push). The
     review pointed out that chained pushes can double the drift, so the answer is the scan's in every case.
   - Each bucket keeps its residents in ascending order, so a crowd in one cell (the hall's door at dusk) needs no
     reordering.
2. **The people's pairs by bucket** (`demo/people/people_taps.gd` PAIRS BY BUCKET). Shared work looks only at pairs at
   the same dig, and at pairs on board tasks in the same or a neighbouring NEAR_M cell (8 m). The pairs are sorted and
   de-duplicated, then tested by `together` and credited in the old (a, b) order, so the ledger moves exactly as before.
   `ledger.midnight`, the supper pass and the N x N ledger are not changed. The supper pass is the review-fix lane's.
3. **The work board's claim index does not grow with the village** (`demo/work/work_board.gd` THE INDEX DOES NOT GROW
   WITH THE VILLAGE).
   - A source whose rows can never hold a task to claim says so (`work_source.gd may_wait`, false for the kitchen, a
     row per resident) and is not read.
   - The promises are kept by task in a Dictionary built once a rebuild. Each lookup is O(1), not a pass over every
     order-list entry.
   - The index it builds is the old one, entry for entry and promise for promise.

## Why

- **Exactness was cheap to keep, so it was kept.** Three tests compare each change with the old full scans:
  - `test_demo_resident_cells.gd`: the four questions, against the old scans, over 80 residents moved at random for
    300 rounds;
  - `test_demo_people_pairs.gd`: the pairs, against the loop over every pair, for 40 random villages of 120;
  - `test_demo_work_index.gd`: the index, against the old rebuild, for 25 random boards and order lists.
- **The board was not made revision-driven.** The scale test recommended rebuilding the index "incrementally on owner
  revisions". The thirteen sources' `waiting(row)` read their owners' state in thirteen ways: crews, stores, the
  network, time. A source would need a revision its owner bumps on every change `waiting` can see, and no owner
  promises that today. A missed bump would leave a waiting task unclaimed, silently. Instead the rebuild's only parts
  that grew with the village are gone: the kitchen's row per resident and the promise search. After decision 1001 the
  board's measured cost is a fraction of a millisecond at 100 residents. Its old p99 spikes were the route plans its
  claims started, which the routing desk now cuts. **PROPOSAL (Brendan):** owners could publish a waiting revision.
  Options: (a) leave the index as it is; (b) add `revision()` to the sources one owner at a time, each with a test that
  every change `waiting` reads bumps it. Recommendation: (a), until the board shows in a profile again.
- **2 m cells, 64 at most.** A walker's own questions reach 1.7 m (two badgers and the separation margin), so a 2 m
  cell keeps a look to 2 x 2 or 3 x 3 cells. 64 cells is a 16 m box, beyond which the old scan costs no more than
  hashing the cells.

## Consequences

- `cast_space.gd`'s per-frame questions no longer cost O(residents) each. They read the cells round them, plus a sort
  of a handful of candidates where order matters.
- `people_taps.gd`'s shared-work poll costs O(residents on tasks and digs), plus their pairs within 8 m.
- `room_ahead`, `oncoming` and `mouth_clear` (residents in a bore) still scan everyone. Only residents in a tunnel ask
  them.


## Brendan's rulings (2026-10-02)

Brendan approved 1004 as recommended:
- no revision-driven ("truly incremental") board rebuild for now (option (a)).

## Source

Decision 0561's hot spots 4, 6 and 7 and recommendations 5–7; decisions 0196 (the cast space), 0491 (the people) and
0411 (the work board); Brendan's approval of 2026-10-02.
