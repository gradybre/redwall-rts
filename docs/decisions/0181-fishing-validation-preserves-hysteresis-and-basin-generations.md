# 0181 — Fishing validation preserves hysteresis and basin generations

Date:2026-09-20. Status: Accepted for bounded implementation.

FISHING-S4-VALIDATE-R01v1 adds a cold22-field Columns image, static local predicate and framed owner4 adapter. The section4 owner remains version1; the existing section7 claim schema2 is separate. No gameplay, claim restore, new bulk capture/apply or canonical schema change belongs to this milestone.

All three stocks are owned by their habitat row and must match its presence, self reference and source capacities. Item IDs remain arbitrary nonnegative i32 locally, not species table offsets. Public writers bound population to10%..100% capacity and harvested totals to the daily shared quota. Restocking retains either boolean in the inclusive30%..40% band; strict cross multiplication handles transitions outside it. Destruction preserves selected habitat history but blanks all stock rows.

Current self slots must be unique, while zone uniqueness compares full slot/generation pairs. The public106-assertion probe demonstrates old/new zone generations coexisting, quota/floor/refusal behavior and both hysteresis directions. Inactive private bytes remain source-backed, not claimed from refusing public getters.

Caller5344 plus cold defaults5344 gives10688 conservative logical packed bytes. Fixed32-row duplicate scans need no packed scratch; native/RSS remains unmeasured. Independent contract findings are closed by explicit67 shape cases, clear swapped-order mutant labeling, equivalent-arithmetic exclusions and indirect Fishing.EntityDirectory metadata access. Actual code/runtime/fault/CI acceptance remains required. Full saved bindings and gameplay integration are not waived.
