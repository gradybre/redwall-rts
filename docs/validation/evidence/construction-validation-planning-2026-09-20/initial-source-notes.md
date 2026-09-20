# Construction source discovery — not a contract

Read-only findings while Buildings implementation is in progress. No Construction code changed, domains accepted or runtime results claimed.

Owner1 construction/v1 has16fields,82944primaryrows/nochildren,4893696values,4893828payload,4893864block,offset3298593. `_delivered_milli` is NOT in this section4image: its4-per-project331776cell ledger is separately stored. Exact source layout and source hashes are retained.

Writer facts to exercise publicly before freezing domains:
- clear(): present/work_begun/paused/assigned/max/remaining0; material/self/subject null; purposeBUILD0,type-1,phaseAWAITING0,refundFULL0.
- _write_row(): live, self and subject nonnull, containerNULL, workers0/max4, purpose/type selected from immutable definition/bill facts, remaining declared work, work_begun0, phaseAWAITING if billcount>0 otherwiseREADY, policy derived from purpose/work_begun.
- begin_work(): READY/unpaused/full materials/subjectlive; sets work_begun1/WORKING/policy. add_work_mwu() consumes a positive amount capped to remaining; zero remainder goes WORK_DONE.
- set_assigned_count accepts0..max on any unpaused phase except REFUNDING, including awaiting/ready/workdone. Do not invent working-only assignment. set_paused(true) clears count; begin_refund clears count but retains pause, work_begun, remainder, ledger and policy.
- _retire clears present/work_begun/self/subject/container/assigned/paused/remaining/ledger. It RETAINS max_workers, purpose, type_id, phase and refund_policy. Therefore retired work_begun0 does NOT imply a FULL refund policy: a finished build can retain PARTIAL. Retired rows are not the exact never-used image.
- set_material_container uses the INVENTORY CONTAINER namespace, accepts null or any nonnegative signed-i32 slot/positive generation. It does not constrain slot to Directory capacity; saved inventory capacity/liveness is a separate binding concern.
- declared work for demolition is base building work/4. Existing docs explicitly leave tier2 demolition package basis unresolved; this validator must not invent it. Upgrade allowed only the four existing package types. Furniture uses its nine definitions.

Open planning questions: exact retired/never-used union and phase-history bounds; source-fact tables versus live definition construction; public terminal/refund/pause probes; whether same-file self/subject uniqueness belongs to the subsequent Directory/binding pass and how to prove it without quadratic82944-row scans or an unbudgeted scratch image. A default second owner image would violate the stream ceiling; reuse Buildings borrowed-view strategy only after its real adapter proof. Native memory remains unqualified. No construction/hauling/work integration is completed by these notes.
