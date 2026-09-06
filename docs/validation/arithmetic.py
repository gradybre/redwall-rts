"""Executable GDD §7.1 arithmetic and architecture bounds; integer authority."""
import argparse
import json
from pathlib import Path

def ceil_div(n,d):
    if n<0 or d<=0:raise ValueError('Expected nonnegative numerator and positive denominator')
    return (n+d-1)//d

def demand(small,medium,large,winter=False):
    if min(small,medium,large)<0 or small+medium+large>256:raise ValueError('Invalid living cohort')
    base=(small*1000+medium*1200+large*1600)*6000//1000
    return base*1200//1000 if winter else base

def route_bound(requests,expansions_per_route,quota=2048):
    """Cold, distinct FIFO queries; no cached/coalesced work credited [NEW fixture]."""
    if requests<1 or expansions_per_route<1 or quota<1:raise ValueError('Positive workload required')
    ready_ticks=[ceil_div(i*expansions_per_route,quota) for i in range(1,requests+1)]
    rank=ceil_div(95*requests,100)
    t=ready_ticks[rank-1]
    return dict(requests=requests,expansions_per_route=expansions_per_route,
                p95_rank=rank,p95_ready_tick=t,p95_real_us=ceil_div(t*1000000,30),
                within_250000_us=4*t<=30)

def next_harvest(plant_day,maturity_days,first_autumn_day,last_autumn_day):
    mature=plant_day+maturity_days
    for day in range(mature,mature+49):
        season=((day-1)%48)//12
        season_day=(day-1)%12+1
        if season==2 and first_autumn_day<=season_day<=last_autumn_day:return day
    raise AssertionError('Annual harvest window not found')

def fixtures():
    grain=64*10000*(500+7000//20)//1000
    seed_need=64*250
    grain_for_seed=ceil_div(seed_need,4)
    winter_np=demand(200,0,0,True)*12
    ration_milli=ceil_div(winter_np*1000,2400)*115//100
    batches=ceil_div(ration_milli,3000)
    starter_np=60*2400+60*1800+80*800+40*700+40*1600
    result={
        'status':'ARITHMETIC_ONLY_NOT_THREE_YEAR_SURVIVAL',
        'provenance':{
            'economy':'GDD §7.1; formulas §5.2, §5.6, §5.7',
            'path':'GDD §5.11 fixed 2048 expansions/tick and route gate; NEW cold FIFO workload of 256 expansions per route',
            'orchard':'GDD §5.6, §5.11; DERIVED earliest planting at day 49',
            'memory':'systems_architecture.md §2–3; planned packed-array capacities, not observed allocation',
        },
        'demand':dict(small200=demand(200,0,0),small200_winter=demand(200,0,0,True),
                      mixed200=demand(120,60,20),mixed200_winter=demand(120,60,20,True)),
        'field':dict(grain_milli=grain,seed_milli=seed_need,seed_grain_milli=grain_for_seed,
                     net_grain_milli=grain-grain_for_seed,np_before_seed=grain*1800//1000,
                     np_after_seed=(grain-grain_for_seed)*1800//1000,
                     crop_work_mwu=(64*4+64*8+64*6)*1000,
                     cooking_work_mwu=grain//2000*12000,water_milli=grain,
                     cooking_wood_milli=grain//2000*100),
        'winter_stock':dict(np=winter_np,ration_milli=ration_milli,batches=batches,
                            flour_milli=batches*2000,dried_fish_milli=batches*1000,
                            nuts_milli=batches*1000,water_milli=batches*1000,
                            work_mwu=batches*24000,mass_g=ration_milli*500//1000,
                            cellars=ceil_div(ration_milli*500//1000,1000000)),
        'starter':dict(np=starter_np,demand_np=demand(10,2,0),food_days_centi=starter_np*100//demand(10,2,0)),
        'quality':dict(score=40+4*4+10+5000//1000-2500*20//10000,fish_stew_np=3*2200*1050//1000),
        'mood':dict(base=(3*6000+2*7000+2*5000+4000+2*8000)//10,meal=6500,friend_loss=4700),
        'calendar':dict(calendar_three_year_ticks=144*18000-4500,elapsed_three_year_ticks=144*18000),
        'orchard':dict(apple_mature_day=49+96,apple_first_harvest_day=next_harvest(49,96,1,6),
                       pear_mature_day=49+144,pear_first_harvest_day=next_harvest(49,144,3,8)),
        'path':[route_bound(n,256) for n in (1,58,59,256)],
        'memory':dict(one_world_with_reserve=57713254+8388608,
                      two_worlds_with_reserve=57713254+8388608+51497670,
                      two_world_over_budget=57713254+8388608+51497670-100000000)
    }
    assert result['demand']==dict(small200=1200000,small200_winter=1440000,mixed200=1344000,mixed200_winter=1612800)
    assert result['field']['grain_milli']==544000 and result['field']['np_after_seed']==972000
    assert result['winter_stock']['ration_milli']==8280000 and result['winter_stock']['mass_g']==4140000
    assert result['starter']['np']==408000 and result['starter']['food_days_centi']==548
    assert result['quality']==dict(score=66,fish_stew_np=6930)
    assert result['orchard']['apple_first_harvest_day']==169
    assert result['orchard']['pear_first_harvest_day']==219
    assert result['path'][1]['within_250000_us'] and not result['path'][2]['within_250000_us']
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    a.output.parent.mkdir(parents=True,exist_ok=True)
    result=fixtures();a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
