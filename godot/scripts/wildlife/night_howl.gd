class_name NightHowl
extends Node3D
## howl.js: now and then on a dark night out in the open country, a coyote trots up onto the highest ground nearby,
## sits, tips its nose to the moon and howls (and, far off, another answers), then lopes away over the rise. Only
## scenery: it never comes for you. One puppet at a time, only while it's on.

var wait := 40.0 + randf() * 40.0
var c = null

## on: a dark night out in the country; on_howl(vol, answer) plays the howl.
func update(dt: float, player: Player, camera: Camera3D, on: bool, on_howl := Callable()) -> void:
	if c == null:
		wait -= dt
		if not on or wait > 0.0: return
		wait = 100.0 + randf() * 80.0
		# the highest dry ground 26-42 m off (never down in a hollow)
		var best = null
		for i in 14:
			var a := (i / 14.0) * TAU + randf() * 0.3; var r := 26.0 + randf() * 16.0
			var x := player.pos.x + cos(a) * r; var z := player.pos.z + sin(a) * r
			if Terrain.is_water(x, z): continue
			var h := Terrain.get_height(x, z)
			if best == null or h > best.h: best = {"x": x, "z": z, "h": h, "a": a}
		if best == null or best.h < player.pos.y - 1.0: return # (only a hollow to sit in: not tonight)
		var p := Puppet.new("coyote", 1.0)
		var fx: float = best.x + cos(best.a) * 6.0; var fz: float = best.z + sin(best.a) * 6.0 # (it comes up from the far side)
		p.group.position = Vector3(fx, Terrain.get_height(fx, fz), fz); add_child(p.group)
		c = {"p": p, "at": Vector3(best.x, best.h, best.z), "away": best.a, "phase": "come", "t": 0.0}
		return
	var C: Dictionary = c
	C.t += dt
	var pup: Puppet = C.p
	var g := pup.group.position
	var speed := 0.0; var pitch := 0.0
	if C.phase == "come":
		var dx: float = C.at.x - g.x; var dz: float = C.at.z - g.z; var d := sqrt(dx * dx + dz * dz)
		if d > 0.2: speed = 2.2; g.x += (dx / d) * speed * dt; g.z += (dz / d) * speed * dt
		else: C.phase = "howl"; C.t = 0.0
		if C.t > 8.0: C.phase = "howl"; C.t = 0.0
	elif C.phase == "howl":
		# sit, then the nose goes up and the howl comes; a second after a pause
		pitch = clampf((C.t - 0.6) / 0.5, 0.0, 1.0) * (0.3 if C.t < 7.0 else maxf(0.0, 1.0 - (C.t - 7.0) / 0.5) * 0.3)
		if C.t - dt < 1.0 and C.t >= 1.0 and on_howl.is_valid(): on_howl.call(_vol(player, g), false)
		if C.t - dt < 4.6 and C.t >= 4.6 and on_howl.is_valid(): on_howl.call(_vol(player, g), true)
		if C.t > 7.6: C.phase = "go"; C.t = 0.0
	else: # away over the rise, the way it came
		speed = 4.5; g.x += cos(C.away) * speed * dt; g.z += sin(C.away) * speed * dt
		if C.t > 5.0: pup.group.queue_free(); c = null; return
	g.y = Terrain.get_height(g.x, g.z)
	pup.group.position = g
	var cam := camera.global_position
	pup.update(dt, speed, "flee" if speed > 3.0 else "idle", false, atan2(cam.x - g.x, cam.z - g.z))
	if C.phase == "howl": pup.flip.rotation.y = atan2(player.pos.x - g.x, player.pos.z - g.z) - PI / 2.0 + PI / 2.4 # (side-on to you, against the sky)
	pup.flip.rotation.z = pitch; pup.flip.position.y = -sin(pitch) * 0.55 # (nose up, haunches down)

func _vol(player: Player, g: Vector3) -> float: return maxf(0.15, 1.0 - Vector2(g.x - player.pos.x, g.z - player.pos.z).length() / 70.0)
