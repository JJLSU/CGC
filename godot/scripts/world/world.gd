class_name World
extends Node3D
## world.js's World: streams 32 m chunks of the paper land in around the player (radius 3, nearest first, one a
## frame), drops the far ones, keeps a 360 m backdrop page under everything, and paints the wrapping 256 m region
## map (R region height, G path, B moisture, A crop field) and land-tint map the ground shader prints from.
## Props stand in one MultiMesh pool per kind and cut; each chunk's cards pop up on their hinges as it arrives.
## (Regrowth, gathering, wobble/fall and the occlusion ghosts live with the systems that use them.)

const VIEW_RADIUS := 3
var chunks := {}            ## "cx,cz" -> {cx, cz, terrain: MeshInstance3D}
var exclusions: Array = []  ## {x, z, r}: no props here
var colliders: Array = []
var time := 0.0
var ground_mat: Material
var ground: MeshInstance3D
var map_img: Image
var land_img: Image
var map_tex: ImageTexture
var land_tex: ImageTexture
var _map_dirty := false
var pools := {}
var destroyed := {}
var on_site_load: Callable    ## (site): a chunk's guarded site came into the world (the guardians spawn)
var on_site_unload: Callable
var animating := {}        ## res.key -> res (wobbling, falling or growing back)
var regrow := {}           ## res.key -> {at, res}
var regrow_clock := 0.0
var rain := 0.0            ## (rain doubles the regrowth pace)
var crop_grow := 1.0       ## (a rain barrel from the cooper: crops come on a quarter sooner)
var regrow_blocked: Callable   ## (res) -> true if something (a built piece) now stands there
var on_resource_gone: Callable ## (res, fell)
const CROPS := ["corn", "pumpkin", "apples", "berries", "stook"]
const CUTS := {"rock": 3, "bush": 3, "pine": 3, "flowers": 3}
const ROCK_MODELS := {"lodge": ["prop_beaverlodge", 1.15]}
const POOL_CAP := {"sang": 200, "silver": 200, "pearl": 300, "geode": 200, "amber": 200, "snag": 400, "lodge": 40, "birch": 1100, "signthicket": 120, "log": 500, "bale": 400, "stook": 700, "ore": 600, "quartz": 200, "clay": 900, "mushroom": 900, "hive": 300, "satchel": 60, "appletree": 500, "apples": 700, "cattail": 1500, "lilypad": 1400, "lilybloom": 400, "corn": 120, "pumpkin": 60, "signvein": 120, "signgrove": 160, "pine": 2200, "maple": 1800, "goldtree": 1500, "sagetree": 1100, "grass": 2600, "flowers": 2200, "bush": 1300, "rock": 1300, "hill": 1300, "peak": 900}
const OCCLUDERS := {"silver": [1.4, 0.6], "snag": [5.2, 0.6], "birch": [5.6, 1.0], "ore": [1.4, 0.6], "quartz": [1.4, 0.6], "pine": [5.7, 1.3], "maple": [5.9, 1.35], "goldtree": [5.9, 1.35], "appletree": [5.7, 1.35], "sagetree": [5.9, 1.35], "hill": [3.6, 4.2], "peak": [6.0, 4.8], "rock": [1.4, 0.6]}
var ducking := {}
var _seen_frame := 0
const TALL := {"snag": 1.25, "birch": 1.3, "pine": 1.35, "maple": 1.35, "goldtree": 1.35, "sagetree": 1.35, "appletree": 1.3}

static var inst: World
## Is the real ground built under (x, z)? Out past the built chunks there's only the flat sheet at 0, so a camp set on
## a hillside out there hangs in the air (the player saw one floating): the camps keep hidden till their ground is in.
static func ground_ready(x: float, z: float) -> bool:
	return inst == null or inst.chunks.has(key(floori(x / Terrain.CHUNK), floori(z / Terrain.CHUNK)))
## Mark a whole branch near_only: drawn only over the built ground (a rail line or train seen far off would hang in the air).
static func near_only(n: Node) -> void:
	if n is GeometryInstance3D: (n as GeometryInstance3D).set_instance_shader_parameter("near_only", 1.0)
	for c in n.get_children(): near_only(c)
