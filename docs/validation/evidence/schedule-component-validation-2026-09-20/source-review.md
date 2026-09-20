# Independent source review — Schedule owner 14 validation

Date: 2026-09-20. Scope: `schedule.gd` (`columns_refusal`, `_free_row_is_clear`), new
`save_owner_schedule.gd`, the two test suites, and `tools/test_schedule_metadata_preflights.py`,
reviewed against SCHEDULE-S4-VALIDATE-R01 v1 and ADR 0172. Reading only; nothing was run here,
and the recorded focus and metadata results are treated as reported evidence, not as my results.
Accepted deferred scope (bulk/`present_count` rebuild, cross-owner agreement, section 2 catalog
identity, lifecycle publication, migration, full save/load) is deliberately not reopened.

## Argument mapping and shapes

The predicate signature is `(present, hourly_activity, template_ids, current_activity,
sleep_satisfied, resolved)`. The bridge supplies `u8_column(0)`, `u8_column(1)`, `i32_column(2)`,
`i32_column(3)`, `u8_column(4)`, `u8_column(5)` in exactly that order, with the ordinals pinned as
named scalar constants rather than inline literals. That matches the contract's canonical order and
the owner's field ordinals.

The compiled schema for owner 14 places its six fields at global ordinals 265–270:
`_present` u8[512], `_hourly_activity` u8[12288], `_template` i32[512], `_current_activity`
i32[512], `_sleep_satisfied` u8[512], `_resolved` u8[512]. Physical extents reconcile: value bytes
512+12288+2048+2048+512+512 = 17920; payload 17920 + 4 child-count bytes + 6*8 element-count bytes
= 17972, which is the declared payload; block 17972 + 24 wrapper bytes + 8 key bytes = 18004, which
is the declared block; and owner offset 9722581 + 18004 = 9740585, the declared Transforms offset.
The bridge additionally pins 512/24/4/3/1 against the owner's own constants and 12288 = 512*24.

## Gate order and global completeness

`columns_refusal` runs shape, then present/sleep/resolved flag bytes, then hourly/template/current
domains, then free-row, unresolved-state and sleep-state, each as a complete pass over all 512
physical rows (12288 bytes for hourly) before the next begins. That is gates 1–10 in the contract's
exact order, so a later row's earlier gate wins over row 0's later fault; the precedence test
exercises that across nine distinct rows. Flag columns use `count(0)+count(1) != 512`, which is a
sound whole-column 0/1 domain test for a byte array. The hourly test needs no lower bound because
packed bytes cannot be negative; both i32 columns are checked on both signs, and the tests pin
INT32_MIN, -1 and INT32_MAX. No default buffer, duplicate, sort, range Array, Columns object,
callback or diagnostic write appears in either new path.

## Inactive helper and reader guards

`_free_row_is_clear` is static, takes a validated slot, performs no address or presence check, and
is reached only after complete shape and domain gates. `inactive_row_is_clear` retains its slot
range and `present != 0` guards before delegating, and the reader-guard test still pins -1, 512,
a present row and a despawned row. No other gameplay path was touched.

## Present-row implications

I re-derived both implications from the writers rather than accepting the disposition. `spawn` and
`_write_template_hours` leave current ANYTHING, resolved 0, latch 0. `assign_template` clears the
latch and deliberately retains current/resolved, so an unresolved row keeps ANYTHING/0.
`_resolve_activity` clears the latch on collapse and on every non-SLEEP branch, and on the
scheduled-SLEEP branch returns ANYTHING whenever the latch is or becomes 1. `despawn` restores the
free-row state. I found no reachable public counterexample to "unresolved implies current ANYTHING
and latch 0" or "latch 1 implies current ANYTHING". Nothing in the predicate compares current
activity with the timetable, template, clock, Needs or hunger/rest, so edited hours, reassignment
and a later refused resolve all keep resolved history — which the public-history test replays
through the real owner API rather than through a fixture.

## Dependencies, memory and security

The bridge preloads only Schedule, Schema, Section and SaveHeader; `Section` reaches Schema,
SaveCodec and SaveHeader. There is no CatalogIds edge in either direction from these files, so the
cycle CatalogIds→Schedule is not closed. No Schedule, Needs or catalog instance is constructed;
every new function is static. The six accessors return stored columns without duplication and are
passed straight through, so no projection or scan scratch is added and inputs are unmutated on both
the accepted and refused paths, which the tests assert by value comparison. Loops are bounded by
fixed compiled extents, so input cannot drive allocation or iteration count. Column-failure details
carry only the owner index and the exact code — no row identity and no payload values; metadata
details quote compiled constants, not caller data. There is no file, network, reflection or float
use.

## Metadata fault arithmetic

All eight counterfactuals remain schema-valid, so each reaches gate 4 with earlier prerequisites
intact. The corrected field-count witness moves Transforms' leading `_bound_persistent_id`
i32[87552] into Schedule by shifting `OWNER_FIELD_BEGIN[15]` 271→272 and counts to 7/8, adjusting
both owners' payload and block by 350216 bytes (87552*4 + 8) and Transforms' offset by the same
amount; the section total, the 298-field total and the descriptor row total are unchanged. The
child-extent witness moves one extent from owner 10 to owner 14 with balanced -8/+8 lengths and
shifted intermediate offsets; the primary witness preserves the 193184 row sum; the type and extent
witnesses rebalance owner 14 and the three later offsets and both pinned section totals. The
correction note is explicit that the first field-count witness did not isolate the count guard and
that this is a witness fix, not a product defect. The harness requires the exact
`1 test(s), 9 assertion(s), N failure(s)` summary and rejects `SCRIPT ERROR:` and `Parse Error:`,
so the eight bypass kills rest on assertion failures rather than on compilation breakage, and the
schema-first case proves gate 3's detail is forwarded unchanged while gate 4 carries the exact
`Schedule owner14 metadata:` prefix. Reported totals reconcile: 18 cases, 9 assertions each = 162.

## Findings

No blocker, and no material gap in the delivered sources or tests. Outstanding items, none of which
is a defect in the reviewed code:

1. The twelve required projection/state mutants are reported as running; their kill evidence is not
   yet on record and cannot be assessed here.
2. The full suite, import/static checks and exact-head CI remain unrun; the contract requires all
   three before merge. The focus figures (62 tests, 17896 assertions, 0 failures) reconcile with
   the log's 12 + 50 test names but cover only these two suites.
3. The parent-owned registry wording correction for `resolved` (last successful resolution, not
   "this hour was applied") is not present in the reviewed inputs and remains unverified.
4. `Needs.Columns`, `copy_columns_into` and `restore_columns`, used by the history test, were not
   supplied for inspection; their behaviour is taken from the reported passing run.

Two notes, recorded rather than raised: the deliberate spacing difference between the column detail
(`Schedule owner 14 `) and the metadata prefix (`Schedule owner14 metadata:`) is contract-pinned but
reads as inconsistent; and a caller that passed one array for two arguments could not be detected by
a pure predicate, which stays a caller obligation. The 17920-byte claim is arithmetic against the
caller's streamed allowance, and native/wrapper overhead remains unmeasured, as both the contract
and the module header state.
