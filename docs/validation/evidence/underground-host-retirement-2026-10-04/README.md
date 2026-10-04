# ADR1158 — Actual host/Session retirement candidate

Status: independently accepted component; root author review completed on
2026-10-04. Exact seven executable pins are unchanged. The review is copied
verbatim at `annotations/root-independent-review.json`; original frozen
document pins resolve through `annotations/output-locators.json`. Own branch
`codex/underground-host-retirement`, worktree
`/Users/brendan/Developer/redwall-rts-codex-ug-host-retirement`; diff base
`81950fe54706f98bd81667e98e077f593970deb9` includes accepted ADR1155.
No push, shared source edits or operational Room activation is part of this packet.

The actual Settlement host now retains its original Session through
prepare → whole-store clear → static owner-owned release. Its private permanent
Owners packet is constructed from the actual fifteen host borrows plus the
existing foundation, never registered by an external caller. The exact mount
is checked before and after cold observations. The private Scope and original
request/source banks are retained across repeated preparation. Idle/preparing/
prepared/clearing are distinct integer states; current getters, fresh
underground borrows, ticks and host admissions refuse while stopped. Only an
unchanged original pre-clear World can abandon. Partial clear stays stopped,
and Host PREDELETE breaks the Scope self-retention without releasing any live
authority or pretending a reset succeeded.

## Public composition and remaining work

Host `prepare_world_reset(allow_prepared_world=false)`, `reset(...)` and
`abandon_world_reset()` compose Session `retirement_observation_refusal`,
`prepare_retirement`, `release_retirement` and `abandon_retirement`. Session's
prepare/release methods are an internal composition seam: host/session tokens
alone are not proof of actual mounting. The concrete host supplies that proof.
No public setter adopts arbitrary owner packets. All optional operational
slots remain null, and preexisting unowned authority bindings still refuse.

The mounted operational Room/Sites/Inventory/provider constructor is not yet
present and is explicitly refused. Root must populate the private packet from
its own actual receivers and extend its concrete source check when that
composition exists. No Room, physical stair route, paid work, profile backend,
whole-demo acceptance or native allocation qualification follows here.

`ui-failure-audit.md` gives exact root-owned boot/Create cleanup sites. A failed
clear cannot be reported as an intact original World. The main path's two
external clears also cannot be undone by abandoning a host Scope. Those caller
changes are intentionally not implemented by this file lease.

## Exact validation

- `candidate-1`: Session 15 tests / 225 assertions and the then-current Host
  17 / 179, zero failures/diagnostics/leaks, analyzer 0 / 4. Initial actual
  populated reset, exact owner substitution, stopped access, recursion and
  partial-clear destruction cases.
- `candidate-2`: final Host 21 / 219; accepted kernel 19 / 1,963; existing
  Settlement 179 / 6,044; UI World session 16 / 78, all zero failures. The five
  preexisting expected Settlement diagnostics are retained explicitly; zero
  unexpected diagnostics, tolerated diagnostics and leaks. Analyzer 0 / 4.
  Added real Inventory journal, late reentrant observer, exact staged Request
  identity and immutable Profile-bank replacement cases.
- Together the unchanged Session suite and final four selected suites cover
  **250 tests / 8,529 assertions / zero failures**. This is selected-component
  evidence, not a no-argument full milestone.
- Both successful clean imports had zero raw findings. Original HEAD,
  source/project/registry/assets/import sidecars were preserved/restored.
  Unique per-output user directories isolate every engine process.
- `teardown-regression-1` is preserved as a rejected test mechanism. Godot
  refuses freeing a Node while its method is executing; the host was never
  destroyed, and the attempt produced an unexpected diagnostic/failure. No
  production change or diagnostic waiver followed. The final Host test is
  byte-identical to candidate-2; out-of-call destruction after a partial clear
  remains a real passing case. See its `review-limit.json`.
- `census-tests-1.log`: all 16 source/census mutants pass. `census.json` is the
  final exact source-derived report; `census-1.json` is the equal earlier output.

`source-sha256.json` freezes four GDScript sources/tests and three Python
support files. `output-sha256.json` pins current proof/metadata, while
`history-sha256.json` pins prior runs, rejected evidence and exact predecessor
snapshots. The predecessor manifest supplies the exact accepted Session/host
source and unchanged ADR1155 census provenance; no historical source replaces
an executed production file.

## Storage and scope

Two additional Session references and one host integer add 72 provisional
bytes to the accepted ADR1155 control calculation. The complete fixed tuple
has 111 reference slots and 84 numeric member bytes. Additional controls are
5,673 / 6,144; complete selected Host/Session plus accepted static release
frames are 170 numeric/name bytes and 23 references (including implicit self
and reference-valued returns). With the existing 256-byte expression allowance,
helpers are 1,162 / 2,048. The original Session 1,536 is charged once; retirement
remains 8,192 inside the unchanged 262,144 PROFILE_BYTES envelope, with the
parent-reported 1156 joint becoming 246,868. No bank/capacity grows.

The census explicitly marks unchanged source-hash/Level/Terrain observations
and whole-store-clear internals as their original owner reservations; their
host/Session caller prefixes are counted here. No source image is copied.
The 32-byte reference, three 256-byte object/header and 2,048-byte native/symbol
terms are provisional, not measured native memory.

The verbatim accepted ADR1155 `registry-test-only-append.md` is temporarily
appended only when its kernel stanza is absent, then restored byte-for-byte.
It supplies test inventory metadata, not memory admission; its older prose
about the proposed reservation is historical. The current exact census above
and root-owned shared ledger are the accounting sources. No permanent registry
change belongs to this component.

## Reproduce

From this exact worktree, using the configured Godot 4.7.2 and Python 3:

```sh
python3 -B docs/validation/evidence/underground-host-retirement-2026-10-04/test_census.py
python3 -B docs/validation/evidence/underground-host-retirement-2026-10-04/census.py --out /tmp/ug1158-new-census.json
python3 -B docs/validation/evidence/underground-host-retirement-2026-10-04/reproduce.py --out /tmp/ug1158-new-check --suites test_underground_session.gd test_underground_host.gd test_underground_world_retirement.gd test_settlement_system.gd test_ui_world_session.gd
```

Every output must be new. The wrapper performs exact clean import, official
singleton sharding, raw diagnostics and zero-warning analysis; it restores all
temporary project/registry/assets inputs in `finally`. The only write subjects
are this worktree, its unique user directory and the requested evidence output.

## Independent acceptance

Root rehashed all seven source, 38 original output and 50 historical pins,
read the complete production/test delta, and independently ran all 16 census
mutants. No runtime finding remained. The one requested Main-boot wording
clarification is recorded with its original bytes; executable sources did not
change. Acceptance covers this actual foundation lifecycle component only.
UI/main outcome cleanup, mounted operational Room construction and measured
native/full-demo gates remain open as stated above.
