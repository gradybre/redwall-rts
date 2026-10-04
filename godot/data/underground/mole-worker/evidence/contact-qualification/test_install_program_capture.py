"""Adversarial native-evidence validator tests; synthetic event fixtures never grant runtime permission."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("install_program_capture", HERE / "run_install_program_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


def synthetic_report(table, digest):
    """Retain real old event coverage, append explicitly synthetic v3 events for outer-check mutants only."""
    report = json.loads((HERE / "native-compact-program-v1/report.json").read_text())
    report.update(program_version=3, content_sha256=digest, user_directory="/synthetic/install-test")
    for view in ("side", "opposite", "rts"):
        for label, count in (("partial", 17), ("retrace", 17), ("work", 83), ("recovery", 101)):
            for tick in range(count):
                if label == "partial":
                    phase = 5
                elif label == "retrace":
                    phase = 0 if tick == 16 else 8
                elif label == "work":
                    phase = 5 if tick < 59 else 6
                else:
                    phase = 0 if tick == 100 else (6 if tick < 40 else 7)
                clip = {0: 0, 5: 12, 6: 11, 7: 13, 8: 12}[phase]
                frames = [8, 9, 0] if phase == 0 else [table[clip][0], table[clip][0] + 1, 0]
                report["events"].append({"label": view + "-install-" + label, "tick": tick, "phase": phase,
                                         "profile": 5, "ready": phase == 0, "frames": frames * 2 + [65536]})
    report["poses"] = len(report["events"])
    report["assertions"] = report["poses"] * 4
    report["phase_counts"] = [sum(row["phase"] == phase for row in report["events"]) for phase in range(10)]
    return report


class InstallProgramCapture(unittest.TestCase):
    def setUp(self):
        self.preview = HERE / "install-program-compile-v3/result"
        compiled = json.loads((self.preview / "compilation.json").read_text())
        self.spec = {"content": str(self.preview / "mole-worker.ugactor"), "content_sha256": compiled["content_sha256"],
                     "user_directory_name": "install-test"}
        self.table = R.BASE.wire_timing(self.spec)
        self.report = synthetic_report(self.table, self.spec["content_sha256"])

    def test_explicit_fourteen_clip_census_includes_all_install_states_and_views(self):
        result = R.validate_report(self.report, self.spec, self.table)
        self.assertEqual(result, {"poses": 2868, "assertions": 11472, "phases": 9, "work_choices": 4,
                                  "production_qualified": False})

    def test_retained_actual_native_run_has_complete_source_and_phase_census(self):
        out = HERE / "install-program-native-v1"
        report = json.loads((out / "report.json").read_text())
        spec = json.loads((out / "spec.json").read_text())
        self.assertEqual(R.validate_report(report, spec, self.table), {
            "poses": 2868, "assertions": 11843, "phases": 9, "work_choices": 4, "production_qualified": False})

    def test_wrong_protocol_native_directory_scope_or_failed_assertions_refuse(self):
        for delta in ({"program_version": 2}, {"user_directory": "/default/user"}, {"production_qualified": True},
                      {"failures": ["native failure"]}, {"assertions": 0}, {"poses": 2867}, {"assertions": True}):
            with self.assertRaises(ValueError):
                R.validate_report(dict(self.report, **delta), self.spec, self.table)

    def test_wrong_loop_duration_or_partial_install_clip_table_refuses(self):
        with self.assertRaisesRegex(ValueError, "TIMING"):
            R.expected_poses(self.table[:11])
        for clip, field in ((11, 2), (12, 3), (13, 1)):
            table = [list(row) for row in self.table]
            table[clip][field] += 1
            with self.assertRaisesRegex(ValueError, "TIMING"):
                R.expected_poses(table)

    def test_install_role_cannot_render_another_work_clip_or_unproved_blend(self):
        event = copy.deepcopy(next(row for row in self.report["events"] if row["profile"] == 5 and row["phase"] == 6))
        event["frames"][0:2] = [self.table[2][0], self.table[2][0] + 1]
        with self.assertRaisesRegex(ValueError, "ROLE_FRAMES"):
            R.event_refusal(event, self.table)
        event = copy.deepcopy(next(row for row in self.report["events"] if row["profile"] == 5 and row["phase"] == 6))
        event["frames"][6] = 0
        with self.assertRaisesRegex(ValueError, "UNAUTHORED_BLEND"):
            R.event_refusal(event, self.table)

    def test_full_event_total_cannot_hide_a_missing_install_phase(self):
        report = copy.deepcopy(self.report)
        for row in report["events"]:
            if row["profile"] == 5 and row["phase"] == 7:
                row["phase"] = 6
                row["frames"] = [self.table[11][0], self.table[11][0] + 1, 0] * 2 + [65536]
        report["phase_counts"] = [sum(row["phase"] == phase for row in report["events"]) for phase in range(10)]
        with self.assertRaisesRegex(ValueError, "PHASES"):
            R.validate_report(report, self.spec, self.table)

    def test_partial_view_duplicate_tick_or_idle_padding_cannot_replace_install_sequence(self):
        for mutation in (lambda row: row.update(tick=9), lambda row: row.update(label="missing-view"),
                         lambda row: row.update(profile=2)):
            events = copy.deepcopy(self.report["events"])
            target = next(row for row in events if row["profile"] == 5)
            mutation(target)
            with self.assertRaisesRegex(ValueError, "SEQUENCE"):
                R.install_sequence_refusal(events)

    def test_bound_role_protocol_and_plan_bytes_cannot_drift_behind_an_unchanged_image(self):
        roles = R.bound_roles(Path(self.spec["content"]), self.spec["content_sha256"], self.preview)
        self.assertEqual(roles["install"]["CONTACT_PATCH"], [[127, 128, -449, 129, 128, -447]])
        with tempfile.TemporaryDirectory() as name:
            target = Path(name)
            for filename in ("program.json", "roles.json", "plan.json"):
                (target / filename).write_bytes((self.preview / filename).read_bytes())
            for filename in ("program.json", "roles.json", "plan.json"):
                prior = (target / filename).read_bytes()
                (target / filename).write_bytes(prior + b" ")
                with self.assertRaisesRegex(ValueError, "METADATA"):
                    R.bound_roles(Path(self.spec["content"]), self.spec["content_sha256"], target)
                (target / filename).write_bytes(prior)

    def test_existing_output_or_dangling_symlink_refuses_before_source_read_or_any_write(self):
        with tempfile.TemporaryDirectory() as name:
            target = Path(name) / "saved"
            target.mkdir()
            (target / "report.json").write_bytes(b"unchanged prior evidence")
            link = Path(name) / "dangling"
            link.symlink_to(Path(name) / "absent")
            for path in (target, link):
                with mock.patch.object(R, "bounded_json", side_effect=AssertionError("must not read")):
                    with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                        R.run(Path("unread"), path)
            self.assertEqual((target / "report.json").read_bytes(), b"unchanged prior evidence")
            self.assertTrue(link.is_symlink())

    def test_missing_image_list_or_phase_rows_cannot_pass_zero_engine_exit(self):
        for delta in ({"screenshots": []}, {"events": self.report["events"][:-1]}, {"phase_counts": [0] * 10}):
            with self.assertRaisesRegex(ValueError, "PHASES"):
                R.validate_report(dict(self.report, **delta), self.spec, self.table)


if __name__ == "__main__":
    unittest.main()
