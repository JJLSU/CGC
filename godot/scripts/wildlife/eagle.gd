class_name Eagle
extends Node3D
## eagle.js: a bald eagle over the high country. By day, with highland or peak within reach of the farmer, it soars in
## wide slow circles high over it, banked into the turn, its shadow sweeping the hillside; now and then three lazy
## wingbeats. Flat cards built to read from above: broad fingered wings, white head, yellow beak, white tail fan.

var g := Node3D.new()
var wl: MeshInstance3D
var wr: MeshInstance3D
var center := Vector3.ZERO
var has := false
var a := 0.0
var t := 0.0
var scan_t := 0.0
var flap_t := 8.0

func _m(mesh: Mesh, hex: int, shadow := false) -> MeshInstance3D:
	var x := ModelBake.mesh_node(mesh, ModelBake.paper(hex), shadow); g.add_child(x); return x

func _init() -> void:
	var F := func(p: Array, th := 0.02) -> ArrayMesh: return ModelBake.flat(ModelBake.pts(p), th)
	_m(F.call([[0.36, 0], [0.24, 0.12], [-0.1, 0.13], [-0.36, 0.08], [-0.36, -0.08], [-0.1, -0.13], [0.24, -0.12]]), 0x4a3424, true) # body
	_m(F.call([[0.62, 0], [0.56, 0.08], [0.4, 0.11], [0.3, 0.08], [0.3, -0.08], [0.4, -0.11], [0.56, -0.08]], 0.03), 0xf3ead6).position.y = 0.01 # white head
	_m(F.call([[0.72, 0], [0.62, 0.035], [0.6, -0.035]], 0.035), 0xe0a832).position.y = 0.012 # yellow beak
	_m(F.call([[-0.34, 0.08], [-0.66, 0.16], [-0.7, 0.05], [-0.72, -0.05], [-0.66, -0.16], [-0.34, -0.08]]), 0xf3ead6).position.y = 0.005 # white tail fan
	# broad wings with fingered primaries, hinged at the shoulders
	var wing: ArrayMesh = F.call([[0.16, 0], [-0.16, 0], [-0.28, 0.6], [-0.2, 1.2], [-0.04, 1.4], [0.02, 1.3], [0.08, 1.38], [0.12, 1.26], [0.18, 1.3], [0.2, 0.9]], 0.018)
	wl = _m(wing, 0x3e2c1e, true); wr = _m(wing, 0x3e2c1e, true)
	wl.position.z = 0.1; wr.position.z = -0.1; wr.scale.z = -1.0
	g.scale = Vector3.ONE * 2.4; g.visible = false
	add_child(g)

func update(dt: float, focus: Vector3, night: float) -> void:
	# find high ground to circle over, now and then: the nearest highland or peak within ~70 m of the farmer
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 12.0; has = false
		var bd := INF
		for k in 24:
			var an := (k / 24.0) * TAU; var d := 25.0 + (k % 3) * 20.0
			var x := focus.x + cos(an) * d; var z := focus.z + sin(an) * d
			var reg := Terrain.region_at(x, z)
			if (reg == "highland" or reg == "peak") and d < bd: bd = d; center = Vector3(x, Terrain.get_height(x, z), z); has = true
	g.visible = has and night < 0.35
	if not g.visible: return
	t += dt
	a += dt * 0.16 # (one slow round in about forty seconds)
	var R := 16.0
	var pos := Vector3(center.x + cos(a) * R, center.y + 26.0 + sin(t * 0.3) * 1.5, center.z + sin(a) * R)
	# nose along the circle, banked into the turn
	g.transform = Transform3D((Basis(Vector3.UP, -a - PI / 2.0) * Basis(Vector3.RIGHT, 0.3)).scaled_local(Vector3.ONE * 2.4), pos)
	# mostly gliding with wings a touch up; now and then three slow beats
	flap_t -= dt
	var flap := 0.08
	if flap_t < 0.0:
		flap = 0.08 + sin(-flap_t * 4.5) * 0.45
		if flap_t < -2.1: flap_t = 9.0 + randf() * 8.0
	wl.rotation.x = -flap; wr.rotation.x = flap
