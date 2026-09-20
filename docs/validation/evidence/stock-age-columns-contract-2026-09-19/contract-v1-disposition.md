# SAVE-AGE-R01v2 contract disposition

H1: choose direct public typed-group transfer after explicit shape/payload validation, using storage_index_of; no public setters or untested setter-return paths. Count/latch singletoni64arrays allocated independently.
H2: capture staged codec validation is defensive equivalence, hostile semantic failures tested through apply; paired adversarial rule matrix verifies both validators.
H3: returned Refusal is authoritative for both directions, including a hypothetical post-owner capture failure after its diagnostic cleared.
H4: membership scratch function-local, released on return; never owner state.
H5: actual Inventory.is_transaction_open/is_transaction_poisoned return their bool fields; SimClock.is_load_barrier_held queries its LoadBarrier.is_held which returns _held. All are real pure predicates. Include actual Inventory and SimClock in implementation context.
H6: retain optional clock=null intentionally for a structured missing-clock refusal, consistent with the other accepted adapters; a default that refuses is not contradictory.
H7: use unique copy_stock_age_columns_into/restore_stock_age_columns names. Existing Inventory duck gates cannot accept this owner accidentally. No need to expand scope into the old generic API.
H8: per-object/phase accounting only; local constructor arrays, retained buffers and old/new owner fields explicitly considered. No single measured peak/RSS claim.
H9: second Inventory is reconstructed by replaying identical public operations. Only StockAge is restored; test uses actual[2,1] vs[1,2] witness to observe downstream lot IDs.
H10: test-only reflective corruption injection explicitly permitted; production reflection prohibited.
H11: published group Arrays owned solely by output after private locals leave scope; no post-publication mutation. Old buffers stay old because replaced without mutation, not COW.
H12: caller forbids reentry during aging/declaration/Inventory authority callbacks. We do not claim transaction booleans prove whole-world quiescence or that Inventory transitively cannot call an authority.

Version2 accepted for bounded implementation. Structural latch domain and all wire/schema/classification bytes unchanged. Full stock-integrity continuation remains coordinator work.
