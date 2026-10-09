# Independent ordinary Room publication review — first source pass

Read-only review of the four files at `source-sha256.json`; source delta retained in `reviewed.diff`. No engine run: the ordinary SpaceOwner/Locations companion dependency is not yet present. This is not runtime or final acceptance.

## R1 — High: irreversible Room tail still dispatches overridable owner methods

`underground_room_orders.gd:_publish_flat_room_identity` invokes `ids.create_candidate`, then `_buildings._publish_spatial_room`. The latter remains an instance method and dispatches `_write_room_row` internally. The coordinator accepts actual Buildings subclasses (the new test itself installs one); it does not pin a concrete implementation. A subclass wrapper can call `super._publish_spatial_room`, then release the original cold lease. The caller already has a live Directory/Buildings Room before the Sites publication guard refuses, producing an assertion/partial publication. The new test arms only `room_identity_into`, so it does not exercise this reachable call.

The newly added static Sites wrappers likewise invoke `actual._claim_batch_current_refusal`, and publication invokes `actual._publish_claim_rows`. Those remain virtual instance helpers, with further ordinary getter/composition calls. A last helper observation can mutate access after the approach final hook, or invalidate the cold token after identity has been created. An outer static function does not close these dispatch points.

Close the new ordinary final/publication boundary with concrete static nested reads/writes or an explicit original implementation closure, while keeping earlier public observation interfaces. Add actual wrappers armed only at the final/after-allocation boundary, preserving live state on refusal and proving valid retry. Do not merely move one callback to a different location after the final access proof. This is a source-reachable sequence; it has not been executed in this review.

## Checked and remaining integration boundary

The new ordinary final order compares the borrowed original plan with its private snapshot and copied Sites input; the batch pins the complete candidate (full ref, kind, typed row, persistent ID), owner/authority, complete Domain key facts, original cold token and history count. Claim publication reuses the existing unique sorted/prepaid cursor rather than allocating a second cut list. Duplicate/unprepared, mutated request and same-sized replacement-lease tests cover meaningful boundaries. No retained column or new array is added by this four-file delta.

The approach observation now runs while the four Sites input/cursor images are retained. The concrete 1150 observer must therefore admit its complete coexisting scratch under the original lease; the base hook itself allocates nothing. The pending 1151 ordinary Space/Locations composition must complete all fallible current-source and companion checks before Room allocation, then publish without an observer or a new refusal after the first swap. The current root Space kernel is still entry-only, so final atomic/composed acceptance awaits those dependencies and execution.
