"""Evidence-boundary tests; no Windows performance samples are synthesized."""
import unittest
from run_headless import same_result,inspect_log

class HeadlessRunnerTests(unittest.TestCase):
    def test_numeric_type_mismatch_cannot_hide_in_equality(self):
        with self.assertRaisesRegex(ValueError,'type differs'):
            same_result({'tick':18000},{'tick':18000.0})

    def test_nested_result_difference_identifies_exact_location(self):
        with self.assertRaisesRegex(ValueError,r'results\[0\]\.daily\[0\]\.living'):
            same_result([{'daily':[{'living':12}]}],[{'daily':[{'living':11}]}])

    def test_truncated_results_rejected(self):
        with self.assertRaisesRegex(ValueError,'list length differs'):
            same_result([1,2],[1])

    def test_script_failure_cannot_be_certified_by_process_exit_alone(self):
        with self.assertRaisesRegex(ValueError,'runtime error'):
            inspect_log('SCRIPT ERROR: Invalid call\n')

    def test_unknown_engine_error_is_not_ignored(self):
        with self.assertRaisesRegex(ValueError,'Unrecognized'):
            inspect_log('ERROR: Failed to write checkpoint\n')

    def test_certificate_diagnostic_requires_its_known_origin(self):
        message='ERROR: Condition "ret != noErr" is true. Returning: ""\n'
        with self.assertRaisesRegex(ValueError,'Unrecognized'):
            inspect_log(message+'   at: other_function (test:1)\n')
        self.assertEqual(len(inspect_log(message+'   at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)\n')),1)

if __name__=='__main__':unittest.main()
