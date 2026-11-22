class_name Steer
extends RefCounted
## steer.js: walking round things. Bends a walker's heading to slip round the side of any obstacle circle ahead (the
## one round its goal ignored), and pushes it back out if it ends up inside one. Re-gathers near obstacles twice a second.

var margin := 0.3
var near: Array = []
var scan_t := 0.0

func _init(m := 0.3) -> void: margin = m

func heading(desired: Vector3, pos: Vector3, goal, colliders: Array, dt: float) -> Vector3:
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.5
		near = []
		for c in colliders:
			if Vector2(c.x - pos.x, c.z - pos.z).length() < c.r + 6.0 and not (goal != null and Vector2(c.x - goal.x, c.z - goal.z).length() < c.r + 0.2): near.append(c)
	var out := desired
	for c in near:
		var dx: float = pos.x - c.x; var dz: float = pos.z - c.z; var d := sqrt(dx * dx + dz * dz)
		if d == 0.0: d = 1e-3
		var R: float = c.r + margin
		if d > R + 1.6: continue
		if desired.x * -dx + desired.z * -dz > 0.0:
			var tx := -dz / d; var tz := dx / d
			if tx * desired.x + tz * desired.z < 0.0: tx = -tx; tz = -tz
			var w := (R + 1.6 - d) / 1.6
			out.x += tx * w * 2.2 + (dx / d) * w * 0.4; out.z += tz * w * 2.2 + (dz / d) * w * 0.4
	out.y = 0.0
	return out.normalized() if out.length_squared() > 1e-6 else desired

func push_out(pos: Vector3) -> Vector3:
	for c in near:
		var dx: float = pos.x - c.x; var dz: float = pos.z - c.z; var d := sqrt(dx * dx + dz * dz); var R: float = c.r + margin * 0.8
		if d < R and d > 1e-4: pos.x = c.x + (dx / d) * R; pos.z = c.z + (dz / d) * R
	return pos
