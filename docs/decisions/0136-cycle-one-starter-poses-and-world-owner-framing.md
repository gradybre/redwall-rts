# 0136 — Starter poses and WORLD owner framing
Date: 2026-09-14 · Status: Accepted

## Decision
Adopt INIT-POSE-R01's explicit initial resident roots and one simulation-owned
Transform store. Adopt R-WORLD-S1-001's nine WORLD owners, typed counted columns
for the seven missing encoders, and correction of three deposit planning arrays
from persistent state to scratch. These are implementation contracts, not runtime
acceptance. Keep the active registry unchanged until its atomic implementation.

## Why
The renderer's private poses cannot participate in simulation or saves. Missing
owner framing blocks valid WORLD serialization. Persisting temporary last-call
deposit plans would make scratch history part of the save identity. Source audit
also found 17 Construction fields absent from the canonical artifact; that is a
separate reconciliation obligation, not authority to freeze obsolete totals.

## Consequences
Preserve generation-safe bindings, previous/current history and atomic publication.
Do not remove memory budget rows until allocations disappear. Reconcile the real
implementation base before parallel lanes; preserve existing staged work. Open
movement, inactive-row, goods, UI and art questions remain open. No credit spend.

## Source
Brendan requested Cycle 1 under the repository Astra loop. Owning GDD §5.1 /
REQ-SET-009, ARCH-SYS-001, ARCH-SAVE-002 and REG-R01; complete decisions and
evidence are linked in [Cycle 1](../planning/astra_cycles/cycle_01.md).
