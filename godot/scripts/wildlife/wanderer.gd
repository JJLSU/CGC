class_name Wanderer
extends Node3D
## wanderer.js: Johnny Appleseed comes by. On some mornings (about one day in four, from Day 3, never fair day) the
## old wanderer walks the lane across the bottom of the farm, west to east, barefoot, tin pot for a hat, a sack of
## apple seeds. Walk up and he stops to talk; E and he gives you apples and plants a sapling by the lane. (folk_johnny)

const SAYINGS := [
	"\"Mornin', neighbor. Plant a seed today and somebody you'll never meet sits in its shade.\"",
	"\"I've walked from the Ohio to here with nothing but this pot and these seeds. Rich as a king.\"",
	"\"An apple tree's a promise you make to the folks who come after. I'll leave you one.\"",
	"\"Treat the critters kindly, even the cross old boars. Most of 'em only want an apple.\"",
]

var C: Vector3
var man: ModelFigure
var group := Node3D.new()
var steer := Steer.new(0.4)
var heading := Vector3(1, 0, 0)
var visit_day := -1
var talked_day := -1
var state := "away"
var talked := false

var pos: Vector3:
	get: return group.position
	set(v): group.position = v

func _init(center: Vector3) -> void:
	C = center
	man = ModelFigure.new("folk_johnny")
	group.add_child(man.root); group.visible = false
	add_child(group)

## Does he come by today?
static func visits(day: int) -> bool: return day >= 3 and day % 7 != 0 and ((day * 2654435761) & 0xFFFFFFFF) % 4 == 1
func near(p: Vector3, r := 2.6) -> bool: return state == "walking" and group.visible and Vector2(p.x - pos.x, p.z - pos.z).length() < r

## Returns "arrived" the moment he turns up, else "".
func update(dt: float, day: int, time: float, player: Player, colliders: Array = []) -> String:
	if state == "away":
		if day != visit_day and visits(day) and time > 0.34 and time < 0.55:
			visit_day = day; state = "walking"; talked = talked_day == day # (a reload doesn't get you a second sapling)
			pos = Vector3(C.x - 46.0, Terrain.get_height(C.x - 46.0, C.z + 13.5), C.z + 13.5)
			group.visible = true
			return "arrived"
		return ""
	# he walks the lane across the bottom of the farm, west to east, and stops while you're near
	var d := Vector2(player.pos.x - pos.x, player.pos.z - pos.z).length()
	var stopped := d < 4.5
	var speed := 0.0 if stopped else 1.0
	if speed > 0.0:
		var ax := pos.x + 3.0; var az := C.z + 13.5 + sin(ax * 0.15) * 1.2 # (a gentle wave in the lane)
		var w := Vector3(ax - pos.x, 0, az - pos.z).normalized()
		heading = heading.lerp(steer.heading(w, pos, null, colliders, dt), minf(1.0, dt * 5.0)).normalized()
		var q := pos; q.x += heading.x * speed * dt; q.z += heading.z * speed * dt
		pos = steer.push_out(q)
	var q2 := pos; q2.y = Terrain.get_height(q2.x, q2.z); pos = q2
	# he faces the way he walks, or turns to you when he stops to talk
	var want := atan2(player.pos.x - pos.x, player.pos.z - pos.z) if stopped else atan2(heading.x, heading.z)
	var dy := want - group.rotation.y; dy = atan2(sin(dy), cos(dy))
	group.rotation.y += dy * minf(1.0, dt * 6.0)
	man.update(dt, speed)
	if pos.x > C.x + 46.0 or (time > 0.7 and not stopped): state = "away"; group.visible = false
	return ""
