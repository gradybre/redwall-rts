# Astra disposition — final Construction design review

Accepted for bounded implementation as CONSTRUCTION-S4-VALIDATE-R01v2 / ADR0186. Full independent reviews remain intact; this is design acceptance only.

C1: four retained negative cases added to witness-plan-v2 (40 single faults, 48 shape cases). C2: bill/catalog/fact keys are exact TYPE_STRING, with explicit StringName conversion only after type proof for material membership. C3: BUILD/UPGRADE/DEMOLISH use building worker facts; furniture uses4. C4: positive/divisible4 building work and positive other work explicit; demolition no-bill is a structural assumption with fail-closed future direction. C5: direct caller-owned Columns nonmutation and direct mutation counterfactual required; bridge CoW and allocation checks are independent.

Both direct preflight collision pairs are explicit. Real public retained histories are required for all4 purposes, not synthetic-only coverage. The accepted framing probe is fixed-width/genuine-output only, has test-only allocations and currently covers BUILD only. The original public-history probe used Buildings8f21111b; retained probe a2 uses Buildingseb6d09a1. Construction78e72461 is unchanged. Their source-bound results remain separate; no combined coherent-source claim. See probe-source-lineage.json beside both artifacts.

Minor notes adopted: static mapper called directly without wrapper; no performance claim; explicit compile/sort ban. Flag count scanning is implementation latitude. The delivered ledger registration correction is accepted: section5 codec/capture/apply/bindings remain pending, not registry coverage.
