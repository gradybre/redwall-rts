# Root Contacts / Delivery readiness migration source review

Read-only independent review of the two-file diff retained in `root-delta.patch`
at the exact hashes in `source-sha256.json`. The current Geometry1156 Routes
implementation was read as API context only; its separate source and runtime
review was still pending. No engine, allocation measurement or foreign source
write was performed here.

No high/medium finding in this bounded delta:

- Contacts `_observe_workers` observes readiness before the existing final
  proof. Both final observation entry points retain their original reentry
  guard and original scope recheck. The new call receives the selected exact
  station profile/revision and Frontier content revision.
- `_worker_leaf` still proves the actual full Job/worker/endpoint, current
  direct dynamic selection, tool/load, root, yaw and committed source tuple.
  It then calls concrete `Routes.source_work_leaf_refusal`, before the existing
  direct retreat, occupancy and handling checks. The obsolete raw phase-word
  equality is removed; no new caller boolean or source permission substitutes
  for those physical checks.
- START/PRODUCTIVE still require workers. Worker-free COMMIT/CANCEL retain their
  existing branch and are not made dependent on source WORK readiness.
- Delivery replaces only its raw arrival phase comparison with concrete static
  `actor_phase_in`. Full current handling/source/cargo checks already precede it,
  and the exact endpoint, no-edge and no-queued-span checks remain. This is
  physical arrival decoding, not new HAUL source qualification.
- The draft Routes transitive static implementations read concrete original
  columns and static source equations. `actor_phase_in` does not call the
  instance observer. `source_work_leaf_refusal` validates original caller
  worker/Job/profile/content, complete clock/tag semantics, physical stationary
  state and the SOURCE_WORK subphase where tagged. Observed Profile reads remain
  in the separate observation method.

Final integration still requires the frozen1156 dependency, combined consumer
fingerprint renewal, actual regression execution, and source-derived numeric
helper coexistence. No retained field is added by this diff. This review does
not qualify its transitive helper growth, production haul content, paid ordinary
Room traversal, or whole-room completion.
