# Priorities validation primitive — PRIORITIES-S4-VALIDATE-R01v1

ADR0171 accepts one static four-packed-argument predicate for owner11 and a framed bridge that calls it directly. It checks strict presence, distinct boolean policy domains,0..4priorities, reservedkind3zero and exact inactive clearing. The existing inactive-row reader shares the same predicate and retains its guards. All512physical policy rows remain legal; cross-owner living-population limits are separate.

The bridge checks null/owner/schema/metadata/physicalshape before reading the four fields. Metadata uses pinned contract literals plus source capacities, since the owner publishes no column tables. No live owner or Columns projection is constructed and no packed buffer is duplicated. The caller's7680packed bytes are already in the stream allowance; native overhead remains unmeasured.

Planning: two independent reviews and explicit Astra dispositions are in ../priorities-validation-planning-2026-09-20/. The author returned286patchlines, which passed exactinputSHA, exacttargetallowlist and git apply --recount --check before application. No production repair was needed at intake. Worker packet/input/result/events and stopped ownership are archived.

Current validation:
- Focus33tests /7585assertions /0failures;11new tests plus22existing public API tests.
- Every6144priority byte covered; nondefault player settings, reserved first/last rows,512present, malformed inputs, exactrefusal precedence and nonmutation tested.
- Eight projection/domain mutants killed by assertions, including four zero substitutions and the asymmetric policy swap. Baseline/restored controls pass with no parser/script-error kill.
-18real-engine metadata cases /162assertions pass, including eight guard bypasses killed. Schema-valid owner/field faults preserve prerequisite arithmetic; type/extent counterfactuals adjust both compiled and expected totals only inside the disposable clone. The production generator and capacity proofs are unchanged.
-17static/source gates pass; source-capacity sidecar refreshed, import passes. Independent source review and bounded follow-up found no blocker. The parent removed a temporary range Array and strengthened an owner-label assertion; focused/mutations/metadata/static checks passed again on final source. Pre-cleanup full suite passes4895/216053/0; final full suite also passes4895/216053/0 with unchanged553objects/33resources shutdown diagnostics. Exact-head CI is pending.

This completes neither bulk capture/apply nor cross-owner agreement, the all18-owner parent, coordinator or full save/load. No first-playable or release acceptance is inferred.
