#!/usr/bin/env python3
"""Refuse hidden clock state, arrays, calls and source-image growth before admission."""
import struct
import unittest
import census as C


class CensusTests(unittest.TestCase):
    def test_current_image_and_complete_presentation_counts(self):
        result = C.build()
        self.assertEqual(result["incremental_retained_presentation"], 135304)
        self.assertEqual(result["clock_own_logical_proposal"], 160)
        self.assertFalse(result["shared_runtime_admission"])

    def test_new_retained_state_refuses(self):
        source = (C.HERE/"handling_clock.gd").read_text()
        for extra in ("var _phase: int = 0\n", "var _rows: PackedInt32Array = PackedInt32Array()\n"):
            with self.subTest(extra=extra), self.assertRaises(ValueError): C.build(source=source+extra)

    def test_hidden_literals_and_allocations_refuse(self):
        source = (C.HERE/"handling_clock.gd").read_text()
        for extra in ("var x: Array = [0, 1]", "var x: Dictionary = {}",
                      "var x: PackedInt32Array = PackedInt32Array([0])", "out.resize(4096)"):
            mutant = source.replace('var clip: int = 0', extra+'\n\tvar clip: int = 0')
            with self.subTest(extra=extra), self.assertRaises(ValueError): C.build(source=mutant)

    def test_changed_phase_capacity_duration_and_calls_refuse(self):
        source = (C.HERE/"handling_clock.gd").read_text()
        for old, new in (("TRANSITION_TICKS: int = 30", "TRANSITION_TICKS: int = 60"),
                         ("SOURCE_INTERVALS: int = 54", "SOURCE_INTERVALS: int = 54000"),
                         ("HANDLED_READY: int = 11", "HANDLED_READY: int = 16"),
                         ("return time == 0", "return unseen(time)")):
            with self.subTest(old=old), self.assertRaises(ValueError): C.build(source=source.replace(old,new))

    def test_reached_expression_allocations_refuse(self):
        source = (C.HERE/"handling_clock.gd").read_text()
        for expression in ("([" + ",".join(["0"] * 1024) + "]).size()",
                           "({0: 0}).size()", "([0] + [0]).size()"):
            mutant = source.replace("out[0] = clip", "out[0] = " + expression)
            with self.subTest(expression=expression[:40]), self.assertRaisesRegex(
                    ValueError, "ASSEMBLY_CLOCK_EXECUTABLE"):
                C.build(source=mutant)

    def test_mixed_docstring_and_executable_line_refuses(self):
        source = (C.HERE/"handling_clock.gd").read_text()
        docstring = '"""Write exact clip/Q16 into two caller scalars; all refusal paths preserve the output."""'
        for extra in ('; out.resize(4096)', '; out[0] = ([0]).size()'):
            with self.subTest(extra=extra), self.assertRaisesRegex(ValueError, "ASSEMBLY_CLOCK_EXECUTABLE"):
                C.build(source=source.replace(docstring, docstring + extra))

    def test_raw_source_correspondence_requires_explicit_renewal(self):
        source = (C.HERE/"handling_clock.gd").read_text()
        with self.assertRaisesRegex(ValueError, "ASSEMBLY_CLOCK_EXECUTABLE"):
            C.build(source=source + "\n# An annotation must also be reviewed.\n")

    def test_added_numeric_frame_or_parameter_refuses(self):
        source = (C.HERE/"handling_clock.gd").read_text()
        for mutant in (source.replace("var clip: int = 0", "var extra: int = 0\n\tvar clip: int = 0"),
                       source.replace("var clip: int = 0", "var extra = 0\n\tvar clip: int = 0"),
                       source.replace("var clip: int = 0", "for index: int in 5: pass\n\tvar clip: int = 0"),
                       source.replace("advance(phase: int, time: int)", "advance(phase: int, time: int, extra: int)")):
            with self.assertRaises(ValueError): C.build(source=mutant)

    def test_image_growth_and_clip_overlap_refuse(self):
        image = (C.HERE/"compiled-3/mole-worker.ugactor").read_bytes()
        with self.assertRaises(ValueError): C.build(image=image+b"\0")
        for offset in (24, 328+48, 328+48+4):
            bad = bytearray(image); struct.pack_into("<I", bad, offset, 65536)
            with self.subTest(offset=offset), self.assertRaises(ValueError): C.build(image=bytes(bad))


if __name__ == "__main__": unittest.main()
