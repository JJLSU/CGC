"""Give every rigged figure an idle of its own from Meshy's animation library, so the townsfolk don't all stand
about in step. Each figure gets one of the library's standing idles (Idle 1 .. Idle 15; the stock Idle stays with
whoever draws it), dealt out in turn so neighbours differ, and saved as assets/models/meshy/<name>/idle.glb.
tools/blender_folk.py then uses that clip as the figure's 'idle'.

Usage (PowerShell):
    $env:MESHY_API_KEY = "<your key>"
    python tools/meshy_idles.py              # every rigged figure that hasn't got its own idle yet
    python tools/meshy_idles.py saloon_1     # just these
One animation task per figure; re-runs skip figures already done (state.json remembers the task).
"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshy_batch import OUT, call, wait, download

IDLES = [11, 12, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 599, 0]  # Idle 1, 2, 3 .. 14, 15, and the stock Idle


def folk():
    return sorted(n for n in os.listdir(OUT) if os.path.exists(os.path.join(OUT, n, 'state.json'))
                  and 'rig' in json.load(open(os.path.join(OUT, n, 'state.json'))) and os.path.exists(os.path.join(OUT, n, 'anims.glb')))


def run(name, idle):
    d = os.path.join(OUT, name); sp = os.path.join(d, 'state.json'); st = json.load(open(sp))
    if os.path.exists(os.path.join(d, 'idle.glb')): return
    print(f'== {name}: idle action {idle}')
    if st.get('idle_id') != idle or 'idle_anim' not in st:
        st['idle_anim'] = call('POST', '/animations', {'rig_task_id': st['rig'], 'action_ids': [idle]})['result']; st['idle_id'] = idle
        json.dump(st, open(sp, 'w'), indent=2)
    t = wait(f'/animations/{st["idle_anim"]}', 'idle')
    download(t['result']['animation_glb_url'], os.path.join(d, 'idle.glb'))


if __name__ == '__main__':
    every = folk()
    names = sys.argv[1:] or every
    for arg in names:
        n, _, want = arg.partition(':')  # name:action_id picks the idle (folk_jim:11); a new pick replaces the old idle.glb
        if want and json.load(open(os.path.join(OUT, n, 'state.json'))).get('idle_id') != int(want):
            p = os.path.join(OUT, n, 'idle.glb')
            if os.path.exists(p): os.remove(p)
        try: run(n, int(want) if want else IDLES[every.index(n) % len(IDLES)] if n in every else IDLES[0])
        except SystemExit as e:
            if '402' in str(e): raise
            print(f'!! {n} skipped: {e}')
    print('Done. Next: tools/blender_folk.py on these figures.')
