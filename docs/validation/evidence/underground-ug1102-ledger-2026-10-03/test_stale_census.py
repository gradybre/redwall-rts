#!/usr/bin/env python3
"""Run the real arithmetic gate against isolated, read-only stale-census inputs."""
from pathlib import Path
import json
import os
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[4]
READY = ROOT / "docs/validation/ready07_arithmetic.py"
ARCH = ROOT / "docs/systems_architecture.md"
FUNDING = ROOT / "godot/scripts/core/excavation_inventory.gd"
REGISTRY = ROOT / "docs/planning/canonical_state_registry.json"


def changed_once(text, before, after):
    """Require an exact live fixture target rather than silently testing unchanged input."""
    assert text.count(before) == 1, before
    return text.replace(before, after)


def overrides(case):
    """Return virtual input replacements; never change repository source or metadata."""
    if case in ("three_domains", "unaccounted_fifth_domain"):
        count = 3 if case == "three_domains" else 5
        return {FUNDING: changed_once(FUNDING.read_text(),
            "const LOSS_DOMAIN_COUNT: int = 4", f"const LOSS_DOMAIN_COUNT: int = {count}")}
    if case == "old_schema":
        registry = json.loads(REGISTRY.read_text())
        owner = next(o for o in registry["owners"] if o["owner_key"] == "excavation_inventory")
        assert owner["owner_schema_version"] == 3
        owner["owner_schema_version"] = 2
        return {REGISTRY: json.dumps(registry)}
    if case == "current":
        return {}
    text = ARCH.read_text()
    if case == "old_loss_row_and_auxiliary":
        text = changed_once(text,
            "| ExcavationFunding | _lost_milli | I64 | 8 | 1 | 1024 | 8192 |",
            "| ExcavationFunding | _lost_milli | I64 | 8 | 1 | 768 | 6144 |")
        text = changed_once(text, "| Auxiliary payload | 39758689 | 1 | 39758689 |",
            "| Auxiliary payload | 39756641 | 1 | 39756641 |")
    elif case in ("missing_cold_image", "double_counted_live_growth"):
        size = 4958293 if case == "missing_cold_image" else 4962389
        text = changed_once(text,
            "| Joint underground pack and remaining envelopes | 1 | 4960341 | 4960341 |",
            f"| Joint underground pack and remaining envelopes | 1 | {size} | {size} |")
    elif case == "old_headroom":
        text = changed_once(text, "| Headroom below decimal 100 MB | 40750 |",
            "| Headroom below decimal 100 MB | 44846 |")
    elif case == "missing_trail_step":
        text = changed_once(text,
            "| Connector installation loss domain, live and conservative cold image | decision1102 | +4096 | 91570642 | 99959250 |\n", "")
    else:
        raise AssertionError(case)
    return {ARCH: text}


def run_case(case):
    """Execute unchanged checker code with only the named input observed differently."""
    inputs = overrides(case)
    code = READY.read_text()
    original = Path.read_text
    def read_text(path, *args, **kwargs):
        return inputs[path] if path in inputs else original(path, *args, **kwargs)
    sys.argv = [str(READY)]
    with patch.object(Path, "read_text", read_text):
        exec(compile(code, str(READY), "exec"), {"__file__": str(READY), "__name__": "__main__"})


class StaleCensusTests(unittest.TestCase):
    def check_case(self, case, needle=None):
        """Every mutant must fail a real assertion; invocation/import errors do not count."""
        result = subprocess.run([sys.executable, "-B", str(Path(__file__).resolve()), "--case", case],
            cwd=ROOT, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            capture_output=True, text=True, check=False)
        output = result.stdout + result.stderr
        if needle is None:
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('"status": "PASS"', output)
        else:
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn("AssertionError", output)
            self.assertIn(needle, output)
        self.assertNotIn("ImportError", output)
        self.assertNotIn("FileNotFoundError", output)

    def test_current_source_and_ledger_pass(self):
        self.check_case("current")

    def test_three_domain_source_refuses(self):
        self.check_case("three_domains", "excavation_inventory")

    def test_unaccounted_fifth_domain_refuses(self):
        self.check_case("unaccounted_fifth_domain", "excavation_inventory")

    def test_old_owner_schema_refuses(self):
        self.check_case("old_schema", "owner_schema_version")

    def test_internally_balanced_old_loss_row_refuses_actual_source(self):
        self.check_case("old_loss_row_and_auxiliary", "_lost_milli")

    def test_omitted_cold_image_refuses(self):
        self.check_case("missing_cold_image", "Joint underground pack")

    def test_live_growth_counted_twice_refuses(self):
        self.check_case("double_counted_live_growth", "Joint underground pack")

    def test_stale_headroom_refuses(self):
        self.check_case("old_headroom", "Headroom below decimal")

    def test_missing_historical_trail_step_refuses(self):
        self.check_case("missing_trail_step", "trail_rows[-1]")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--case":
        run_case(sys.argv[2])
    else:
        unittest.main()
