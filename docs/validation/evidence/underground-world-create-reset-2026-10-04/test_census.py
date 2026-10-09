#!/usr/bin/env python3
"""Adversarial checks on additional packet/header lifetime and the composed host stack."""
import unittest
import census as C

class CensusTests(unittest.TestCase):
    def mutate(self,module,old,new):
        source=(C.ROOT/C.FILES[module]).read_text()
        self.assertIn(old,source)
        return {module:source.replace(old,new,1)}

    def test_actual_joint_fits_existing_carve_out(self):
        row=C.build()
        self.assertEqual(row['retained_numeric_name_delta'],18)
        self.assertEqual(row['outcome_numeric_name_bytes'],16)
        self.assertEqual(row['maximum_simultaneous_outcome_objects'],1)
        self.assertEqual(row['accounting']['controls'],5995)
        self.assertEqual(row['accounting']['helpers'],1882)
        self.assertEqual(row['maximum_reference_values'],45)
        self.assertTrue(any('Host.reset' in p for p in (row['numeric_chain'],row['reference_chain'])))
        self.assertFalse(row['native_measured'])

    def test_new_retained_owner_cannot_hide(self):
        with self.assertRaisesRegex(ValueError,'retained UI'):
            C.build(self.mutate('UI','var _creating_world: bool = false',
                'var _creating_world: bool = false\nvar extra_owner: RefCounted = null'))

    def test_report_width_is_not_a_free_new_reference(self):
        with self.assertRaisesRegex(ValueError,'report delta'):
            C.build(self.mutate('Form','var reset_state: int = RESET_STOPPED','var reset_state: RefCounted = null'))

    def test_outcome_cannot_grow_packed_payload(self):
        with self.assertRaisesRegex(ValueError,'outcome scalar'):
            C.build(self.mutate('Form','var state: int = RESET_STOPPED','var payload: PackedByteArray = PackedByteArray()\n\tvar state: int = RESET_STOPPED'))

    def test_outcome_default_remains_closed(self):
        with self.assertRaisesRegex(ValueError,'default stopped'):
            C.build(self.mutate('Form','var state: int = RESET_STOPPED','var state: int = RESET_CLEARED'))

    def test_existing_standalone_create_is_exact(self):
        with self.assertRaisesRegex(ValueError,'standalone'):
            C.build(self.mutate('Form','return _generate_into(out)','return false'))

    def test_hidden_extra_constructor_refuses(self):
        with self.assertRaisesRegex(ValueError,'construction sites'):
            C.build(self.mutate('UI','out.state = UiWorldSession.RESET_STOPPED',
                'var second: UiWorldSession.ResetOutcome = UiWorldSession.ResetOutcome.new()\n\tout.state = UiWorldSession.RESET_STOPPED'))

    def test_caller_retaining_outcome_across_child_allocation_refuses(self):
        source=(C.ROOT/C.FILES['UI']).read_text()
        source=source.replace('var outcome: UiWorldSession.ResetOutcome = UiWorldSession.ResetOutcome.new()',
                              'var outcome: UiWorldSession.ResetOutcome = null',1)
        source=source.replace('_creating_world = true','_creating_world = true\n\tvar held: UiWorldSession.ResetOutcome = UiWorldSession.ResetOutcome.new()',1)
        with self.assertRaisesRegex(ValueError,'frames must not overlap'):C.build({'UI':source})

    def test_transitive_new_reference_chain_is_charged(self):
        added='\n'.join('\tvar extra%d: RefCounted = null'%i for i in range(8))
        with self.assertRaisesRegex(ValueError,'carve-out exceeded'):
            C.build(self.mutate('UI','\tout.state = UiWorldSession.RESET_STOPPED',added+'\n\tout.state = UiWorldSession.RESET_STOPPED'))

    def test_variable_helper_scratch_refuses(self):
        with self.assertRaisesRegex(ValueError,'bounded helper'):
            C.build(self.mutate('UI','\tout.state = UiWorldSession.RESET_STOPPED',
                '\tvar scratch: Array = []\n\tout.state = UiWorldSession.RESET_STOPPED'))

    def test_loop_cannot_hide_repeated_packet_lifetime(self):
        with self.assertRaisesRegex(ValueError,'loop lifetime'):
            C.build(self.mutate('UI','\tout.state = UiWorldSession.RESET_STOPPED',
                '\tfor i: int in 5:\n\t\tpass\n\tout.state = UiWorldSession.RESET_STOPPED'))

    def test_callback_edge_is_required_for_peak(self):
        with self.assertRaisesRegex(ValueError,'callback lifetime'):
            C.build(self.mutate('Form','reset.call(outcome)','reset.call()'))

if __name__=='__main__':unittest.main()
