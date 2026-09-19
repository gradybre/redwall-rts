# Independent review — CAP-ADD proof grammar and Cycle 4 contract consistency

2026-09-19 · independent reviewer session (author session a7af9fea was a separate
Sonnet session; this review was written without access to that session's state).

## Scope and what this review cannot certify

Read scope was exactly four files: `tools/audit_registry_capacities.py`,
`tools/test_registry_capacity_audit.py`,
`docs/rulings/2026-09-19_cycle04_resumption.md`, and
`docs/planning/resumption_2026_09_19/starter_settlement.md`.

`godot/scripts/core/*.gd`, `docs/planning/canonical_state_registry.json` and
`docs/planning/registry_capacity_audit.json` were **not** supplied. Therefore the
reported real-source figures — 516 prose records, 470 proved equalities,
46 proved bounds, 0 unproved, 158 checks / 0 failures — are recorded here as
Astra's supplied execution evidence. This reviewer ran nothing and certifies
none of those numbers. No statement below certifies any other specification or
the game as a whole.

## Verdict

No blocking defect was found in the REG-C4-R01 addition extension as written.
Five concrete findings are recorded; F-01 and F-02 are pre-existing Cycle 3
soundness gaps that addition inherits rather than creates, F-03 and F-04 are
evidence-integrity defects, F-05 is a planning-contract ordering contradiction.

## Grammar, precedence, overflow, cycles — findings none

* Precedence and associativity are structurally correct: `resolve_expression`
  splits on `+` first and delegates each summand to `resolve_product`, which
  splits on `*`, so `*` binds tighter and both fold left to right
  (`audit_registry_capacities.py`, `resolve_expression` / `resolve_product`).
* Every intermediate is guarded. `resolve_product` calls `_guard_int64` after
  each multiplication (`total * resolved.value`) and `resolve_expression` after
  each addition (`total + product.value`), both **before** the next step. A
  nested constant's own overflow returns `Unproved` from `_resolve_const`, which
  cannot be reduced to a value by a later `* 0`; the added
  `test_c4_overflow_cannot_be_rescued_by_zero` covers both the nested-sum and
  the product-intermediate forms.
* Refusals are closed, not permissive. `NON_ALLOWLISTED_OPERATORS` halts on
  `- / % ( ) < > & | ^ ~`; anything surviving that filter must still satisfy
  `TERM_RE` per term, so unary `+`, empty addends and `++` degrade to
  `unsupported_expression` rather than being repaired. There is no `eval`/`exec`
  and no bare `open(`; N10 asserts this structurally.
* Cycles terminate at `MAX_RESOLVE_DEPTH = 16` with `resolution_too_deep`, and
  N22 covers self-reference, mutual reference and a cycle hidden inside a sum.
  Observation (not a finding): resolution is depth-bounded but not work-bounded,
  so a pathological constant chain of high arity could blow up combinatorially
  before hitting depth 16. Inputs are repository GDScript only, so this is not
  reachable by untrusted input.
* Exact-resize binding is preserved: `audit_field` still requires
  `resize_expression == parsed.expression` as literal text, so widening `LHS_RE`
  to admit `+` lets the prose *state* a sum but never lets one be believed
  without the source's own identical resize argument.
* Relation preservation is intact. `classify_from_source` now flattens across
  summands as well as factors, and any runtime var mixed with another term
  anywhere in the sum is refused as `mixed_dynamic_expression` rather than
  collapsed. N04/N05 still prove both directions of relation mismatch are
  findings, and P01 still proves a below-maximum store stays a bound.

## Findings

**F-01 (should fix, pre-existing) — resize-binding uniqueness only scans one
indentation level.** `resize_binding` matches direct resizes with
`^\t{member}\.resize\(...\)$` (single tab) plus one recognised `for`-group form.
A resize nested inside `if`/`for`/`match` at two or more tabs is invisible, so
the `conflicting_resize` guarantee can be satisfied while a second, different
sizing exists. Reproducible synthetic:

```
const BETA_ROWS: int = 512
const BETA_OTHER: int = 8
var _alpha_column: PackedInt32Array = PackedInt32Array()
func _init() -> void:
	_alpha_column.resize(BETA_ROWS)
	if true:
		_alpha_column.resize(BETA_OTHER)
```

Audited against ``​`BETA_ROWS` = 512`` this yields `proved_equality`, not
`unproved_conflicting_resize`. Whether any real core module contains such a
resize could not be checked, because those modules were not supplied.

**F-02 (should fix, pre-existing) — clamped-bound proof ignores augmented
assignment.** `ASSIGN_RE_TEMPLATE` is `^[ \t]*{var} = (?!=)[^\n]*$`, which does
not match `_beta_rows += 1`, `-=`, or any other compound form. A variable that is
clamped once and then incremented therefore still counts as one assignment with
one clamp and is published as a proved upper bound it may exceed. Reproducible
synthetic: take `clamped_module("_beta_rows", "BETA_ROW_MAX", 16384)` and insert
`\t_beta_rows += 1` before the resize; the row still reports
`proved_upper_bound` with `source_value` 16384. N12 covers a second plain `=`
assignment but not the augmented form. This affects the 46 bound rows.

**F-03 (should fix) — `registry_file_sha256` is not a file digest.**
`build_audit` computes it over `json.dumps(registry, sort_keys=True,
separators=(",",":"))`, i.e. a canonical re-serialisation, while
`audited_source.module_sha256` genuinely digests file text. The field name and
the note "only the file digest below is this audit's own observation" both
overstate it: a registry edited only in key order, indentation or trailing
whitespace produces an identical value and `sha256sum` of the file on disk will
never match it. Either rename to `registry_canonical_json_sha256` or digest the
bytes.

**F-04 (must fix before this evidence is cited) — `test_p09` docstring
contradicts both the ruling and the reported run.** The docstring states the
check "is expected to fail until `docs/planning/registry_capacity_audit.json` is
regenerated against REG-C4-R01: that regeneration is out of scope for this
packet", while the body asserts `--check` returns 0 and the supplied evidence
reports 0 failures. REG-C4-R01 also directs "Regenerate the sidecar from
source". At most one of these is true. If the sidecar was regenerated, the
docstring is stale and misleads a later reader about what the lane did; if it was
not, the reported 158/0 cannot be from this file. Resolve the prose, not the
assertion.

**F-05 (planning contract) — INIT-0 and INIT-A are ordered inconsistently.**
In `starter_settlement.md`, INIT-A is declared "Required before runtime startup
edits", yet INIT-0 is declared "First integration packet" and owns
`systems/settlement_system.gd` and `scripts/main.gd`, which are runtime startup
edits. Name INIT-0 as an explicit carve-out from the INIT-A precondition or move
it after INIT-A. Minor related tension: INIT-E must both "preserve prior-valid-
world failure behavior" and avoid "a second complete in-memory world"; the
prepared-state phrasing hedges this but the peak-memory contract is not yet
quoted.

## Ruling and starter-brief consistency — no contradiction found

* **No active-runtime acceptance is claimed from plans.** INIT-C4-R01 ends "No
  current test count closes first-playable, full-release, visual-acceptance,
  Windows or minimum-hardware performance gates by implication"; the starter
  brief repeats this for headless runs and for checkpoint-local repeatability.
  BUILD-C4-R01 explicitly labels itself "a newly authored economic
  interpretation, not a claim about source code", and ECON-C4-R01 forbids
  publishing an orphan compiled domain as evidence that excavation exists.
* **No additional art or spend approval.** UI-C4-R01 states screenshots are
  "functional/structural evidence, not Brendan's ART-UI-12 acceptance";
  MOVE-C4-R01 restates DEC-039's five existing height anchors while explicitly
  withholding torso/gear/pose envelopes, landmark ratios and final models, and
  directs that the human-owned approval file be left intact. Nothing grants new
  budget.
* **Full product is not shrunk.** The brief's "End-to-end release remains larger"
  section retains tasks 06–10, all fifteen persistence sections, all three
  premise families and the connected spaces, and states PC-03/PC-04 remain real
  authoring gaps that listing does not close.
* Internal numerics in the starter brief are self-consistent where checkable:
  6+2+2+2 = 12 residents, pairs (1,2)…(11,12) cover 1–12, and dormitory 40 +
  kitchen 10 + common 25 + pantry 5 = 80 = the 10×8 hall interior.

## Recommendation

Proceed with REG-C4-R01's grammar extension. Resolve F-04 before this evidence
is cited as a gate, correct F-03 in the next sidecar regeneration, and schedule
F-01/F-02 as their own bounded packet, since both affect rows already published
as proved and neither is caused by addition.
