#!/usr/bin/env python3
"""Self-test of how test/run_tests.gd classifies engine diagnostics and leaks (decision 0501).

Builds a throwaway Godot project holding only the runner, the test framework and six fixture suites, runs the
real runner on it, and checks each classification against what the fixtures provoke:

  - a declared `expect_diagnostic` that is printed: reprinted EXPECTED, the test passes;
  - a declared one that is never printed: the test FAILS (a refusal that stopped reporting itself);
  - an undeclared push_warning: stays a plain WARNING line and is counted unexpected;
  - an outside-the-tree 3D read in a suite that tolerates it: reprinted TOLERATED;
  - the same message from another engine function (a focus grab), or in a suite that declares nothing: a finding;
  - a RefCounted cycle: counted on the leaked-at-exit figures.

Needs `godot` on PATH. Usage: python3 tools/test_run_tests_diagnostics.py
"""
from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HEAD = 'extends "res://test/framework/test_case.gd"\n\n\n'
FIXTURES = {
    "test_a_declared.gd": HEAD + (
        "func test_declared_refusal_is_expected() -> void:\n"
        '\t"""Declared, then provoked."""\n'
        '\texpect_diagnostic("fixture refusal")\n'
        '\tpush_error("fixture refusal: nothing was built")\n'
        '\tassert_true(true, "ran")\n'),
    "test_b_missing.gd": HEAD + (
        "func test_declared_but_never_printed_fails() -> void:\n"
        '\t"""Declared, never provoked."""\n'
        '\texpect_diagnostic("never printed")\n'
        '\tassert_true(true, "ran")\n'),
    "test_c_unexpected.gd": HEAD + (
        "func test_an_undeclared_warning_is_a_finding() -> void:\n"
        '\t"""Provoked without a declaration."""\n'
        '\tpush_warning("stray fixture warning")\n'
        '\tassert_true(true, "ran")\n'),
    "test_d_tolerated.gd": HEAD + (
        "func tolerates_outside_tree() -> bool:\n"
        '\t"""Node fixtures outside the tree."""\n'
        "\treturn true\n\n\n"
        "func test_an_outside_tree_read_is_tolerated() -> void:\n"
        '\t"""A global transform read on a node that is not in the tree."""\n'
        "\tvar node := Node3D.new()\n"
        "\tvar origin: Vector3 = node.global_transform.origin\n"
        "\tnode.free()\n"
        '\tassert_equal(origin, Vector3.ZERO, "identity outside the tree")\n\n\n'
        "func test_another_unguarded_tree_check_is_not_tolerated() -> void:\n"
        '\t"""The same engine message from a focus grab: not the harness 3D read, so a finding."""\n'
        "\tvar control := Control.new()\n"
        "\tcontrol.grab_focus()\n"
        "\tcontrol.free()\n"
        '\tassert_true(true, "ran")\n'),
    "test_f_untolerated.gd": HEAD + (
        "func test_an_outside_tree_read_in_a_suite_that_does_not_tolerate_it() -> void:\n"
        '\t"""No declaration: the tolerance of test_d must not carry over."""\n'
        "\tvar node := Node3D.new()\n"
        "\tvar origin: Vector3 = node.global_transform.origin\n"
        "\tnode.free()\n"
        '\tassert_equal(origin, Vector3.ZERO, "identity outside the tree")\n'),
    "test_e_leak.gd": HEAD + (
        "class Pair extends RefCounted:\n"
        "\tvar other: RefCounted = null\n\n\n"
        "func test_a_cycle_outlives_the_run() -> void:\n"
        '\t"""Two objects holding each other are never freed."""\n'
        "\tvar a := Pair.new()\n"
        "\tvar b := Pair.new()\n"
        "\ta.other = b\n"
        "\tb.other = a\n"
        '\tassert_true(a.other == b, "linked")\n'),
}


SINGLE_LEAK = {
    "test_g_one_leak.gd": HEAD + (
        "func test_one_object_outlives_the_run() -> void:\n"
        '\t"""One engine object holding itself (no script of its own to keep alive): the singular report."""\n'
        "\tvar a := RefCounted.new()\n"
        '\ta.set_meta("me", a)\n'
        '\tassert_true(a.get_meta("me") == a, "linked")\n'),
}


