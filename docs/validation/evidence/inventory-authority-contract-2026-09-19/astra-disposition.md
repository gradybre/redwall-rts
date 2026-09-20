# Inventory authority audit disposition

The audit's diagnosis of separate stock owners, destructive borrow-reset,
two-container summaries, failed replacement and stale aging summaries is accepted.
Its header quotes the old manifest baseline47a4da2; the packet's actual source
baseline was ce679f8 and hashes are retained. Economy's Inventory allocation occurs
in its field initializer, not inside reset(); reset clears it and reloads definitions.
Both sites must change during the eventual cutover.

The proposed API bundle is advisory, not an accepted implementation packet:
- live_container_count already exists. Container enumeration alone misses equipped
  lots, so it cannot produce the proposed equipped/live totals without another scan.
- registered_catalog_token set by register_item has no defined identity semantics,
  owner comparison API, overflow/reset or lifecycle contract. Do not invent one.
- store_epoch is a state mutation, not a read-only primitive. The audit's blanket
  claim that all proposed primitives are read-only is incorrect.
- The proposal mentions refreshing from a caller hour but its signature has only a
  reason StringName; freshness cannot be implemented from that signature.
- Per-item totals caching/staging and equipment enumeration are absent from its
  budget. Do not accept the all-container buffer formula as a complete budget.
- Retiring int-returning UI APIs and changing default Economy initialization would
  be production activation. That cannot be called an unbound preparation helper.

The first accepted-design candidate is therefore narrower: one owner-side,
read-only bulk stock-count snapshot, covering loose and equipped lots in the same
scan. It replaces repeated per-item diagnostic scans as a future projection input.
No catalog token, reset epoch, constructor/boot change, cached container binding or
cutover is invented. Ready-NP/catalog compatibility, freshness/publication binding
and physical starter admission remain the next explicit contracts. INIT-0 as a
whole is not complete when this primitive lands.