## Show or hide a camp's pieces and people together.
static func show_all(nodes: Array, on: bool) -> void:
	for n in nodes: if n is Node3D and is_instance_valid(n) and (n as Node3D).visible != on: (n as Node3D).visible = on

func _ready() -> void:
	inst = self
	map_img = Image.create(Terrain.MAP, Terrain.MAP, false, Image.FORMAT_RGBA8)
	land_img = Image.create(Terrain.MAP, Terrain.MAP, false, Image.FORMAT_RGBA8)
	land_img.fill(Color8(204, 204, 204, 204))
	map_tex = ImageTexture.create_from_image(map_img)
	land_tex = ImageTexture.create_from_image(land_img)
	ground_mat = PaperMats.ground(map_tex, land_tex)
	var backdrop_mat := PaperMats.ground(map_tex, land_tex, true)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(360, 360)
	ground.mesh = pm; ground.material_override = backdrop_mat
	add_child(ground)

static func key(cx: int, cz: int) -> String: return "%d,%d" % [cx, cz]

func update(px: float, pz: float, dt: float) -> void:
	time += dt
	ground.position = Vector3(roundf(px), -0.05, roundf(pz))
	RenderingServer.global_shader_parameter_set("paper_ground_reach", Vector4(px, pz, (VIEW_RADIUS - 0.1) * Terrain.CHUNK, 0.0)) # (the near_only shapes stop where the built ground does)
	var pcx := floori(px / Terrain.CHUNK); var pcz := floori(pz / Terrain.CHUNK)
	var best := [1 << 30, 0, 0]
	for dz in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var d2 := dx * dx + dz * dz
			if d2 > VIEW_RADIUS * VIEW_RADIUS + 1: continue
			if not chunks.has(key(pcx + dx, pcz + dz)) and d2 < best[0]: best = [d2, pcx + dx, pcz + dz]
	if best[0] < (1 << 30) and not _building: _create_chunk_sliced(best[1], best[2]) # (one chunk at a time, spread over frames)
	var far := pow(VIEW_RADIUS + 1.5, 2)
	for k in chunks.keys():
		var ch: Dictionary = chunks[k]
		var ddx: int = ch.cx - pcx; var ddz: int = ch.cz - pcz
		if ddx * ddx + ddz * ddz > far: dispose_chunk(k)
	_regrow(px, pz, dt)
	_rise_chunks()
	_update_animations(dt)
	if _map_dirty:
		map_tex.update(map_img); land_tex.update(land_img); _map_dirty = false

## Build every chunk within the view radius right away (on load, and for screenshots).
func fill_around(px: float, pz: float) -> void:
	var pcx := floori(px / Terrain.CHUNK); var pcz := floori(pz / Terrain.CHUNK)
	for dz in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			if dx * dx + dz * dz <= VIEW_RADIUS * VIEW_RADIUS + 1 and not chunks.has(key(pcx + dx, pcz + dz)): create_chunk(pcx + dx, pcz + dz)
	map_tex.update(map_img); land_tex.update(land_img); _map_dirty = false

## Every prop pool built ahead, one a frame, after startup: the first tree of a new kind otherwise builds its
## MultiMesh and material on the spot (50-130 ms the first time a chunk brings in several).
func prewarm() -> void:
	var names := []
	for t in Res.TYPES:
		names.append(t)
		for c in range(1, CUTS.get(t, 1)): names.append("%s~%d" % [t, c])
	for n in names:
		if not is_inside_tree(): return # (the scene gave way: a new game)
		if not pools.has(n): pool_for(n); await get_tree().process_frame

