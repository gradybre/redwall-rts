# StockAge column boundary: source discovery

Remaining I1 owner candidate, not implementation authorization yet.

StockAge has4packed canonical arrays at fixed101376capacity (class/heated u8, generation/declared slots i32), plus declared_count and last_hour_tick. Total packed1013760B plus native scalars; section7 count usesu32 and latchi64. The declared-list order is already canonical because waste expiry retirement affects Inventory free-stack order. Array tails areNULL_SLOT; the codec writes only the live list prefix. Existing structural validation checks class/heated/generation domains, latch>=-1, unique list prefix and every declared class represented.

Stale declarations are natural: declared_container_count explicitly includes stale declarations until swept. Do not validate them away against current Inventory during exact restoration. Normal _drop_declaration swaps tail into removed slot and zeroes the old tail; preserve order and let normal hourly continuation retire stale generations. bind_stores to a different inventory clears declarations, so coordinator must bind before installing.

No bulk snapshot/restore/state_bytes API exists. Fields include borrowed Inventory/definitions, calendar/math scratch, compiled spoiled-food/compost caches, store/temperature scratch and last_refusal. These are not canonical; decide precisely which successful restore invalidates and prove failure unchanged. Existing public Inventory is_transaction_open/is_transaction_poisoned are pure queries.

Avoid a codec/owner cycle: section7 already preloads StockAge. Prefer owner-nested typed Columns with independent arrays, plus separate save_stock_age_restore adapter accepting section7 OwnerRecord so tests/callers need not allocate all6owner blocks. Adapter validates local group/extent/owner shape before any owner_refusal call (existing owner_refusal alone assumes valid shape). Snapshot count range must be checked beforeu32/i32 narrowing. No generic full-world or section7-complete claim.

Open for contract audit: exact per-path refusal order and codes; malformed owner arrays; latch semantic compatibility; tail canonicalization versus exact arrays; temporary packed payload; successful cache reset policy; local quiescence; same-world binding/load order; raw-hour/fault latch versus pending stock-integrity continuation. Full save coordinator must resolve fault/retry/hold policy independently.
