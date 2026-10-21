"""Data-only verification (does not claim GDScript compilation)."""
import json
from collections import Counter
from pathlib import Path

base=Path(__file__).resolve().parents[1]
d=json.loads((base/'data'/'seven_boxes.json').read_text(encoding='utf-8'))
assert d['schema_version']==1
assert d['id']=='BF-MK-01'
ids={a['id'] for a in d['actions']}
assert len(ids)==len(d['actions'])
assert set(d['rooms'])=={a['room'] for a in d['actions']}
sources={s['id'] for s in d['sources']}
assert all(s['url'].startswith('https://') for s in d['sources'])
assert all(c['status'] in {'D','A','P','C','U','F'} for c in d['claims'])
assert all(set(c['source_ids'])<=sources for c in d['claims'])
assert all(c['source_ids'] for c in d['claims'] if c['status']!='F')
assert all(set(a.get('require',[]))<=ids for a in d['actions'])
assert all(a['cost']>=0 for a in d['actions'])
assert sum(d['opening_balances'].values())==0
assert len(d['actions'])==9
assert len({a['ending'] for a in d['actions'] if 'ending' in a})==4
assert len({a['id'] for a in d['documents']})==len(d['documents'])
assert all(set(a.get('unlock',[]))<={p['id'] for p in d['documents']} for a in d['actions'])

# No dependency cycles.
visiting=set();done=set()
by_id={a['id']:a for a in d['actions']}
def visit(x):
    if x in done:return
    assert x not in visiting, f'dependency cycle at {x}'
    visiting.add(x)
    for y in by_id[x].get('require',[]):visit(y)
    visiting.remove(x);done.add(x)
for x in ids:visit(x)

# Four valid terminal paths; verify conservation + prerequisites and route parity.
paths=[
 ['inspect_inventory','reconcile_vouchers','protect_redactions','request_oversight','qualified_brief'],
 ['inspect_inventory','protect_redactions','preserve_archive'],
 ['inspect_inventory','reconcile_vouchers','withdraw_claim'],
 ['defer_finding']
]
for path in paths:
    balances=d['opening_balances'].copy()
    taken=[];m=d['starting_metrics'].copy()
    for a_id in path:
        a=by_id[a_id]
        assert set(a.get('require',[]))<=set(taken)
        assert all(m[k]>=v for k,v in a.get('thresholds',{}).items())
        assert balances['case_fund']>=a['cost']
        balances['case_fund']-=a['cost'];balances['outside_services']+=a['cost']
        assert sum(balances.values())==0
        for k in ('evidence','oversight','preservation','privacy','days'):
            m[k]=min(999 if k=='days' else 100,m[k]+a.get(k,0))
        taken.append(a_id)
    assert 'ending' in a
    print(f"VALID ending={a['ending']}: commands={len(path)}, budget_left={balances['case_fund']}")

# Static scene wiring: these are non-Godot assertions.
main=(base/'main.tscn').read_text()
script=(base/'main.gd').read_text()
assert 'res://main.gd' in main
assert 'const CaseEngine = preload("res://case_engine.gd")' in script
assert 'user://blackfile_seven_boxes_save.json' in script
assert 'engine.command(' in script
print('CONTENT + STATIC REFERENCES OK (Godot not executed)')