## Build a chunk a slice at a time, ~4 ms of work a frame (the heights, then the region map row by row, then the
## props): walking into new country costs a few frames of a little work each, not one long stall.
const SLICE_US := 4000
var _building := false
var last_finish_ms := 0.0  ## (the props-and-instancing end of the last chunk built: for the profiler)
func _create_chunk_sliced(cx: int, cz: int) -> void:
	_building = true
	var t0 := Time.get_ticks_usec()
	var job := Terrain.chunk_job(cx, cz)
	while not Terrain.chunk_step(job, 2):
		if Time.get_ticks_usec() - t0 > SLICE_US:
			if not is_inside_tree(): return
			await get_tree().process_frame; t0 = Time.get_ticks_usec()
	for j in Terrain.CHUNK:
		_paint_row(cx, cz, j)
		if Time.get_ticks_usec() - t0 > SLICE_US:
			if not is_inside_tree(): return
			await get_tree().process_frame; t0 = Time.get_ticks_usec()
	_map_dirty = true
	# the props' layout too, spread over frames (step 28: a chunk not laid out before cost 17-50 ms here in one go)
	var placed: Dictionary = await Props.place_sliced(cx, cz, exclusions, SLICE_US)
	if not is_inside_tree(): return
	var tc := Time.get_ticks_usec()
	if not chunks.has(key(cx, cz)): create_chunk(cx, cz, job.mesh, true, placed)
	last_finish_ms = (Time.get_ticks_usec() - tc) / 1000.0
	_building = false

func create_chunk(cx: int, cz: int, mesh: Mesh = null, painted := false, pre_placed = null) -> Dictionary:
	var t := MeshInstance3D.new()
	t.mesh = mesh if mesh != null else Terrain.build_chunk_mesh(cx, cz)
	t.material_override = ground_mat
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(t)
	if not painted: paint_region_map(cx, cz)
	var placed: Dictionary = pre_placed if pre_placed != null else Props.place(cx, cz, exclusions)
	var resources := []
	var rng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 13))
	var counters := {}
	for r in placed.list:
		var type: String = r.type
		var cut: int = absi(floori(r.x * 0.73 + r.z * 1.31)) % CUTS[type] if CUTS.has(type) else 0
		var pool = pool_for(type + "~" + str(cut) if cut else type)
		var i: int = counters.get(type, 0) + 1
		counters[type] = i
		var v: float = r.get("tone", 1.0) * (0.95 + rng.next() * 0.1)
		var jitter := rng.next()
		if pool == null: continue
		var rkey := "%d,%d,%s,%d" % [cx, cz, type, i - 1]
		var res: Dictionary = r.duplicate()
		res.merge({"index": -1, "pool": pool, "key": rkey, "alive": not destroyed.has(rkey), "anim": null, "rise": 0.0, "hp": int(Res.TYPES[type].get("hp", 1)),
			"delay": 0.02 * Vector2(r.lx - Terrain.CHUNK / 2.0, r.lz - Terrain.CHUNK / 2.0).length() + jitter * 0.15})
		var slot := _alloc(pool, res)
		if slot < 0: continue
		res.index = slot
		write_matrix(res)
		var tint := Color(v * r.tint[0], v * r.tint[1], v * r.tint[2]) if r.has("tint") else Color(v, v, v)
		(pool.mm as MultiMesh).set_instance_color(slot, tint)
		resources.append(res)
	colliders.append_array(placed.colliders)
	var ch := {"cx": cx, "cz": cz, "terrain": t, "resources": resources, "colliders": placed.colliders, "born": time, "settled": false, "sites": placed.sites}
	for r in resources: r.chunk = ch
	chunks[key(cx, cz)] = ch
	if on_site_load.is_valid():
		for site in ch.sites: on_site_load.call(site)
	return ch

func dispose_chunk(k: String) -> void:
	var ch: Dictionary = chunks[k]
	Terrain.forget_chunk(ch.cx, ch.cz)
	(ch.terrain as Node).queue_free()
	for r in ch.resources:
		animating.erase(r.key); ducking.erase(r.key)
		_release(r.pool, r.index)
	for c in ch.colliders: colliders.erase(c)
	if on_site_unload.is_valid():
		for site in chunks[k].sites: on_site_unload.call(site)
	chunks.erase(k)

