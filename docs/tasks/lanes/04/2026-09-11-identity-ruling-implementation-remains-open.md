# 2026-09-11 identity ruling — implementation remains open

Task: 04_world_commands.md
Date: 2026-09-11


[R-INIT-ID-001](../rulings/2026-09-11_initial_ids_and_narrow_alerts.md) resolves
the historical 1714–1725 divergence above: reset the composed transaction once
before allocation, allocate the cohort first as global IDs 1–12, then allocate
world entities without clearing that cohort. The previous “needs a ruling”
statement is historical. Replace its diagnostic test deliberately; retain the
derived world census and add the ruling’s uniqueness/failure/determinism evidence.
