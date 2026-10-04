# Multi-cell ordinary Room frontier responsibility

This is a read-only trace of the integration working-tree bytes pinned in
`source-sha256.json`. It adds no runtime owner, policy, source permission or
state. Parent host work outside this pinned snapshot is not assessed.

**No current owner automatically selects the next reachable ordinary Kitchen
Site after the first paid cube completes.** The existing owners provide parts
of that workflow:

| Existing owner / method | Current responsibility | What it does not do |
|---|---|---|
| `modular_access.gd::_next_candidate`, `_derive`, `_attempt` | Enumerate live endpoints and source profiles, derive a source contact on the painted boundary and prove the selected first approach. | Schedule a second excavation Site after completion. |
| `modular_runtime.gd::_confirm` | Forward the selected first-contact RoomPlan to actual `Orders.confirm_room`, then return its receipt. | Open, assign or advance paid excavation phases. |
| `underground_room_cut_map.gd::advance` | Enumerate the exact touched whole-cube union in canonical Sites Y/Z/X order under a bounded cold operation. | Decide which cube is physically reachable or grant a work contact. |
| `excavation_sites.gd::site_at`, `room_of`, `open_phase` | Resolve an already claimed exact Site and open the caller-selected Site/operation through Construction. | Select a Room's next frontier. |
| `Sites::_operation_allowed`, `_settle_phase`, `_publish_physical_completion`, `_retire_phase` | Enforce the selected Site's BRACE → CUT → FINISH history, publish its paid result and retire its Project/Job while keeping physical history. | Open the next Site/phase or assign another worker. |
| `Placements.prepare_room_phase_refresh` and `Locations.stage_refresh` | Revalidate and refresh existing companion records as geometry changes. | Create new work stations, connect the newly opened cube or invent a next route. |

The retained `phase-callsite-search.txt` searches runtime `godot/scripts` and
`godot/demo` for `open_phase`, `begin_phase_work` and `settle_phase`. In this
snapshot it finds the Site definitions/internal dispatch only, with no host
caller running the sequence. Decision 1154 explicitly labels its selection
“First cut / work face”; confirmation is not a retained phase permission.

The missing host responsibility is a bounded operation scheduler for a confirmed
Room. It must derive candidate Sites from the actual Room claim/cube source,
inspect their current paid physical history, and choose only a candidate whose
current full WorkFace and directed approach/retreat can be proved. Its next
operation may be another phase on the same cube before advancing to another
cube. Canonical cube order alone is not a reachable-frontier rule.

The host must also arrange actual worker/Job assignment, material and output
endpoints, movement, phase START, productive Work and settlement/retry. Where
newly paid geometry needs another work station or path, that publication needs
an actual supported endpoint and source-qualified directed edge through the
existing spatial owners. Refreshing an old endpoint cannot supply this missing
publication. Full refs, source revisions and paid phase checks remain mandatory
at each operation; the first contact's admission witness cannot be reused as
permission for another cube.

Therefore a future one-cube 1152 BRACE/CUT/FINISH positive proves the provider's
paid operation boundary only. Whole Kitchen completion still requires that
host sequence to run across every required claimed cube, with all final Room
geometry and outputs published. This trace does not choose a new frontier
algorithm or authorize speculative implementation.