# ------------------------------------------------------------------ prop pools (one MultiMesh per kind and cut)
func pool_for(type: String):
	if pools.has(type): return pools[type]
	var kind = PropKinds.get_kind(type)
	if kind == null:
		pools[type] = null
		return null
	var base := type.split("~")[0]
	var cap := ceili(POOL_CAP.get(base, 600) / (2.0 if CUTS.has(base) else 1.0))
	var mesh: Mesh = kind.mesh
	var mat: Material = kind.material
	if ROCK_MODELS.has(type): # (the beaver lodge from the reference art, as wide as the card outcrop it replaces)
		var m = _model_mesh(ROCK_MODELS[type][0], mesh.get_aabb().size.x * ROCK_MODELS[type][1])
		if m != null:
			mesh = m
			mat = null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = OCCLUDERS.has(base)
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat and OCCLUDERS.has(base):
		mat = mat.duplicate()
		(mat as ShaderMaterial).set_shader_parameter("ghosts", true)
	if mat: mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if base in ["grass", "flowers", "lilypad", "lilybloom"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)) # (instances span the whole view)
	add_child(mmi)
	var pool := {"mm": mm, "node": mmi, "cap": cap, "count": 0, "owners": []}
	pool.owners.resize(cap)
	pools[type] = pool
	return pool

func _model_mesh(name: String, width: float):
	var scene: PackedScene = load("res://assets/models/props/%s.glb" % name)
	if scene == null: return null
	var root := scene.instantiate()
	PaperMats.paperize(root)
	var meshes := PaperMats._meshes(root)
	if meshes.is_empty():
		root.free()
		return null
	var mi: MeshInstance3D = meshes[0]
	var src := mi.mesh
	var bb := src.get_aabb()
	var k := width / bb.size.x
	var xf := Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -Vector3(bb.position.x + bb.size.x * 0.5, bb.position.y, bb.position.z + bb.size.z * 0.5))
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in v.size(): v[i] = xf * v[i]
		arr[Mesh.ARRAY_VERTEX] = v
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(s, mi.get_active_material(s))
	root.free()
	return out

func _alloc(pool: Dictionary, res: Dictionary) -> int:
	if pool.count >= pool.cap: return -1
	var slot: int = pool.count
	pool.count += 1
	pool.owners[slot] = res
	(pool.mm as MultiMesh).visible_instance_count = pool.count
	return slot

## Free a slot by moving the last live instance into it (keeps the range packed).
func _release(pool: Dictionary, slot: int) -> void:
	var mm: MultiMesh = pool.mm
	var last: int = pool.count - 1
	if slot != last:
		mm.set_instance_transform(slot, mm.get_instance_transform(last))
		mm.set_instance_color(slot, mm.get_instance_color(last))
		var moved: Dictionary = pool.owners[last]
		pool.owners[slot] = moved
		moved.index = slot
	pool.owners[last] = null
	pool.count = last
	mm.visible_instance_count = last

