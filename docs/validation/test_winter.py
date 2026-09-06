"""Independent boundary cases for the isolated control; not game qualification."""
import unittest
from winter import Winter, DEN, DAY

class WinterTests(unittest.TestCase):
    def test_start_has_exactly_three_food_days(self):
        w=Winter(False)
        self.assertEqual(w.ready(),267840)
        self.assertEqual(w.daily_demand(),89280)
        self.assertEqual(w.ready(),3*w.daily_demand())

    def test_meal_requires_full_150_intervals(self):
        w=Winter(False)
        w.need['hunger'][0]=3000*DEN
        self.assertTrue(w.start_eat(0))
        for _ in range(149):w.step()
        self.assertEqual(w.consumed_np,0)
        self.assertEqual(w.eat_ticks[0],149)
        w.step()
        self.assertEqual(w.consumed_np,2400)
        self.assertEqual(w.eat_ticks[0],150)
        self.assertEqual(w.need['hunger'][0],5340*DEN)

    def test_urgent_food_interrupts_sleep(self):
        w=Winter(False)
        w.need['hunger'][0]=1500*DEN
        w.need['rest'][0]=5000*DEN
        w.state[0]=2
        w.step()
        self.assertEqual(w.state[0],1)
        self.assertEqual(w.until[0],151)

    def test_social_window_closes_at_20(self):
        w=Winter(False)
        w.tick=20*750-1
        w.state[0]=3
        w.step()
        self.assertNotEqual(w.state[0],3)

    def test_sleep_window_does_not_restart_after_reaching_9000(self):
        w=Winter(False)
        w.need['rest'][0]=9000*DEN-1200000
        w.step()
        self.assertNotEqual(w.state[0],2)
        w.step()
        self.assertNotEqual(w.state[0],2)

    def test_closed_starvation_matches_independent_55_hour_derivation(self):
        w=Winter(False)
        w.alive[1:]=type(w.alive)('b',[0]*11)
        w.need['hunger'][0]=9000*DEN
        w.rations=w.roots=w.initial_np=0
        while w.tick<41249:w.step()
        self.assertEqual(w.alive[0],1)
        w.step()
        self.assertEqual(w.alive[0],0)
        self.assertEqual(w.collapse_tick,41250)

    def test_work_has_no_assignment_tick_credit_and_separate_skills(self):
        w=Winter(True)
        w.tick=6*750
        w.water=0
        w.state[0]=0
        w.choose(0)
        self.assertEqual(w.work_numerator['well'][0],0)
        self.assertIn('well',w.jobs)
        while w.work_numerator['well'][0]<10000000:w.step()
        self.assertEqual(w.work_numerator['well'][0],10000000)
        self.assertEqual(w.skill_xp['well'][0],20100)
        self.assertEqual(w.skill_xp['kitchen'][0],20000)

    def test_need_cap_discards_excess(self):
        w=Winter(False)
        w.need['rest'][0]=10000*DEN
        w.state[0]=2
        w.step()
        self.assertEqual(w.need['rest'][0],10000*DEN)
        w.step()
        self.assertEqual(w.need['rest'][0],10000*DEN-375000)

    def test_two_day_replay_and_daily_ledgers(self):
        a=Winter(True).run(days=2)
        b=Winter(True).run(days=2)
        self.assertEqual(a,b)
        self.assertEqual(a['completed_tick'],2*DAY)
        for day in a['daily']:
            self.assertEqual(day['alive_ticks_total'],12*day['tick'])
            self.assertGreater(day['prepared_np_total'],0)

    def test_finite_stock_winter_controls_have_opposite_outcomes(self):
        enabled=Winter(True).run()
        disabled=Winter(False).run()
        self.assertEqual(enabled['completed_tick'],12*DAY)
        self.assertEqual(enabled['deaths'],0)
        self.assertEqual(enabled['stable_day'],3)
        self.assertEqual(len(enabled['daily']),12)
        self.assertTrue(all(row['minimum_health']==100 for row in enabled['daily']))
        self.assertEqual(disabled['deaths'],12)
        self.assertEqual(disabled['collapse_tick'],91500)
        self.assertIsNone(disabled['stable_day'])

if __name__=='__main__':unittest.main()
