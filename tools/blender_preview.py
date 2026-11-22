"""Render a quick turntable-ish preview (front and three-quarter) of a GLB, for judging a model.
    blender -b --factory-startup --python tools/blender_preview.py -- <in.glb> <out.png>
"""
import bpy, sys, math, mathutils
a = sys.argv[sys.argv.index('--') + 1:]
src, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (lo + hi) / 2; size = max(hi - lo)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
sc.render.resolution_x, sc.render.resolution_y = 900, 700
sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True; sc.world.node_tree.nodes['Background'].inputs[0].default_value = (0.93, 0.82, 0.74, 1); sc.world.node_tree.nodes['Background'].inputs[1].default_value = 1.0
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sun.data.energy = 3; sun.rotation_euler = (math.radians(50), 0, math.radians(35)); sc.collection.objects.link(sun)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = size * 1.25
# two views side by side: render front, then three-quarter, and join
import os
views = []
for i, ang in enumerate([0, 40]):
    r = size * 3; t = math.radians(ang)
    cam.location = (c.x + math.sin(t) * r, c.y - math.cos(t) * r, c.z + size * 0.15)
    d = c - cam.location; cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    p = out.replace('.png', f'_{i}.png'); sc.render.filepath = p; bpy.ops.render.render(write_still=True); views.append(p)
print('rendered', views, 'size', tuple(round(v, 2) for v in (hi - lo)))
