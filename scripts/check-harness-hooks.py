#!/usr/bin/env python3
"""check-harness-hooks.py - the shipped build must be inert to the test-harness hooks. No Godot needed (runs in CI before
the export, and in scripts/ci-gates-local.sh).

The hooks (src/debug/harness_hooks.gd) unlock Episode 2 from a URL and kill the stage-3 boss from a URL. On the live site
that would remove the founder's access code and skip progression, so they exist only when the build carries the custom
feature tag `gm_harness`, which only `GM_HARNESS=1 scripts/ep2-local-export.sh` ever writes. This script fails if:

  H1  a harness query parameter (ep2gate, bosskill) is mentioned in any src/ .gd file except harness_hooks.gd
  H2  a function in harness_hooks.gd that reads one is missing OS.has_feature("web") or OS.has_feature("gm_harness")
  H3  allowed() stops requiring BOTH web and tag before it reads the page URL, or JavaScriptBridge.eval appears anywhere
      in the file except the single literal (no interpolation) eval inside _search(), which only allowed() may call
  H4  the hook API is called from a place other than its one sanctioned call site
      (apply_ep2_gate_skip -> ep2_entry.gd, kill_boss_after -> level_base.gd, skip_boss_credit -> claim_jumper.gd),
      or the functions that set/read the no-credit mark lose their tag / gate
  H5  .github/workflows/export-game.yml or scripts/export-web.sh (the two shipped-preset writers) lacks custom_features=""
      or mentions gm_harness, or gm_harness appears in any other script/workflow except as the opt-in block in
      scripts/ep2-local-export.sh (which must be guarded by GM_HARNESS=1)
  H6  a NEW raw touch predicate (DisplayServer.is_touchscreen_available) appears outside the allow-list
      (the single predicate is TouchUi / TouchMetrics; known leftovers only warn)

Usage:  python3 scripts/check-harness-hooks.py [--root DIR]      exit 0 = clean, 1 = violation
Mutation check (what was run): each H-rule was broken in a scratch copy and this script failed - see the final report.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if '--root' in sys.argv:
    ROOT = os.path.abspath(sys.argv[sys.argv.index('--root') + 1])

HOOKS = 'src/debug/harness_hooks.gd'
PARAMS = ('ep2gate', 'bosskill')
SANCTIONED_CALLS = {                       # api name -> the only src file (besides harness_hooks.gd) that may call it
    'apply_ep2_gate_skip': 'src/episode2/ep2_entry.gd',
    'kill_boss_after': 'src/level/level_base.gd',
    'skip_boss_credit': 'src/boss/claim_jumper.gd',
}
RAW_TOUCH_ALLOW = {'src/input/mobile/touch_metrics.gd', 'src/autoload/mobile_input_handler.gd'}
RAW_TOUCH_WARN = {'src/ui/hud.gd': 'hud.gd still re-derives touch from OS.get_name(); route it through TouchUi.is_touch()'}

fails = []
warns = []


def fail(rule, msg):
    fails.append(f'  [FAIL] {rule}: {msg}')


def read(rel):
    try:
        with open(os.path.join(ROOT, rel), encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return None


def gd_files(sub):
    out = []
    for d, _dirs, files in os.walk(os.path.join(ROOT, sub)):
        for f in files:
            if f.endswith('.gd'):
                out.append(os.path.relpath(os.path.join(d, f), ROOT).replace(os.sep, '/'))
    return sorted(out)


def functions(text):
    """{name: body} for every top-level func in a GDScript file (body = from the 'func' line to the next top-level func/class)."""
    out = {}
    parts = re.split(r'(?m)^(?=(?:static\s+)?func\s)', text)
    for p in parts:
        m = re.match(r'(?:static\s+)?func\s+(\w+)', p)
        if m:
            # full-line comments (the doc block of the NEXT function lands at the tail of this body) are not code
            out[m.group(1)] = '\n'.join(ln for ln in p.splitlines() if not ln.lstrip().startswith('#'))
    return out



# ---- H1 -----------------------------------------------------------------------------------------------------------
for rel in gd_files('src'):
    if rel == HOOKS:
        continue
    t = read(rel) or ''
    for p in PARAMS:
        if p in t:
            fail('H1', f'{rel} mentions the harness parameter "{p}" (only {HOOKS} may read it)')

hooks = read(HOOKS)
if hooks is None:
    fail('H1', f'{HOOKS} is missing')
    hooks = ''
fns = functions(hooks)

# ---- H2 -----------------------------------------------------------------------------------------------------------
for name, body in fns.items():
    code = body
    if any(f'"{p}"' in code for p in PARAMS):
        if 'OS.has_feature("gm_harness")' not in code:
            fail('H2', f'{HOOKS}:{name}() reads a harness parameter without OS.has_feature("gm_harness")')
        if 'OS.has_feature("web")' not in code:
            fail('H2', f'{HOOKS}:{name}() reads a harness parameter without OS.has_feature("web")')

# ---- H3 -----------------------------------------------------------------------------------------------------------
allowed = fns.get('allowed', '')
m_gate = re.search(r'if not \(web and tag\):\s*\n\s*return false', allowed)
i_search = allowed.find('_search()')
if not m_gate or i_search < 0 or m_gate.start() > i_search:
    fail('H3', 'allowed() must `if not (web and tag): return false` BEFORE it calls _search()')
for name, body in fns.items():
    if name != 'allowed' and '_search(' in re.sub(r'(?m)^(?:static\s+)?func\s+_search.*$', '', body) and name != '_search':
        fail('H3', f'{name}() calls _search(); only allowed() may read the page URL')
evals = [(n, b) for n, b in fns.items() if 'JavaScriptBridge.eval' in b]
if [n for n, _ in evals] != ['_search']:
    fail('H3', f'JavaScriptBridge.eval must appear only in _search(); found in {[n for n, _ in evals]}')
for n, b in evals:
    for call in re.findall(r'JavaScriptBridge\.eval\(([^)]*)\)', b):
        if '%' in call or '+' in call.split(',')[0]:
            fail('H3', f'{n}(): the JavaScriptBridge.eval must be a literal string with no interpolation (sentinel INJ-003)')
# the tag in the header constant and the gate wrappers must be the exact feature name
if 'const TAG := "gm_harness"' not in hooks:
    fail('H3', 'const TAG := "gm_harness" is missing/renamed - the export sed and this checker key on that exact name')

# ---- H4 -----------------------------------------------------------------------------------------------------------
for rel in gd_files('src'):
    if rel == HOOKS:
        continue
    t = read(rel) or ''
    for api, owner in SANCTIONED_CALLS.items():
        n = len(re.findall(r'\b' + api + r'\(', t))
        if n and rel != owner:
            fail('H4', f'{rel} calls {api}(); only {owner} may')
        if n > 1:
            fail('H4', f'{rel} calls {api}() {n} times; exactly one call site is sanctioned')
for api, owner in SANCTIONED_CALLS.items():
    t = read(owner) or ''
    if not re.search(r'\b' + api + r'\(', t):
        fail('H4', f'{owner} no longer calls {api}() - the hook is unwired (update this checker if that is deliberate)')
if 'OS.has_feature("gm_harness")' not in fns.get('skip_boss_credit', ''):
    fail('H4', 'skip_boss_credit() must test OS.has_feature("gm_harness") itself (it is the NFT-credit bypass)')
for name, body in fns.items():
    if 'set_meta(META_NO_CREDIT' in body and name != '_kill_boss':
        fail('H4', f'{name}() sets the no-credit mark; only _kill_boss() may')
if not re.search(r'level_index != KILL_LEVEL or not boss_kill_requested\(\)', fns.get('kill_boss_after', '')):
    fail('H4', 'kill_boss_after() must return unless boss_kill_requested() (the gate) and the level is the stage-3 boss')
for name, body in fns.items():
    if '_kill_boss(' in re.sub(r'(?m)^static func _kill_boss.*$', '', body) and name not in ('kill_boss_after', '_kill_boss'):
        fail('H4', f'{name}() calls _kill_boss(); only kill_boss_after() may (after the gate)')
cj = read(SANCTIONED_CALLS['skip_boss_credit']) or ''
if not re.search(r'if not preload\("res://src/debug/harness_hooks\.gd"\)\.skip_boss_credit\(self\):\n\s+GameManager\.mark_boss_defeated\("claim_jumper"\)', cj):
    fail('H4', 'claim_jumper.die() must keep GameManager.mark_boss_defeated("claim_jumper") directly under the skip_boss_credit guard')

# ---- H5 -----------------------------------------------------------------------------------------------------------
wf = read('.github/workflows/export-game.yml')
ew = read('scripts/export-web.sh')
for rel, t in (('.github/workflows/export-game.yml', wf), ('scripts/export-web.sh', ew)):
    if t is None:
        fail('H5', f'{rel} is missing (cannot prove the shipped preset is untagged)')
        continue
    if 'custom_features=""' not in t:
        fail('H5', f'{rel}: the shipped preset must contain custom_features="" (found none)')
    if 'gm_harness' in t:
        fail('H5', f'{rel} mentions gm_harness; the tag may only be written by scripts/ep2-local-export.sh')
for d in ('scripts', '.github'):
    for dp, _dn, files in os.walk(os.path.join(ROOT, d)):
        for f in files:
            rel = os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, '/')
            if rel in ('scripts/check-harness-hooks.py', 'scripts/ep2-local-export.sh') or not f.endswith(
                    ('.sh', '.yml', '.yaml', '.mjs', '.js', '.py', '.txt', '.json', '.cfg')):
                continue
            if re.search(r'custom_features\s*=.*gm_harness', read(rel) or ''):
                fail('H5', f'{rel} writes custom_features with gm_harness; only scripts/ep2-local-export.sh may (and only opt-in)')
local = read('scripts/ep2-local-export.sh') or ''
if 'custom_features="gm_harness"' in local:
    if not re.search(r'if \[ "\$\{GM_HARNESS:-0\}" = "1" \]; then\n(?:(?!\nfi\b).)*custom_features="gm_harness"', local, re.S):
        fail('H5', 'scripts/ep2-local-export.sh: the gm_harness sed must sit inside the opt-in `if [ "${GM_HARNESS:-0}" = "1" ]; then` block')
else:
    fail('H5', 'scripts/ep2-local-export.sh no longer writes the gm_harness tag - the probes cannot run (update this checker if deliberate)')

# ---- H6 -----------------------------------------------------------------------------------------------------------
for rel in gd_files('src'):
    t = read(rel) or ''
    code = '\n'.join(ln.split('#')[0] for ln in t.splitlines())
    if 'DisplayServer.is_touchscreen_available' in code and rel not in RAW_TOUCH_ALLOW:
        if rel in RAW_TOUCH_WARN:
            warns.append(f'  [WARN] H6: {rel}: {RAW_TOUCH_WARN[rel]}')
        else:
            fail('H6', f'{rel} calls DisplayServer.is_touchscreen_available(); use TouchUi.is_touch() / TouchUi.keys_shown()')

# ---- verdict ------------------------------------------------------------------------------------------------------
for w in warns:
    print(w)
if fails:
    print('\n'.join(fails))
    print(f'CHECK_HARNESS_HOOKS: {len(fails)} FAILURE(S)')
    sys.exit(1)
print('CHECK_HARNESS_HOOKS: ALL PASS')
