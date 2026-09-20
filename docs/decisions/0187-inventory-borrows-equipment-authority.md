# 0187 — Inventory borrows its equipment authority

Date:2026-09-20. Status: Accepted for bounded implementation.

The public diagnostic proves Inventory's strong equipment authority and Gear's strong Inventory collaborator form a retaining cycle. Follow the already accepted seed-expiry authority pattern: Inventory stores WeakRef; Gear retains its collaborators; the composed world retains Gear. The binding is wiring outside authoritative state and survives clear.

EQUIPMENT-LIFETIME-R01v1 preserves live attestation and transactional behavior. Never-bound/explicitly-unbound refuses NO_EQUIPMENT_AUTHORITY. A bound target that expired refuses INVALID_EQUIPMENT_AUTHORITY before attach/detach preflight or mutation. Audit retains the existing orphan-lot refusal. Strong per-call acquisition and the callback reentrancy guard remain mandatory. No automatic stock changes and no weak Gear-to-Inventory edge.

Also free the source-proven anonymous SettlementSystem comparison fixture without changing its expected bytes or assertions. Publish exact repair paths in the contract/work queue before authoring. This is not attribution of all553 objects/33resources. The simple boot diagnostic is clean; full-suite retained counts must be measured again after repair. Require lifetime and refusal-preservation tests, meaningful counterfactuals, full regression, independent authority/security review and normal CI acceptance.
