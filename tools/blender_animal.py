"""Blender (headless) processing of Meshy's four-legged animals into game models for Paydirt Hollow.

Run:
    "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python tools/blender_animal.py -- animal_dog animal_horse

Reads  assets/models/meshy/<name>/walk.glb and run.glb (Meshy's quadruped rig and its two basic clips)
Writes assets/models/animals/<name>.glb  : one skinned mesh, textures at most TEX px, the clips 'walk' and 'run'
       assets/models/animals/<name>.json : length (nose to tail, along the model's +Z front), height, triangles
       assets/models/animals/index.json  : the animals that exist
"""
import bpy, os, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'models', 'meshy')
DST = os.path.join(ROOT, 'assets', 'models', 'animals')
TEX = 2048


def process(name):
    walk, run = (os.path.join(SRC, name, f) for f in ('walk.glb', 'run.glb'))
    if not os.path.exists(walk): print(f'!! {name}: no walk.glb yet'); return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=walk)
    keep = set(bpy.data.objects)
    for a in bpy.data.actions: a.name = 'walk'
    if os.path.exists(run):  # take only the run clip from the second file
        before = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=run)
        for a in set(bpy.data.actions) - before: a.name = 'run'; a.use_fake_user = True
        extra = [o for o in bpy.data.objects if o not in keep]
        bpy.ops.object.select_all(action='DESELECT')
        for o in extra: o.select_set(True)
        bpy.ops.object.delete()
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    arm.animation_data.action = bpy.data.actions['walk']
    for a in list(bpy.data.actions):
        if a.name not in ('walk', 'run'): bpy.data.actions.remove(a)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX: img.scale(TEX, TEX)
        if img.packed_file is None and img.size[0]: img.pack()
    # size at rest (the bind pose): glTF +Z (the front) is Blender's -Y
    vs = [m.matrix_world @ v.co for m in meshes for v in m.data.vertices]
    length = max(v.y for v in vs) - min(v.y for v in vs); height = max(v.z for v in vs) - min(v.z for v in vs)
    tris = sum(len(p.vertices) - 2 for m in meshes for p in m.data.polygons)
    os.makedirs(DST, exist_ok=True)
    out = os.path.join(DST, name + '.glb')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS', export_apply=False,
                              export_image_format='JPEG', export_jpeg_quality=85, export_skins=True, export_morph=False)
    info = {'name': name, 'length': round(length, 3), 'height': round(height, 3), 'tris': tris, 'clips': [a.name for a in bpy.data.actions]}
    json.dump(info, open(os.path.join(DST, name + '.json'), 'w'), indent=2)
    print(f'== {name}: {tris} tris, length {length:.2f} m, height {height:.2f} m, clips {info["clips"]}, {os.path.getsize(out) // 1024} KB')


argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not argv: print(__doc__)
for n in argv: process(n)
if os.path.isdir(DST): json.dump(sorted(f[:-4] for f in os.listdir(DST) if f.endswith('.glb')), open(os.path.join(DST, 'index.json'), 'w'))
