class_name Cat
extends Node3D
## cat.js: Marmalade, the barn cat. By day she naps in a loaf on her favourite spots (atop the hay bales, the porch
## boards by the rocker, a warm patch by the garden, under the washing line), hopping up and down where she has to,
## and every few minutes strolls to another; after dark she goes mousing along the garden rows, low and slow. A scratch
## (E) and she purrs. She gives Old Blue a wide berth.

var puppet: Puppet
var spots: Array = []
var garden := {}
var dir := Vector3(1, 0, 0)
var state := "rest"
var spot := 0
var t := 0.0
var rest_for := 40.0 + randf() * 60.0
var goal := Vector3.ZERO
var target = null
var hop = null
var pat_t := 0.0
var flick_t := 2.0
var flick := 0.0
var scan_t := 0.0
var obstacles: Array = []
var on_purr: Callable

var pos: Vector3:
	get: return puppet.group.position
	set(v): puppet.group.position = v

func _init(center: Vector3, seat: Vector3, facing: float) -> void:
	var C := center
	var ground := func(x: float, z: float) -> Vector3: return Vector3(x, Terrain.get_height(x, z), z)
	var bale: Vector3 = ground.call(C.x - 6, C.z - 3.5); bale.y += 1.15
	var deck := seat + Vector3(-0.9 * cos(facing), -0.28, 0.9 * sin(facing))
	spots = [bale, deck, ground.call(C.x - 4.2, C.z + 2.6), ground.call(C.x + 8.5, C.z + 2.4), bale]
	garden = {"x0": C.x - 12.5, "x1": C.x - 6.5, "z0": C.z + 2.2, "z1": C.z + 7.2}
	puppet = Puppet.new("cat", 1.6)
	add_child(puppet.group)
	pos = spots[0]

func near(p: Vector3, r := 1.6) -> bool:
	var up := pos.y - Terrain.get_height(pos.x, pos.z) > 0.3 # (on a perch you can reach up a bit further)
	return Vector2(p.x - pos.x, p.z - pos.z).length() < r + (1.1 if up else 0.0) and absf(p.y - pos.y) < 1.8

func pat() -> void:
	pat_t = 2.2; t = minf(t, 5.0)
	if on_purr.is_valid(): on_purr.call()

func next_goal(night: float) -> void:
	if night > 0.6:
		target = null
		goal = Vector3(garden.x0 + randf() * (garden.x1 - garden.x0), 0, garden.z0 + randf() * (garden.z1 - garden.z0))
		goal.y = Terrain.get_height(goal.x, goal.z)
		return
	var i := spot
	while spots[i] == spots[spot]: i = randi() % spots.size()
	spot = i; target = spots[i]
	goal = target; goal.y = Terrain.get_height(goal.x, goal.z)

func _steer(desired: Vector3, colliders: Array, dt: float) -> Vector3:
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.5
		obstacles = []
		for c in colliders:
			if Vector2(c.x - pos.x, c.z - pos.z).length() < c.r + 6.0 and Vector2(c.x - goal.x, c.z - goal.z).length() > c.r + 0.1: obstacles.append(c)
	var out := desired
	for c in obstacles:
		var dx: float = pos.x - c.x; var dz: float = pos.z - c.z; var d := maxf(sqrt(dx * dx + dz * dz), 1e-3); var R: float = c.r + 0.3
		if d > R + 1.6: continue
		if desired.x * -dx + desired.z * -dz > 0.0:
			var tx := -dz / d; var tz := dx / d
			if tx * desired.x + tz * desired.z < 0.0: tx = -tx; tz = -tz
			var w := (R + 1.6 - d) / 1.6
			out.x += tx * w * 2.2 + (dx / d) * w * 0.4; out.z += tz * w * 2.2 + (dz / d) * w * 0.4
	return out.normalized()

