class_name Shafts
extends Node3D
## shafts.js: shafts of sunlight slanting down through the trees, cut from tissue paper: long soft strips laid along
## the sun's direction, streaked with paler threads, glowing faintly. A dozen drift round the farmer in wooded
## country, breathing in and out on their own clocks; brightest in the low gold of morning and evening, gone by night
## and in the rain. One MultiMesh; each strip turns about its long axis to face the camera and fades by narrowing.

const N := 12
const TREES := ["pine", "maple", "goldtree", "sagetree", "birch", "appletree", "snag"]
const SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 col = vec3(1.0, 0.86, 0.6);
uniform float strength = 0.0;
varying float view_z;
void vertex() { view_z = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float across = 1.0 - smoothstep(0.18, 0.5, abs(UV.x - 0.5));                       // soft torn sides
	float v = 1.0 - UV.y;                                                              // (0 at the ground)
	float along = smoothstep(0.0, 0.35, v) * (1.0 - smoothstep(0.75, 1.0, v));          // fades at the ground and up high
	float threads = sin(UV.x * 23.0 + v * 2.0) * 0.25 + sin(UV.x * 57.0) * 0.12 + 0.75;  // paler fibres in the tissue
	float near_cam = smoothstep(5.0, 14.0, view_z);                                    // a beam by the lens fades out
	ALBEDO = col * across * along * threads * near_cam * strength;
}"""

var mm := MultiMesh.new()
var mat := ShaderMaterial.new()
var list: Array = []
var strength := 0.0
var mi := MultiMeshInstance3D.new()

func _init() -> void:
	var sh := Shader.new(); sh.code = SHADER; mat.shader = sh
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.center_offset = Vector3(0, 0.5, 0)
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = q; mm.instance_count = N
	mi.multimesh = mm; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(mi)
	for i in N: list.append({"x": 0.0, "z": 0.0, "y": 0.0, "len": 12.0, "age": 99.0, "life": 1.0 + i, "wide": 1.0})

## Put a strip somewhere near the farmer, beside a tree if there's one to be found.
func _place(s: Dictionary, world: World, p: Vector3) -> void:
	for k in 6:
		var a := randf() * TAU; var d := 6.0 + randf() * 22.0; var x := p.x + cos(a) * d; var z := p.z + sin(a) * d
		var near := world.resources_near(x, z, 4.0).any(func(r): return r.type in TREES and r.alive)
		if near or k == 5: s.x = x; s.z = z; s.y = Terrain.get_height(x, z); break
	s.age = 0.0; s.life = 7.0 + randf() * 9.0; s.len = 10.0 + randf() * 8.0; s.wide = 0.8 + randf() * 1.8

func update(dt: float, camera: Camera3D, pos: Vector3, sky: DaySky, rain: float, world: World, wooded: float) -> void:
	# strongest in the low gold light, softer at noon, nothing at night or under rain
	var a := sky.key_dir; var e := a.y; var day := 1.0 - sky.night
	var target := day * (1.0 - minf(1.0, rain * 1.6)) * (0.18 + 0.22 * (1.0 - clampf((e - 0.45) / 0.35, 0.0, 1.0))) * (0.45 + 0.55 * wooded)
	strength += (target - strength) * minf(1.0, dt * 0.8)
	var sc: Color = sky.sun.light_color.lerp(Color.WHITE, 0.15)
	mat.set_shader_parameter("col", Vector3(sc.r, sc.g, sc.b)); mat.set_shader_parameter("strength", strength)
	mi.visible = strength > 0.004
	if not mi.visible: return
	var cp := camera.global_position
	for i in N:
		var s: Dictionary = list[i]
		s.age += dt
		if s.age > s.life or Vector2(s.x - pos.x, s.z - pos.z).length() > 34.0: _place(s, world, pos)
		var k := sin(PI * minf(1.0, s.age / s.life)) # (breathes in and out)
		# axial billboard: the strip runs from the ground up toward the sun and turns to face the camera
		var c := Vector3(s.x, s.y, s.z)
		var w: Vector3 = a.cross(cp - c).normalized() * (float(s.wide) * k + 1e-4)
		var n: Vector3 = w.cross(a).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(w, a * s.len, n), c))
