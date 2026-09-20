# Planner bulk API: source notes before contract

Current35-field schema2 preserves3dirty lists and counts,383884B canonical,
384164B payload,384203B full section. Section8 capture/apply still return the
explicit J2 blocker. Existing revalidate_after_load drops unresolved jobs and
must not run inside a strict restore. The dirty membership bitsets must be
rebuilt from saved prefixes only; mark_all_owners_dirty changes future job IDs.

The codec currently preloads JobPlanner for capacities/status domains. A direct
owner preload of the codec would cycle. A real Godot4.7.2 probe confirms a thin
codec can inherit a shared schema's constants, nested Record type and static
validator while preserving Codec.Record.new() and typed Codec.Record use.
This is language feasibility only, not acceptance of a source extraction.

Candidate design for review: neutral job_planner_state.gd owns existing pure
Record/layout/domain validation; codec inherits it and retains encoding/framing
and live adapter APIs. Owner imports shared state; domain constants either move
to one neutral owner with backward-compatible aliases or remain drift-checked
against existing owner constants. Avoid duplicate validators and dynamic external
reads of another owner's underscore columns. No code extraction is accepted yet.

Cross-reference validity needs particular care: committed simulation boundaries
can hold pending index rows whose completed/cancelled/destroyed jobs will only
be reconciled on a later sweep. A blanket resolve-every-ref restore might reject
valid snapshots or silently consume work. Audit actual reachable transitions
before defining strict refusal; never repair away an exact captured state.
