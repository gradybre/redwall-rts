# 0184 — Prepare the authored refuge without fabricating physical access

September20,2026. Accepted for INIT-C-PREP-R01v1 implementation after independent design review.

The exact starter refuge exists in the GDD, but production initialization still seeds no buildings. A compact preparation dependency makes those authored data executable while the real topology, measured envelopes and service-contact owners are completed.

The plan uses ten packed integer arrays/2480logical bytes for seven buildings, four room runs,31floor furniture instances, eight undirected partition edges, all candidate access tiles, the three-part south exit and bed allocation order. Room ordinals and compiled types are distinct. Edges retain both adjacent room ordinals; future runtime edge encoding chooses ownership. Pantry access may cross the open common-room boundary, as the GDD requires.

The independent review's exact diagram arithmetic is accepted. Its summary budget differs from its table and assumes unspecified scalars; the final explicit contract removes those undefined fields and freezes2480bytes. Its suggested serial is declined: no success flag is stored in the plan, refusal preserves the prior successful output, the caller must inspect the return value, and repeated successful preparation must be byte-identical. A serial cannot make an ignored return value safe. The three exit refusals and a counterfactual solid-edge candidate test are required.

Tile connectivity is not body fit, room validity, heat, exterior reachability or a real contact. The producer never allocates a mutable world owner or publishes gameplay. This is one INIT-C dependency and cannot complete INIT-C, INIT-E or FP-01. No release scope or rollback requirement changes.

## Independent source review disposition

The independent review found no production correctness, safety or allocation must-fix. Its frozen-reference-loading condition is being met with an executable reference check, not waived. Final imported/committed file identity and CI remain required. Detailed dispositions are recorded in the starter evidence directory.

For this bounded cold module, Astra accepts a narrow style exception for the existing long sequential validation/fill/exact-match functions, trivial column accessors without separate docstrings, and inferred integer loop counters. The ordered checks and explicit all-field comparisons remain directly auditable, and a style-only runtime rewrite is unnecessary for this acceptance. This exception does not relax typed authoritative storage, refusal ordering, bounds checks, hot-path rules or any functional acceptance criterion. New test helpers remain typed, documented and short.

The catalog verifier recommendation is not adopted as a direct replacement: its current implementation coerces values with `int()`, whereas this module must reject string IDs before use. Strict metadata type checks remain required. The future materializer still owns rotation/pivot semantics; this plan publishes rotation-zero authored rows only.
