"""Exact-tick food/health winter control fixture; not a whole-game simulator.

GDD: 5.1, 5.2, 5.7, 5.8, 5.10, 7. Model assumptions are emitted with results.
"""
from array import array
import argparse
import csv
from hashlib import sha256
import json
from pathlib import Path
import platform

HOUR=750
DAY=18000
DEN=750000
CAP=10000*DEN

def roll(x):
    x=(x ^ ((x<<13)&0xffffffff))&0xffffffff
    x=(x ^ (x>>17))&0xffffffff
    return (x ^ ((x<<5)&0xffffffff))&0xffffffff

class Winter:
    def __init__(self,recovery):
        self.recovery=recovery
        # 10 small and 2 medium, matching starter size composition.
        self.size=array('q',[1000]*8+[1200]*2+[1000]*2)
        self.need={k:array('q',[7500*DEN]*12) for k in ['hunger','rest','comfort','social','purpose']}
        self.health=array('q',[100*DEN]*12)
        self.alive=array('b',[1]*12)
        self.state=array('b',[0]*12) # 0 free, 1 eat, 2 sleep, 3 social, 4 work
        self.until=array('q',[0]*12)
        self.woken=array('q',[-2]*12) # -1 is the valid sleep window containing tick 0.
        self.food_np=array('q',[0]*12)
        self.skill_xp={k:array('q',[20000]*12) for k in ('kitchen','well')}
        self.xp_remainder={k:array('q',[0]*12) for k in ('kitchen','well')}
        self.work_ticks=array('q',[0]*12)
        self.sleep_ticks=array('q',[0]*12)
        self.eat_ticks=array('q',[0]*12)
        self.social_ticks=array('q',[0]*12)
        self.idle_ticks=array('q',[0]*12)
        self.travel_ticks=array('q',[0]*12)
        self.incap_ticks=array('q',[0]*12)
        self.alive_ticks=array('q',[0]*12)
        self.work_numerator={k:array('q',[0]*12) for k in ('kitchen','well')}
        self.starving_ticks=array('q',[0]*12)
        self.rations=111000
        self.roots=1800
        self.grain=600000
        self.water=60000
        self.wood=100000
        self.meals=[] # [quantity milli, nutrition/U, born_tick, quality]
        self.jobs={} # fixed, small station registry; actors remain packed columns
        self.tick=0
        self.rng=20260905
        self.events=[]
        self.days=[]
        self.produced=0
        self.consumed_np=0
        self.spoiled_np=0
        self.lost_np=0
        self.food_surplus=0
        self.heat_remainder=0
        self.collapse_tick=None
        self.stable_count=0
        self.stable_day=None
        self.initial_np=self.ready()
        assert self.ready()==3*89280
        for i in range(12):self.choose(i)

    def living(self):
        return sum(self.alive)

    def ready(self):
        return self.rations*2400//1000+self.roots*800//1000+sum(q*np//1000 for q,np,_,_ in self.meals)

    def daily_demand(self):
        return sum(7200*s//1000 for s,a in zip(self.size,self.alive) if a)

    def mood(self,i):
        n=self.need
        return (3*(n['hunger'][i]//DEN)+2*(n['rest'][i]//DEN)+2*(n['comfort'][i]//DEN)
                +n['social'][i]//DEN+2*(n['purpose'][i]//DEN))//10

    def factor(self,i,kind='kitchen'):
        from math import isqrt
        level=min(10,isqrt(self.skill_xp[kind][i]//5000))
        mood=self.mood(i)
        mf=600 if mood<2000 else 800 if mood<4000 else 1000 if mood<7000 else 1100 if mood<8500 else 1150
        hp=self.health[i]//DEN
        hf=600 if hp<40 else 850 if hp<70 else 1000
        return max(300,min(1800,(1000+50*level)*mf*hf//1000000))

    def start_eat(self,i):
        self.meals.sort(key=lambda m:m[2])
        nutrition=0
        if self.meals and self.meals[0][0]>=1000:
            self.meals[0][0]-=1000;nutrition=self.meals[0][1]
            if self.meals[0][0]==0:self.meals.pop(0)
        elif self.rations>=1000:
            self.rations-=1000;nutrition=2400
        elif self.need['hunger'][i]<=1500*DEN and self.roots:
            q=min(self.roots,3000000//800)
            self.roots-=q;nutrition=q*800//1000
        if nutrition:
            self.state[i]=1;self.until[i]=self.tick+150;self.food_np[i]=nutrition
            return True
        return False

    def choose(self,i):
        hour=(self.tick//HOUR)%24
        day=self.tick//DAY
        sleep_window=day if hour>=22 else day-1
        if self.need['hunger'][i]<=3500*DEN and self.start_eat(i):return
        if self.need['rest'][i]<=2500*DEN or ((hour>=22 or hour<6) and self.woken[i]!=sleep_window):
            self.state[i]=2;return
        if 18<=hour<20 and self.living()>1:
            self.state[i]=3;return
        if not self.recovery:return
        if 'well' not in self.jobs and self.water<10000:
            # Draw 10 U/10 WU and 40 m round trip at the resident speed cap.
            speed=4096 if self.size[i]==1200 else 3277
            travel=2*((20*1024*30+speed-1)//speed)
            self.jobs['well']=[i,10000000,0,self.tick+travel,0]
            self.state[i]=4;return
        if 'kitchen' not in self.jobs and sum(q for q,*_ in self.meals)<12000:
            from math import isqrt
            level=min(10,isqrt(self.skill_xp['kitchen'][i]//5000))
            grain=2000*(1000-10*level)//1000
            if self.grain>=grain and self.water>=2000 and self.wood>=100:
                self.grain-=grain;self.water-=2000;self.wood-=100
                self.rng=roll(self.rng)
                # Grain in covered storage ages at winter factor 500/1000.
                age_fraction=(self.tick*500*10000)//(750*720000)
                score=max(0,min(100,40+4*level+10+5-age_fraction*20//10000+self.rng%21-10))
                quality=0 if score<40 else 1 if score<65 else 2 if score<85 else 3
                np=1800*[900,1000,1050,1100][quality]//1000
                # Kitchen bench and its input/output are co-located in this fixture.
                self.jobs['kitchen']=[i,12000000,np,self.tick,quality]
                self.state[i]=4

    def step(self):
        self.heat_remainder+=4000
        fuel,self.heat_remainder=divmod(self.heat_remainder,DAY)
        self.wood-=fuel
        assert self.wood>=0,'Fixture ran out of heating wood; invalid warm-bed premise'
        n=self.need
        for i in range(12):
            if not self.alive[i]:continue
            st=self.state[i]
            self.alive_ticks[i]+=1
            if self.health[i]<=15*DEN:self.incap_ticks[i]+=1
            elif st==1:self.eat_ticks[i]+=1
            elif st==2:self.sleep_ticks[i]+=1
            elif st==3:self.social_ticks[i]+=1
            elif st==4:
                job=next(j for j in self.jobs.values() if j[0]==i)
                if self.tick<job[3]:self.travel_ticks[i]+=1
                else:self.work_ticks[i]+=1
            else:self.idle_ticks[i]+=1
            starving=n['hunger'][i]==0
            n['hunger'][i]=max(0,n['hunger'][i]-300*self.size[i])
            n['rest'][i]=max(0,min(CAP,n['rest'][i]+(1200000 if st==2 else -375000)))
            target=(6000 if st==2 else 7500)*DEN
            decayed=max(0,n['comfort'][i]-100000)
            n['comfort'][i]=decayed+min(300000,max(0,target-decayed))
            n['social'][i]=max(0,min(CAP,n['social'][i]+(1100000 if st==3 else -100000)))
            n['purpose'][i]=max(0,min(CAP,n['purpose'][i]+(245000 if st==4 else -75000)))
            if starving:
                self.health[i]=max(0,self.health[i]-4000);self.starving_ticks[i]+=1
            elif self.health[i]<100*DEN and n['hunger'][i]>=4000*DEN and n['rest'][i]>=4000*DEN:
                self.health[i]=min(100*DEN,self.health[i]+2000)
            if self.health[i]==0:
                if st==1:self.lost_np+=self.food_np[i]
                self.alive[i]=0;self.events.append(dict(tick=self.tick+1,resident=i+1,cause='starvation'))
                continue
            if self.health[i]<=15*DEN:continue
            if st==1:
                if self.tick+1>=self.until[i]:
                    before=n['hunger'][i]
                    n['hunger'][i]=min(CAP,before+self.food_np[i]*DEN)
                    self.consumed_np+=self.food_np[i]
                    self.food_surplus+=max(0,self.food_np[i]-(CAP-before)//DEN)
                    self.state[i]=0
                    self.food_np[i]=0
                    n['social'][i]=min(CAP,n['social'][i]+200*DEN)
            elif st==2:
                if n['rest'][i]>=9000*DEN:
                    hour=(self.tick//HOUR)%24;day=self.tick//DAY
                    self.woken[i]=day if hour>=22 else day-1;self.state[i]=0
        for key,job in list(self.jobs.items()):
            i,remaining,np,travel_end,quality=job
            if not self.alive[i] or self.health[i]<=15*DEN:continue
            if self.tick<travel_end:continue
            work=min(job[1],80*self.factor(i,key))
            job[1]-=work
            self.work_numerator[key][i]+=work
            gain,self.xp_remainder[key][i]=divmod(self.xp_remainder[key][i]+work,100000)
            self.skill_xp[key][i]+=gain
            if job[1]<=0:
                if key=='well':self.water+=10000
                else:
                    self.meals.append([2000,np,self.tick+1,quality]);self.produced+=2*np
                self.state[i]=0;del self.jobs[key]
        self.tick+=1
        for meal in list(self.meals):
            if (self.tick-meal[2])*750>=24*1000*HOUR:
                self.spoiled_np+=meal[0]*meal[1]//1000;self.meals.remove(meal)
        for i in range(12):
            if not self.alive[i] or self.health[i]<=15*DEN:continue
            if self.state[i]==3 and not 18<=(self.tick//HOUR)%24<20:self.state[i]=0
            if self.state[i]==2 and n['hunger'][i]<=1500*DEN:
                self.start_eat(i) # Interrupt sleep only when reachable food exists, GDD §7.
            if self.state[i]==0:self.choose(i)
        if not self.living() and self.collapse_tick is None:self.collapse_tick=self.tick
        if self.tick%DAY==0:self.snapshot()

    def snapshot(self):
        demand=self.daily_demand()
        food_days=100*self.ready()//demand if demand else 0
        starving=sum(a and h==0 for a,h in zip(self.alive,self.need['hunger']))
        stable=self.living()==12 and food_days>=200 and self.wood>=8000 and starving==0
        self.stable_count=self.stable_count+1 if stable else 0
        if self.stable_count>=3 and self.stable_day is None:self.stable_day=self.tick//DAY
        row=dict(day=self.tick//DAY,tick=self.tick,living=self.living(),ready_np=self.ready(),
                 food_days_centi=food_days,grain_milli=self.grain,water_milli=self.water,wood_milli=self.wood,
                 deaths=12-self.living(),starving=starving,prepared_np_total=self.produced,
                 consumed_np_total=self.consumed_np,spoiled_np_total=self.spoiled_np,
                 lost_np_total=self.lost_np,
                 work_ticks_total=sum(self.work_ticks),sleep_ticks_total=sum(self.sleep_ticks),
                 eat_ticks_total=sum(self.eat_ticks),social_ticks_total=sum(self.social_ticks),
                 travel_ticks_total=sum(self.travel_ticks),idle_ticks_total=sum(self.idle_ticks),
                 incapacitated_ticks_total=sum(self.incap_ticks),alive_ticks_total=sum(self.alive_ticks),
                 cook_work_numerator=sum(self.work_numerator['kitchen']),
                 haul_work_numerator=sum(self.work_numerator['well']),
                 minimum_health=min((self.health[i]//DEN for i in range(12) if self.alive[i]),default=0))
        self.days.append(row)
        pending=sum(self.food_np[i] for i in range(12) if self.state[i]==1 and self.alive[i])
        assert self.initial_np+self.produced==self.ready()+self.consumed_np+self.spoiled_np+pending+self.lost_np
        for i in range(12):
            assert self.alive_ticks[i]==sum(col[i] for col in (self.work_ticks,self.sleep_ticks,
                self.eat_ticks,self.social_ticks,self.travel_ticks,self.idle_ticks,self.incap_ticks))

    def run(self,days=12):
        while self.tick<days*DAY and self.living():self.step()
        if not self.days or self.days[-1]['tick']!=self.tick:self.snapshot()
        return dict(mode='conversion_enabled' if self.recovery else 'conversion_disabled',
                    completed_tick=self.tick,collapse_tick=self.collapse_tick,deaths=12-self.living(),
                    stable_day=self.stable_day,daily=self.days,events=self.events)

ASSUMPTIONS=[
 'Isolated first-winter control, starting at midnight with the starter size mix, needs 7500, health 100, 12 warm beds, and no injuries.',
 'Exactly 267840 ready NP: 111 ration U and 1.8 roots U. Both cases also hold 600 grain U, 60 water U, and 100 wood U. These winter inventories are NEW fixture choices, not a traced day-37 save.',
 'One kitchen bench, one well, 12 seats, covered storage and adequate legal input/output space exist. No building construction or immigration occurs during the fixture.',
 'Conversion-enabled policy maintains 12 prepared portions and draws water below 10 U. Disabled policy performs no acquisition or cooking.',
 'Kitchen inputs/output are co-located. Water fetching charges a 20 m leg in each direction at size speed cap. Travel is a timed workload, not an authored-map route.',
 'The fixture isolates food/health: no ingredient buffs, meal memories, relationship/conflict/departure, hazards, exposure, or rescue. Five baseline needs and mood work factors are integrated. Inactive mechanics prevent full GDD certification.',
 'All residents remain warm, including water-fetching intervals: a deliberate favorable exposure boundary condition. Actual outdoors/cold validation remains a separate test.',
 'Stocks are consumed at job assignment; no reservation phase or incomplete-job handoff. Work and COOK/HAUL XP use separate integer remainders. Gear wear and the other ten skills are outside this fixture.',
 'Stabilization means 3 consecutive daily samples with all 12 alive, no starvation, at least 2 ready food-days and 2 heating-fuel days. Food ingredients not yet cooked never count as ready.',
 'Neither a successful control nor a failed control establishes a three-year strategy outcome or M4 reachability.'
]

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    results=[Winter(False).run(),Winter(True).run()]
    for result in results:
        with (args.output/(result['mode']+'.csv')).open('w',newline='') as f:
            writer=csv.DictWriter(f,fieldnames=list(result['daily'][0]));writer.writeheader();writer.writerows(result['daily'])
    report=dict(status='ISOLATED_CONTROL_NOT_FULL_SURVIVAL_VALIDATION',assumptions=ASSUMPTIONS,
                code_sha256=sha256(Path(__file__).read_bytes()).hexdigest(),results=results,
                runtime=dict(python=platform.python_version(),platform=platform.platform()),
                source_sha256={name:sha256((Path(__file__).resolve().parents[1]/name).read_bytes()).hexdigest()
                               for name in ('game_gdd.md','ui_ux_controls.md','crowd_rendering_architecture.md','setting_rules_amendment.md')},
                assertions=dict(daily_food_ledger='PASS',per_resident_activity_partition='PASS'))
    (args.output/'winter_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps([{k:v for k,v in r.items() if k not in ['daily','events']} for r in results],indent=2))

if __name__=='__main__':main()
