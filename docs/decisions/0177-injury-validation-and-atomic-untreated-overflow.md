# 0177 — Validate Injury history and refuse untreated-counter overflow atomically

Date2026-09-20. Status: Accepted. Contract INJURY-S4-VALIDATE-R01v1.

Add a pure11column owner6 validator and framed bridge with unchanged version1/512rows. Validate boolean/kind/severity/ref and full nonnegativei64 domains, kind/severity association, no-injury time/care reset, positive incident history for injury/latches, exact inactive defaults and unique nonnull rescuer pairs. Healthy bindings and stale references remain valid; different generations on one slot are distinct. No live lookup or extra packed scratch.

An actual injected boundary experiment showed tick_all reporting success while advancing an earlier patient and wrapping untreated INT64_MAX toINT64_MIN. Keep the full saved scalar domain and repair the producer: preflight all eligible rows before any increments, refuse existingOVERFLOW and record first blocked row. Dead/uninjured/inactive rows stay skipped, nullNeeds staysdiagnostic-1, MAX-1 advancesonce thennexttickrefuses. Canonical Injury/Needs data stay unchanged on refusal. No new column, public mutator, health clock or recipe ceiling.

Public history47assertions/0 confirms full care/ordinal extrema, checked care overflow, treatment-retained latches/ordinal and healthy/stale rescue. Injected boundary12/0 is explicitly not public reachability or restore evidence. Parent tests may seed that single private counter via inheritedset only to test the actual public tick and diagnostics; no production getter/setter is added. Future real bulkrestore requires separate continuation proof.

Independent feasibility and final contract review accepted source geometry, metadata arithmetic and33required mutants. Caller20992packedbytes stay inside existingstream allowance6417408; native/wrapper overhead remains unmeasured. Required same-file Needs/resident/Directory/movement identity and bulkcapture/restore are separate blocked prerequisites. Author owns injury.gd andnewbridge only; parent owns tests/tools/docs. Production intake follows ResourceNodes predecessor merge; exact-head CI gates this change too.
