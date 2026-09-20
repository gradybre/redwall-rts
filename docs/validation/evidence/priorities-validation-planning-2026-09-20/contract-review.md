# Contract review — PRIORITIES-S4-VALIDATE-R01 draft2 (pre-author)

Read-only review of the draft2 contract against the feasibility review, the Astra disposition and
the cited source. Nothing was executed and no figure here is measured. Verdict: **dispatchable
after the four contract-text amendments below**; no contradiction requiring a new decision.

## Must fix in the contract before the author starts

**M1 — Mutant witnesses. The all-zero-accepted fixture cannot kill a projection mutant.**
The contract lists "all-zero accepted" and "four projection-substitution mutants replace one mapped
argument with an all-zero correctly-sized column" without binding each mutant to a fixture that
distinguishes it. On the all-zero image every substitution is a no-op. Each mutant needs a named
witness stated in the contract:

- `job_priority`: a fixture refused *because of* that column (a present row carrying priority 7 →
  `COLUMN_PRIORITY_RANGE`); substitution turns it into `REFUSE_NONE`. An accepted fixture cannot
  kill it, because a present row with all twelve bytes 0 is legal.
- `present`: a fixture with a present row holding non-default flags or priorities; substitution
  makes the row free → `COLUMN_FREE_ROW` against `REFUSE_NONE`.
- `auto_fallback` / `dangerous_work`: the disposition's distinct codes plus asymmetric content
  (one column out of domain, the other all 0), which also kills the swap mutant.

**M2 — `PackedByteArray.count()` is an engine-version dependency.** The contract mandates "count()
per legal value". That method is not available on packed arrays in every Godot 4.x point release
and `docs/ENVIRONMENT.md` is not in this packet's inputs. Allow an explicit bounded single-pass
loop over named owner constants as an equal alternative, so the author is not forced into an API
they may not have. Either form must still reach slots 0 and 511 and must not `duplicate()`.

**M3 — Pin the shared free-row helper precisely.** Three points are currently loose:

1. Argument order. The predicate's canonical order starts with `present`; the helper drops it and
   starts at `job_priority`. State the helper signature verbatim so the two orders are not
   confused at the call sites.
2. The helper's two flag arguments are symmetric (both tested for nonzero), so a swap *inside* the
   helper is unobservable by construction. That is benign, but the transposition mutant must target
   the bridge/predicate call sites, not the helper.
3. The helper must not read `present`. `inactive_row_is_clear` keeps its invalid-address and
   present-row `false` guard *before* delegating; the validator calls the helper only for rows it
   has already classified as `present == 0`. If the helper consulted presence itself, the reader's
   published contract would change, which this slice excludes.

Also resolve the vocabulary: the reader says "inactive", the new gate says "free". Either is
source-backed (the persistence registry uses "free row"); pick one term for the helper name.

**M4 — Detail strings must not imply row identity.** The contract already says details need not
identify a row. Make that prohibitive rather than permissive for the column gates: the bridge
detail names owner 11 and the exact code only. Otherwise a later author adds a slot number, and the
scanning order silently becomes part of the observable contract.

## Confirmed — no change needed

- **Ordering.** Shape → present → auto → dangerous → range → reserved → free row is total and
  unambiguous. Gate 4 already absorbs reserved bytes 5..255, so the pinned examples (byte 7 →
  `COLUMN_PRIORITY_RANGE`; inactive reserved 3 → `COLUMN_RESERVED_PRIORITY`; inactive
  `auto_fallback` 1 → `COLUMN_FREE_ROW`) are consistent with the stated gates.
- **512, not 256.** The contract charges 512 physical rows everywhere, states the 256 living cap is
  not this owner's, and cross-checks `PRIORITY_CAPACITY == 512` and `JOB_KIND_COUNT == 12`. No
  capacity confusion found; no text implies a 256-row scan.
- **No store construction.** Both new entry points are `static`, so `priorities.gd::_init()` — and
  its column allocation and `NeedsScript.RESIDENT_CAPACITY` assert — never runs from this path.
- **Memory.** 6144 + 3 × 512 = 7680 is correct, and it is the caller's already-framed image.
  `u8_column()` returns the stored buffer without duplicating, and assignment keeps it
  copy-on-write shared, so read-only validation leaves caller arrays untouched.
- **Metadata honesty.** The disposition's position is correctly reflected: pinned contract literals
  plus existing capacity/stride constants, gate-3 detail forwarded unchanged, and an explicit
  refusal to claim owner-publication-table parity. Gate 4's `Priorities owner11 metadata:` prefix is
  the only thing separating gates 3 and 4, which the contract states.
- **Scope.** Owner capture/apply, `_present_count` rebuild, cross-owner presence and identity, job
  eligibility and low-risk FORAGE remain excluded and are named as such.
