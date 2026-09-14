# 0140 — Inventory projection, goods safety and movement measurement
Date: 2026-09-14 · Status: Accepted

## Decision
Adopt INV-CANON-R01 and INV-GOODS-R01; adopt MOVE-C2-R01's Q1 convention while
keeping its Q2 production-profile question open. Keep execution evidence distinct
from authoring: one working inventory projection is not a whole-world save, and
an envelope formula is not a measured body.

## Why
The current transfer reads attributes after retirement, so an eager clear would
break behavior. Canonical copying solves unused payload history without changing
the transaction. Demolition needs affected endpoint coverage, not caller-supplied
permission. North-west anchored clearance needs a root-offset fit proof.

## Consequences
Coordinate schema3 with all inventory adapters/compiled declarations; preserve
generations/free order. Real hauling and final revalidation precede demolition.
Profile values and measurements remain gated. No art approval or paid credits.
PR116 is the merged base; preserve the old local working snapshot. PR117 owns
the packet tooling and ADR0139. Cycle1 is ADR0136 on merged master.

## Source
Brendan requested Cycle2 under the repository Astra loop. See
[the complete rulings, evidence and handoff](../planning/astra_cycles/cycle_02.md).
