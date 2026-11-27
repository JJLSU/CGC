"""Weld a Meshy model's loose triangles together (merge vertices by distance, keeping its UV seams) so Godot can build
level-of-detail copies on import (it can't simplify unwelded triangle soup). Writes <out.glb> beside, texture packed.
    blender -b --factory-startup --python tools/blender_weld.py -- <in.glb> <out.glb> [distance m, default 0.0005]"""
import bpy, sys, bmesh
a = sys.argv[sys.argv.index('--') + 1:]
src, out = a[0], a[1]; dist = float(a[2]) if len(a) > 2 else 0.0005
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
before = after = 0
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    bm = bmesh.new(); bm.from_mesh(o.data)
    before += len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist) # (positions only: the UVs stay per face corner, so seams keep)
    after += len(bm.verts)
    bm.to_mesh(o.data); bm.free()
    o.data.shade_smooth() if False else None
print("WELD verts %d -> %d" % (before, after))
for img in bpy.data.images:
    w0, h0 = img.size[0], img.size[1]
    if w0 > 0: img.scale(w0, h0); img.pack()
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_image_format='JPEG', export_apply=True)
