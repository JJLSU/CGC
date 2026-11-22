class_name Fishing
extends Node3D
## fishing.js: fishing from the bank. With the willow pole, face the water and click to cast; a red-and-cream paper
## bobber rides the water on a sagging line; when it ducks under (a bite), click quickly to reel in a fish, which
## leaps to your hands. Now and then a fish jumps in a pond near you, and for half a minute they bite sooner there.
## After dark a bite may be Old Whiskers. One bobber, one pole, a 12-point twine ribbon, three ripple rings.

const FISH := ["a whiskered catfish", "a speckled brook trout", "a pumpkinseed sunfish", "a bigmouth bass", "a fat yellow perch", "a bluegill no bigger than your hand"]
const N := 12
const NONE := {"engaged": false, "hint": ""}
const FISH_PTS := [[0.3, 0], [0.18, 0.08], [0, 0.1], [-0.18, 0.06], [-0.26, 0.1], [-0.3, 0.1], [-0.25, 0], [-0.3, -0.1], [-0.26, -0.1], [-0.18, -0.06], [0, -0.1], [0.18, -0.08]]

var state := "idle" # idle, cast, wait, bite
var t := 0.0
var timer := 0.0
var on_catch: Callable  ## (name, legend)
var on_bite: Callable
var on_cast: Callable
var on_miss: Callable
var on_jump: Callable
var target := Vector3.ZERO
var cast_at := Vector3.ZERO
var bobber := Node3D.new()
var pole: MeshInstance3D
var line := MeshInstance3D.new()
var line_mesh := ImmediateMesh.new()
var line_mat: StandardMaterial3D
var ripples: Array = []
var fish: MeshInstance3D
var jumper: MeshInstance3D
var leap := {"t": 9.0, "from": Vector3.ZERO, "to": Vector3.ZERO}
var jump := {"t": 9.0, "next": 6.0 + randf() * 8.0, "from": Vector3.ZERO, "to": Vector3.ZERO}
var hot: Array = []
var clock := 0.0
var camera: Camera3D
var rain := 0.0
var night := 0.0
var legend_chance := 0.07

