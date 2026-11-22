class_name Butterflies
extends Node3D
## butterflies.js: on fine days, little die-cut paper wings (cabbage whites, sulphurs, a blue, a monarch now and then)
## flapping on a crease along the body, looping lazily over the grass round the farmer. Out of the rain, gone at dusk.
## Two MultiMeshes (left and right wings) for all of them.

const N := 18
const COLS := [0xf3ede0, 0xf0d84a, 0xe0782e, 0xf3ede0, 0xbcd0e8, 0xf0d84a]
const WING := [Vector2(0, 0.02), Vector2(0.08, 0.1), Vector2(0.16, 0.1), Vector2(0.18, 0.04), Vector2(0.12, -0.01), Vector2(0.14, -0.07), Vector2(0.08, -0.11), Vector2(0.02, -0.06)]

var wl := MultiMesh.new()
var wr := MultiMesh.new()
var bugs: Array = []
var t := 0.0

func _init() -> void:
	var mat := PaperMats.card(load("res://assets/baked/wildlife/butterfly.png"), {"flip": true, "snow": 0.0})
	var left := PackedVector2Array(WING); var right := PackedVector2Array()
	for q in WING: right.append(Vector2(-q.x, q.y))
	for pair in [[wl, left], [wr, right]]:
		var m: MultiMesh = pair[0]
		m.transform_format = MultiMesh.TRANSFORM_3D; m.use_colors = true
		m.mesh = CardMesh.build(pair[1], 0.004); m.instance_count = N; m.visible_instance_count = 0
		for k in N: m.set_instance_color(k, Color.hex((COLS[k % COLS.size()] << 8) | 0xff).srgb_to_linear())
		var mi := MultiMeshInstance3D.new(); mi.multimesh = m; mi.material_override = mat
		mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
		add_child(mi)
	for k in N: bugs.append({"home": Vector3.ZERO, "seed": k * 7.31, "set": false})

func update(dt: float, center: Vector3, night: float, rain: float) -> void:
	t += dt
	var n := N if (night < 0.3 and rain < 0.15) else 0
	wl.visible_instance_count = n; wr.visible_instance_count = n
	var flat := Basis(Vector3.RIGHT, -PI / 2.0) # (the wing card laid flat, as three's rotateX(-PI/2))
	for i in n:
		var b: Dictionary = bugs[i]
		# each keeps to a patch of meadow; a new patch when the farmer has wandered far off
		if not b.set or b.home.distance_squared_to(center) > 900.0:
			var a := randf() * TAU; var d := 4.0 + randf() * 18.0
			b.home = Vector3(center.x + cos(a) * d, 0, center.z + sin(a) * d); b.set = true
		var s: float = b.seed
		var x: float = b.home.x + sin(t * 0.37 + s) * 3.0 + sin(t * 1.3 + s * 2.0) * 0.4
		var z: float = b.home.z + cos(t * 0.29 + s * 1.7) * 3.0 + cos(t * 1.1 + s) * 0.4
		var y := Terrain.get_height(x, z) + 0.6 + sin(t * 0.8 + s) * 0.35 + absf(sin(t * 3.1 + s)) * 0.15
		# heading along the path; wings beat on the body crease
		var dx := cos(t * 0.37 + s) * 0.37 * 3.0; var dz := -sin(t * 0.29 + s * 1.7) * 0.29 * 3.0
		var yaw := atan2(dx, dz)
		var flap := 0.2 + absf(sin(t * 13.0 + s * 3.0)) * 1.1
		var p := Vector3(x, y, z)
		wl.set_instance_transform(i, Transform3D((Basis.from_euler(Vector3(0, yaw, flap), EULER_ORDER_YXZ) * flat).scaled_local(Vector3.ONE * 2.3), p))
		wr.set_instance_transform(i, Transform3D((Basis.from_euler(Vector3(0, yaw, -flap), EULER_ORDER_YXZ) * flat).scaled_local(Vector3.ONE * 2.3), p))
