class_name FireSmoke
extends Node3D
## firesmoke.js: smoke and sparks over the fires: soft cream paper puffs drift up from the nearest three fires
## (campfires, the forge's chimney, the camps' cookfires, the bunkhouse supper fire, the town's stovepipes), leaning
## with the breeze and opening out as they climb; after dusk little orange flecks fly up from the coals and wink out.

const FIRES := 3
const PUFFS := 7
const SPARKS := 10

var puffs := MultiMesh.new()
var sparks := MultiMesh.new()
var puff_mat: ShaderMaterial
var spark_mat: StandardMaterial3D
var t := 0.0
var seeds: Array = []

func _init() -> void:
	var pts := PackedVector2Array()
	for i in 30:
		var a := (i / 30.0) * TAU; var r := 0.42 + 0.1 * absf(sin(a * 2.5))
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.85))
	puff_mat = PaperMats.card(null, {"albedo": Color.hex(0xe8e0d0ff), "snow": 0.0, "self_fill": 0.35})
	puffs.transform_format = MultiMesh.TRANSFORM_3D; puffs.mesh = CardMesh.build(pts, 0.04); puffs.instance_count = FIRES * PUFFS; puffs.visible_instance_count = 0
	var pmi := MultiMeshInstance3D.new(); pmi.multimesh = puffs; pmi.material_override = puff_mat; pmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(pmi)
	spark_mat = StandardMaterial3D.new(); spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; spark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED; spark_mat.albedo_color = Color(2.0, 0.9, 0.25)
	var qm := QuadMesh.new(); qm.size = Vector2(0.06, 0.1)
	sparks.transform_format = MultiMesh.TRANSFORM_3D; sparks.mesh = qm; sparks.instance_count = FIRES * SPARKS; sparks.visible_instance_count = 0
	var smi := MultiMeshInstance3D.new(); smi.multimesh = sparks; smi.material_override = spark_mat; smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; smi.custom_aabb = pmi.custom_aabb; add_child(smi)
	for i in FIRES * 10: seeds.append(randf())

## fires: [{x, y, z, top, sparks}] where the smoke leaves (nearest first).
func update(dt: float, fires: Array, camera: Camera3D, night: float, rain: float) -> void:
	t += dt
	puff_mat.set_shader_parameter("self_fill", 0.35 * (1.0 - minf(1.0, night * 1.4))) # (lit through by day, so a puff against the sun stays cream)
	var np := 0; var ns := 0
	var lean := 0.5 + 0.25 * sin(t * 0.21) # (the breeze, out of the west)
	var cam := camera.global_position
	for f in mini(FIRES, fires.size()):
		var F: Dictionary = fires[f]
		for i in PUFFS:
			var k := fmod(t / 7.0 + i / float(PUFFS) + seeds[f * 9 + i] * 0.1, 1.0)
			var rise := k * 4.2
			var pp := Vector3(F.x + rise * lean * (0.8 + 0.4 * sin(i)) + sin(t * 0.9 + i * 2) * 0.12, F.y + F.top + rise, F.z + rise * 0.15 + cos(t * 0.7 + i) * 0.1)
			var s := (0.18 + k * 0.75) * (k / 0.1 if k < 0.1 else 1.0) * ((1.0 - k) / 0.2 if k > 0.8 else 1.0) * (0.6 if rain > 0.3 else 1.0)
			# (full face to the lens, pitched up to a camera looking down, so no puff is seen edge-on and in shade)
			var basis := Basis.from_euler(Vector3(-atan2(cam.y - pp.y, Vector2(cam.x - pp.x, cam.z - pp.z).length()), atan2(cam.x - pp.x, cam.z - pp.z), i * 1.3 + t * 0.2), EULER_ORDER_YXZ)
			puffs.set_instance_transform(np, Transform3D(basis.scaled_local(Vector3.ONE * s), pp)); np += 1
		if night > 0.35 and F.get("sparks", false):
			for i in SPARKS:
				var seed: float = seeds[f * 9 + (i % 9)] + i * 0.37
				var k := fmod(t / 1.6 + seed, 1.0)
				var pp := Vector3(F.x + sin(seed * 20.0 + k * 3.0) * 0.3 * k, F.y + 0.4 + k * 2.2, F.z + cos(seed * 17.0 + k * 2.0) * 0.3 * k)
				var sc := 1.0 if k < 0.85 else (1.0 - k) / 0.15
				sparks.set_instance_transform(ns, Transform3D(Basis.from_euler(Vector3(t * 6.0 + seed * 9.0, t * 4.0 + seed * 5.0, 0)).scaled(Vector3.ONE * sc), pp)); ns += 1
	puffs.visible_instance_count = np; sparks.visible_instance_count = ns
