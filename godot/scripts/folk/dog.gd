class_name Dog
extends Node3D
## dog.js: Old Blue, the farm hound. He potters about near the farmer (ambling to a spot, sniffing, sitting a while),
## lopes after you only once you're well off, barks when trouble's near, has a daily errand (off to dig and back with
## something in his mouth), plays fetch with a stick he brings you after a scratch, tracks the lost calf, chases
## tumbleweeds and ducks now and then, and settles beside the porch rocker when you sit in it.

var puppet: Puppet
var dir := Vector3(1, 0, 0)
var speed := 0.0
var side := 1.0
var bark_t := 0.0
var still := 0.0
var pat_t := 0.0
var errand = null
var errand_t := 120.0 + randf() * 120.0
var found_day := 0
var day := 0
var stick: MeshInstance3D
var steer := Steer.new(0.35)
var fetch = null
var potter = null
var potter_t := 0.0
var amble := false
var lead = null
var track_t := 6.0
var romp = null
var romp_t := 0.0
var rest_face = null
var on_bark: Callable
var on_dig: Callable
var on_find: Callable
var on_fetched: Callable
var on_track: Callable

var pos: Vector3:
	get: return puppet.group.position
	set(v): puppet.group.position = v

func _init(at: Vector3) -> void:
	puppet = Puppet.new("dog", 1.15)
	add_child(puppet.group)
	pos = Vector3(at.x + 1.5, Terrain.get_height(at.x + 1.5, at.z), at.z)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bm := BoxMesh.new(); bm.size = Vector3(0.7, 0.05, 0.05)
	var tw := BoxMesh.new(); tw.size = Vector3(0.18, 0.035, 0.035)
	st.append_from(bm, 0, Transform3D.IDENTITY)
	st.append_from(tw, 0, Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0.12, 0.05, 0)))
	stick = MeshInstance3D.new(); stick.mesh = st.commit(); stick.material_override = PaperMats.paper(Color.hex(0x7a5636ff))
	stick.visible = false; stick.top_level = true
	add_child(stick)

## After a scratch he sometimes trots up with a stick and drops it at your feet.
func offer_stick(player: Player) -> bool:
	if fetch != null or errand != null: return false
	var x := (player.pos.x + pos.x) / 2.0; var z := (player.pos.z + pos.z) / 2.0
	fetch = {"phase": "offered", "t": 0.0, "from": Vector3.ZERO, "to": Vector3(x, Terrain.get_height(x, z) + 0.03, z)}
	stick.visible = true; stick.global_position = fetch.to; stick.rotation = Vector3(0, randf() * 6.0, 0)
	return true

func stick_near(p: Vector3, r := 2.2) -> bool: return fetch != null and fetch.phase == "offered" and Vector2(p.x - fetch.to.x, p.z - fetch.to.z).length() < r

## Throw the stick: it sails off ahead of the farmer, end over end, and he's after it like a shot.
func throw_stick(player: Player) -> void:
	if fetch == null: return
	fetch.from = Vector3(player.pos.x, player.pos.y + 1.4, player.pos.z)
	var d := 11.0
	var fx := sin(player.facing); var fz := cos(player.facing)
	while d > 3.0 and Terrain.is_water(player.pos.x + fx * d, player.pos.z + fz * d): d -= 1.0
	var x := player.pos.x + fx * d; var z := player.pos.z + fz * d
	fetch.to = Vector3(x, Terrain.get_height(x, z) + 0.03, z)
	fetch.phase = "fly"; fetch.t = 0.0
	still = 0.0
	if on_bark.is_valid(): on_bark.call()

func start_errand(player: Player) -> bool:
	var a := randf() * TAU; var d := 6.0 + randf() * 3.0
	var x := player.pos.x + cos(a) * d; var z := player.pos.z + sin(a) * d
	if Terrain.is_water(x, z): return false
	errand = {"phase": "go", "spot": Vector3(x, Terrain.get_height(x, z), z), "t": 0.0}
	return true

func near(p: Vector3, r := 1.9) -> bool: return Vector2(p.x - pos.x, p.z - pos.z).length() < r
func pat() -> void:
	pat_t = 1.6; still = 0.0
	if on_bark.is_valid(): on_bark.call()

