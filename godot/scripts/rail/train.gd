class_name Train
extends Node3D
## train.js: the Overland & Western's train, a paper 4-4-0 locomotive, her tender, a boxcar and a green coach (baked
## from the web's builders: assets/baked/rail/*.glb). She keeps a timetable: out from the depot mid-morning and again
## in the afternoon, drawing up at each whistle-stop a while, out to the end of the line and home again; smoke puffs
## from her stack while she runs. Board her where she stands ($1) and ride on the coach's back platform.

const SPEED := 3.5 ## m/s at full steam (the web runs 6.5; the player found that too fast)
const DWELL := 18.0
const CAR_GAP := 0.6
const TIE := 0.9
const RUNS := [0.33, 0.6]
const CARS := [["locomotive", 5.2], ["tender", 2.8], ["boxcar", 5.6], ["coach", 6.2]]

var rr: Railroad
var cars: Array = []
var lens: Array = []
var stop_s: Array = []
var end := 0.0
var s := 0.0
var dir := 1
var state := "home"
var wait := 0.0
var at_stop := -1
var ran := -1
var passenger := false
var puffs := MultiMesh.new()
var pp: Array = []
var pn := 0
var pacc := 0.0
var chuff_acc := 0.0
var on_whistle: Callable
var on_chuff: Callable
var on_depart: Callable

func _init(railroad: Railroad) -> void:
	rr = railroad
	for c in CARS:
		var car: Node3D = (load("res://assets/baked/rail/%s.glb" % c[0]) as PackedScene).instantiate()
		Homestead.bake_materials(car)
		add_child(car); cars.append(car); lens.append(c[1])
	visible = false
	# where along the line (metres) each whistle-stop's platform lies (worked out once the line is built)
	end = (rr.path.size() - 1) * TIE
	# smoke from the stack: soft cream paper puffs
	var pts := PackedVector2Array()
	for i in 18:
		var a := (i / 18.0) * TAU; var r := 0.42 + 0.1 * absf(sin(a * 2.5))
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.85))
	puffs.transform_format = MultiMesh.TRANSFORM_3D; puffs.mesh = CardMesh.build(pts, 0.02); puffs.instance_count = 24; puffs.visible_instance_count = 0
	var pmi := MultiMeshInstance3D.new(); pmi.multimesh = puffs; pmi.material_override = PaperMats.card(null, {"albedo": Color.hex(0xe8e0d0ff), "snow": 0.0, "self_fill": 0.3})
	pmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(pmi)
	for i in 24: pp.append({"age": 9.0, "pos": Vector3.ZERO, "s": 1.0})

func _stops_s() -> void:
	stop_s = []
	for st in rr.stops:
		var target: Vector3 = st.get("stand", st.at); var k := 0
		for j in rr.path.size(): if rr.path[j].distance_to(target) < rr.path[k].distance_to(target): k = j
		stop_s.append(k * TIE)

## Point and heading at distance d along the line.
func at(d: float) -> Dictionary:
	var P := rr.path; var f := clampf(d / TIE, 0.0, P.size() - 1.001); var i := floori(f); var t := f - i
	var a: Vector3 = P[i]; var b: Vector3 = P[i + 1]
	var x := a.x + (b.x - a.x) * t; var z := a.z + (b.z - a.z) * t
	return {"pos": Vector3(x, 0.55 if Terrain.is_water(x, z) else Terrain.get_height(x, z) + 0.04, z), "yaw": atan2(b.x - a.x, b.z - a.z)}

## Where she's standing for passengers, if she is: at the depot (home) or a whistle-stop (dwelling there).
func stopped_at():
	if not rr.built: return null
	if state == "home": return {"name": "Cold Glitter Creek", "platform": rr.depot_group.to_global(Vector3(-2, 0.3, 3.4)), "depot": true}
	if state == "dwell" and at_stop >= 0: var st: Dictionary = rr.stops[at_stop]; return {"name": st.name, "platform": st.platform, "depot": false}
	return null
## The coach's back platform, where a passenger stands to ride.
func ride_point() -> Vector3: return (cars[3] as Node3D).to_global(Vector3(0.35, 0.83, -3.35))
## The next stop she'll draw up at, by name.
func next_stop_name() -> String:
	var best = null
	for i in stop_s.size():
		var sv: float = stop_s[i]
		if (sv > s + 0.05) if dir > 0 else (sv < s - 0.05):
			if best == null or ((sv < stop_s[best]) if dir > 0 else (sv > stop_s[best])): best = i
	return rr.stops[best].name if best != null else "Cold Glitter Creek"
## All aboard from the depot: she leaves straight away.
func depart() -> void:
	if state == "home":
		state = "run"; dir = 1
		if on_whistle.is_valid(): on_whistle.call(at(s).pos)
		if on_depart.is_valid(): on_depart.call()
	elif state == "dwell": wait = minf(wait, 2.5)

