class_name Ducks
extends Node3D
## ducks.js: a mallard hen and her ducklings. By day, on a pond near the farmer, a brown paper duck paddles slow
## loops with three or four downy ducklings strung out behind her in a line, each following the one in front. Come
## close (or Old Blue barks from the bank) and she hurries them off; corn tossed on the water and they paddle over to
## dabble. One family at a time, only near water.

const WATER_Y := 0.03

var fam = null
var look := 0.0
var on_ring: Callable   ## (x, z, size): a wake ring
var on_quack: Callable  ## (dist)

## The open water nearest (x, z), if the ducks are within reach of it: where tossed corn would land.
func toss_spot(x: float, z: float) -> Variant:
	if fam == null or Vector2(fam.ducks[0].p.group.position.x - x, fam.ducks[0].p.group.position.z - z).length() > 10.0: return null
	var r := 1.0
	while r <= 4.0:
		var a := 0.0
		while a < TAU:
			var px := x + cos(a) * r; var pz := z + sin(a) * r
			if Terrain.is_water(px, pz) and Terrain.is_water(px + cos(a) * 0.6, pz + sin(a) * 0.6): return Vector2(px + cos(a) * 0.6, pz + sin(a) * 0.6)
			a += 0.4
		r += 0.5
	return null

## Corn on the water at spot: the family comes over and dabbles a while.
func feed(spot: Vector2) -> void:
	if fam != null: fam.come = {"x": spot.x, "z": spot.y, "t": 14.0}; fam.quackT = 0.4

func lead_group() -> Node3D: return fam.ducks[0].p.group if fam != null else null

func _clear() -> void:
	for d in fam.ducks: d.p.group.queue_free()
	fam = null

## day: daylight and no downpour (they're off the water otherwise); dog: Old Blue's position or null.
func update(dt: float, player: Player, camera: Camera3D, day: bool, dog = null) -> void:
	if fam != null and (not day or Vector2(fam.c.x - player.pos.x, fam.c.z - player.pos.z).length() > 75.0): _clear(); return
	if fam == null:
		look -= dt
		if not day or look > 0.0: return
		look = 4.0
		# a pond within 12-40 m: a water point with open water a good few metres all round it
		for i in 16:
			var a := randf() * TAU; var r := 12.0 + randf() * 28.0
			var x := player.pos.x + cos(a) * r; var z := player.pos.z + sin(a) * r
			if not Terrain.is_water(x, z): continue
			var open := true
			for k in 8: if not Terrain.is_water(x + cos(k * 0.785) * 3.5, z + sin(k * 0.785) * 3.5): open = false; break
			if not open: continue
			var n := 3 + randi() % 2
			var ducks := []
			for j in n + 1:
				var p := Puppet.new("duckling" if j else "duck", 0.55 if j else 1.0)
				p.group.position = Vector3(x, WATER_Y, z); add_child(p.group)
				ducks.append({"p": p, "phase": randf() * 6.0})
			fam = {"c": Vector3(x, 0, z), "r": 2.4, "ang": 0.0, "ducks": ducks, "trail": [], "come": null, "ringT": 0.0, "quackT": 3.0}
			return
		return
	var F: Dictionary = fam
	var m: Dictionary = F.ducks[0]
	var mp: Vector3 = m.p.group.position
	# the mother paddles a slow loop (quicker and wider if you've come close); each duckling follows the trail
	var near: bool = Vector2(mp.x - player.pos.x, mp.z - player.pos.z).length() < 5.0 or (dog != null and Vector2(mp.x - dog.x, mp.z - dog.z).length() < 7.5)
	var speed := 1.4 if near else 0.45
	var tx: float; var tz: float
	if F.come != null and F.come.t - dt > 0.0:
		F.come.t -= dt
		# corn on the water: she paddles straight over to it, the brood behind, and dabbles there
		speed = 0.0
		var dx: float = F.come.x - mp.x; var dz: float = F.come.z - mp.z; var d := sqrt(dx * dx + dz * dz)
		if d > 0.35: speed = 0.8; tx = mp.x + (dx / d) * speed * dt; tz = mp.z + (dz / d) * speed * dt
		else: tx = mp.x; tz = mp.z
		if not Terrain.is_water(tx, tz): tx = mp.x; tz = mp.z; speed = 0.0
		F.ang = atan2(tz - F.c.z, tx - F.c.x); F.r = maxf(1.2, Vector2(tx - F.c.x, tz - F.c.z).length()) # (so she picks up her loop from here)
	else:
		F.come = null
		F.ang += (speed / F.r) * dt
		tx = F.c.x + cos(F.ang) * F.r; tz = F.c.z + sin(F.ang) * F.r
		if not Terrain.is_water(tx, tz): F.r = maxf(1.2, F.r * 0.9); tx = F.c.x + cos(F.ang) * F.r; tz = F.c.z + sin(F.ang) * F.r # (keep to open water)
		elif F.r < 3.2: F.r += dt * 0.05
	m.p.group.position = Vector3(tx, WATER_Y, tz)
	F.trail.push_front(Vector2(tx, tz))
	if F.trail.size() > 400: F.trail.resize(400)
	# a little V of rings behind her as she paddles, and a quack every so often (a flurry when you come close)
	F.ringT -= dt
	if F.ringT <= 0.0:
		F.ringT = 0.35 if near else 0.9
		if on_ring.is_valid(): on_ring.call(tx, tz, 0.55)
	F.quackT -= dt
	if F.quackT <= 0.0:
		F.quackT = (1.2 + randf()) if near else (7.0 + randf() * 9.0)
		if on_quack.is_valid(): on_quack.call(Vector2(tx - player.pos.x, tz - player.pos.z).length())
	var cam := camera.global_position
	var yaw_to_cam := atan2(cam.x - tx, cam.z - tz)
	var now := Time.get_ticks_msec()
	for j in F.ducks.size():
		var d: Dictionary = F.ducks[j]
		if j: # a stride behind the one in front along the mother's wake
			var want: float = j * 0.55; var acc := 0.0; var k := 1
			while k < F.trail.size():
				acc += (F.trail[k] - F.trail[k - 1]).length()
				if acc >= want: break
				k += 1
			var pt: Vector2 = F.trail[mini(k, F.trail.size() - 1)]
			d.p.group.position = Vector3(pt.x, WATER_Y, pt.y)
		d.p.update(dt, speed, "walk", false, yaw_to_cam)
		d.p.group.position.y = WATER_Y + sin(now / 600.0 + d.phase) * 0.012 # (bobbing on the ripples)