def run(fixtures: dict = FIXTURES) -> str:
    """Run the real runner over `fixtures` in a scratch project; return its merged output."""
    with tempfile.TemporaryDirectory(prefix="redwall-runner-diagnostics-") as scratch:
        project = Path(scratch)
        (project / "project.godot").write_text('config_version=5\n\n[application]\n\nconfig/name="runner"\n')
        (project / "test" / "framework").mkdir(parents=True)
        shutil.copy(REPO / "godot/test/run_tests.gd", project / "test/run_tests.gd")
        shutil.copy(REPO / "godot/test/framework/test_case.gd", project / "test/framework/test_case.gd")
        for name, text in fixtures.items():
            (project / "test" / name).write_text(text)
        result = subprocess.run(["godot", "--headless", "--path", str(project), "--script", "res://test/run_tests.gd"],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
        return result.stdout


def check(output: str) -> list[str]:
    """Every expectation the fixtures set that the output does not meet."""
    problems: list[str] = []

    def need(pattern: str, why: str) -> re.Match | None:
        found = re.search(pattern, output, re.M)
        if found is None:
            problems.append(f"{why}: no line matching {pattern!r}")
        return found

    need(r"^7 test\(s\), \d+ assertion\(s\), 1 failure\(s\)$", "exactly the never-printed declaration fails")
    need(r"^  PASS  test_declared_refusal_is_expected$", "a declared, printed refusal passes")
    need(r"^EXPECTED ERROR: fixture refusal", "the declared line is reprinted EXPECTED")
    need(r"^  FAIL  test_declared_but_never_printed_fails$", "a declaration nothing printed fails")
    need(r"expected an engine diagnostic containing 'never printed'; none was printed", "and says why")
    need(r"^WARNING: stray fixture warning", "an undeclared warning stays a plain WARNING line")
    need(r'^TOLERATED ERROR: Condition "!is_inside_tree\(\)" is true', "the outside-the-tree read is TOLERATED")
    plain = re.findall(r'^ERROR: Condition "!is_inside_tree\(\)" is true', output, re.M)
    if len(plain) != 2:
        problems.append(f"want 2 untolerated outside-tree lines (a focus grab; a suite that declares nothing), "
                        f"got {len(plain)}")
    summary = need(r"^diagnostics: (\d+) unexpected error\(s\), (\d+) unexpected warning\(s\), (\d+) expected, "
                   r"(\d+) tolerated; leaked at exit: (\d+) object\(s\), (\d+) resource\(s\)$", "the diagnostics line")
    if summary is not None:
        errors, warnings, expected, tolerated, objects = (int(summary[i]) for i in (1, 2, 3, 4, 5))
        if errors < 2:
            problems.append(f"the two untolerated outside-tree lines were not counted unexpected ({errors})")
        if expected != 1:
            problems.append(f"expected count {expected}, want 1")
        if tolerated != 1:
            problems.append(f"tolerated count {tolerated}, want exactly the one 3D read in test_d")
        if warnings < 1:
            problems.append("the stray warning was not counted unexpected")
        if objects < 2:
            problems.append(f"the cycle's two objects were not counted as leaked ({objects})")
    return problems


def check_single(output: str) -> list[str]:
    """Decision 0998 (Brendan's P1): one leaked object -- the engine's singular "1 ObjectDB instance was leaked" --
    is counted by the runner's diagnostics line and by tools/run_tests.sh's own grep."""
    problems: list[str] = []
    if not re.search(r"^WARNING: 1 ObjectDB instance was leaked at exit", output, re.M):
        problems.append("the engine did not print its singular line for one leaked object")
    if not re.search(r"^diagnostics: .*leaked at exit: 1 object\(s\), \d+ resource\(s\)$", output, re.M):
        problems.append("the runner did not count the one leaked object")
    shell = (REPO / "tools/run_tests.sh").read_text()
    grep = re.search(r"leaked_objects=\"\$\(grep -oE '([^']+)'", shell)
    if grep is None:
        problems.append("tools/run_tests.sh has no leaked-objects grep")
        return problems
    sample = "WARNING: 1 ObjectDB instance was leaked at exit\nWARNING: 3 ObjectDB instances were leaked at exit\n"
    counted = subprocess.run(["bash", "-c", f"grep -oE '{grep.group(1)}' | awk '{{ t += $1 }} END {{ print t + 0 }}'"],
                             input=sample, capture_output=True, text=True).stdout.strip()
    if counted != "4":
        problems.append(f"tools/run_tests.sh's grep counts {counted!r} objects in the singular and plural lines, want 4")
    return problems


def main() -> int:
    output = run()
    problems = check(output)
    single = run(SINGLE_LEAK)
    single_problems = check_single(single)
    if single_problems:
        print(single)
    problems += single_problems
    if problems:
        print(output)
        for problem in problems:
            print(f"FAIL: {problem}")
        return 1
    print("test_run_tests_diagnostics: PASS -- expected, missing, unexpected, tolerated and leaked all classified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
