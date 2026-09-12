# 0107 — Underground economy and hazard parameters

Date: 2026-09-12 · Status: Accepted engineering values; dependency-gated implementation.

## Decision

Adopt [SET-MOVE-ECON-001](../underground_economy_hazard_amendment.md) as the owning
numerical excavation/spoil and movement-hazard package under DEC-040. Price actual
1m³ cut quanta, maintain real earth/embedded-stock accounts, scope modular phase
refunds explicitly, and bind air/exhaustion/fall/rescue to existing InjuryKind/care.
Four underground levels at4m spacing remain a candidate.

## Why

The user asked to plan the quantities, costs and hazard rules after confirming
the spoil and prevention/rescue direction. Volume pricing avoids free taller
rooms; distinct virgin/embedded source branches prevent repeated-earth creation;
work-ready commit retries prevent repeated XP/tool charges. Deterministic danger
thresholds preserve warnings and rescue without new random disasters.

## Consequences

GDD receives the explicit scoped amendment to REQ-SET-126. Work/gear contribution
settlement and one health-rate owner are required integrations. No new InjuryKind
enum is needed: the earlier audit's missing-domain claim is corrected with GDD
§4.3. These are author-adopted values, not user-measured constants, implemented
runtime behavior, adopted depth or complete movement/visual/performance gates.

## Source

DEC-040; user: “let's plan those as well, then give me what to send back to claude”.
Existing GDD quantities/health/tool/HAUL/care rules are tagged inherited in the
values manifest; new parameters are tagged author-adopted. Independent arithmetic
and account oracles report their own limited validation separately from runtime.