func _push_out() -> void:
	var q := pos
	for c in obstacles:
		var dx: float = q.x - c.x; var dz: float = q.z - c.z; var d := sqrt(dx * dx + dz * dz); var R: float = c.r + 0.25
		if d < R and d > 1e-4: q.x = c.x + (dx / d) * R; q.z = c.z + (dz / d) * R
	pos = q

func update(dt: float, player: Player, camera: Camera3D, dog: Dog, night: float, colliders: Array) -> void:
	t += dt
	pat_t = maxf(0.0, pat_t - dt)
	var ground_y := Terrain.get_height(pos.x, pos.z)
	var speed := 0.0
	if hop != null:
		hop.t += dt
		var k := minf(1.0, hop.t / 0.45)
		var q: Vector3 = hop.from.lerp(hop.to, k); q.y += sin(k * PI) * 0.6; pos = q
		if k >= 1.0:
			var then: String = hop.get("then", "")
			hop = null
			if then != "": state = then
			t = 0.0
	elif state == "rest":
		var prowling := night > 0.6
		if (t > ((6.0 + randf() * 3.0) if prowling else rest_for) and pat_t <= 0.0) or (dog.near(pos, 1.8) and pos.y - ground_y < 0.3):
			next_goal(night); rest_for = 40.0 + randf() * 70.0
			if pos.y - ground_y > 0.3:
				var to := pos + Vector3(goal.x - pos.x, 0, goal.z - pos.z).normalized() * 0.9
				to.y = Terrain.get_height(to.x, to.z)
				hop = {"from": pos, "to": to, "t": 0.0, "then": "walk"}
			else: state = "walk"
			t = 0.0
	elif state == "walk":
		var d := Vector3(goal.x - pos.x, 0, goal.z - pos.z)
		var length := d.length()
		var raised: bool = target != null and target.y - goal.y > 0.3
		if length < (0.85 if raised else 0.2) or t > 40.0:
			if raised: hop = {"from": pos, "to": target, "t": 0.0, "then": "rest"}
			else: state = "rest"; t = 0.0
		else:
			dir = dir.lerp(_steer(d.normalized(), colliders, dt), minf(1.0, dt * 6.0)).normalized()
			speed = 0.7 if night > 0.6 else 1.3
			var q := pos; q.x += dir.x * speed * dt; q.z += dir.z * speed * dt; pos = q
			_push_out()
			q = pos; q.y = Terrain.get_height(q.x, q.z); pos = q
	var cam := camera.global_position
	var cy := atan2(cam.x - player.pos.x, cam.z - player.pos.z)
	var cam_right := Vector3(cos(cy), 0, -sin(cy))
	puppet.update(dt, speed, "walk" if speed > 0.1 else "idle", dir.dot(cam_right) < 0.0, atan2(cam.x - pos.x, cam.z - pos.z))
	var loaf := minf(1.0, t / 0.6) if (state == "rest" and hop == null) else 0.0
	var rig := puppet.rig
	if puppet.model == null: rig.position.y -= loaf * 0.16
	for l in puppet.legs: l.rotation.z = (-1.45 if l.position.x > 0 else 1.45) * loaf + l.rotation.z * (1.0 - loaf)
	if puppet.tail: puppet.tail.rotation.z = loaf * -0.9 + sin(t * (6.0 if pat_t > 0.0 else 1.3)) * (0.12 if pat_t > 0.0 else 0.06)
	if pat_t > 0.0:
		puppet.head.rotation.z = 0.25 + sin(pat_t * 4.0) * 0.08; rig.rotation.z += sin(pat_t * 9.0) * 0.03
	elif loaf > 0.0:
		flick_t -= dt
		if flick_t <= 0.0: flick_t = 3.0 + randf() * 6.0; flick = 0.3
		flick = maxf(0.0, flick - dt)
		for e in puppet.ears: e.rotation.z = sin(flick * 30.0) * 0.3 * (1.0 if flick > 0.0 else 0.0)
		puppet.head.rotation.z = sin(t * 0.4) * 0.08
	if hop != null: rig.rotation.z += (Props.spring_rise(hop.t * 2.2) - 1.0) * 0.2
