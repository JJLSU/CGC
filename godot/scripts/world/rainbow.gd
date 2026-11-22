class_name Rainbow
extends Node3D
## rainbow.js: after a daytime shower a rainbow pops up out of the page like the arch of a pop-up book: six bands of
## muted hand-painted paper, barn red to violet, cut as half-rings, standing 42 m off with the sun at your back. It
## hinges up slowly with a springy overshoot, stands a minute or so, then folds back down.

const BANDS := [0xc4574a, 0xd98a4a, 0xd9b45a, 0x8fa868, 0x5e9a9a, 0x8a74a8]
var hinge := Node3D.new()
var t := 0.0
var state := "down"
var stand := 0.0

func _ready() -> void:
	add_child(hinge)
	var R := 19.0; var W := 1.3
	for i in BANDS.size():
		var r0 := R - (i + 1) * W; var r1 := R - i * W
		var pts := PackedVector2Array()
		for k in 49: var a := PI * k / 48.0; pts.append(Vector2(cos(a) * r1, sin(a) * r1))
		for k in range(48, -1, -1): var a := PI * k / 48.0; pts.append(Vector2(cos(a) * r0, sin(a) * r0))
		var m := MeshInstance3D.new(); m.mesh = CardMesh.build(pts, 0.12)
		m.position.z = -i * 0.05 + 0.06 # (three's extrusion runs 0..depth along z, then stepped back per band)
		m.material_override = PaperMats.paper(Color.hex((BANDS[i] << 8) | 0xff))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 40.0
		hinge.add_child(m)
	visible = false

## Pop up ahead of the farmer, on the side away from the sun.
func show_at(player_pos: Vector3, sun_dir: Vector3) -> void:
	if state != "down": return
	var away := Vector3(-sun_dir.x, 0, -sun_dir.z)
	if away.length_squared() < 1e-4: away = Vector3(0, 0, -1)
	away = away.normalized()
	var x := player_pos.x + away.x * 42.0; var z := player_pos.z + away.z * 42.0
	position = Vector3(x, Terrain.get_height(x, z) - 0.5, z)
	rotation.y = atan2(away.x, away.z) # (its face toward the farmer)
	visible = true
	state = "up"; t = 0.0; stand = 70.0 + randf() * 30.0

func update(dt: float) -> void:
	if state == "down": return
	t += dt
	if state == "up":
		hinge.rotation.x = -(1.0 - Props.spring_rise(t * 0.45)) * (PI / 2.0)
		if t > stand: state = "folding"; t = 0.0
	elif state == "folding":
		var k := minf(1.0, t / 2.5)
		hinge.rotation.x = -(k * k) * (PI / 2.0)
		if k >= 1.0: state = "down"; visible = false
