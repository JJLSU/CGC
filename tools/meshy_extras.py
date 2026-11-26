"""More life for the player's new folk (the player: more different idles and action animations, women's for women and
men's for men): a second animation task on each figure's rig with everyday clips from Meshy's library, saved as
assets/models/meshy/<name>/extras.glb. tools/blender_folk.py merges them in, each named x_<what> (x_idle_a, x_talk,
x_shrug, x_drink, x_look, x_wave_big, x_hip ...); the game plays one now and then while a figure stands about.

Usage (PowerShell):
    $env:MESHY_API_KEY = "<your key>"        # set it yourself; this script only reads it
    python tools/meshy_extras.py             # every cgc_ townsman, townswoman, saloon girl and native man not done yet
    python tools/meshy_extras.py cgc_man_elder
One animation task per figure; re-runs skip figures already done (state.json remembers the task).
"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshy_batch import OUT, call, wait, download

# Meshy library action ids (looked up with meshy_batch.py --library)
MEN = {243: 'idle_a', 245: 'idle_b', 313: 'talk', 317: 'shrug', 342: 'drink', 336: 'look'}      # Idle 3, Idle 5, Talk with Hands Open, Shrug, Stand and Drink, Long Breathe and Look Around
WOMEN = {244: 'idle_a', 246: 'idle_b', 309: 'hip', 28: 'wave_big', 336: 'look'}                 # Idle 4, Idle 6, Talk with Left Hand on Hip, Big Wave Hello, Long Breathe and Look Around


def who(name):
    if name.startswith(('cgc_woman_', 'cgc_saloon_')): return WOMEN
    if name.startswith('cgc_man_'): return MEN
    if name.startswith('cgc_native_'): return {k: v for k, v in MEN.items() if v != 'drink'}  # (no drinking idle for the camps' men)
    return None


def run(name):
    acts = who(name)
    if acts is None: return
    d = os.path.join(OUT, name); sp = os.path.join(d, 'state.json')
    if not os.path.exists(sp): return
    st = json.load(open(sp))
    if 'rig' not in st or os.path.exists(os.path.join(d, 'extras.glb')): return
    print(f'== {name}: {", ".join(acts.values())}')
    if 'extras_anim' not in st:
        st['extras_anim'] = call('POST', '/animations', {'rig_task_id': st['rig'], 'action_ids': list(acts.keys())})['result']
        json.dump(st, open(sp, 'w'), indent=2)
    t = wait(f'/animations/{st["extras_anim"]}', 'extras')
    download(t['result']['animation_glb_url'], os.path.join(d, 'extras.glb'))
    json.dump({'extras': list(acts.values())}, open(os.path.join(d, 'extras.json'), 'w'))


if __name__ == '__main__':
    names = sys.argv[1:] or sorted(n for n in os.listdir(OUT) if who(n) is not None)
    for n in names:
        try: run(n)
        except SystemExit as e:
            if '402' in str(e) or 'MESHY_API_KEY' in str(e): raise
            print(f'!! {n} skipped: {e}')
    print('Done. Next: tools/blender_folk.py on these figures.')
