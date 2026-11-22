class_name Calf
extends Node3D
## calf.js: the lost calf. Now and then (about one day in five, from Day 4, never on fair day) Daisy the cow's calf
## slips through the pasture rails in the night and wanders off 40-70 m into the meadows; a note says which way. It
## grazes and bawls for its mother now and then (heard from a good way off). E by it and it trots after you; bring it
## within sight of the pasture and it scampers in to Daisy, who gives extra milk. Unfound, it's home by nightfall.

const DIRS := ["east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east"]

var pasture: Vector3
var puppet: Puppet
var state := "home"
var lost_day := -1
var dir := Vector3(1, 0, 0)
var speed := 0.0
var moo_t := 3.0
var t := 0.0
var on_moo: Callable
var steer := Steer.new(0.3)

var pos: Vector3:
	get: return puppet.group.position
	set(v): puppet.group.position = v

func _init(pasture_at: Vector3) -> void:
	pasture = pasture_at
	puppet = Puppet.new("calf", 0.55)
	puppet.group.visible = false
	add_child(puppet.group)

static func lost_today(day: int) -> bool: return day >= 4 and day % 7 != 0 and ((day * 2246822519) & 0xFFFFFFFF) % 5 == 2
func near(p: Vector3, r := 2.4) -> bool: return state == "lost" and Vector2(p.x - pos.x, p.z - pos.z).length() < r

## Morning: it's gone. Returns the direction word for the note, or "".
func wander(day: int) -> String:
	for tries in 30:
		var a := randf() * TAU; var d := 40.0 + randf() * 30.0
		var x := pasture.x + cos(a) * d; var z := pasture.z + sin(a) * d
		var reg := Terrain.region_at(x, z)
		if Terrain.is_water(x, z) or (reg != "meadow" and reg != "field"): continue
		pos = Vector3(x, Terrain.get_height(x, z), z)
		state = "lost"; lost_day = day; puppet.group.visible = true
		var k := floori(atan2(-(z - pasture.z), x - pasture.x) / (PI / 4.0) + 0.5)
		return DIRS[((k % 8) + 8) % 8]
	return ""

## Returns {lost: dir} the morning it goes, {home: true} when you bring it in, else {}.
func update(dt: float, day: int, time: float, player: Player, camera: Camera3D, colliders: Array = []) -> Dictionary:
	t += dt
	if state == "home":
		if day != lost_day and lost_today(day) and time > 0.27 and time < 0.5:
			var w := wander(day)
			return {"lost": w} if w != "" else {}
		return {}
	# it finds its own way home by nightfall
	if time > 0.8 or day != lost_day: state = "home"; puppet.group.visible = false; return {}
	var p := player.pos
	var want := 0.0
	var out := {}
	if state == "lost":
		# grazing about, and bawling for its mother now and then
		moo_t -= dt
		if moo_t <= 0.0:
			moo_t = 6.0 + randf() * 6.0
			var d := Vector2(p.x - pos.x, p.z - pos.z).length()
			if d < 90.0 and on_moo.is_valid(): on_moo.call(maxf(0.15, 1.0 - d / 90.0))
	elif state == "follow":
		var tx := p.x - pos.x; var tz := p.z - pos.z; var d := sqrt(tx * tx + tz * tz)
		if d > 2.2: dir = steer.heading(Vector3(tx / d, 0, tz / d), pos, p, colliders, dt); want = minf(6.5, 1.5 + d * 1.2)
		if d > 45.0: pos = Vector3(p.x - 2, Terrain.get_height(p.x - 2, p.z), p.z - 2) # (never lose it on the way home)
		# home: in sight of the pasture, it scampers in to Daisy
		if Vector2(pos.x - pasture.x, pos.z - pasture.z).length() < 11.0: state = "run"; t = 0.0; out = {"home": true}
	elif state == "run":
		var tx := pasture.x - pos.x; var tz := pasture.z - pos.z; var d := sqrt(tx * tx + tz * tz)
		var dd := d if d > 0.0 else 1.0
		dir = steer.heading(Vector3(tx / dd, 0, tz / dd), pos, pasture, colliders, dt); want = 5.0
		if d < 2.0 or t > 6.0: state = "home"; puppet.group.visible = false
	speed += (want - speed) * minf(1.0, dt * 5.0)
	if speed > 0.05:
		var q := pos
		var nx := q.x + dir.x * speed * dt; var nz := q.z + dir.z * speed * dt
		if not Terrain.is_water(nx, nz): q.x = nx; q.z = nz
		pos = steer.push_out(q)
	var q2 := pos; q2.y = Terrain.get_height(q2.x, q2.z); pos = q2
	var cam := camera.global_position
	var yaw_to_cam := atan2(cam.x - pos.x, cam.z - pos.z)
	var cam_yaw := atan2(cam.x - p.x, cam.z - p.z)
	puppet.update(dt, speed, "walk" if speed > 0.3 else "idle", dir.x * cos(cam_yaw) - dir.z * sin(cam_yaw) < 0.0, yaw_to_cam)
	if state == "lost": puppet.head.rotation.z = -0.5 + sin(t * 1.3) * 0.15 # (nose down in the grass)
	return out

func lead() -> bool:
	if state == "lost": state = "follow"; return true
	return false

## For the save: is it out today, and where?
func save() -> Dictionary: return {"lostDay": lost_day, "out": state == "lost" or state == "follow", "x": pos.x, "z": pos.z}
func load_state(s, day: int) -> void:
	if s == null or int(s.get("lostDay", -1)) != day: return
	lost_day = day
	if s.get("out", false): pos = Vector3(s.x, Terrain.get_height(s.x, s.z), s.z); state = "lost"; puppet.group.visible = true
