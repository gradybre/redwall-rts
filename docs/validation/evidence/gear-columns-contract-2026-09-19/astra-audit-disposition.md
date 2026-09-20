# Gear feasibility audit disposition — still planning

The audit is useful input, not an accepted implementation contract. Several
recommendations require correction before the packet can be released.

- Use unique copy_gear_columns_into/restore_gear_columns names, not the generic
  Inventory duck-typed names proposed by the audit. Keep a separate single-block
  adapter; do not invent digest registration in this owner packet.
- Do not run existing audit() as the hostile-shape gate. Its heap check does not
  prove unique prefix membership or min-heap order and assumes shaped arrays.
  New validation must be total, with bounds-before-index and native count checks.
- The old per-row restore path indeed loses equipped state and is not atomic.
  Preserve its historical API for now; new bulk restore must not replay it.
- Successful seeding leaves _seed_count24. That is category3 residue, not a busy
  flag. Correct registry prose; preserve seed buffers/count and wear scratch.
- is_equipped_record itself does NOT read cached item IDs: it checks lot row,
  equipped flag and resident directory validity. The audit overstates that
  cache dependency. Cached IDs do govern equip-kind and wear-model queries, so
  refresh/preservation still needs an exact rule before implementation.
- Codec claim-slot bound352418 versus live claim API bound8192 is confirmed.
  The claim generation wording and typed-row mapping need explicit treatment;
  do not collapse job typed rows and directory slots by inference.
- Codec accepts nonzero generation on a null owner/claim slot. Its structural
  gate is weaker than matched-pair validation. Define an explicit owner rule
  and tests; do not silently edit codec admission while claiming no change.
- Caps/manufacture/catalog subtype checks proposed by the audit are stronger
  than existing row-restore/codec checks. Audit must distinguish healthy public
  creation from malformed legacy restore inputs; Astra must rule the exact
  bulk admission domain before implementing those checks.
- The ~704KB staging estimate omits live/caller arrays, publication duplicates,
  private heap, adapter constructor bodies and retained buffers. Use explicit
  phases/envelopes rather than treating it as a peak or RSS measurement.
- Its equip test says restore then bind, contradicting its own bind-before-load
  requirement for equipped rows. Test exact lifecycle and preserve borrowed
  identities; the full coordinator separately verifies Inventory/Equipment
  mirrors and world association after all owners are present.

No production Gear changes are authorized by this audit alone. The existing
end-to-end project authorization permits the next bounded contract once these
ordinary engineering choices are resolved and independently reviewed.
