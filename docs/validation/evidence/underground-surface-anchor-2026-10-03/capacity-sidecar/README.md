# Capacity sidecar refresh

The integrated cc2ffbac Specification checks correctly rejected a stale generated
capacity sidecar. Regeneration changes exactly the reviewed SpaceOwner source
digest and its shifted header resize line2186→2223; no arithmetic, capacity,
canonical field or gate changes. The source hash is725850066ac27f24db48c237d0601c78a8c34efe783b7b142e246f4503d82a07.

Root inspected the complete two-value generated diff. The exact regeneration
comparison passes, and190 capacity-audit checks pass with0 failures. The earlier
failed integrated gate output is preserved in checkpoint-cc2ffbac. This metadata
refresh does not change any GDScript tested by that ongoing full checkpoint.
