# Independent follow-up review — section 4 streaming remedies

Date: 2026-09-20. Separate author session. Scope: the bounded remedies for M1, M2, L3 and L4 and
the dispositions of L5–L9 from the prior independent report, read against SAVE-S4-STREAM-R01 v2.
Both runtime GDScript files are stated unchanged from the reviewed versions and I found no claim
in the remedies that alters them. Source and evidence reading only: nothing here was executed,
nothing was measured, and no production file was edited. The 21-test / 11814-assertion focus log,
the 58-check generator log and the seven-case preflight JSON are inspected as artifacts, not
re-run.

## Verdict

**No blockers. Accept the remedies with the five low findings and the limits below.**

## M1 — injected runtime faults instead of source call counting

The parent's substitution is the stronger instrument and I endorse it. A call-site count would
have pinned text, not behaviour; `tools/test_component_stream_preflights.py` instead perturbs
runtime state (`probe.reverse()` after the probe buffer is built; `OWNER_OFFSETS[0]` 4→5) and then
deletes each gate in turn.

What I checked in the tool's control flow:

- **Non-vacuity.** `probe_suite('')` asserts the empty code, `has_more() == true` and
  `next_read_size() == 4`. A cursor that refused for any unrelated reason would fail the positive
  control, so the fault cases cannot pass by accident.
- **Real kill semantics.** Each bypass is spliced into the one named preflight function while the
  injected fault stays in place; the untouched cursor still refuses, so the bypassed cursor's
  empty code mismatches the expected StringName and the run reports failures. That is an assertion
  failure inside a compiled suite, not a parse or script error — `execute()` explicitly rejects
  output containing `SCRIPT ERROR:` or `Parse Error:` before counting a kill.
- **Fail-closed accounting.** The kill criterion is a matched summary line *and* a nonzero failure
  count. If a bypass produced fewer assertions, aborted early or failed to compile, the regex
  would not match, `valid` would be false and the tool would raise rather than credit a kill.
- **Independence of faults.** `bypass()` is applied to a freshly derived source each iteration, so
  no fault leaks between cases, and the `finally` block re-asserts both production digests.
- **Honesty.** The docstring and the emitted `"native_big_endian_tested": false` correctly decline
  the claim the contract forbids. The byte-order case simulates the mismatch branch only.

The seven recorded cases match the four required bypasses plus a control and two fault baselines.

## M2 — float policy guard

`test_component_sources_keep_integer_conversion_paths` greps both new runtime files and also calls
`Section.byte_order_refusal()` on the real host, which kills an always-refusing probe mutant. The
always-accepting direction is killed only by the Python tool, which CI does run in the Godot job.
See F1 for the residual gap in the banned-token list.

## L3 — targeted registry numeric parity

`check_registry_integer_fields` is correctly narrow. It tests `type(x) is not int` — which rejects
`True` and `4.0` while accepting ordinary integers — over exactly `section_id`,
`owner_schema_version`, `ordinal` and `type_code`. No recursive rejection is applied to the
registry, so `release_save_ready` and canonical policy flags remain legitimate booleans. I agree
with the parent's refusal of the blanket suggestion.

One point the disposition undersells: scanning *all* owners, not only section 4, is load-bearing.
`check_registry_parity` filters on `o["section_id"] == SECTION_ID`, and a float `4.0` would compare
equal and pass that filter silently. The `registry float section id` fixture closes exactly that
hole. The three fixtures each contribute three checks, consistent with the 58-check total.

## L4 — wrapper witnesses

The witness list is now `[0,4,13,17,24,25,32,33,37,44,45,52]`, adding the primary-count high byte
and both child-extent high bytes. The test name's "each wrapper member" claim is now honest, with
the prior report's caveat still true: whole-array equality makes these witnesses, not distinct
branches.

I reconciled the assertion delta arithmetically rather than trusting the log's total: 11814 − 11764
= 50, which is exactly 3 new offsets × 9 assertions in the wrapper loop (27) plus the new policy
test's 2 files × (1 non-empty + 10 banned tokens) + 1 probe call (23). The remedies account for the
whole delta, so no undisclosed test change is hiding in it.

## Findings (all low, none blocking)

**F1 — float grep is narrower than M2 asked for.** The banned list covers encode/decode float and
double, packed float arrays and `: float` / `-> float` annotations, but not a `float(` cast or a
bare `1.0` / `0.0` literal, both of which would introduce a float without matching any token.
Repair: add `"float("` and `".0"` to the list.

**F2 — fault tool is textually coupled to the sources it perturbs.** `replace_once` asserts a
unique anchor and `bypass()` slices on `static func <cursor>_preflight_refusal(` and the next
`\n\nstatic func `. Any benign reformatting turns CI red with a bare `AssertionError`/`ValueError`
rather than a diagnostic. Cheap repair: wrap the anchor failures in an explicit message naming the
anchor.

**F3 — harness constants are duplicated.** `8` appears in the probe's assertion count, the summary
regex and the emitted JSON. Adding a probe assertion requires three coordinated edits or the run
fails opaquely. Derive the regex count from the probe instead.

**F4 — kill detection also requires a nonzero exit status.** `execute()` demands
`result.returncode != 0` for a kill and `== 0` for a pass, while the repository's own
`tools/run_tests.sh` comment states that pass/fail is asserted on the summary line *because* the
exit status is not trusted. This is conservative in both directions — a stale exit code produces a
red run, never a false green — so it is not a defect, but the summary line alone would be the more
consistent oracle.

**F5 — portability and cold-start limits.** The tool symlinks `docs/` and `assets/` into the clone
(POSIX-only, and a dangling link if `assets/` is absent) and allows 90 s per Godot invocation
across seven runs. Both are fine in the configured job, which checks out on Linux and runs the
editor import before the tool so `copytree` carries a warm `.godot`; a fresh clone without that
import could exceed the timeout. Also unverified from this packet: that
`res://test/run_tests.gd` really exposes `_discover_suites() -> PackedStringArray`. If it does not,
the positive control's summary line will not match and the tool errors — again fail-closed.

Minor, not numbered: `check_registry_integer_fields` indexes `owner["fields"]` before parity runs,
so a registry owner lacking that key would produce a traceback rather than a `refuse()` line. Same
class as L9 and unreachable for the checked-in registry.

## L5–L9 dispositions

All accepted. L5 keeps the cheap alignment check without claiming its unreachable branch is
exercised, and the zero read size stays disambiguated by the readiness/completion/refusal
accessors. L6, L8 and L9 are retained with no new claims. L7 correctly stops short of calling
10536 a wire payload or a resident footprint and leaves the reserve qualification open — that
remains a carried item, not something these remedies close.

## Mutant interpretation

The parent's correction is substantively right. Swapping two identical 1024 literals emits
identical bytes and is therefore not a corruption a byte oracle can or should distinguish; the
prior report's wording implied otherwise. The real swap mutant (Buildings fields 3/4, encoder side
only) is killed by the patterned per-field comparison, and a globally consistent `storage_index`
permutation is killed by the schema suite's independent bucket-index assertion. The kill living in
a different suite is worth keeping recorded, which the disposition does.

## Limits of this review

Read-only. I did not run the suites, the generator tests, the fault tool or the editor import, and
I make no claim about the logs beyond their internal consistency with the checked-in sources. The
arithmetic reconciliations above are hand-derived from the files in this packet. Little-endian
behaviour remains assumed; no big-endian host is exercised anywhere and none is claimed. The two
runtime GDScript files were re-reviewed only for the remedies' claims about them, not re-derived
in full — the prior independent report stands for that.
