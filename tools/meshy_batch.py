"""Meshy batch: reference crop -> textured 3D model -> rigged -> animated, for Paydirt Hollow's folk.

Usage (PowerShell):
    $env:MESHY_API_KEY = "<your key>"        # set it yourself; this script only reads it
    python tools/meshy_batch.py saloon_1 townsfolk_3 prospectors_1      # a few figures
    python tools/meshy_batch.py --all                                    # every crop in assets/refs
    python tools/meshy_batch.py --library idle                           # look up animation action ids (free)

For each figure it saves into assets/models/meshy/<name>/:
    raw.glb      the textured model (A-pose)
    rigged.glb   the model on a skeleton
    anims.glb    the rigged model with every clip in ACTIONS (one clip per action, in order)
    state.json   task ids, so a re-run resumes instead of paying twice
Standard library only. Stops on any API error and says why.
"""
import base64, json, os, sys, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFS = os.path.join(ROOT, 'assets', 'refs')
OUT = os.path.join(ROOT, 'assets', 'models', 'meshy')
API = 'https://api.meshy.ai/openapi/v1'

# the clips every figure gets (Meshy animation library action ids; check with --library before a big run)
ACTIONS = {
    'idle': 0,           # Idle
    'walk': 30,          # Casual_Walk
    'wave': 290,         # Wave_One_Hand
    'work': 128,         # Heavy_Hammer_Swing (chopping, mining, smithing)
    'dance': 22,         # FunnyDancing_01
    'sit': 32,           # Chair_Sit_Idle_F
}
# the warriors also shoot, fight and run (on top of everything the folk do), and ride with the sit clip
WARRIOR_ACTIONS = {'shoot': 224, 'attack': 4, 'run': 14}  # Archery Shot, Attack, Run 2
WARRIORS = {'folk_native_warrior', 'folk_native_archer', 'folk_native_hunter'}
CHILDREN = {'folk_native_girl': 1.25, 'townsfolk_4': 1.25, 'trades_4': 1.3, 'folk_jim': 1.95, 'folk_amos': 1.95}  # height in metres where it isn't an adult's 1.75 (children; the big men)
# four-legged animals get Meshy's quadruped rig (walk and run); props, plants, rocks, birds and frogs are static models
QUADRUPEDS = {'animal_bison', 'animal_horse', 'animal_donkey', 'animal_dog', 'animal_cat', 'animal_coyote', 'animal_fox', 'animal_rabbit',
              'animal_cow', 'animal_calf', 'animal_ox', 'animal_sheep', 'animal_deer', 'animal_boar', 'animal_beaver', 'animal_hodag', 'animal_wampus', 'animal_babe', 'animal_gouger'}


def key():
    k = os.environ.get('MESHY_API_KEY')
    if not k: sys.exit('Set MESHY_API_KEY in your environment first (this script never asks for it).')
    return k


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, headers={'Authorization': f'Bearer {key()}', 'Content-Type': 'application/json'},
                                 data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=120) as r: return json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors='replace')
        if e.code == 402: sys.exit(f'Meshy says 402: not enough credits, or a paid plan is needed. {msg}')
        if e.code == 429: print('Rate limited, waiting a minute...'); time.sleep(60); return call(method, path, body)
        if e.code >= 500: print(f'Meshy {e.code}, retrying in 30 s...'); time.sleep(30); return call(method, path, body)
        sys.exit(f'Meshy {method} {path} failed: {e.code} {msg}')
    except (urllib.error.URLError, TimeoutError, ConnectionError) as e:  # a dropped connection: wait and try again
        print(f'Network trouble ({e}), retrying in 30 s...'); time.sleep(30); return call(method, path, body)


def wait(path, label):
    while True:
        t = call('GET', path)
        st, pr = t.get('status'), t.get('progress', 0)
        print(f'  {label}: {st} {pr}%', end='\r', flush=True)
        if st == 'SUCCEEDED': print(); return t
        if st in ('FAILED', 'CANCELED'): print(); sys.exit(f'{label} {st}: {t.get("task_error")}')
        time.sleep(8)


def download(url, path, tries=5):
    try:
        with urllib.request.urlopen(url, timeout=300) as r: data = r.read()
    except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
        if tries <= 1: raise
        print(f'Download trouble ({e}), retrying in 30 s...'); time.sleep(30); return download(url, path, tries - 1)
    with open(path, 'wb') as f: f.write(data)
    print(f'  saved {os.path.relpath(path, ROOT)} ({os.path.getsize(path) // 1024} KB)')