## A card's instance transform: turned to its yaw, hinged up from lying folded back about its base line (rise 0..1,
## with its lean), tipped by a wobble or a fall, scaled (trees taller than wide).
func write_matrix(res: Dictionary) -> void:
	var mm: MultiMesh = res.pool.mm
	if not res.alive and not (res.anim != null and res.anim.kind == "fall"):
		mm.set_instance_transform(res.index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		return
	var lies_flat: bool = res.type in ["lilypad", "lilybloom"]
	var fold: float = 0.0 if lies_flat else (1.0 - res.rise) * (-PI / 2.0) + res.lean
	var q := Basis(Vector3.UP, res.rot) * Basis(Vector3.RIGHT, fold)
	if res.anim != null and res.anim.kind != "grow":
		var a: Dictionary = res.anim
		var angle: float = sin(a.t * 38.0) * 0.09 * (1.0 - a.t / a.dur) if a.kind == "wobble" else pow(minf(1.0, a.t / a.dur), 2.2) * (PI / 2.0 - 0.05)
		# (three's setFromAxisAngle turns right-handed about the axis, as Basis does)
		q = Basis(a.axis, angle) * q
	var s: Vector3 = Vector3.ONE * float(res.scale)
	s.y *= TALL.get(res.type, 1.0)
	mm.set_instance_transform(res.index, Transform3D(q * Basis.from_scale(s), Vector3(res.x, res.y, res.z)))
	if mm.use_custom_data: mm.set_instance_custom_data(res.index, Color(res.get("fade", 0.0), 0, 0, 0))

## The pop-up: each chunk's cards rotate up about their folds from lying flat, staggered, with overshoot.
func _rise_chunks() -> void:
	for ch in chunks.values():
		if ch.settled: continue
		var t: float = time - ch.born
		var done := true
		for r in ch.resources:
			var local: float = t - r.delay
			r.rise = Props.spring_rise(local)
			if local < 1.3: done = false
			write_matrix(r)
		if done:
			ch.settled = true
			for r in ch.resources:
				r.rise = 1.0
				write_matrix(r)

## Work a prop: a wobble while it holds, else it's gone (marked destroyed, set to grow back) and trees fall over,
## away from you. Returns {destroyed, amount, item}.
func hit(res: Dictionary, from_x: float, from_z: float, damage := 1) -> Dictionary:
	var def: Dictionary = Res.TYPES[res.type]
	if res.anim != null and res.anim.kind == "grow": res.rise = 1.0
	res.hp = maxi(0, res.hp - damage)
	var dx: float = res.x - from_x; var dz: float = res.z - from_z
	var length := sqrt(dx * dx + dz * dz)
	if length == 0.0: length = 1.0
	var axis := Vector3(dz / length, 0, -dx / length)
	if res.hp > 0:
		res.anim = {"kind": "wobble", "t": 0.0, "dur": 0.35, "axis": axis}
		animating[res.key] = res
		return {"destroyed": false}
	res.alive = false
	destroyed[res.key] = true
	if Res.REGROW.has(res.type):
		regrow[res.key] = {"at": time + Res.REGROW[res.type] * (0.85 + randf() * 0.3) * (crop_grow if res.type in CROPS else 1.0), "res": res}
	var amount: int = def.loot[0] + randi() % (def.loot[1] - def.loot[0] + 1)
	if def.get("falls", false):
		res.anim = {"kind": "fall", "t": 0.0, "dur": 0.9, "axis": axis}
		animating[res.key] = res
	else:
		res.anim = null
		animating.erase(res.key)
		write_matrix(res)
		if on_resource_gone.is_valid(): on_resource_gone.call(res, false)
	return {"destroyed": true, "amount": amount, "item": def.item}

func _update_animations(dt: float) -> void:
	for k in animating.keys():
		var res: Dictionary = animating[k]
		var a = res.anim
		if a == null:
			animating.erase(k); continue
		a.t += dt
		if a.kind == "grow": res.rise = 1.0 if a.t >= a.dur else Props.spring_rise(a.t)
		if a.t >= a.dur:
			res.anim = null
			animating.erase(k)
			if a.kind == "fall" and on_resource_gone.is_valid(): on_resource_gone.call(res, true)
		write_matrix(res)

## Regrowth: once a second, pop gathered props back up (never under the farmer's feet, nor under a building).
func _regrow(px: float, pz: float, dt: float) -> void:
	regrow_clock += dt
	if regrow_clock <= 1.0 or regrow.is_empty(): return
	var boost := regrow_clock * rain
	regrow_clock = 0.0
	for k in regrow.keys():
		var g: Dictionary = regrow[k]
		g.at -= boost
		if time < g.at: continue
		var r: Dictionary = g.res
		var loaded = chunks.get(key(floori(r.x / Terrain.CHUNK), floori(r.z / Terrain.CHUNK)))
		if loaded != null and r.get("chunk") != loaded:
			for q in loaded.resources:
				if q.key == k: r = q; break
		var blocked: bool = regrow_blocked.is_valid() and regrow_blocked.call(r)
		if loaded != null and r.get("chunk") == loaded:
			if (r.x - px) * (r.x - px) + (r.z - pz) * (r.z - pz) < 6.25 or blocked: g.at = time + 20.0; continue
			r.alive = true; r.hp = int(Res.TYPES[r.type].get("hp", 1)); r.rise = 0.0
			r.anim = {"kind": "grow", "t": 0.0, "dur": 1.2}
			animating[r.key] = r
		elif blocked: g.at = time + 20.0; continue
		destroyed.erase(k)
		regrow.erase(k)

## Tall cards between the camera and the farmer dissolve to a faint ghost (and fill back in once out of the way).
func update_occlusion(cam: Vector3, target: Vector3, dt: float) -> void:
	var tx := target.x; var tz := target.z; var ty := target.y + 1.0
	var sx := cam.x - tx; var sz := cam.z - tz
	var length := sqrt(sx * sx + sz * sz)
	_seen_frame += 1
	var seen := _seen_frame
	if length > 0.5:
		var dir_x := sx / length; var dir_z := sz / length
		var min_x := minf(tx, cam.x) - 3.0; var max_x := maxf(tx, cam.x) + 3.0
		var min_z := minf(tz, cam.z) - 3.0; var max_z := maxf(tz, cam.z) + 3.0
		for cx in range(floori(min_x / Terrain.CHUNK), floori(max_x / Terrain.CHUNK) + 1):
			for cz in range(floori(min_z / Terrain.CHUNK), floori(max_z / Terrain.CHUNK) + 1):
				var ch = chunks.get(key(cx, cz))
				if ch == null: continue
				for r in ch.resources:
					var occ = OCCLUDERS.get(r.type)
					if occ == null or not r.alive or r.rise < 0.99 or r.x < min_x or r.x > max_x or r.z < min_z or r.z > max_z: continue
					var along: float = (r.x - tx) * dir_x + (r.z - tz) * dir_z
					if along < 0.6 or along > length + 1.0: continue
					var ox: float = tx + dir_x * along - r.x; var oz: float = tz + dir_z * along - r.z
					var rad: float = occ[1] * r.scale + 0.5
					if ox * ox + oz * oz > rad * rad: continue
					var line_y := ty + (cam.y - ty) * minf(1.0, along / length)
					if r.y + occ[0] * r.scale < line_y: continue
					r.duck_seen = seen
					ducking[r.key] = r
	for k in ducking.keys():
		var r: Dictionary = ducking[k]
		var want := 0.82 if r.get("duck_seen", -1) == seen else 0.0
		var f: float = r.get("fade", 0.0)
		r.fade = minf(want, f + dt * 5.0) if want > f else maxf(0.0, f - dt * 2.5)
		if want == 0.0 and r.fade <= 0.0: ducking.erase(k)
		if r.alive: write_matrix(r)

## Every living, workable prop within range of (x, z) (padding each by its own radius), from the 3x3 chunks round it.
func resources_near(x: float, z: float, rng: float) -> Array:
	var out := []
	var cx := floori(x / Terrain.CHUNK); var cz := floori(z / Terrain.CHUNK)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var ch = chunks.get(key(cx + dx, cz + dz))
			if ch == null: continue
			for r in ch.resources:
				var def: Dictionary = Res.TYPES[r.type]
				if not r.alive or def.get("decor", false): continue
				var rr: float = rng + float(def.radius) * r.scale
				var ddx: float = r.x - x; var ddz: float = r.z - z
				if ddx * ddx + ddz * ddz < rr * rr: out.append(r)
	return out

func paint_region_map(cx: int, cz: int) -> void:
	for j in Terrain.CHUNK: _paint_row(cx, cz, j)
	_map_dirty = true

func _paint_row(cx: int, cz: int, j: int) -> void:
	var M := Terrain.MAP
	for i in Terrain.CHUNK:
		var x := cx * Terrain.CHUNK + i; var z := cz * Terrain.CHUNK + j
		var tx := posmod(x, M); var tz := posmod(z, M)
		var r := clampf((Terrain.coarse_region(cx, cz, i, j) + 10.0) / 60.0, 0.0, 1.0)
		var g := clampf(Terrain.path_field(x, z) / 0.25, 0.0, 1.0)
		var b := clampf(Terrain.moisture(x, z) * 0.5 + 0.5, 0.0, 1.0)
		var a := clampf(Terrain.field_mask(x, z), 0.0, 1.0)
		map_img.set_pixel(tx, tz, Color(floorf(r * 255.0) / 255.0, floorf(g * 255.0) / 255.0, floorf(b * 255.0) / 255.0, floorf(a * 255.0) / 255.0))
		if (i & 1) == 0 and (j & 1) == 0: # (the tint changes slowly: sampled every 2 m, filling the 2x2 block)
			var t := Terrain.land_tint(x, z)
			var c := Color(minf(1.0, floorf(minf(255.0, t.x * 204.0)) / 255.0), minf(1.0, floorf(minf(255.0, t.y * 204.0)) / 255.0), minf(1.0, floorf(minf(255.0, t.z * 204.0)) / 255.0), 204.0 / 255.0)
			for dj in 2:
				for di in 2: land_img.set_pixel(posmod(x + di, M), posmod(z + dj, M), c)
