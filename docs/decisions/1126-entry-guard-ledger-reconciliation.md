# 1126 — Entry and phase-guard allocation ledger reconciliation

Date: 2026-10-04. Status: source and ledger correction independently accepted.

The integrated Specification job at2929bc2a refused READY07 arithmetic because
its exact Sites boolean set still allowed only the original publication guard.
Its expected joint total and the architecture allocation table also predated
the already reviewed1117/1120 transaction guards and1122 EntryStructure packet.
The source-derived joint pack correctly included those additions; allowing the
old table to continue asserting the earlier total would hide388 logical bytes.

Keep1071's original one-byte guard,1072's4,962,389-byte contribution and1102's
4,096-byte increment unchanged. Add three explicit architecture allocation and
trail rows:1117's two synchronous boolean bytes,1120's two synchronous boolean
bytes, and1122's384-byte fixed/helper reservation. The last amount includes153
fixed bytes plus231 helper bytes; neither it nor the guards can borrow the
already assigned524,288-byte binding allowance.1121's128-byte shared context
and mode remain inside the previously admitted Placement allowance and are not
charged a second time.

The architecture now has48 allocation rows: payload91,571,030, live plus the
unchanged8,388,608 reserve99,959,638, and40,362 below the unchanged decimal100MB
limit. The historical rejected two-world alternative grows by776 to185,280,975.
Its mutable candidate is85,321,337; disk-backed rollback remains required.

READY07 keeps exact expected control names, source-derived contributions,
explicit historical deltas, allocation-row count, totals and trail endpoint.
It additionally compares its live total directly with the joint source pack.
Existing memory-checker mutants still reject missing, wider, duplicate and
extra guards or Entry fields. No diagnostic, capacity, memory or runtime
qualification threshold is relaxed. This changes no gameplay or runtime code.

The rejected integrated Specification run retains34 command logs:33 passed,
READY07 failed. The corrected source arithmetic, merge gate and sixteen merge
gate self-tests pass locally. Independent Geometry review accepted source pins77fdec5b… and35adfacd9…
after recomputing each total and once-only historical charge. The integrated
rerun remains required; logical arithmetic does not measure native allocations or qualify
the complete client at256 residents.
