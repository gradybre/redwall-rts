#!/usr/bin/env python3
"""Changes to current room owners or evidence must fail before historical replay."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

import audit_registry_capacities as audit
import underground_room_memory as room


class RoomMemoryWitnessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = audit.load_source_index()
        cls.manifest = json.loads((room.ROOT / room.MANIFEST).read_bytes())

    def refuses_before_replay(self, changes):
        read = Path.read_bytes

        def changed(path):
            return changes[path] if path in changes else read(path)

        with mock.patch.object(Path, "read_bytes", changed), mock.patch.object(room, "producer") as execute:
            with self.assertRaises(ValueError):
                room.build(self.index)
            execute.assert_not_called()

    def test_transitive_constructor_census_is_checked_before_import(self):
        path = room.ROOT / room.C / "constructor_census.py"
        self.refuses_before_replay({path: b"raise RuntimeError('unreviewed producer')\n"})

    def test_transitive_turn_census_is_checked_before_import(self):
        path = room.ROOT / room.I / "predecessors/turn-census.py.txt"
        self.refuses_before_replay({path: path.read_bytes() + b"\nimport os\n"})

    def test_all_five_census_producers_are_checked_before_execution(self):
        for folder in (room.P, room.I, room.C, room.G, room.R):
            path = room.ROOT / folder / "census.py"
            with self.subTest(producer=folder):
                self.refuses_before_replay({path: path.read_bytes() + b"\n# unreviewed\n"})

    def test_coordinated_producer_and_manifest_change_has_no_new_authority(self):
        path = room.ROOT / room.C / "constructor_census.py"
        changed = path.read_bytes() + b"\n# coordinated change\n"
        rows = json.loads((room.ROOT / room.MANIFEST).read_bytes())
        rows["witnesses"][str(path.relative_to(room.ROOT))] = hashlib.sha256(changed).hexdigest()
        self.refuses_before_replay({path: changed, room.ROOT / room.MANIFEST: json.dumps(rows).encode()})

    def test_historical_sources_cannot_become_current_mutable_baselines(self):
        for name in ("underground_room_world_bindings", "underground_locations", "underground_session"):
            path = room.ROOT / self.manifest["baseline"][name]["locator"]
            with self.subTest(owner=name):
                self.refuses_before_replay({path: path.read_bytes() + b"\nvar extra: int = 1\n"})

    def test_current_owner_text_overrides_cannot_be_replaced_with_disk_or_cached_hash(self):
        names = ("underground_room_composition", "underground_room_itinerary",
                 "underground_room_frontier_publication", "underground_locations",
                 "underground_session", "underground_connector_catalog",
                 "underground_route_composition", "underground_world_retirement", "settlement_system")
        for name in names:
            row = self.manifest["sources"][name]
            old = self.index.get(name) or audit.parse_module(
                name, row["path"], (room.ROOT / row["path"]).read_text())
            changed = old._replace(text=old.text + "\nvar uncounted: PackedByteArray = PackedByteArray()\n")
            with self.subTest(owner=name), mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, "current reviewed source changed"):
                    room.build(dict(self.index, **{name: changed}))
                execute.assert_not_called()

    def test_current_transitive_body_changes_are_not_hidden_by_frame_counts(self):
        name = "underground_work_face"
        old = self.index[name]
        changed = old._replace(text=old.text + "\nfunc same_size_callback() -> void:\n\tpass\n")
        with self.assertRaisesRegex(ValueError, "current reviewed source changed"):
            room.build(dict(self.index, **{name: changed}))

    def test_actual_movement_reader_cannot_add_uncounted_scratch(self):
        old = self.index["movement"]
        start = old.text.index("func profile_speed_into(")
        body = old.text.index("\n", old.text.index("-> bool:", start)) + 1
        text = old.text[:body] + "\tvar uncounted: PackedByteArray = PackedByteArray()\n\tuncounted.resize(4096)\n" + old.text[body:]
        changed = audit.parse_module(old.name, old.relative_path, text)
        with self.assertRaisesRegex(ValueError, "current reviewed source changed: movement"):
            room.build(dict(self.index, movement=changed))

    def test_injected_module_path_must_identify_original_owner(self):
        name = "underground_locations"
        with self.assertRaisesRegex(ValueError, "module identity"):
            room.build(dict(self.index, **{name: self.index[name]._replace(relative_path="foreign.gd")}))

    def test_route_engine_lifetime_evidence_is_checked_before_any_producer(self):
        rows = json.loads((room.ROOT / room.R / "engine-lifetime/source-sha256.json").read_bytes())
        for relative in rows:
            path = room.ROOT / relative
            with self.subTest(engine_source=relative):
                self.refuses_before_replay({path: path.read_bytes() + b"\n// changed lifetime\n"})

    def test_route_constructor_dependency_cannot_hide_same_frame_size_mutation(self):
        name = "underground_level_catalog"
        old = self.index[name]
        changed = old._replace(text=old.text.replace("func binding_matches(", "func changed_binding_matches(", 1))
        self.assertNotEqual(old.text, changed.text)
        with mock.patch.object(room, "producer") as execute:
            with self.assertRaisesRegex(ValueError, "current reviewed source changed"):
                room.build(dict(self.index, **{name: changed}))
            execute.assert_not_called()

    def test_route_predecessors_are_not_mutable_accounting_inputs(self):
        for name, row in self.manifest["route_predecessors"].items():
            path = room.ROOT / row["locator"]
            with self.subTest(owner=name):
                self.refuses_before_replay({path: path.read_bytes() + b"\nvar extra: int = 0\n"})

    def test_route_census_result_cannot_be_changed_to_create_headroom(self):
        path = room.ROOT / room.R / "source-review-1/census.json"
        changed = json.loads(path.read_bytes())
        changed["constructor_exclusive_reuse"]["simultaneous_total"] = 0
        self.refuses_before_replay({path: json.dumps(changed).encode()})

    def test_producer_assertions_survive_optimized_python(self):
        script = "import underground_room_memory as m; m.producer(m.P/'census.py', {str(m.P/'census.py'): b'assert False, \\\"mandatory census refusal\\\"'})"
        result = subprocess.run([sys.executable, "-O", "-c", script], cwd=room.ROOT / "tools",
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AssertionError: mandatory census refusal", result.stderr)

    def test_current_recount_requires_no_git_history_or_subprocess(self):
        with mock.patch.object(subprocess, "check_output", side_effect=AssertionError("no history")):
            result, historical = room.build(self.index)
        self.assertEqual(result["additional_global_reserved_bytes"], 0)
        self.assertEqual(result["publication"]["cold_controls_accounted"], 8050)
        self.assertEqual(result["composition"]["constructor_exclusive_reuse"]["simultaneous_total"], 7493)
        route = result["route_composition"]
        self.assertEqual(route["constructor_exclusive_reuse"]["simultaneous_total"], 8161)
        self.assertEqual(route["accounting"]["controls"], 6067)
        self.assertEqual(route["accounting"]["helpers"], 1919)
        self.assertEqual(route["source_sha256"][self.index["underground_session"].relative_path],
                         hashlib.sha256(self.index["underground_session"].text.encode()).hexdigest())
        self.assertEqual(result["composition"]["source_sha256"][self.index["underground_session"].relative_path],
                         self.manifest["route_predecessors"]["underground_session"]["sha256"])
        self.assertEqual(result["ground_catalog"]["fixed_peak_accounted"], 1468)
        self.assertNotEqual(historical["underground_session"].text, self.index["underground_session"].text)
        self.assertFalse(result["native_measured"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
