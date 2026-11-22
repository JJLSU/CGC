"""Blender (headless) processing of Meshy's static models (buildings, props, plants, rocks, furniture, wagons,
mining gear) into game models for Paydirt Hollow.

Run:
    "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python tools/blender_static.py -- bldg_church_ruined prop_barrel
    ... --python tools/blender_static.py -- --all        (every static model Meshy has finished)

Reads  assets/models/meshy/<name>/raw.glb (the textured model)
Writes assets/models/props/<name>.glb  : the mesh as Meshy made it (its own ~8-20k triangles: cutting it down
                                         tears the texture seams), textures at most TEX px, JPEG
       assets/models/props/<name>.json : size in glTF axes (x across, y up, z front to back) and triangles
       assets/models/props/index.json  : the models that exist
"""
import bpy, os, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'models', 'meshy')
DST = os.path.join(ROOT, 'assets', 'models', 'props')
TEX = 2048
BODY = {}
STATIC = ('prop_', 'plant_', 'rock_', 'bldg_', 'furn_', 'veh_', 'mine_')


def keep_main(meshes):
    """A building cut from a sheet can carry bits of its neighbours (a lamp kiosk, flying shards). Keep the biggest
    piece and everything touching it (grown outward), and drop the loose bits standing apart."""
    bpy.ops.object.select_all(action='DESELECT')
    for m in meshes: m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.separate(type='LOOSE'); bpy.ops.object.mode_set(mode='OBJECT')
    parts = [o for o in bpy.data.objects if o.type == 'MESH']
    def box(o):
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        return [min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)], len(vs)
    boxes = {o.name: box(o) for o in parts}
    main = max(parts, key=lambda o: boxes[o.name][2])
    lo, hi, _ = boxes[main.name]; tol = 0.02 * max(h - l for l, h in zip(lo, hi))
    keep, grew = {main.name}, True
    while grew:
        grew = False
        for o in parts:
            if o.name in keep: continue
            a, b, _ = boxes[o.name]
            if all(a[i] <= hi[i] + tol and b[i] >= lo[i] - tol for i in range(3)):
                keep.add(o.name); grew = True; lo = [min(lo[i], a[i]) for i in range(3)]; hi = [max(hi[i], b[i]) for i in range(3)]
    # and bits floating beside the body, off the ground (flying shards): the body is where most of the surface is,
    # across and front to back (Meshy's mesh is mostly loose triangles, so no one piece is "the body")
    import numpy as np
    kp = [o for o in parts if o.name in keep]
    cs = np.array([[(boxes[o.name][0][i] + boxes[o.name][1][i]) / 2 for i in range(3)] for o in kp]); ws = np.array([boxes[o.name][2] for o in kp], float)
    ground = lo[2] + 0.04 * (hi[2] - lo[2]); span = []
    for ax in (0, 1):
        h, edges = np.histogram(cs[:, ax], bins=40, range=(lo[ax], hi[ax]), weights=ws)
        k = int(h.argmax()); a = b = k; th = 0.04 * h.max()
        while a > 0 and h[a - 1] > th: a -= 1
        while b < 39 and h[b + 1] > th: b += 1
        pad = edges[1] - edges[0]; span.append((edges[a] - pad, edges[b + 1] + pad))
    BODY.update(x=round(span[0][1] - span[0][0], 3), z=round(span[1][1] - span[1][0], 3), cx=round((span[0][0] + span[0][1]) / 2, 3))  # (cx: its middle across)  # the body's own width and depth (glTF axes), without the debris
    for o, c in zip(kp, cs):
        if boxes[o.name][0][2] > ground and not (span[0][0] <= c[0] <= span[0][1]): keep.discard(o.name)  # (sideways only: a porch roof reaches out front)
    drop = [o for o in parts if o.name not in keep]
    bpy.ops.object.select_all(action='DESELECT')
    for o in drop: o.select_set(True)
    if drop: bpy.ops.object.delete()
    kept = [o for o in bpy.data.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in kept: o.select_set(True)
    bpy.context.view_layer.objects.active = kept[0]; bpy.ops.object.join()
    print(f'   {len(parts)} pieces, dropped {len(drop)} standing apart')
    return [bpy.context.view_layer.objects.active]


def process(name):
    src = os.path.join(SRC, name, 'raw.glb')
    if not os.path.exists(src): print(f'!! {name}: no raw.glb yet'); return
    out = os.path.join(DST, name + '.glb')
    if os.path.exists(out) and os.path.getmtime(out) > os.path.getmtime(src): return  # done already
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    BODY.clear()
    if name.startswith('bldg_'): meshes = keep_main(meshes)
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX: img.scale(TEX, TEX)
        if img.packed_file is None and img.size[0]: img.pack()
    vs = [m.matrix_world @ v.co for m in meshes for v in m.data.vertices]
    lo = [min(v[i] for v in vs) for i in range(3)]; hi = [max(v[i] for v in vs) for i in range(3)]
    # Blender (x, y, z) is glTF (x, -z, y)
    size = {'x': round(hi[0] - lo[0], 3), 'y': round(hi[2] - lo[2], 3), 'z': round(hi[1] - lo[1], 3)}
    tris = sum(len(p.vertices) - 2 for m in meshes for p in m.data.polygons)
    os.makedirs(DST, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=85, export_animations=False)
    json.dump({'name': name, 'size': size, 'tris': tris, **({'body': dict(BODY)} if name.startswith('bldg_') else {})}, open(os.path.join(DST, name + '.json'), 'w'), indent=2)
    print(f'== {name}: {tris} tris, size {size}, {os.path.getsize(out) // 1024} KB')


argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not argv: print(__doc__)
names = sorted(n for n in os.listdir(SRC) if n.startswith(STATIC)) if argv[:1] == ['--all'] else argv
for n in names: process(n)
if os.path.isdir(DST): json.dump(sorted(f[:-4] for f in os.listdir(DST) if f.endswith('.glb')), open(os.path.join(DST, 'index.json'), 'w'))