func update(dt: float, clock: float, camera: Camera3D, player: Player) -> void:
	if not rr.built: visible = false; return
	if stop_s.is_empty(): _stops_s()
	# the timetable: away at each run's hour, out to the end of the line stop by stop, and home again
	if state == "home":
		var run := -1
		for k in RUNS.size(): if clock > RUNS[k] and clock < RUNS[k] + 0.08: run = k
		if run >= 0 and ran != run:
			ran = run; state = "run"; dir = 1
			if on_whistle.is_valid(): on_whistle.call(at(s).pos)
			if on_depart.is_valid(): on_depart.call()
		if run < 0: ran = -1
	var moving := false
	if state == "run":
		var next = null # (the stop she has just left drops out; the one ahead stays till she reaches it)
		for i in stop_s.size():
			var sv: float = stop_s[i]
			if (sv > s + 0.05) if dir > 0 else (sv < s - 0.05):
				if next == null or ((sv < stop_s[next]) if dir > 0 else (sv > stop_s[next])): next = i
		var target: float = stop_s[next] if next != null else (end if dir > 0 else 0.0)
		var d := absf(target - s); var v := minf(SPEED, 0.6 + d * 0.5) # (easing into each stop)
		if d < 0.3:
			s = target
			if next == null and dir < 0: state = "home"
			elif next == null: dir = -1; state = "dwell"; wait = DWELL
			else:
				state = "dwell"; wait = DWELL; at_stop = next
				if dir > 0 and target >= end - 0.5: dir = -1
		else: s += signf(target - s) * v * dt; moving = true
	elif state == "dwell":
		wait -= dt
		if wait <= 0.0:
			state = "run"; at_stop = -1
			if on_whistle.is_valid(): on_whistle.call(at(s).pos)
	# the cars along the line, coupled one behind another
	var cp := camera.global_position; var head := at(s)
	var far := Vector2(cp.x - head.pos.x, cp.z - head.pos.z).length() > 170.0
	visible = not far
	if not far:
		var off := 0.0
		for i in cars.size():
			var half: float = lens[i] / 2.0; off += half if i else 0.0
			var p: Vector3 = at(s - dir * off).pos
			# tilted with the grade: the line from the car's back wheels to its front (the web keeps every car level)
			var pf: Vector3 = at(s - dir * (off - half * 0.8)).pos; var pb: Vector3 = at(s - dir * (off + half * 0.8)).pos
			var fwd := pf - pb
			cars[i].position = p
			# (at the line's ends the two points close up and the heading is lost: then the car keeps the one it had)
			if Vector2(fwd.x, fwd.z).length() > 0.05: cars[i].basis = Basis.looking_at(-fwd.normalized(), Vector3.UP); cars[i].set_meta("faced", true)
			elif not cars[i].get_meta("faced", false): cars[i].rotation = Vector3(0, float(at(s - dir * off).yaw) + (0.0 if dir > 0 else PI), 0) # (standing at the very end before she's ever moved: level, along the track)
			off += half + CAR_GAP
		if moving and not passenger: # she won't run a man down: anyone on the track is nudged off it
			for c in cars:
				var dx: float = player.pos.x - c.position.x; var dz: float = player.pos.z - c.position.z; var dd := sqrt(dx * dx + dz * dz)
				if dd < 1.9 and dd > 0.01: player.pos.x += (dx / dd) * (1.9 - dd); player.pos.z += (dz / dd) * (1.9 - dd)
	# smoke from the stack while she runs (and a lazy wisp while she stands)
	var stack: Vector3 = (cars[0] as Node3D).to_global(Vector3(0, 3.0, 1.6))
	pacc += dt * (6.0 if moving else 0.8)
	while pacc >= 1.0:
		pacc -= 1.0; pp[pn].age = 0.0; pp[pn].pos = stack; pp[pn].s = 0.35 + randf() * 0.25; pn = (pn + 1) % pp.size()
	var n := 0
	for P in pp:
		if P.age > 2.6: continue
		P.age += dt; var k: float = P.age / 2.6
		P.pos += Vector3(dt * 0.5, dt * (1.2 - k * 0.6), 0) # (drifting up and off with the breeze)
		var sc: float = P.s * (0.6 + k * 1.6) * (k / 0.1 if k < 0.1 else 1.0) * (1.0 - k * k)
		puffs.set_instance_transform(n, Transform3D(Basis(Vector3.UP, atan2(cp.x - P.pos.x, cp.z - P.pos.z)).scaled(Vector3.ONE * maxf(0.001, sc)), P.pos)); n += 1
	puffs.visible_instance_count = 0 if far else n
	if moving and not far:
		chuff_acc += dt * (1.2 + minf(SPEED, 6.0) * 0.6)
		if chuff_acc >= 1.0:
			chuff_acc = 0.0
			if on_chuff.is_valid(): on_chuff.call(head.pos)

func save() -> Dictionary: return {"s": s, "dir": dir, "state": state}
