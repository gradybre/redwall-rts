# Contract review disposition

SAVE-RES-R01v2 resolves all seven precision findings without changing wire bytes.

F1: specify REF for any per-row slot/generation failure; mixed slot generations
retain JOB_GENERATION/LOT_GENERATION. This is the chosen naming split, rather
than the review's proposed shared code for row and group errors. Global scans
fix generation-before-duplicate/sum precedence.
F2: explicitly bind SAVE_RES_BUSY to either open or poisoned Inventory. Retain
one code, consistent with StockAge, instead of adding a new poisoned code.
F3: provide exact public predicate source excerpts; all three are pure bool
queries and already exist. No additional Inventory API is needed.
F4: specify the heap prefix bounds/membership/parent formula and never read tail.
F5: keep canonical_detail as the exact code string, deliberately no richer
buffer. Tests can assert that stated contract; no row-detail promise is made.
F6: explain preserved pending scratch and require a post-restore fresh-count test.
F7: explicitly classify the -1 heap tail as construction residue, never state.

The review's added cases are included in v2 acceptance. Owner metadata/extents
must also remain in compiled ranges before allocating validation staging.
