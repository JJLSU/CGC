class_name Wisp
extends Node3D
## wisp.js: the will-o'-the-wisp. On some nights a little paper lantern-light bobs at the edge of the dark and drifts
## ahead of the farmer toward the nearest unopened lost satchel, waits if you fall behind, and fades away over the
## satchel when you get there. Two small glowing card pairs.

var state := "idle"   ## idle · searching · leading · fading
var cool := 40.0
var target = null
var goal := Vector3.ZERO
var pos := Vector3.ZERO
var t := 0.0
var fade := 1.0
var search := {}
var on_appear: Callable
var mats: Array = []
var group := Node3D.new()

func _init() -> void:
	for spec in [[0.5, 18, 0xffc070, 0.25], [0.16, 14, 0xffe2a0, 0.9]]:
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color.hex((int(spec[2]) << 8) | 0xff); m.albedo_color.a = spec[3]; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.no_depth_test = false
		m.set_meta("a", spec[3]); mats.append(m)
		var disc := _disc(spec[0], spec[1])
		for ry in [0.0, PI / 2]:
			var mi := MeshInstance3D.new(); mi.mesh = disc; mi.material_override = m; mi.rotation.y = ry; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; group.add_child(mi)
	group.visible = false; add_child(group)

static func _disc(r: float, seg: int) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := i * TAU / seg; var a1 := (i + 1) * TAU / seg
		for v in [Vector3.ZERO, Vector3(cos(a1) * r, sin(a1) * r, 0), Vector3(cos(a0) * r, sin(a0) * r, 0)]: st.add_vertex(v)
	return st.commit()

## The lost satchel of a chunk, if it's unopened: {x, z, key} (guessed from its own seed; no layout).
static func satchels_for(world: World, cx: int, cz: int) -> Array:
	var q = Props.satchel_guess(cx, cz, world.exclusions)
	return [q] if q != null and not world.destroyed.has(q.key) else []

func update(dt: float, world: World, player: Player, camera: Camera3D, night: float) -> void:
	var p := player.pos
	t += dt
	if state == "idle":
		cool -= dt
		if night < 0.7 or cool > 0.0: return
		cool = 90.0 + randf() * 90.0
		# look around for a lost satchel a couple of chunks a frame
		state = "searching"; search = {"cx": floori(p.x / Terrain.CHUNK), "cz": floori(p.z / Terrain.CHUNK), "i": 0, "best": null, "bd": INF}
		return
	if state == "searching":
		var S := search; var n := 0
		while n < 9 and S.i < 81:
			var dx: int = (S.i % 9) - 4; var dz: int = floori(S.i / 9.0) - 4
			for q in satchels_for(world, S.cx + dx, S.cz + dz):
				var d := Vector2(q.x - p.x, q.z - p.z).length()
				if d > 20.0 and d < S.bd: S.bd = d; S.best = q
			n += 1; S.i += 1
		if S.i < 81: return
		state = "idle"; target = S.best
		if target == null or night < 0.7: return
		# (make sure: lay its chunk out, once, in case a guarded site's clearing took it)
		var real: Dictionary = Props.sites_for(floori(target.x / Terrain.CHUNK), floori(target.z / Terrain.CHUNK), world.exclusions)
		if not real.satchels.any(func(q): return q.key == target.key): target = null; return
		state = "leading"; fade = 0.0
		_place(p, 9.0); pos = goal; group.visible = true
		if on_appear.is_valid(): on_appear.call()
	if state == "leading":
		if night < 0.5 or world.destroyed.has(target.key): state = "fading"
		var to_t := Vector2(target.x - p.x, target.z - p.z).length()
		if to_t < 7.0:
			goal = Vector3(target.x, Terrain.get_height(target.x, target.z) + 1.4, target.z)
			if to_t < 3.0: state = "fading"
		elif Vector2(pos.x - p.x, pos.z - p.z).length() < 5.0: _place(p, 11.0) # (you caught up: it drifts on ahead)
		fade = minf(1.0, fade + dt * 0.8)
	elif state == "fading":
		fade -= dt * 0.6
		if fade <= 0.0: state = "idle"; group.visible = false; return
	# drift lazily toward its goal, bobbing and swaying
	pos = pos.lerp(goal, minf(1.0, dt * 0.9))
	group.position = Vector3(pos.x + sin(t * 1.3) * 0.3, pos.y + sin(t * 2.1) * 0.25, pos.z + cos(t * 1.1) * 0.3)
	var cp := camera.global_position
	group.rotation.y = atan2(cp.x - group.position.x, cp.z - group.position.z)
	var flicker := 0.85 + sin(t * 9) * 0.08 + sin(t * 23) * 0.05
	for m in mats: m.albedo_color.a = float(m.get_meta("a")) * fade * flicker

## Put the goal d metres from the farmer, toward the satchel.
func _place(p: Vector3, d: float) -> void:
	var dx: float = target.x - p.x; var dz: float = target.z - p.z; var L := maxf(0.0001, sqrt(dx * dx + dz * dz))
	var k := minf(d, L); var x := p.x + dx / L * k; var z := p.z + dz / L * k
	goal = Vector3(x, Terrain.get_height(x, z) + 1.5, z)
