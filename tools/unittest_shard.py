#!/usr/bin/env python3
"""Run one stable shard of an unchanged unittest module (decision 1244).

    python3 tools/unittest_shard.py tools/test_underground_memory_budget.py --shard 0/2
    python3 tools/unittest_shard.py tools/test_underground_memory_budget.py --list

The module is loaded exactly as ``unittest.main()`` loads it when run as a script: the same loader,
the same discovery over the module (including test classes it imports), the same class grouping, so
``setUpClass`` and ``tearDownClass`` still run once per class in each shard that has one of its tests.
Nothing in the module is changed, skipped or re-ordered within a class.

Membership is by position in the sorted list of test-method ids (``Class.test_name``): test ``k`` belongs
to shard ``k % count``. Shards are therefore disjoint and together exhaustive by construction, and adding
a test moves only the tests sorted after it. The run fails unless every selected test ran and passed and
the shard is not empty; ``--list`` prints the plan and runs nothing.
"""
from __future__ import annotations

import argparse
import importlib
from pathlib import Path
import sys
import unittest
from typing import Iterator


def flatten(suite: unittest.TestSuite) -> Iterator[unittest.TestCase]:
    """Yield every test case in the suite, depth first, in loader order."""
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from flatten(item)
        else:
            yield item


def method_id(case: unittest.TestCase) -> str:
    """Return ``Class.test_name``, independent of the name the module was imported under."""
    return f"{type(case).__qualname__}.{case._testMethodName}"


def load(path: Path) -> unittest.TestSuite:
    """Import the module at ``path`` with its own directory first on sys.path, as running it would."""
    directory = str(path.resolve().parent)
    if sys.path[0] != directory:
        sys.path.insert(0, directory)
    module = importlib.import_module(path.stem)
    return unittest.defaultTestLoader.loadTestsFromModule(module)


def assignment(ids: list[str], count: int) -> dict[str, int]:
    """Map each test id to its shard: position in the sorted id list modulo the shard count."""
    if len(set(ids)) != len(ids):
        raise SystemExit("error: duplicate test ids; a stable shard needs unique ids")
    return {test_id: index % count for index, test_id in enumerate(sorted(ids))}


def select(suite: unittest.TestSuite, index: int, count: int) -> tuple[unittest.TestSuite, int]:
    """Return the shard's tests, still grouped by class in loader order, and the module's test total."""
    cases = list(flatten(suite))
    owner = assignment([method_id(case) for case in cases], count)
    chosen = unittest.TestSuite()
    group = unittest.TestSuite()
    group_class: type | None = None
    for case in cases:
        if type(case) is not group_class:
            if group.countTestCases():
                chosen.addTest(group)
            group, group_class = unittest.TestSuite(), type(case)
        if owner[method_id(case)] == index:
            group.addTest(case)
    if group.countTestCases():
        chosen.addTest(group)
    return chosen, len(cases)


def parse_shard(text: str) -> tuple[int, int]:
    """Parse ``N/COUNT`` with 0 <= N < COUNT."""
    try:
        index_text, count_text = text.split("/")
        index, count = int(index_text), int(count_text)
    except ValueError:
        raise argparse.ArgumentTypeError(f"expected N/COUNT, got {text!r}") from None
    if count < 1 or not 0 <= index < count:
        raise argparse.ArgumentTypeError(f"shard {text!r} is out of range")
    return index, count


def main(argv: list[str] | None = None) -> int:
    """Run (or list) one shard; return 0 only when every selected test ran and passed."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("module", type=Path)
    parser.add_argument("--shard", type=parse_shard, default=(0, 1), metavar="N/COUNT")
    parser.add_argument("--list", action="store_true", help="print the shard's test ids and run nothing")
    args = parser.parse_args(argv)
    index, count = args.shard
    chosen, total = select(load(args.module), index, count)
    selected = chosen.countTestCases()
    print(f"unittest_shard: {args.module} shard {index}/{count}: {selected} of {total} test(s)", flush=True)
    if args.list:
        for case in flatten(chosen):
            print(method_id(case))
        return 0
    if selected == 0:
        print("error: empty shard; lower the shard count", file=sys.stderr)
        return 1
    result = unittest.TextTestRunner(verbosity=2).run(chosen)
    if result.testsRun != selected:
        print(f"error: {result.testsRun} test(s) ran, {selected} selected", file=sys.stderr)
        return 1
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
