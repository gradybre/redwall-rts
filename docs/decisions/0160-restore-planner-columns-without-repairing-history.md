# 0160 — Restore planner columns without repairing history

Date: 2026-09-19 · Status: Implemented and merged in PR151 (`e2ce392`); independent review and exact-head CI4703/184136/0 passed

[SAVE-J2-R02v2](../planning/job_planner_bulk_columns_contract.md) supplies exact
35-field capture/restore and the section8 live adapters. Move shared Record,
layout and structural validation into job_index_schema.gd; the codec inherits it,
and the owner uses it without a preload cycle. Existing public constants/types,
wire bytes and schema2 stay compatible. The21required planner constants plus
STATUS_UNMET have one shared definition and backward-compatible owner aliases.

Persisted dirty order/membership/counts remain exact. Rebuild3membership bitsets
and8status-derived counters; reset21session outcome diagnostics. A real runtime
probe proves pending rows can legally reference destroyed jobs. Preserve them
until normal reconciliation instead of rejecting or silently repairing them;
resolving refs must have correct kind and owner typed row. This exact owner API
does not certify cross-owner forage claims or whole-world restore order.

The codec apply API requires the actual supplied world's held load barrier.
No barrier acquisition/release, scheduler change, job creation, claim consumption,
reconciliation or collaborator mutation occurs inside the adapter. Full save
coordination and disk rollback remain independent release obligations.
