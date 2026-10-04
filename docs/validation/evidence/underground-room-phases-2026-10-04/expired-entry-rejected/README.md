# Expired optional EntryContacts receiver: rejected source

The exact source-review-2 provider and the added lifetime regression are retained
under `source/` and pinned in `rejected-source-sha256.json`. The actual receiver
loses its last strong reference; its original WeakRef remains bound in the
provider. The old `_ordinary_revision_for` then treated that expired receiver as
the never-bound optional Entry case and returned an ordinary qualification.

The strict provider suite reproduced this with 19 tests / 235 assertions /
1 failure. Every strict/raw diagnostic and leak counter is zero. Clean import
passed; `invocation.json` records source unchanged and original project,
diagnostic registry and assets restored. The wrapper stopped on the expected
test failure before running LSP. This is rejected evidence, not acceptance.

The receiver is an explicitly injected, unconfigured EntryContacts fault. While
alive it correctly refuses qualification; its expiration must not turn that
refusal into a usable ordinary epoch. The test does not claim a successful
mixed Entry binding. It also retains the genuine never-bound ordinary positive.

The successor changes one conditional: a null receiver returns the ordinary
epoch only when the optional WeakRef itself has never been set. An existing
expired WeakRef returns zero. Repeated refusal must keep all existing packet
identities, physical/paid state, original Budget counters and publication tokens
unchanged. Source inspection confirms this leaf adds no allocation site; the
runtime checks do not purport to measure transient native allocation.