## opts: danger (bool), colliders, track (Vector3 or null), prey (Node3D or null), rocker ({seat, facing} or null)
func update(dt: float, player: Player, camera: Camera3D, opts := {}) -> void:
	var danger: bool = opts.get("danger", false)
	var colliders: Array = opts.get("colliders", [])
	var track = opts.get("track")
	var prey = opts.get("prey")
	var rocker = opts.get("rocker")
	var p := player.pos
	var to_p := Vector3(p.x - pos.x, 0, p.z - pos.z)
	var dist := to_p.length()
	if dist > 40.0: pos = Vector3(p.x - 2.0, Terrain.get_height(p.x - 2.0, p.z), p.z - 2.0); speed = 0.0
	var back := Vector3(player.vel.x, 0, player.vel.z)
	var moving := back.length() > 0.6
	back = back.normalized() if moving else Vector3.ZERO
	var goal := Vector3(p.x - back.x * 2.2 + back.z * 1.3 * side, 0, p.z - back.z * 2.2 - back.x * 1.3 * side)
	amble = false
	if fetch == null and errand == null and lead == null:
		potter_t -= dt
		var far := dist > 14.0
		var spot_far: bool = potter != null and Vector2(potter.x - p.x, potter.z - p.z).length() > 10.0
		if potter == null or potter_t <= 0.0 or (far and spot_far):
			potter_t = 6.0 + randf() * 10.0
			for i in 6:
				var a := randf() * TAU; var r := (2.5 + randf() * 3.0) if far else (3.0 + randf() * 6.5)
				var x := p.x + cos(a) * r; var z := p.z + sin(a) * r
				if not Terrain.is_water(x, z): potter = Vector3(x, 0, z); break
		if potter != null: goal = potter; moving = true; amble = not far
	# on the scent of the lost calf: a few bounds toward it, a bark, a look back
	track_t -= dt
	if track != null and fetch == null and errand == null and lead == null and track_t <= 0.0 and dist < 12.0:
		var tx: float = track.x - p.x; var tz: float = track.z - p.z; var td := sqrt(tx * tx + tz * tz)
		if td > 12.0:
			lead = {"to": Vector3(p.x + (tx / td) * 9.0, 0, p.z + (tz / td) * 9.0), "t": 0.0, "barked": false}; track_t = 11.0 + randf() * 5.0
			if on_track.is_valid(): on_track.call()
	if track == null: lead = null
	if lead != null:
		lead.t += dt
		if lead.t < 4.0:
			goal = lead.to; moving = true
			if Vector2(lead.to.x - pos.x, lead.to.z - pos.z).length() < 0.8 and not lead.barked:
				lead.barked = true; puppet.head.rotation.z = 0.35
				if on_bark.is_valid(): on_bark.call()
		else: lead = null
	# a tumbleweed (or the ducks) is too much for him, now and then
	romp_t -= dt
	if prey != null and is_instance_valid(prey) and fetch == null and errand == null and lead == null and romp == null and romp_t <= 0.0 and dist < 14.0 and Vector2(prey.global_position.x - pos.x, prey.global_position.z - pos.z).length() < 12.0:
		romp = {"t": 0.0, "prey": prey, "yip": false}; romp_t = 25.0 + randf() * 20.0; puppet.head.rotation.z = 0.35
		if on_bark.is_valid(): on_bark.call()
	if romp != null:
		romp.t += dt
		if romp.t < 5.0 and is_instance_valid(romp.prey) and romp.prey.is_inside_tree() and dist < 26.0:
			goal = Vector3(romp.prey.global_position.x - 0.9, 0, romp.prey.global_position.z); moving = true
			if romp.t > 2.2 and not romp.yip:
				romp.yip = true; puppet.head.rotation.z = 0.3
				if on_bark.is_valid(): on_bark.call()
		else: romp = null
	# you in the porch rocker: he settles at its side
	if rocker != null and fetch == null and errand == null and romp == null:
		var sd := Vector3(cos(rocker.facing), 0, -sin(rocker.facing))
		goal = Vector3(rocker.seat.x + sd.x * 1.3 + sin(rocker.facing) * 0.45, 0, rocker.seat.z + sd.z * 1.3 + cos(rocker.facing) * 0.45); moving = true; amble = true
		rest_face = rocker.facing if Vector2(goal.x - pos.x, goal.z - pos.z).length() < 0.9 else null
	else: rest_face = null
	if fetch != null:
		var F: Dictionary = fetch
		F.t += dt
		if F.phase == "offered":
			if F.t > 25.0: fetch = null; stick.visible = false
		elif F.phase == "fly":
			var k := minf(1.0, F.t / 0.9)
			var sp: Vector3 = F.from.lerp(F.to, k); sp.y += sin(k * PI) * 3.0
			stick.global_position = sp; stick.rotation.z = F.t * 14.0
			if k >= 1.0: stick.rotation = Vector3(0, stick.rotation.y, 0); stick.global_position = F.to
			goal = F.to; moving = true
			if k >= 1.0: F.phase = "chase"
		elif F.phase == "chase":
			goal = F.to; moving = true
			if Vector2(F.to.x - pos.x, F.to.z - pos.z).length() < 0.7: F.phase = "bring"; F.t = 0.0
		elif F.phase == "bring":
			goal = Vector3(p.x, 0, p.z); moving = true
			if dist < 1.8:
				var x := (p.x + pos.x) / 2.0; var z := (p.z + pos.z) / 2.0
				F.to = Vector3(x, Terrain.get_height(x, z) + 0.03, z); F.phase = "offered"; F.t = 0.0
				stick.global_position = F.to; stick.rotation = Vector3(0, randf() * 6.0, 0)
				pat_t = 1.2
				if on_fetched.is_valid(): on_fetched.call()
	elif errand != null:
		var E: Dictionary = errand
		E.t += dt
		if E.phase == "go":
			goal = E.spot; moving = true
			if Vector2(E.spot.x - pos.x, E.spot.z - pos.z).length() < 0.6: E.phase = "dig"; E.t = 0.0
		elif E.phase == "dig":
			goal = pos
			if E.t > 0.3 and E.t - dt <= 0.3 and on_dig.is_valid(): on_dig.call(E.spot)
			if E.t > 2.6: E.phase = "back"; E.t = 0.0
		elif dist < 2.2 or E.t > 20.0:
			errand = null
			if on_find.is_valid(): on_find.call()
		if errand != null and E.t > 30.0: errand = null
	else:
		errand_t -= dt
		if errand_t <= 0.0:
			errand_t = 60.0 + randf() * 60.0
			if day != found_day and dist < 10.0 and start_errand(player): found_day = day
	var to_goal := Vector3(goal.x - pos.x, 0, goal.z - pos.z)
	var gd := to_goal.length()
	var want := 0.0
	var chasing: bool = romp != null or (fetch != null and (fetch.phase == "chase" or fetch.phase == "fly"))
	if gd > ((0.3 if chasing else 0.8) if moving else 2.4):
		dir = steer.heading(to_goal.normalized(), pos, goal, colliders, dt)
		want = 9.0 if chasing else (minf(2.4, 0.8 + gd * 0.5) if amble else minf(12.0, 1.5 + gd * 1.6))
	speed += (want - speed) * minf(1.0, dt * 5.0)
	if speed > 0.05:
		var nx := pos.x + dir.x * speed * dt; var nz := pos.z + dir.z * speed * dt
		var q := pos
		if not Terrain.is_water(nx, nz): q.x = nx; q.z = nz
		pos = steer.push_out(q)
	var q2 := pos; q2.y = Terrain.get_height(q2.x, q2.z); pos = q2
	bark_t -= dt
	if danger and bark_t <= 0.0:
		bark_t = 4.0 + randf() * 3.0; puppet.head.rotation.z = 0.3
		if on_bark.is_valid(): on_bark.call()
	var cam := camera.global_position
	var cy := atan2(cam.x - p.x, cam.z - p.z)
	var cam_right := Vector3(cos(cy), 0, -sin(cy))
	puppet.update(dt, speed, "walk" if speed > 0.3 else "idle", dir.dot(cam_right) < 0.0, atan2(cam.x - pos.x, cam.z - pos.z))
	if rest_face != null and speed < 0.3:
		var h: float = puppet.heading if puppet.heading != null else 0.0
		var dd: float = rest_face - PI / 2.0 - h; dd = atan2(sin(dd), cos(dd))
		puppet.heading = h + dd * minf(1.0, dt * 3.0); puppet.flip.rotation.y = puppet.heading
	# sitting after a couple of quiet seconds; digging nose down; a pat: a happy wriggle
	still = still + dt if speed < 0.3 else 0.0
	pat_t = maxf(0.0, pat_t - dt)
	var sit := 0.0 if (pat_t > 0.0 or errand != null) else clampf((still - 1.5) / 0.5, 0.0, 1.0)
	var rig := puppet.rig
	if puppet.model == null: rig.rotation.z += sit * 0.38; rig.position.y -= sit * 0.12
	for l in puppet.legs:
		if l.position.x < 0: l.rotation.z = sit * 1.1
		else: l.rotation.z -= sit * 0.38
	puppet.head.rotation.z = puppet.head.rotation.z * (1.0 - sit) + sit * 0.15
	if errand != null and errand.phase == "dig": puppet.head.rotation.z = -0.7 + sin(errand.t * 22.0) * 0.25
	if pat_t > 0.0: rig.rotation.z += sin(pat_t * 30.0) * 0.06; rig.position.y += absf(sin(pat_t * 12.0)) * 0.05
	if fetch != null and fetch.phase == "bring":
		stick.global_position = puppet.head.global_position - Vector3(0, 0.05, 0); stick.rotation = Vector3(0, atan2(dir.x, dir.z), 0)
	if puppet.tail and dist < 4.0: puppet.tail.rotation.z = sin(Time.get_ticks_msec() * (0.06 if pat_t > 0.0 else 0.02)) * (0.6 if pat_t > 0.0 else 0.35)
