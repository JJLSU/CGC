class_name Geese
extends Node3D
## geese.js: every few minutes by day a skein of seven paper Canada geese crosses the sky in a V, high over the farmer,
## honking now and then, their little shadows sliding across the land. Flat cards from above: a grey-brown back, a
## pale breast, the black neck and head with the white chinstrap, broad wings beating slowly, each a beat apart.

const N := 7
const HEIGHT := 16.0
const SPEED := 8.5

var birds: Array = []
var timer := 70.0 + randf() * 60.0
var flying := false
var lead := Vector3.ZERO
var dir := Vector3.ZERO
var side := Vector3.ZERO
var t := 0.0
var honk_t := 0.0
var seen := false
var on_honk: Callable
var on_first: Callable

func _init() -> void:
	var F := func(p: Array, th := 0.02) -> ArrayMesh: return ModelBake.flat(ModelBake.pts(p), th)
	var back: ArrayMesh = F.call([[0.3, 0], [0.2, 0.11], [0, 0.15], [-0.26, 0.12], [-0.42, 0.05], [-0.48, 0], [-0.42, -0.05], [-0.26, -0.12], [0, -0.15], [0.2, -0.11]])
	var breast: ArrayMesh = F.call([[0.28, 0], [0.18, 0.08], [0.02, 0.1], [0.02, -0.1], [0.18, -0.08]], 0.022)
	var tail: ArrayMesh = F.call([[-0.4, 0.06], [-0.56, 0.08], [-0.6, 0], [-0.56, -0.08], [-0.4, -0.06]], 0.024)
	var neck: ArrayMesh = F.call([[0.26, 0.04], [0.52, 0.04], [0.62, 0.06], [0.7, 0.03], [0.72, 0], [0.7, -0.03], [0.62, -0.06], [0.52, -0.04], [0.26, -0.04]], 0.024)
	var chin: ArrayMesh = F.call([[0.56, 0.035], [0.64, 0.045], [0.64, -0.045], [0.56, -0.035]], 0.026)
	var wing: ArrayMesh = F.call([[0.16, 0], [-0.14, 0], [-0.3, 0.5], [-0.12, 0.72], [0.08, 0.5]], 0.016)
	for i in N:
		var g := Node3D.new()
		for pm in [[back, 0x7d6c5a, true], [breast, 0xd8ccb4, false], [tail, 0x2a2420, false], [neck, 0x2a2420, false], [chin, 0xf3ead6, false]]:
			g.add_child(ModelBake.mesh_node(pm[0], ModelBake.paper(pm[1]), pm[2])) # (one little shadow per bird is plenty)
		var wl := ModelBake.mesh_node(wing, ModelBake.paper(0x6a5a4a), false); var wr := ModelBake.mesh_node(wing, ModelBake.paper(0x6a5a4a), false)
		wl.position.z = 0.12; wr.position.z = -0.12; wr.scale.z = -1.0
		g.add_child(wl); g.add_child(wr)
		g.scale = Vector3.ONE * 2.2; g.visible = false
		add_child(g)
		birds.append({"g": g, "wl": wl, "wr": wr, "phase": randf() * 6.0})

func update(dt: float, center: Vector3, night: float) -> void:
	if not flying:
		timer -= dt
		if timer > 0.0 or night > 0.35: return
		timer = 160.0 + randf() * 160.0
		# across the sky, more or less southward with the season, passing near overhead
		var an := PI / 2.0 + (randf() - 0.5) * 1.4
		dir = Vector3(cos(an), 0, sin(an)); side = Vector3(-dir.z, 0, dir.x)
		var off := (randf() - 0.5) * 16.0
		lead = Vector3(center.x - dir.x * 75.0 + side.x * off, 0, center.z - dir.z * 75.0 + side.z * off)
		flying = true; t = 0.0; honk_t = 1.5
		for b in birds: b.g.visible = true
	t += dt
	lead += dir * SPEED * dt
	var yaw := atan2(-dir.z, dir.x)
	var ground := Terrain.get_height(lead.x, lead.z)
	for i in N:
		var b: Dictionary = birds[i]
		# the V: the leader at the point, the rest trailing back along two arms
		var rank := ceili(i / 2.0); var arm := 0.0 if i == 0 else (1.0 if i % 2 else -1.0)
		var x := lead.x - dir.x * rank * 1.7 + side.x * arm * rank * 1.4
		var z := lead.z - dir.z * rank * 1.7 + side.z * arm * rank * 1.4
		b.g.position = Vector3(x, maxf(ground, 0.0) + HEIGHT + sin(t * 0.8 + i) * 0.25, z)
		b.g.rotation.y = yaw
		var flap := sin(t * 5.2 + b.phase) * 0.55
		b.wl.rotation.x = -flap; b.wr.rotation.x = flap
	honk_t -= dt
	if honk_t <= 0.0:
		honk_t = 2.5 + randf() * 3.0
		if on_honk.is_valid(): on_honk.call()
	if not seen and Vector2(lead.x - center.x, lead.z - center.z).length() < 30.0:
		seen = true
		if on_first.is_valid(): on_first.call()
	if t > 150.0 / SPEED + 4.0:
		flying = false
		for b in birds: b.g.visible = false
