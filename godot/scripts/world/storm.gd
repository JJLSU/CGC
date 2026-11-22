class_name Storm
extends Node3D
## storm.js: summer thunderstorms. While it pours, every 7-21 s a cut-paper lightning bolt stabs down out of the
## clouds somewhere far off across the county, flickers twice and is gone; the page flashes pale (flash, read by the
## exposure) and a beat or three later, the farther the longer, the thunder rolls in (on_thunder(volume)).

const BOLT := [[0, 0], [0.9, 2.6], [0.3, 2.6], [1.3, 5.4], [0.6, 5.4], [1.8, 8.6], [-0.2, 4.6], [0.5, 4.6], [-0.6, 2.0], [0.1, 2.0], [-0.5, 0]]
var bolt: MeshInstance3D
var next := 4.0
var t := 9.0
var flash := 0.0
var thunder: Array = []
var on_thunder: Callable

func _ready() -> void:
	var pts := PackedVector2Array()
	for p in BOLT: pts.append(Vector2(p[0], -p[1]))
	bolt = MeshInstance3D.new(); bolt.mesh = CardMesh.build(pts, 0.1)
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/glow_card.gdshader")
	m.set_shader_parameter("has_map", false); m.set_shader_parameter("glow", 1.0)
	m.set_shader_parameter("flat_color", Vector3(2.4, 2.15, 1.5)) # (brighter than paper: it should crack the gloom)
	bolt.material_override = m
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.visible = false; bolt.extra_cull_margin = 1000.0
	add_child(bolt)

func update(dt: float, camera: Camera3D, center: Vector3, storming: bool) -> void:
	flash = maxf(0.0, flash - dt * 5.0)
	for th in thunder: th.at -= dt
	while thunder.size() and thunder[0].at <= 0.0:
		var th: Dictionary = thunder.pop_front()
		if on_thunder.is_valid(): on_thunder.call(th.vol)
	if t < 0.45:
		t += dt
		bolt.visible = t < 0.12 or (t > 0.2 and t < 0.3)
		if t >= 0.45: bolt.visible = false
	if not storming: return
	next -= dt
	if next > 0.0: return
	next = 7.0 + randf() * 14.0
	var a := randf() * PI * 2.0; var d := 110.0 + randf() * 120.0
	bolt.position = Vector3(center.x + cos(a) * d, 70.0 + randf() * 10.0, center.z + sin(a) * d)
	var look := Vector3(camera.global_position.x, bolt.position.y, camera.global_position.z)
	bolt.look_at(look, Vector3.UP, true) # (three's lookAt points +z at the target)
	var s := 6.0 + randf() * 3.0
	bolt.scale = Vector3(s * (-1.0 if randf() < 0.5 else 1.0), s, s)
	t = 0.0; bolt.visible = true
	flash = 1.0
	thunder.append({"at": 0.6 + d / 120.0, "vol": maxf(0.35, 1.3 - d / 250.0)})
