class_name Dandelions
extends Node3D
## dandelions.js: dandelion clocks in clumps about the meadows (never in the lanes), each a crossed printed card.
## Walk through a clump (or let Old Blue barrel through) and the clocks you brushed puff away: a dozen paper
## parachutes drift up and off on the west wind, and the clock is left a bald green nub till the next morning.
## Three MultiMeshes; the seeds only update while some are in the air.

const CELL := 13.0
const REACH := 3
const PER := 5
const MAXC := (REACH * 2 + 1) * (REACH * 2 + 1) * PER
const SEEDS := 120

var clocks := MultiMesh.new()
var bald := MultiMesh.new()
var seeds := MultiMesh.new()
var cell := ""
var list: Array = []
var blown := {}        ## key -> the day it was blown
var flying: Array = []
var day := 0
var dirty := true

static func _crossed(pts: PackedVector2Array) -> ArrayMesh:
	var m := CardMesh.build(pts, 0.012)
	var st := SurfaceTool.new()
	st.append_from(m, 0, Transform3D.IDENTITY); st.append_from(m, 0, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO))
	return st.commit()

func _init() -> void:
	var P: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/wildlife/dandelion.json"))
	var pv := func(a: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in a: out.append(Vector2(q[0], q[1]))
		return out
	var tex := func(k: String) -> Material: return PaperMats.card(load("res://assets/baked/wildlife/dandelion_%s.png" % k), {"flip": true})
	var aabb := AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	for e in [[clocks, _crossed(pv.call(P.full)), tex.call("clock"), MAXC], [bald, _crossed(pv.call(P.bald)), tex.call("bald"), MAXC], [seeds, CardMesh.build(pv.call(P.seed), 0.004), tex.call("seed"), SEEDS]]:
		var mm: MultiMesh = e[0]
		mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = e[1]; mm.instance_count = e[3]; mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = e[2]; mi.custom_aabb = aabb
		if mm == seeds: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

## Lay out the clumps round the farmer (re-done when he walks into another cell).
func place(cx: int, cz: int) -> void:
	list = []
	for dz in range(-REACH, REACH + 1):
		for dx in range(-REACH, REACH + 1):
			var gx := cx + dx; var gz := cz + dz
			var rng := PNoise.Mulberry32.new(((gx * 73856093) ^ (gz * 19349663)) & 0xFFFFFFFF)
			if rng.next() > 0.45: continue # (not every patch of meadow has them)
			var x0 := (gx + 0.15 + rng.next() * 0.7) * CELL; var z0 := (gz + 0.15 + rng.next() * 0.7) * CELL
			if Terrain.is_water(x0, z0) or Terrain.region_at(x0, z0) != "meadow" or Terrain.path_field(x0, z0) < 0.12: continue
			for i in PER:
				var a := rng.next() * TAU; var r := 0.25 + rng.next() * 0.75
				var x := x0 + cos(a) * r; var z := z0 + sin(a) * r
				list.append({"x": x, "z": z, "y": Terrain.get_height(x, z), "s": 1.25 + rng.next() * 0.45, "rot": rng.next() * PI, "key": "%d,%d,%d" % [gx, gz, i]})
	dirty = true

func _write() -> void:
	var a := 0; var b := 0
	for c in list:
		var gone: bool = blown.get(c.key, -1) == day
		var xf := Transform3D(Basis(Vector3.UP, c.rot).scaled(Vector3.ONE * c.s), Vector3(c.x, c.y, c.z))
		if gone: bald.set_instance_transform(b, xf); b += 1
		else: clocks.set_instance_transform(a, xf); a += 1
	clocks.visible_instance_count = a; bald.visible_instance_count = b
	dirty = false

## kickers: [{pos, speed}]. Returns how many clocks were blown this frame.
func update(dt: float, today: int, center: Vector3, kickers: Array) -> int:
	if today != day: day = today; dirty = true
	var cx := floori(center.x / CELL); var cz := floori(center.z / CELL)
	var c_key := "%d,%d" % [cx, cz]
	if c_key != cell: cell = c_key; place(cx, cz)
	var n_blown := 0
	for c in list:
		if blown.get(c.key, -1) == today: continue
		for k in kickers:
			if k.speed < 0.8 or absf(k.pos.x - c.x) > 0.7 or absf(k.pos.z - c.z) > 0.7: continue
			blown[c.key] = today; n_blown += 1; dirty = true
			# a puff of a dozen seeds, away from whoever brushed past and off downwind
			var ax: float = c.x - k.pos.x; var az: float = c.z - k.pos.z; var al := sqrt(ax * ax + az * az)
			if al == 0.0: al = 1.0
			for i in 12:
				if flying.size() >= SEEDS: break
				flying.append({"p": Vector3(c.x + (randf() - 0.5) * 0.2, c.y + 0.33 * c.s + (randf() - 0.5) * 0.15, c.z + (randf() - 0.5) * 0.2),
					"v": Vector3((ax / al) * 0.8 + (randf() - 0.5) * 0.9, 0.5 + randf() * 0.7, (az / al) * 0.8 + (randf() - 0.5) * 0.9),
					"rot": Vector3(randf() * 6.0, randf() * 6.0, 0), "spin": (randf() - 0.5) * 2.0, "t": 0.0, "life": 9.0 + randf() * 5.0, "ph": randf() * 6.0})
			break
	if dirty: _write()
	# the seeds rise on the warm air, sway, and ride the west wind off over the meadow
	if flying.size() or seeds.visible_instance_count:
		var n := 0
		for i in range(flying.size() - 1, -1, -1):
			var f: Dictionary = flying[i]
			f.t += dt
			if f.t > f.life: flying.remove_at(i); continue
			var v: Vector3 = f.v
			v.x += (1.1 - v.x) * dt * 0.6; v.z += (0.0 - v.z) * dt * 0.4; v.y += (0.25 - v.y) * dt * 0.5
			f.v = v
			var p: Vector3 = f.p + v * dt
			p.x += sin(f.t * 1.7 + f.ph) * 0.25 * dt; p.z += cos(f.t * 1.3 + f.ph) * 0.25 * dt
			f.p = p
			var r: Vector3 = f.rot; r.y += f.spin * dt; r.x = sin(f.t * 2.0 + f.ph) * 0.35; f.rot = r
			seeds.set_instance_transform(n, Transform3D(Basis.from_euler(r, EULER_ORDER_XYZ).scaled(Vector3.ONE * 1.6), p)); n += 1
		seeds.visible_instance_count = n
	return n_blown
