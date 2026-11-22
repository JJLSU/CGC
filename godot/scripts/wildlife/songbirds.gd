class_name Songbirds
extends Node3D
## songbirds.js: while a bird feeder you've built holds seed, a cardinal, a bluebird and a chickadee (the reference-art
## models, two of each per feeder) come to it: they perch on the tray pecking with a bob, hop down to glean the grass
## beneath, flit off and back. Walk up close and they burst away, returning once you've stepped off. Three MultiMeshes
## (one per kind) for the two feeders nearest the farmer. (And the mended bakery's doorstep, pecking crumbs on the planks: main.gd adds it as a ground spot.)

const MODELS := ["animal_cardinal", "animal_bluebird", "animal_chickadee"]
const PER_KIND := 2
const FEEDERS := 2

var meshes: Array = []
var birds: Array = []
var feeders: Array = []
var on_flush: Callable

func _init() -> void:
	for i in MODELS.size():
		var b := ModelBake.baked("res://assets/models/props/%s.glb" % MODELS[i], 0.33)
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = b[0]; mm.instance_count = PER_KIND * FEEDERS; mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = b[1]
		mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
		add_child(mi); meshes.append(mm)
	for f in FEEDERS:
		for k in MODELS.size():
			for i in PER_KIND:
				birds.append({"f": f, "k": k, "slot": birds.size(), "pos": Vector3.ZERO, "from": Vector3.ZERO, "to": Vector3.ZERO, "state": "away", "t": randf() * 6.0, "dur": 1.0, "side": 1.0, "peck": randf() * 6.0, "leaving": false})

func spot(F: Dictionary) -> Vector3:
	if F.get("ground", false): # crumbs on a boardwalk: pecking about on the planks
		var a := randf() * TAU; var r := 0.3 + randf() * 1.3
		return Vector3(F.x + cos(a) * r, F.y + 0.16, F.z + sin(a) * r)
	if randf() < 0.6: # on the tray, or on the grass under it
		var a := randf() * TAU
		return Vector3(F.x + cos(a) * 0.22, F.y + 1.57, F.z + sin(a) * 0.16)
	var a := randf() * TAU; var r := 0.5 + randf()
	var x: float = F.x + cos(a) * r; var z: float = F.z + sin(a) * r
	return Vector3(x, Terrain.get_height(x, z) + 0.01, z)

func fly(b: Dictionary, to: Vector3) -> void:
	b.from = b.pos; b.to = to; b.state = "fly"; b.t = 0.0; b.dur = 0.5 + b.from.distance_to(to) * 0.08

func update(dt: float, feeder_list: Array, player: Player, camera: Camera3D) -> void:
	feeders = feeder_list.slice(0, FEEDERS)
	var flushed := false
	var counts := [0, 0, 0]
	var cam := camera.global_position
	for b in birds:
		if b.f >= feeders.size(): b.state = "away"; continue
		var F: Dictionary = feeders[b.f]
		var pd := Vector2(player.pos.x - F.x, player.pos.z - F.z).length()
		b.t += dt
		if b.state == "away":
			if pd > 6.0 and b.t > 2 + (b.slot % 5): b.pos = Vector3(F.x + (randf() - 0.5) * 30.0, F.y + 9.0, F.z + (randf() - 0.5) * 30.0); fly(b, spot(F))
			else: continue
		elif b.state == "perch":
			if pd < 3.2: flushed = true; fly(b, Vector3(F.x + (randf() - 0.5) * 40.0, F.y + 10.0, F.z + (randf() - 0.5) * 40.0)); b.leaving = true
			elif b.t > b.dur:
				if randf() < 0.15: fly(b, Vector3(F.x + (randf() - 0.5) * 16.0, F.y + 5.0, F.z + (randf() - 0.5) * 16.0)); b.leaving = true
				else: fly(b, spot(F))
		if b.state == "fly":
			var k := minf(1.0, b.t / b.dur)
			var p: Vector3 = b.from.lerp(b.to, k); p.y += sin(k * PI) * (1.5 if b.leaving else 0.6); b.pos = p
			b.side = 1.0 if b.to.x - b.from.x >= 0.0 else -1.0
			if k >= 1.0:
				if b.leaving: b.leaving = false; b.state = "away"; b.t = 0.0; continue
				b.state = "perch"; b.t = 0.0; b.dur = 2.0 + randf() * 5.0
		# facing the camera, nose the way it's going; a pecking bob perched, a flutter flying
		var yaw := atan2(cam.x - b.pos.x, cam.z - b.pos.z)
		var cam_right := Vector3(cos(yaw), 0, -sin(yaw))
		var d: Vector3 = (b.to - b.from) if b.state == "fly" else Vector3(b.side, 0, 0)
		var facing := 1.0 if d.dot(cam_right) >= 0.0 else -1.0
		var tilt: float = ((-0.5 if sin(b.t * 9.0 + b.peck) > 0.6 else 0.05) if b.state == "perch" else sin(b.t * 30.0) * 0.25)
		var basis := Basis.from_euler(Vector3(0, yaw, tilt * facing), EULER_ORDER_XYZ).scaled_local(Vector3(1.5 * facing, 1.5, 1.5))
		meshes[b.k].set_instance_transform(counts[b.k], Transform3D(basis, b.pos)); counts[b.k] += 1
	for i in meshes.size(): meshes[i].visible_instance_count = counts[i]
	if flushed and on_flush.is_valid(): on_flush.call()
