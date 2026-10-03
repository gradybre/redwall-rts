# 1093 — Retain actual natural support with paid room phases

Date: 2026-10-03. Status: approved engineering packet; implementation and validation in progress.

## Decision and scope

The actual phase-structure provider reads the same World, Terrain, immutable
LevelCatalog, SpaceOwner, Sites and shared Budget as the phase coordinator. It
derives exact local roof and footing bands from the confirmed Room's claims and
authored section. Caller Plans, datum envelopes and successful component tests
cannot supply missing natural earth or a work/contact permission.

The authored natural bands protect already-retained earth. They are not installed
timber or stone, an additional recipe, or salvage entitlements. Their actual
Room-owned SUPPORT rows persist while that confirmed Room exists. Another Site
in the same vertical column cannot release them; only the eventual actual Room
structural cleanup may retire them after all physical obligations close. Paid
bracing and salvage remain the existing Sites-installed byte and actual recipes.

The separate `underground_phase_structure.gd` provider owns qualification and
staging of these protections. WorldBindings owns delegation, productive contact
qualification and companion orchestration. Sites owns the installed-support
identity reader. No new physical role, packed authoritative column, tariff,
connector recipe, or source namespace is introduced by this packet.

## Cold image lifetime prerequisite

After SpaceOwner seals a physical candidate, Authority drops the original survey's
volume/source arrays before invoking `prepare_companions`. It retains the snapshot
World/version/revision controls. The existing final checks of qualification,
geometry, exact lease, Site/Room context, paid phase, prepared SpaceOwner and
prepared companions remain unchanged. All failure paths still abort the candidate
and release only their actual lease. Proof-only observations and explicit refresh
retain their previous lifetime; productive WORK creates no survey.

This makes the simultaneous lifetime explicit: an actual Locations cold image can
coexist with the two bounded Plan copies after the previous full survey has gone.
It is not permission to retain arbitrary caller aliases or duplicate another
image outside the single shared Budget token.

## Provider budget and obligations

At the admitted R6144/O2048/K8192 pack, structural staging can retain the original
425,984-byte survey, two Plan images totaling at most 145,872 bytes, an 8R handle
image, two flat 6-I32 fragment banks totaling 48R, and at most 1,024 logical fixed
controls: **916,944 bytes**. A later sealed verification drops handle/fragment
images before its 327,680-byte future snapshot, for **900,560 bytes**. These are
logical ceilings within the existing 1,048,960-byte cold lease, not native-memory
measurements. Final source census and refusal-path evidence are required before
acceptance. Per-fragment objects and a second full composed terrain survey are
excluded.

Both original natural Terrain truth and retained paid geometry must be checked.
A previous paid cavity cannot pass merely because the original map was dirt.
Exact other-Room required bands protect a confirmed neighbor before its own
phase publishes SUPPORT. Stage additions use full Room/section identities,
retain exact fine XZ bounds, and avoid duplicate overlap. A current-source and
exact-token check follows every collaborator callback before allocating more
scratch or mutating the staged bank.

This slice does not grant traversal, work contacts, profile capabilities, services,
installed connector identity, or connector recipe permission. Those actual owners
remain mandatory for the first playable room.

## Validation

The Authority lifetime prerequisite passed the clean assets-aside import and
strict runner: **36 tests / 4,991 assertions / 0 failures**, zero unexpected or
expected/tolerated diagnostics, and zero objects/resources leaked in both strict
and raw-log footers. Analyzer reported **0 warnings in 0 of 2 files**. Independent
source review accepted the unchanged final preflights and actual paid retry test.
[Raw evidence](../validation/evidence/underground-phase-structure-2026-10-03/survey-lifetime/README.md)
retains source hashes, import/runner logs, analyzer output and the rejected initial
invocation. The natural-support provider remains the next implementation slice.
