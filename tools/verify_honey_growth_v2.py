#!/usr/bin/env python3
"""Check the candidate rank graph and reproduce the documented finite-resource route model."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNITS = ('coins', 'fiber', 'resin')
# Units: distinct accessible ripe flowers and reachable ripe material hosts per outing.
# Cheap/rich maps are counterfactuals. A fourth outing is rescued in the difficult schedule.
SCENARIOS = {
    'sparse_rescue': {'flowers': (5, 4), 'hosts': 1, 'rescue_every': 4},
    'regular': {'flowers': (9, 8), 'hosts': 2, 'rescue_every': 0},
    'ripe_beds': {'flowers': (14, 12), 'hosts': 3, 'rescue_every': 0},
}


def total(keys, ranks):
    return {unit: sum(ranks[key]['cost'][unit] for key in keys) for unit in UNITS}


def initial():
    return {'visited_meadow': False, 'lifetime_violet_sold': 0, 'sealed': False,
            'lantern_lit': False, 'feast_open': False}


def unlocked(item, owned, world):
    if not set(item.get('requires_all', [])) <= owned:
        return False
    any_ids = item.get('requires_any', [])
    if any_ids and not (set(any_ids) & owned):
        return False
    count = item.get('requires_count', {})
    if len(set(count.get('from_purchased_ranks', [])) & owned) < count.get('minimum', 0):
        return False
    for key, value in item.get('requires_world', {}).items():
        if key == 'min_lifetime_violet_sold':
            if world['lifetime_violet_sold'] < value:
                return False
        elif world[key] != value:
            return False
    return True


def ceiling_capacity(owned):
    capacity = 16 if 'bag2' in owned else 10 if 'bag1' in owned else 6
    capacity += 8 if 'pleats2' in owned else 4 if 'pleats1' in owned else 0
    return capacity


def delivery(owned, area, scenario, outing, pair_stock):
    # Physical stock in reach is a scenario input, independent of the purse.
    flower_count = scenario['flowers'][area]
    # One deliberately met three-flower chain, enough nearby valid unvisited flowers presumed.
    # Flower supplies below are explicitly in addition to the manual set; never count them twice.
    if 'garland1' in owned:
        flower_count += 2 if 'garland2' in owned else 1
        if 'cascade1' in owned:
            flower_count += 3 if 'cascade2' in owned else 2
    # Exactly one extra ripe unit laid out for the return loop, only if the player hits its timing.
    if 'tide1' in owned:
        flower_count += 1
    # Check in at the first reachable depot halfway through collection; a full basket can be emptied.
    capacity = ceiling_capacity(owned)
    depot_limit = 10 if 'relay2' in owned else 6 if 'relay1' in owned else 0
    first_load = min(capacity, flower_count // 2)
    deposited = min(first_load, depot_limit)
    carried = min(capacity, first_load - deposited + flower_count - first_load)
    # A second depot sits on the way home, after all flowers in this benchmark. It cannot create honey.
    assert carried + deposited <= flower_count
    rescue = scenario['rescue_every'] and outing % scenario['rescue_every'] == 0
    if rescue:
        sent = min(deposited, 7 if 'post2' in owned else 4 if 'post1' in owned else 0)
        protected = min(carried, 6 if 'wrap2' in owned else 3 if 'wrap1' in owned else 0)
        honey = sent + protected + (carried - protected) // 2
    else:
        honey = carried + deposited
    material = scenario.get('pond_hosts', scenario['hosts']) if area == 0 else scenario['hosts']
    if 'split_seam1' in owned:
        # The first encountered host is double-seamed; the timed pull/pickup succeeds.
        material += 1
    price = honey * (3 if area else 1)
    bonus = price // 4 if 'market' in owned else 0
    if not rescue:
        # Order always matches this route's destination. No samples set aside in this benchmark.
        if 'order1' in owned and honey >= 5:
            bonus += 6 if 'order2' in owned else 4
            if 'counter1' in owned:
                if 'counter2' in owned and honey - 5 >= 6:
                    bonus += 6
                elif honey - 5 >= 4:
                    bonus += 3
        if 'blend1' in owned:
            pair_stock[area] += honey
            if 'feastplate1' in owned:
                threshold, tip = (8, 23) if 'feastplate2' in owned and min(pair_stock) >= 8 else (6, 15)
            else:
                threshold, tip = (6, 13) if 'blend2' in owned and min(pair_stock) >= 6 else (4, 8)
            if min(pair_stock) >= threshold:
                pair_stock[0] -= threshold
                pair_stock[1] -= threshold
                bonus += tip
    return {'coins': price + bonus, 'fiber': material if area == 0 else 0,
            'resin': material if area == 1 else 0}, honey if area else 0, int(bool(rescue))


def simulate(route, ranks, actions, scenario):
    owned = set()
    wallet = dict.fromkeys(UNITS, 0)
    income = wallet.copy()
    spending = wallet.copy()
    world = initial()
    trips = 0
    pond_trips = 0
    rescues = 0
    milestones = {}
    pair_stock = [0, 0]
    for key in route:
        if key.startswith('@'):
            action = actions[key[1:]]
            assert unlocked(action, owned, world) and not world[action['sets']], key
            world[action['sets']] = True
            milestones[key] = trips
            continue
        rank = ranks[key]
        assert key not in owned
        # Non-field gates must be earned by the listed purchases and world interactions.
        possible_world = dict(world, visited_meadow='meadow' in owned,
                              lifetime_violet_sold=(10**6 if 'meadow' in owned else 0))
        assert unlocked(rank, owned, possible_world), (key, owned)
        while not unlocked(rank, owned, world) or any(wallet[u] < rank['cost'][u] for u in UNITS):
            if trips >= 400:
                raise ValueError(f'Outing limit at {key}')
            if not unlocked(rank, owned, world):
                area = 1
            elif wallet['fiber'] < rank['cost']['fiber']:
                area = 0
            else:
                area = int('meadow' in owned)
            trips += 1
            pond_trips += int(area == 0)
            assert not area or 'meadow' in owned
            gain, violet, rescue = delivery(owned, area, scenario, trips, pair_stock)
            rescues += rescue
            world['visited_meadow'] |= bool(area)
            world['lifetime_violet_sold'] += violet
            for unit in UNITS:
                wallet[unit] += gain[unit]
                income[unit] += gain[unit]
        for unit in UNITS:
            wallet[unit] -= rank['cost'][unit]
            spending[unit] += rank['cost'][unit]
            assert wallet[unit] >= 0 and wallet[unit] == income[unit] - spending[unit]
        owned.add(key)
    assert world['feast_open']
    return dict(outings=trips, pond_outings=pond_trips, rescues=rescues, milestones=milestones, income=income,
                spent=spending, remaining=wallet)


def verify(data, original):
    ranks = {rank['id']: rank for rank in data['ranks']}
    actions = {action['id']: action for action in data['world_actions']}
    assert len(ranks) == len(data['ranks']) == 75
    assert len({cell['id'] for cell in data['cells']}) == len(data['cells']) == 41
    membership = [key for cell in data['cells'] for key in cell['ranks']]
    assert set(membership) == set(ranks) and len(membership) == len(ranks)
    for baseline in original['ranks']:
        for key, value in baseline.items():
            assert ranks[baseline['id']][key] == value, (baseline['id'], key)
    for rank in ranks.values():
        assert rank['id'] not in rank['requires_all'] and rank['id'] not in rank['requires_any']
        assert set(rank['cost']) == set(UNITS)
        assert all(type(value) is int and value >= 0 for value in rank['cost'].values())
        assert rank['effect'] and rank['effect_text'] and rank['feedback']
        count = rank.get('requires_count', {})
        refs = rank['requires_all'] + rank['requires_any'] + count.get('from_purchased_ranks', [])
        assert set(refs) <= ranks.keys()
    # Independent monotone closure; visits and purple sales become possible only after meadow.
    world, owned = initial(), set()
    for _ in range(len(ranks) + len(actions) + 1):
        before = (len(owned), sum(bool(x) for x in world.values()))
        owned.update(r['id'] for r in ranks.values() if unlocked(r, owned, world))
        if 'meadow' in owned:
            world.update(visited_meadow=True, lifetime_violet_sold=6)
        for action in actions.values():
            if unlocked(action, owned, world):
                world[action['sets']] = True
        if before == (len(owned), sum(bool(x) for x in world.values())):
            break
    assert owned == ranks.keys() and world['feast_open']
    for p in data['presets']:
        bought = set(p['owned'])
        assert len(bought) == len(p['owned']) and bought <= ranks.keys()
        for key in bought:
            assert unlocked(ranks[key], bought-{key}, p['world'])
        assert unlocked(ranks[p['selected_rank']], bought, p['world'])
        for a in actions.values():
            if p['world'][a['sets']]:
                assert unlocked(a,bought,p['world'])
    for key, item in [('light_lantern',actions['light_lantern']),('feast',ranks['feast'])]:
        candidates = item['requires_count']['from_purchased_ranks']
        assert len(candidates)==len({ranks[c]['branch'] for c in candidates})==6
        base = set(item.get('requires_all', []))
        w = dict(initial(), sealed=True, lantern_lit=True)
        assert not unlocked(item, base|{candidates[0]}, w)
        assert unlocked(item, base|set(candidates[:2]), w)
    assert not unlocked(ranks['cascade1'], {'garland1','pivot1'}, dict(initial(), sealed=True))
    assert not unlocked(actions['seal'], set(), initial())
    assert not unlocked(actions['open_feast'], {'feast'}, initial())
    result = {'model':'deterministic scenario; no wall time or playtest','full_tree':total(ranks,ranks),'routes':{}}
    for route in data['routes']:
        steps = route['steps']
        assert total([s for s in steps if not s.startswith('@')], ranks) == route['cost']
        result['routes'][route['id']]={k:simulate(steps,ranks,actions,v) for k,v in SCENARIOS.items()}
    # In the flower route alone, buy the 6-coin bag as first purchase for a baseline of capacity sensitivity.
    result['flowers_early_bag'] = simulate(['bag1']+data['routes'][0]['steps'],ranks,actions,SCENARIOS['regular'])
    return result


def fiber_audit(data):
    """Vary pond supply alone, then try a fiber waiver on four skill introductions."""
    ranks = {rank['id']: rank for rank in data['ranks']}
    actions = {action['id']: action for action in data['world_actions']}
    # These actions teach timing, flight or taking an order. Keep every other price
    # and prerequisite, including the fiber used to build the bags and baskets.
    waivers = ('petal_trace1', 'forecast1', 'glide1', 'order1')
    trial = ranks.copy()
    for key in waivers:
        trial[key] = dict(ranks[key], cost=dict(ranks[key]['cost'], fiber=0))
    result = {}
    for route in data['routes']:
        cases = {}
        result[route['id']] = cases
        for hosts in (1, 2, 3):
            scenario = dict(SCENARIOS['regular'], pond_hosts=hosts)
            for prices, table in [('draft', ranks), ('four_waivers', trial)]:
                outcome = simulate(route['steps'], table, actions, scenario)
                cases[f'{prices}_pond_{hosts}'] = {
                    'milestones': outcome['milestones'],
                    'pond_outings': outcome['pond_outings'],
                    'fiber_spent': outcome['spent']['fiber'],
                    'remaining': outcome['remaining'],
                }
                if prices == 'draft':
                    assert outcome['spent'] == route['cost']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data',type=Path,default=ROOT/'docs/design/honey-growth-tree-v2.json')
    parser.add_argument('--baseline',type=Path,default=ROOT/'docs/design/honey-growth-tree-v1.json')
    parser.add_argument('--fiber-audit', action='store_true',
                        help='Compare pond yields and optional skill prices at fixed blue/violet supply')
    args = parser.parse_args()
    data = json.loads(args.data.read_text())
    result = verify(data, json.loads(args.baseline.read_text()))
    if args.fiber_audit:
        result = fiber_audit(data)
    print(json.dumps(result,ensure_ascii=False,indent=2))
