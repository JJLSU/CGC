class_name Crows
extends Node3D
## crows.js: every few minutes by day a little murder of paper crows flaps down into the kitchen garden and pecks at
## the crops. Walk at them (or fly a kite over) and they scatter cawing; leave them and they each carry off a corn ear
## or pumpkin (it grows back). A scarecrow near the garden keeps them away. Landed, each is the reference-art crow.

const N := 4

var state := "away" # away, coming, pecking, leaving
var timer := 90.0 + randf() * 60.0
var birds: Array = []
var on_land: Callable
var on_scatter: Callable
var on_steal: Callable
var on_caw: Callable

func _init() -> void:
	var C := func(p: Array, th: float) -> ArrayMesh: return CardMesh.build(PackedVector2Array(ModelBake.pts(p)), th)
	var body: ArrayMesh = C.call([[0.32, 0.16], [0.2, 0.22], [0.1, 0.3], [0.02, 0.26], [-0.16, 0.2], [-0.34, 0.24], [-0.36, 0.18], [-0.16, 0.08], [0.12, 0.08], [0.22, 0.12]], 0.025)
	var beak: ArrayMesh = C.call([[0.44, 0.2], [0.31, 0.23], [0.31, 0.17]], 0.02)
	# seen from above (the usual camera), a crow is its back: a flat card of body, folded wings and fanned tail
	var back := ModelBake.flat(ModelBake.pts([[0.4, 0], [0.3, 0.06], [0.14, 0.11], [-0.12, 0.1], [-0.3, 0.07], [-0.46, 0.12], [-0.5, 0], [-0.46, -0.12], [-0.3, -0.07], [-0.12, -0.1], [0.14, -0.11], [0.3, -0.06]]), 0.02, 0.26)
	# spread wings for flight, also flat: they flap about the body's long axis
	var spread := ModelBake.flat(ModelBake.pts([[0.12, 0], [-0.16, 0], [-0.3, 0.5], [-0.05, 0.42]]), 0.015)
	var ink := ModelBake.paper(0x2a2a36); var wing_mat := ModelBake.paper(0x3a3a4a); var beak_mat := ModelBake.paper(0x5a5048)
	for i in N:
		var g := Node3D.new(); g.rotation_order = EULER_ORDER_XYZ
		var b := ModelBake.mesh_node(body, ink); var bk := ModelBake.mesh_node(beak, beak_mat, false); var bc := ModelBake.mesh_node(back, ink)
		# wings: hinged at the shoulders, folded along the back when landed, spread and flapping in flight
		var wl := ModelBake.mesh_node(spread, wing_mat); var wr := ModelBake.mesh_node(spread, wing_mat)
		wl.rotation_order = EULER_ORDER_XYZ; wr.rotation_order = EULER_ORDER_XYZ
		wl.position = Vector3(0.02, 0.27, 0.06); wr.position = Vector3(0.02, 0.27, -0.06); wl.scale.z = -1.0
		for n in [b, bk, bc, wl, wr]: g.add_child(n)
		# landed: the crow from the reference art (a still model; the cards fly in and out)
		var model := ModelBake.still("res://assets/models/props/animal_crow.glb", 0.27, 2)
		model.rotation.y = PI / 2.0; model.visible = false; g.add_child(model)
		g.scale = Vector3.ONE * 2.1; g.visible = false
		add_child(g)
		birds.append({"model": model, "cards": [b, bk, bc, wl, wr], "g": g, "wl": wl, "wr": wr, "from": Vector3.ZERO, "to": Vector3.ZERO, "t": 0.0, "target": null, "phase": randf() * 6.0})

## Crops in the garden that are standing right now.
func crops(world: World) -> Array:
	var out := []
	for type in ["corn", "pumpkin"]:
		var pool = world.pools.get(type)
		if pool == null: continue
		for i in pool.count:
			var r = pool.owners[i]
			if r != null and r.alive: out.append(r)
	return out