def run(name):
    src = os.path.join(REFS, name + '.png')
    if not os.path.exists(src): sys.exit(f'No reference image {src}')
    d = os.path.join(OUT, name); os.makedirs(d, exist_ok=True)
    sp = os.path.join(d, 'state.json'); st = json.load(open(sp)) if os.path.exists(sp) else {}
    save = lambda: json.dump(st, open(sp, 'w'), indent=2)
    print(f'== {name}')
    kind = 'quadruped' if name in QUADRUPEDS else 'static' if name.startswith(('prop_', 'plant_', 'rock_', 'animal_', 'bldg_', 'furn_', 'veh_', 'mine_')) else 'folk'
    if 'model' not in st:
        img = 'data:image/png;base64,' + base64.b64encode(open(src, 'rb').read()).decode()
        body = {'image_url': img, 'ai_model': 'latest', 'should_texture': True, 'enable_pbr': False, 'should_remesh': True, 'topology': 'triangle',
                'target_polycount': 20000 if name.startswith('bldg_') else 15000 if name.startswith(('veh_', 'mine_', 'furn_')) else {'folk': 20000, 'quadruped': 15000}.get(kind, 8000), 'target_formats': ['glb']}
        if kind == 'folk': body['pose_mode'] = 'a-pose'
        st['model'] = call('POST', '/image-to-3d', body)['result']; save()
    t = wait(f'/image-to-3d/{st["model"]}', 'model')
    if not os.path.exists(os.path.join(d, 'raw.glb')): download(t['model_urls']['glb'], os.path.join(d, 'raw.glb'))
    if kind == 'static': return  # props, plants, rocks, birds and frogs: the textured model is all
    if kind == 'quadruped': # four-legged: Meshy's quadruped rig comes with a walk and a run
        if 'rig' not in st:
            st['rig'] = call('POST', '/rigging', {'input_task_id': st['model'], 'animation_type': 'quadruped'})['result']; save()
        t = wait(f'/rigging/{st["rig"]}', 'rig')
        r = t['result']; ba = r.get('basic_animations') or {}
        for fn, url in [('rigged.glb', r.get('rigged_character_glb_url')), ('walk.glb', ba.get('walking_glb_url')), ('run.glb', ba.get('running_glb_url'))]:
            if url and not os.path.exists(os.path.join(d, fn)): download(url, os.path.join(d, fn))
        return
    if 'rig' not in st:
        st['rig'] = call('POST', '/rigging', {'input_task_id': st['model'], 'height_meters': CHILDREN.get(name, 1.75)})['result']; save()
    t = wait(f'/rigging/{st["rig"]}', 'rig')
    if not os.path.exists(os.path.join(d, 'rigged.glb')): download(t['result']['rigged_character_glb_url'], os.path.join(d, 'rigged.glb'))
    acts = {**ACTIONS, **(WARRIOR_ACTIONS if name in WARRIORS else {})}
    if 'anim' not in st:
        st['anim'] = call('POST', '/animations', {'rig_task_id': st['rig'], 'action_ids': list(acts.values())})['result']; save()
    t = wait(f'/animations/{st["anim"]}', 'animations')
    if not os.path.exists(os.path.join(d, 'anims.glb')): download(t['result']['animation_glb_url'], os.path.join(d, 'anims.glb'))
    json.dump({'clips': list(acts.keys())}, open(os.path.join(d, 'clips.json'), 'w'))


if __name__ == '__main__':
    args = sys.argv[1:]
    if not args: sys.exit(__doc__)
    if args[0] == '--library':
        import urllib.parse
        q = '?search=' + urllib.parse.quote(args[1]) if len(args) > 1 else ''
        res = call('GET', '/animations/library' + q)
        for a in (res if isinstance(res, list) else res.get('result', res.get('data', []))):
            print(a.get('action_id'), a.get('name'), a.get('category'), a.get('sub_category'), a.get('rig_type'))
        sys.exit()
    names = sorted(f[:-4] for f in os.listdir(REFS) if f.endswith('.png')) if args[0] == '--all' else args
    for n in names:
        try: run(n)
        except SystemExit as e:  # one piece failing (Meshy couldn't rig it, say) shouldn't stop the rest; no credits should
            if '402' in str(e) or 'MESHY_API_KEY' in str(e): raise
            print(f'!! {n} skipped: {e}')
    print('Done. Next: Blender processing (tools/blender_folk.py).')