static func _cyl(rt: float, rb: float, h: float, y: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new(); cm.top_radius = rt; cm.bottom_radius = rb; cm.height = h; cm.radial_segments = 10; cm.rings = 1
	var m := MeshInstance3D.new(); m.mesh = cm; m.material_override = mat; m.position.y = y
	return m

func _init() -> void:
	var red := ModelBake.paper(0xc4402f); var cream := ModelBake.paper(0xf1e6cc); var dark := ModelBake.paper(0x5a3e2a)
	for m in [_cyl(0.11, 0.11, 0.1, 0.08, red), _cyl(0.11, 0.07, 0.08, -0.01, cream), _cyl(0.015, 0.015, 0.14, 0.19, dark)]: bobber.add_child(m)
	bobber.visible = false; add_child(bobber)
	var pm := CylinderMesh.new(); pm.top_radius = 0.018; pm.bottom_radius = 0.03; pm.height = 1.0; pm.radial_segments = 5; pm.rings = 1
	var st := SurfaceTool.new(); st.append_from(pm, 0, Transform3D(Basis(), Vector3(0, 0.5, 0)))
	pole = MeshInstance3D.new(); pole.mesh = st.commit(); pole.material_override = dark; pole.visible = false; add_child(pole)
	# the line: a thin twine ribbon, turned to face the camera
	line_mat = StandardMaterial3D.new(); line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.albedo_color = Color.hex(0x4a3828ff)
	line.mesh = line_mesh; line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; line.visible = false; add_child(line)
	# ripples: flat cream rings where the bobber lands or a fish tugs
	var rm := Wake.ring_mesh(0.8, 1.0, 28)
	for i in 3:
		var m := MeshInstance3D.new(); m.mesh = rm; m.material_override = Wake.flat_mat(Color.hex(0xf3ead6ff), 0.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.visible = false; add_child(m)
		ripples.append({"m": m, "t": 9.0})
	# the catch: a printed fish card that leaps from the water to the farmer; and the jumper in the ponds
	var fm := CardMesh.build(PackedVector2Array(ModelBake.pts(FISH_PTS)), 0.02)
	var fmat := PaperMats.card(load("res://assets/baked/wildlife/fish.png"), {"flip": true, "snow": 0.0})
	fish = MeshInstance3D.new(); fish.mesh = fm; fish.material_override = fmat; fish.scale = Vector3.ONE * 1.4; fish.visible = false; fish.rotation_order = EULER_ORDER_XYZ; add_child(fish)
	jumper = MeshInstance3D.new(); jumper.mesh = fm; jumper.material_override = fmat; jumper.scale = Vector3.ONE * 1.2; jumper.visible = false; jumper.rotation_order = EULER_ORDER_XYZ; add_child(jumper)

## Now and then a fish jumps in the water near the farmer.
func update_jumps(dt: float, player: Player) -> void:
	clock += dt
	var J := jump
	if J.t < 0.8:
		J.t += dt
		var k := minf(1.0, J.t / 0.8)
		var p: Vector3 = J.from.lerp(J.to, k); p.y += sin(k * PI) * 0.9; jumper.position = p
		jumper.rotation = Vector3(0, atan2(J.to.x - J.from.x, J.to.z - J.from.z) - PI / 2.0, cos(k * PI) * 1.2)
		if k >= 1.0: jumper.visible = false; ripple(J.to)
		return
	J.next -= dt
	if J.next > 0.0: return
	J.next = 9.0 + randf() * 16.0
	for tries in 10:
		var a := randf() * TAU; var d := 6.0 + randf() * 16.0
		var x := player.pos.x + cos(a) * d; var z := player.pos.z + sin(a) * d
		var b := a + (randf() - 0.5); var x2 := x + cos(b) * 1.3; var z2 := z + sin(b) * 1.3
		if not Terrain.is_water(x, z) or not Terrain.is_water(x2, z2): continue
		J.from = Vector3(x, Terrain.get_height(x, z) + 0.02, z); J.to = Vector3(x2, Terrain.get_height(x2, z2) + 0.02, z2)
		J.t = 0.0; jumper.visible = true; ripple(J.from)
		hot = hot.filter(func(h): return h.until > clock); hot.append({"x": x2, "z": z2, "until": clock + 30.0})
		if on_jump.is_valid(): on_jump.call()
		return

## Is this spot near where a fish jumped lately?
func hot_at(p: Vector3) -> bool:
	for h in hot: if h.until > clock and Vector2(h.x - p.x, h.z - p.z).length() < 3.5: return true
	return false

func ripple(at: Vector3) -> void:
	var r: Dictionary = ripples[0]
	for q in ripples: if q.t > r.t: r = q
	r.t = 0.0; r.m.position = at + Vector3(0, 0.03, 0); r.m.visible = true

## Ripples spread and fade; a caught fish arcs up into the farmer's hands.
func update_fx(dt: float, player: Player) -> void:
	for r in ripples:
		if r.t > 1.4: r.m.visible = false; continue
		r.t += dt
		var k: float = r.t / 1.4
		r.m.scale = Vector3.ONE * (0.15 + k * 0.9)
		(r.m.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - k)
	var L := leap
	if L.t < 0.8:
		L.t += dt
		var k := minf(1.0, L.t / 0.8)
		L.to = Vector3(player.pos.x, player.pos.y + 1.2, player.pos.z)
		var p: Vector3 = L.from.lerp(L.to, k); p.y += sin(k * PI) * 2.2; fish.position = p
		fish.rotation = Vector3(0, atan2(L.to.x - L.from.x, L.to.z - L.from.z) - PI / 2.0, cos(k * PI) * 1.1)
		fish.visible = k < 1.0

## Where a cast from here would land (water a few metres ahead, from dry land or a dock), or null.
func spot(player: Player, has_rod: bool) -> Variant:
	if not has_rod or (Terrain.is_water(player.pos.x, player.pos.z) and not player.on_deck): return null
	var f := player.forward()
	for d in [3.5, 5.0, 6.5]:
		var x: float = player.pos.x + f.x * d; var z: float = player.pos.z + f.z * d
		if Terrain.is_water(x, z) and Terrain.is_water(x + f.x, z + f.z): return Vector3(x, 0, z)
	return null

func stop() -> void:
	state = "idle"
	bobber.visible = false; pole.visible = false; line.visible = false

## Returns {engaged, hint}: engaged means the click belongs to fishing (no axe swing).
func update(dt: float, player: Player, input: GameInput, allowed: bool, at) -> Dictionary:
	update_fx(dt, player)
	update_jumps(dt, player)
	if not allowed:
		if state != "idle": stop()
		return NONE
	if state != "idle" and player.pos.distance_to(cast_at) > 1.2: stop(); return NONE
	t += dt
	var click := input.clicked
	if state == "idle":
		if at == null: return NONE
		if click:
			state = "cast"; timer = 0.55
			target = at; target.y = Terrain.get_height(at.x, at.z) + 0.02
			cast_at = player.pos
			bobber.visible = true; pole.visible = true; line.visible = true
			if on_cast.is_valid(): on_cast.call()
		else: return {"engaged": true, "hint": "[LMB] Cast your line"}
	elif click and state == "bite":
		# after dark there's a small chance the bite belongs to Old Whiskers, the catfish of the county's tallest tale
		var legend := night > 0.6 and randf() < legend_chance
		if on_catch.is_valid(): on_catch.call("OLD WHISKERS" if legend else FISH[randi() % FISH.size()], legend)
		fish.scale = Vector3.ONE * (4.2 if legend else 1.4)
		leap.t = 0.0; leap.from = bobber.position; ripple(target)
		stop()
		return {"engaged": true, "hint": ""}
	elif click:
		stop() # (reeled in too early)
		return {"engaged": true, "hint": ""}
	# rod tip: up and out in front of the farmer
	var f := player.forward()
	var hand := Vector3(player.pos.x + f.x * 0.35, player.pos.y + 1.15, player.pos.z + f.z * 0.35)
	var tip := Vector3(hand.x + f.x * 1.5, hand.y + 1.0, hand.z + f.z * 1.5)
	var up := (tip - hand).normalized()
	pole.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)).scaled(Vector3(1, hand.distance_to(tip), 1)), hand)
	# the bobber (fish bite sooner in the rain, and where one jumped)
	timer -= dt * (1.0 + rain) * (2.5 if hot_at(target) else 1.0) if state == "wait" else dt
	var b := bobber.position
	var hint := "Waiting for a nibble… (LMB reels in)"; var sag := 0.45
	if state == "cast":
		var k := 1.0 - maxf(0.0, timer) / 0.55
		b = tip.lerp(target, k); b.y += sin(k * PI) * 1.2
		if timer <= 0.0: state = "wait"; timer = 2.5 + randf() * 4.5; ripple(target)
		hint = ""; sag = 0.1
	elif state == "wait":
		b = target; b.y += sin(t * 2.6) * 0.025
		if timer <= 0.0:
			state = "bite"; timer = 1.1; ripple(target)
			if on_bite.is_valid(): on_bite.call()
	elif state == "bite":
		b = target; b.y -= 0.1 + absf(sin(t * 22.0)) * 0.05
		hint = "[LMB] A bite! Reel in!"; sag = 0.08
		if timer <= 0.0:
			state = "wait"; timer = 2.0 + randf() * 4.0
			if on_miss.is_valid(): on_miss.call()
	bobber.position = b
	# a sagging line from the tip to the bobber, a ribbon turned sideways to the view
	var P := []
	for i in N:
		var s := i / float(N - 1)
		P.append(Vector3(tip.x + (b.x - tip.x) * s, tip.y + (b.y + 0.25 - tip.y) * s - sin(s * PI) * sag, tip.z + (b.z - tip.z) * s))
	var cam := camera.global_position if camera else Vector3(0, 50, 0)
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, line_mat)
	for i in N:
		var d: Vector3 = (P[mini(N - 1, i + 1)] - P[maxi(0, i - 1)]).normalized()
		var w: Vector3 = (cam - P[i]).cross(d).normalized() * 0.014
		line_mesh.surface_add_vertex(P[i] + w); line_mesh.surface_add_vertex(P[i] - w)
	line_mesh.surface_end()
	return {"engaged": true, "hint": hint}
