# 0167 — Preserve the full Expedition reference on fishing claims

Date:2026-09-19 · Status:Accepted FISH-ID-R01v2 after independent review

The existing typed-row plus generation can alias another Expedition after its
Directory slot is reused by a different kind. Public probe: A(2,1) destroyed,
zone(2,2) created, B(3,1) reuses Expedition row0. The old claim is reconstructed as
B, not purged, and can be released by B. This violates generation-checked ownership.

FISH-ID-R01 adds one canonical int32 Expedition-slot column, retains the complete
slot/generation pair and compares both. Preserve stale pairs until normal purge;
no Directory-policy change or load-time repair. Append fishing ordinal7, advance
owner2/section7version4/registry6 and refuse ambiguous old development saves.

Budget the2048-byte resident column and44-byte declaration growth; independently
reconcile179bytes of prior declaration-table ledger drift exposed by this audit.
No new gameplay scope, paid asset, collaborator or persistent allocator is added.
Cross-section reconciliation and whole-world save/load remain separate work.

Recompute candidate accounting by excluding the full19048-byte shared immutable
declaration row, not only its223-byte increase; candidate63770659 and rejected
two-world peak142164558. Historical24-row diagnostic transcription remains a
labeled historical fixture with a named refresh follow-up.
