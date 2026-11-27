"""Cut a windmill model's wheel out as its own object, its origin on the hub, so the game can turn it.
    blender -b --factory-startup --python tools/blender_split_wheel.py -- <in.glb> <out.glb> cx cz R y0 y1
The wheel: every face whose middle lies within R of the hub (cx, cz) in the x-z plane (Blender axes, z up) and
between y0 and y1 (the wheel's own slab, in front of the head). Writes the model with two objects, "tower" and
"wheel", its texture packed."""
import bpy, sys, math, bmesh, mathutils
a = sys.argv[sys.argv.index('--') + 1:]
src, out = a[0], a[1]; cx, cz, R, y0, y1 = map(float, a[2:7])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ms = [o for o in bpy.data.objects if o.type == 'MESH']
for m in ms: m.select_set(True)
bpy.context.view_layer.objects.active = ms[0]
if len(ms) > 1: bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for p in [p for p in bpy.data.objects if p != o]: p.select_set(False)
o.name = "tower"
bm = bmesh.new(); bm.from_mesh(o.data)
n = 0
for f in bm.faces:
    c = f.calc_center_median()
    f.select = math.hypot(c.x - cx, c.z - cz) < R and y0 <= c.y <= y1 and c.z > cz - R - 0.02
    n += f.select
bm.to_mesh(o.data); bm.free()
print("wheel faces", n)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
w = [p for p in bpy.data.objects if p.type == 'MESH' and p != o][0]; w.name = "wheel"
bpy.context.scene.cursor.location = mathutils.Vector((cx, (y0 + y1) / 2.0, cz))
bpy.ops.object.select_all(action='DESELECT'); w.select_set(True); bpy.context.view_layer.objects.active = w
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
for img in bpy.data.images: # (the imported texture holds no pixels till forced to load: scaled to its own size, then packed)
    w0, h0 = img.size[0], img.size[1]
    if w0 > 0: img.scale(w0, h0); img.pack()
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_image_format='JPEG', export_apply=True)
print("wrote", out)
