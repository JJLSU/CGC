"""Contact sheet of models: each GLB rendered from the front, the side and the back on a pale ground, one row per
model, to check for holes and missing faces. Backface culling is on, so a hole (or an inside-out face) shows as
the background colour.
    blender -b --factory-startup --python tools/blender_sheet.py -- <out.png> <a.glb> <b.glb> ...
"""
import bpy, sys, math, mathutils, os
import numpy as np
a = sys.argv[sys.argv.index('--') + 1:]
out, files = a[0], a[1:]
W, H = 300, 620
rows = []
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    for m in bpy.data.materials: m.use_backface_culling = True
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
    lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2; size = max(hi - lo)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'TEXTURE'; sc.display.shading.show_backface_culling = True
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.2, 0.8, 0.9)  # a cyan ground: holes jump out
    sc.display.shading.background_type = 'WORLD'
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = (hi.z - lo.z) * 1.04
    views = []
    for i, ang in enumerate([0, 90, 180]):
        r = size * 3; t = math.radians(ang)
        # glTF's +Z (the model's front) is Blender's -Y
        cam.location = (c.x + math.sin(t) * r, c.y - math.cos(t) * r, c.z)
        d = c - cam.location; cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        p = out + f'.tmp{i}.png'; sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(p); px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4); views.append(px); bpy.data.images.remove(img); os.remove(p)
    rows.append(np.concatenate(views, axis=1))
    print('rendered', os.path.basename(f))
sheet = np.concatenate(rows[::-1], axis=0)  # (pixel rows start at the bottom)
hh, ww = sheet.shape[:2]
img = bpy.data.images.new('sheet', width=ww, height=hh, alpha=True); img.pixels[:] = sheet.ravel()
img.filepath_raw = out; img.file_format = 'PNG'; img.save()
print('sheet', out, ww, hh)