## guarded(res) -> bool: a scarecrow minds it; kite: the kite's position while flying, or null.
func update(dt: float, world: World, player: Player, night: float, guarded: Callable, kite = null) -> void:
	timer -= dt
	var day := night < 0.4
	if state == "away":
		if timer > 0.0 or not day: return
		var cs := crops(world)
		timer = 120.0 + randf() * 120.0
		if cs.size() < 3 or guarded.call(cs[0]) or (kite != null and Vector2(kite.x - cs[0].x, kite.z - cs[0].z).length() < 30.0): return # (a scarecrow: they don't even try)
		state = "coming"
		var ang := randf() * TAU
		for i in N:
			var b: Dictionary = birds[i]
			b.target = cs[randi() % cs.size()]
			var sd := -0.65 if randf() < 0.5 else 0.65 # (on the soil between the rows, where they can be seen)
			var lx: float = b.target.x + (randf() - 0.5) * 0.5; var lz: float = b.target.z + sd
			b.to = Vector3(lx, Terrain.get_height(lx, lz), lz)
			b.from = Vector3(b.to.x + cos(ang + i * 0.3) * 45.0, b.to.y + 18.0, b.to.z + sin(ang + i * 0.3) * 45.0)
			b.t = -i * 0.4
			b.g.visible = true
		if on_caw.is_valid(): on_caw.call()
		return
	var near: Vector3 = birds[0].to
	var player_d := Vector2(player.pos.x - near.x, player.pos.z - near.z).length()
	var kite_d := Vector2(kite.x - near.x, kite.z - near.z).length() if kite != null else INF # (a kite over the garden spooks them)
	if (state == "coming" or state == "pecking") and (player_d < 7.0 or kite_d < 30.0): scatter()
	var all_done := true
	for b in birds:
		b.t += dt
		b.phase += dt * (2.0 if state == "pecking" else 18.0)
		var g: Node3D = b.g
		if state == "coming":
			var k := clampf(b.t / 4.0, 0.0, 1.0); var e := 1.0 - (1.0 - k) ** 2
			var p: Vector3 = b.from.lerp(b.to, e); p.y += sin(k * PI) * 3.0; g.position = p
			if k < 1.0: all_done = false
			_flap(b, k < 0.92)
		elif state == "pecking":
			g.position = b.to
			g.rotation.z = maxf(0.0, sin(b.phase * 2.5)) * 0.5 # (peck)
			_flap(b, false)
			if b.t < 9.0: all_done = false
		elif state == "leaving":
			var k := clampf(b.t / 3.0, 0.0, 1.0)
			var p: Vector3 = b.to.lerp(b.from, k * k); p.y += sin(k * PI) * 2.0; g.position = p
			g.rotation.z = 0.0
			_flap(b, true)
			if k < 1.0: all_done = false
			else: g.visible = false
		# face along the flight (or toward the crop)
		var dv: Vector3 = (b.from - b.to) if state == "leaving" else (b.to - b.from)
		g.rotation.y = atan2(-dv.z, dv.x)
	if state == "coming" and all_done:
		state = "pecking"
		for b in birds: b.t = randf() * 2.0
		if on_land.is_valid(): on_land.call()
	elif state == "pecking" and all_done:
		# they each make off with what they were pecking at
		var taken := {}
		for b in birds: if b.target != null and b.target.alive: taken[b.target.key] = b.target
		for r in taken.values(): if on_steal.is_valid(): on_steal.call(r)
		leave()
	elif state == "leaving" and all_done: state = "away"

func _flap(b: Dictionary, flying: bool) -> void:
	b.model.visible = not flying
	for p in b.cards: p.visible = flying
	if flying: # spread and beating
		var a := sin(b.phase) * 0.7
		b.wl.rotation = Vector3(-a, 0, 0); b.wr.rotation = Vector3(a, 0, 0)
	else: # folded down along the back, swept back over the tail
		b.wl.rotation = Vector3(0.15, -1.15, 0); b.wr.rotation = Vector3(-0.15, 1.15, 0)

func scatter() -> void:
	if on_scatter.is_valid(): on_scatter.call()
	leave()

func leave() -> void:
	state = "leaving"
	for b in birds: b.to = b.g.position; b.t = -randf() * 0.3
