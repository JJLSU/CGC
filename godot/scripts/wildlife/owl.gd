class_name Owl
extends Node3D
## owl.js: an owl keeps watch over the farm at night. After dusk it glides in to the corner post of the pen, turns
## its face to follow the farmer, hoots now and then, and flies off at dawn. In flight a printed-card puppet (body,
## face, two beating wings); perched, the barn owl from the reference art.

var perch: Vector3
var state := "away" # away, arriving, perched, leaving
var t := 0.0
var hoot_t := 6.0
var on_hoot: Callable
var g := Node3D.new()
var body: MeshInstance3D
var head := Node3D.new()
var face: MeshInstance3D
var wl: MeshInstance3D
var wr: MeshInstance3D
var model: Node3D
var from := Vector3.ZERO

static func _card(pts: PackedVector2Array, th: float, art: String) -> MeshInstance3D:
	return ModelBake.mesh_node(CardMesh.build(pts, th), PaperMats.card(load("res://assets/baked/wildlife/%s.png" % art), {"flip": true, "snow": 0.0}))

func _init(perch_at: Vector3) -> void:
	perch = perch_at
	var bp := PackedVector2Array(ModelBake.pts([[0.16, 0], [0.2, 0.18], [0.17, 0.36], [0.1, 0.44], [-0.1, 0.44], [-0.17, 0.36], [-0.2, 0.18], [-0.16, 0], [0, -0.06]]))
	var fp := PackedVector2Array()
	for i in 25:
		var a := PI + (i / 24.0) * PI
		fp.append(Vector2(cos(a) * 0.17, sin(a) * 0.14)) # (chin, left to right)
	for q in [[0.17, 0.04], [0.2, 0.2], [0.09, 0.11], [-0.09, 0.11], [-0.2, 0.2], [-0.17, 0.04]]: fp.append(Vector2(q[0], q[1])) # (the ear tufts)
	var wp := [[0, 0], [0.34, 0.06], [0.42, -0.04], [0.3, -0.12], [0.04, -0.1]]
	var wpr := []
	for q in wp: wpr.append([-q[0], q[1]])
	body = _card(bp, 0.04, "owl_body")
	head.position = Vector3(0, 0.52, 0.03); head.rotation_order = EULER_ORDER_XYZ
	face = _card(fp, 0.03, "owl_face"); head.add_child(face)
	wl = _card(PackedVector2Array(ModelBake.pts(wp)), 0.02, "owl_wing"); wl.position = Vector3(0.12, 0.32, -0.03)
	wr = _card(PackedVector2Array(ModelBake.pts(wpr)), 0.02, "owl_wing"); wr.position = Vector3(-0.12, 0.32, -0.03)
	for n in [body, head, wl, wr]: g.add_child(n)
	# perched: the barn owl from the reference art (about 0.75 m on her post, the group being 1.5x)
	model = ModelBake.still("res://assets/models/props/animal_owl.glb", 0.5, 1); model.visible = false; g.add_child(model)
	g.scale = Vector3.ONE * 1.5; g.visible = false
	add_child(g)

func _flap(on: bool) -> void: # wings beat in flight; perched, folded flat along the body's sides
	var a := sin(t * 16.0) * 0.9 if on else -1.25
	wl.rotation.z = a; wr.rotation.z = -a
	wl.position.z = -0.03 if on else 0.035; wr.position.z = wl.position.z

func update(dt: float, night: float, player: Player, camera: Camera3D) -> void:
	t += dt
	var want := night > 0.6
	if state == "away" and want:
		state = "arriving"; t = 0.0
		from = Vector3(perch.x + 30.0, perch.y + 14.0, perch.z - 25.0)
		g.visible = true
	elif state == "perched" and not want:
		state = "leaving"; t = 0.0
	if state == "arriving" or state == "leaving":
		var k := minf(1.0, t / 3.5); var e := (1.0 - (1.0 - k) ** 2) if state == "arriving" else k * k
		var p := from.lerp(perch, e) if state == "arriving" else perch.lerp(from, e)
		p.y += sin(k * PI) * 2.0; g.position = p
		_flap(true)
		if k >= 1.0:
			if state == "arriving": state = "perched"; t = 0.0
			else: state = "away"; g.visible = false
	elif state == "perched":
		g.position = perch
		_flap(false)
		# hoot now and then, with a little bob
		hoot_t -= dt
		if hoot_t <= 0.0:
			hoot_t = 9.0 + randf() * 14.0; t = 0.0
			if on_hoot.is_valid(): on_hoot.call()
		if t < 0.6: g.position.y += sin(t * 10.0) * 0.02
	var sit := state == "perched"
	model.visible = sit
	for p in [body, head, wl, wr]: p.visible = not sit
	if not g.visible: return
	# the body faces the camera; the face swivels toward the farmer (a card can only turn so far)
	var cam := camera.global_position
	g.rotation.y = atan2(cam.x - g.position.x, cam.z - g.position.z)
	var to_farmer := atan2(player.pos.x - g.position.x, player.pos.z - g.position.z) - g.rotation.y
	head.rotation.y = clampf(atan2(sin(to_farmer), cos(to_farmer)), -0.45, 0.45)
	head.rotation.z = sin(t * 0.7) * 0.12 # (the slow owl head-tilt)
