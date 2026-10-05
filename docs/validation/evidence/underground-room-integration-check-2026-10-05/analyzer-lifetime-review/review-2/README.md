# Corrected ADR1180 candidate review

At tool `ae93bbf2012417b66055702b2246fe2f6bfe5e2a81f4ea09c0eefc59b979dbf0`
and tests `4ed2b1e8ab74ffbe4dff64ffefe6df3677364240c3fc5097b83d3820c69389fd`,
the original framed nonempty→empty, warning→EOF/retry, queued final update and
missing-selection probes are corrected. All eleven author protocol tests pass
independently. The one-second final drain is a bounded observation window; this
review makes no claim about notifications arriving arbitrarily later.

One **MEDIUM** retry case remains: an earlier requested file can finish cleanly
in session one, then be newly diagnosed as a dependency while session two opens
the remaining consumer. The actual `_drain` records that nonempty update, but
`collect`'s finally block harvests only its current unfinished suffix. It thus
returns no findings despite receiving the warning, and both files are counted
complete. `probe.py` reproduces this alongside the corrected earlier cases.
Harvesting the union of completed original requests and the current suffix can
close it without reopening completed documents. Root received the exact
source and reproduction paths.

No engine, real socket or author source write was used. The exact candidate
source is retained as nonexecuting text, and no final acceptance is implied.
