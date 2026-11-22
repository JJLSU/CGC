class_name Mist
extends Node3D
## mist.js: morning mist, the papercraft way. Fourteen long torn sheets of cream tissue lie low over the fields at
## first light (most mornings, every morning after a night of rain), drifting with the breeze, lifting and thinning
## by mid-morning. In the Misty Fen it never lifts: low, grey-green, all day and night.

const N := 14
var mm: MultiMesh
var mat: ShaderMaterial
var sheets: Array = []
var anchor = null
var day := -1
var misty := false
var t := 0.0
var fen := 0.0

func _ready() -> void:
	mat = ShaderMaterial.new(); mat.shader = preload("res://shaders/sheet.gdshader")
	mat.set_shader_parameter("map", load("res://assets/baked/sky/mist.png"))
	mat.render_priority = 2
	var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
	mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = pm
	mm.instance_count = N; mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	add_child(mmi)
	var rng := PNoise.Mulberry32.new(61)
	for i in N:
		var ox := (rng.next() - 0.5) * 60.0; var oz := (rng.next() - 0.5) * 60.0
		sheets.append({"off": Vector3(ox, 0, oz), "w": 9.0 + rng.next() * 9.0, "d": 3.0 + rng.next() * 2.5, "h": 1.1 + rng.next() * 1.4, "rot": rng.next() * 0.6 - 0.3, "ph": rng.next() * 6.0})

## time: the sky; rained_last_night: was there a shower since dusk? fen_w: how deep in the Misty Fen you stand (0..1).
func update(dt: float, center: Vector3, sky: DaySky, rained_last_night: bool, fen_w := 0.0) -> void:
	t += dt
	var time := sky.time
	if sky.day != day and time > 0.18 and time < 0.24:
		day = sky.day
		misty = rained_last_night or ((sky.day * 7919) % 10) < 6
		anchor = center
	var k := 0.0 if time < 0.22 else (1.0 if time < 0.29 else (1.0 - (time - 0.29) / 0.11 if time < 0.4 else 0.0))
	var lift := 0.0 if time < 0.29 else maxf(0.0, time - 0.29) / 0.11
	fen += (fen_w - fen) * minf(1.0, dt * 0.5)
	var morning := k * 0.3 if misty else 0.0
	var fenly := fen * 0.5
	var opacity := maxf(morning, fenly)
	mat.set_shader_parameter("opacity", opacity)
	var fen_tint := minf(1.0, fen * 1.4) if fenly > morning else 0.0
	mat.set_shader_parameter("tint", Vector3.ONE.lerp(Vector3(0.82, 0.9, 0.86), fen_tint))
	if fenly > morning and anchor == null: anchor = center
	if opacity <= 0.005 or anchor == null:
		mm.visible_instance_count = 0
		return
	if (anchor as Vector3).distance_squared_to(center) > 35.0 * 35.0: anchor = center
	var drift := t * 0.35
	for i in N:
		var s: Dictionary = sheets[i]
		var x: float = anchor.x + s.off.x + drift
		var z: float = anchor.z + s.off.z + sin(t * 0.05 + s.ph) * 2.0
		x = anchor.x + fposmod((x - anchor.x) + 30.0, 60.0) - 30.0 # wrap round the farmer
		var low := fenly > morning
		var y: float = maxf(0.0, Terrain.get_height(x, z)) + (s.h * 0.55 if low else s.h + lift * 2.5) + sin(t * 0.3 + s.ph) * 0.08
		var b := Basis.from_euler(Vector3(sin(t * 0.2 + s.ph) * 0.03, s.rot, 0), EULER_ORDER_XYZ)
		mm.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(s.w, 1, s.d)), Vector3(x, y, z)))
	mm.visible_instance_count = N
