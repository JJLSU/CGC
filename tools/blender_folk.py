"""Blender (headless) processing of Meshy's animated figures into lean game models for Paydirt Hollow.

Run:
    "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python tools/blender_folk.py -- saloon_1 trades_4
    ... --python tools/blender_folk.py -- --all

Reads  assets/models/meshy/<name>/anims.glb (and clips.json, the clip names in order)
Writes assets/models/folk/<name>.glb  : one skinned mesh (about TRIS triangles), textures at most TEX px, the clips
                                        renamed idle / walk / wave / work / dance / sit, standing on the origin
       assets/models/folk/<name>.json : height, triangle count, clip names, the right-hand bone (for tools)
"""
import bpy, os, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'models', 'meshy')
DST = os.path.join(ROOT, 'assets', 'models', 'folk')
TRIS = 30000  # (Meshy's own ~20k mesh is kept: cutting it down tears the texture seams into white specks)
TEX = 2048


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def process(name):
    src = os.path.join(SRC, name, 'anims.glb')
    if not os.path.exists(src): print(f'!! {name}: no {src} yet'); return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    # an idle of the figure's own (tools/meshy_idles.py), in place of the stock one everybody shares
    own = None; idle_src = os.path.join(SRC, name, 'idle.glb')
    if os.path.exists(idle_src):
        keep, before = set(bpy.data.objects), set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=idle_src)
        new = [a for a in bpy.data.actions if a not in before]
        own = new[0] if new else None
        for a in new[1:]: bpy.data.actions.remove(a)
        bpy.ops.object.select_all(action='DESELECT')
        for o in bpy.data.objects:
            if o not in keep: o.select_set(True)
        bpy.ops.object.delete()
        if own:
            own.use_fake_user = True
            for a in list(bpy.data.actions):
                if a is not own and 'idle' in a.name.lower() and 'sit' not in a.name.lower(): bpy.data.actions.remove(a)
            own.name = 'idle'
    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if not arm or not meshes: print(f'!! {name}: no armature or mesh in {src}'); return
    # one mesh
    if len(meshes) > 1:
        bpy.ops.object.select_all(action='DESELECT')
        for m in meshes: m.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]; bpy.ops.object.join()
    mesh = meshes[0]
    before = tris(mesh)
    # decimate under the armature modifier, so the skin weights survive
    if before > TRIS:
        dec = mesh.modifiers.new('decimate', 'DECIMATE'); dec.ratio = TRIS / before; dec.use_collapse_triangulate = True
        while mesh.modifiers.find('decimate') > 0:
            bpy.context.view_layer.objects.active = mesh; bpy.ops.object.modifier_move_up(modifier='decimate')
        bpy.context.view_layer.objects.active = mesh; bpy.ops.object.modifier_apply(modifier='decimate')
    after = tris(mesh)
    # textures no bigger than TEX
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX: img.scale(TEX, TEX)
        if img.packed_file is None and img.size[0]: img.pack()
    # clips: rename in the order they were asked for
    # clips: named by what Meshy called them (they don't come in the order asked for)
    KEYS = [('sit', 'sit'), ('walk', 'walk'), ('wave', 'wave'), ('hammer', 'work'), ('chop', 'work'), ('swing', 'work'), ('danc', 'dance'), ('run', 'run'), ('idle', 'idle'), ('throw', 'throw'), ('jump', 'slam'), ('attack', 'attack')]
    acts = list(bpy.data.actions)
    print(f'   actions found: {[a.name for a in acts]}')
    for a in acts:
        low = a.name.lower()
        for k, n in KEYS:
            if k in low and not bpy.data.actions.get(n): a.name = n; break
    # everyday extras (tools/meshy_extras.py: extras.glb), merged in as x_<what>, after the main clips have their names
    ex_src = os.path.join(SRC, name, 'extras.glb')
    if os.path.exists(ex_src):
        keep, before = set(bpy.data.objects), set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=ex_src)
        new = [a for a in bpy.data.actions if a not in before]
        bpy.ops.object.select_all(action='DESELECT')
        for o in bpy.data.objects:
            if o not in keep: o.select_set(True)
        bpy.ops.object.delete()
        XKEYS = [('idle_3', 'x_idle_a'), ('idle_4', 'x_idle_a'), ('idle_5', 'x_idle_b'), ('idle_6', 'x_idle_b'), ('hip', 'x_hip'), ('hands_open', 'x_talk'),
                 ('shrug', 'x_shrug'), ('drink', 'x_drink'), ('look_around', 'x_look'), ('big_wave', 'x_wave_big')]
        for a in new:
            low = a.name.lower().replace(' ', '_')
            nm = next((n for k, n in XKEYS if k in low), None)
            if nm and not bpy.data.actions.get(nm): a.name = nm; a.use_fake_user = True
            else: bpy.data.actions.remove(a)
        print(f'   extras: {[a.name for a in bpy.data.actions if a.name.startswith("x_")]}')
    # the right hand, for tools
    hand = next((b.name for b in arm.data.bones if 'hand' in b.name.lower() and ('right' in b.name.lower() or b.name.lower().endswith('_r') or b.name.lower().endswith('.r') or 'r_' in b.name.lower())), None)
    # height
    import mathutils
    zs = [(mesh.matrix_world @ v.co).z for v in mesh.data.vertices]
    height = max(zs) - min(zs)
    os.makedirs(DST, exist_ok=True)
    out = os.path.join(DST, name + '.glb')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS', export_apply=False,
                              export_image_format='JPEG', export_jpeg_quality=85, export_skins=True, export_morph=False)
    info = {'name': name, 'height': round(height, 3), 'tris': after, 'tris_before': before, 'clips': [a.name for a in bpy.data.actions], 'hand': hand}
    json.dump(info, open(os.path.join(DST, name + '.json'), 'w'), indent=2)
    print(f'== {name}: {before} -> {after} tris, height {height:.2f} m, hand bone {hand}, {os.path.getsize(out) // 1024} KB')


argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not argv: print(__doc__)
names = sorted(os.listdir(SRC)) if argv[:1] == ['--all'] and os.path.isdir(SRC) else argv
for n in names: process(n)
# the list of models that exist, so the game asks only for those
if os.path.isdir(DST): json.dump(sorted(f[:-4] for f in os.listdir(DST) if f.endswith('.glb')), open(os.path.join(DST, 'index.json'), 'w'))
