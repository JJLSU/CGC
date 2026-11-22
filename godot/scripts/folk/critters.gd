class_name Critters
extends Node3D
## critters.js: the farm's hens and rooster in the yard, a milk cow and sheep in the pasture (they stay put and go in
## to the hen house and the barn at nightfall and out of a downpour), and the wild ones kept round the farmer: six
## rabbits and four deer, a bison herd out on the highland, a flock of wild turkeys in the woods. Each potters about
## its home, bolts when you come too close, never steps into water, hides in the haze far off, and faces the way it
## goes. A struck beast folds down flat and waits for you to dress it.

const FARM := ["hen", "cow", "sheep"]
const SPEC := {
	"rabbit": {"walk": 1.2, "run": 6.5, "flee": 7.0, "range": 7.0}, "deer": {"walk": 1.1, "run": 7.5, "flee": 11.0, "range": 12.0},
	"hen": {"walk": 0.6, "run": 2.2, "flee": 1.5, "range": 4.0}, "cow": {"walk": 0.45, "run": 1.6, "flee": 0.7, "range": 6.0},
	"sheep": {"walk": 0.55, "run": 2.6, "flee": 0.8, "range": 6.0}, "bison": {"walk": 0.5, "run": 4.2, "flee": 6.0, "range": 9.0},
	"turkey": {"walk": 0.7, "run": 4.8, "flee": 6.0, "range": 6.0},
}
var rng := PNoise.Mulberry32.new(4242)
var list: Array = []
var rooster = null
var roost = null          ## Vector3: the foot of the hen house ramp
var barn = null           ## Vector3: just outside the barn's big doors
var abed := false
var spawn_t := 0.0
var gobble_t := 6.0
var herd_seen := false
var on_spotted: Callable
var on_dressed: Callable
var on_herd: Callable
var on_gobble: Callable

func setup(yard: Vector3, pasture = null) -> void:
	for i in 5:
		var h = spawn("hen", yard.x + (rng.next() - 0.5) * 6.0, yard.z + (rng.next() - 0.5) * 6.0, yard, "rooster" if i == 0 else "hen")
		if i == 0 and h != null: h.rooster = true; rooster = h
	if pasture != null:
		for i in 2: spawn("cow", pasture.x + (rng.next() - 0.5) * 6.0, pasture.z + (rng.next() - 0.5) * 6.0, pasture)
		for i in 4: spawn("sheep", pasture.x + (rng.next() - 0.5) * 7.0, pasture.z + (rng.next() - 0.5) * 7.0, pasture)

func spawn(type: String, x: float, z: float, home = null, kit := ""):
	if kit == "": kit = type
	var scale: float
	match type:
		"turkey": scale = 1.55 + rng.next() * 0.2
		"bison": scale = 1.0 + rng.next() * 0.18
		"deer": scale = 1.05 + rng.next() * 0.2
		"cow": scale = 1.0 + rng.next() * 0.1
		_: scale = 0.95 + rng.next() * 0.2
	var p: Puppet = null
	var spare: Array = idle.get(kit, [])
	if spare.size(): # (a puppet that wandered out of range earlier, kept: no instantiation)
		p = spare.pop_back(); p.rig.scale = Vector3.ONE * scale; p.set_fold(1.0); p.heading = null; p._has = false; p.mw = 0.0; p.rw = 0.0
		p.group.visible = true
	else:
		p = Puppet.new(kit, scale); add_child(p.group)
	p.group.position = Vector3(x, Terrain.get_height(x, z), z)
	var c := {"type": type, "puppet": p, "home": (home as Vector3) if home != null else Vector3(x, 0, z), "target": Vector3(x, 0, z),
		"state": "idle", "timer": rng.next() * 3.0, "dir": Vector3(1, 0, 0), "speed": 0.0, "spotted": false, "scale": scale, "lod": -1,
		"roosting": false, "crowT": 0.0, "rooster": false, "milkedDay": -1, "shornDay": 0}
	list.append(c)
	return c

## A critter out of range or done with goes back in the pool (hidden), up to a few of each kind; the rest are freed.
## (Making a puppet, its model, rig and animations, costs ~10 ms: a herd of five made at once was a 44 ms hitch.)
var idle := {}             ## kit -> [Puppet] kept for reuse
const KEEP := 6
func despawn(c: Dictionary) -> void:
	list.erase(c)
	var kit: String = c.puppet.kind
	var spare: Array = idle.get(kit, [])
	if spare.size() < KEEP: c.puppet.group.visible = false; spare.append(c.puppet); idle[kit] = spare
	else: (c.puppet.group as Node).queue_free()

## Herds come in a few at a time: their members wait here and are made one a frame.
var pending: Array = []    ## [[type, x, z, home]]

func pos(c: Dictionary) -> Vector3: return (c.puppet.group as Node3D).position

## Keep a few rabbits and deer about the farmer, a bison herd on the highland and turkeys in the woods; drop far ones.
func manage(p: Vector3) -> void:
	for c in list.duplicate():
		if not (c.type in FARM) and pos(c).distance_squared_to(p) > 85.0 * 85.0: despawn(c)
	var count := func(t: String) -> int:
		var n := 0
		for c in list: if c.type == t and c.state != "down": n += 1
		return n
	var has := func(t: String) -> bool:
		for c in list: if c.type == t: return true
		for q in pending: if q[0] == t: return true
		return false
	if not has.call("bison") and rng.next() < 0.25:
		var a := rng.next() * TAU; var d := 35.0 + rng.next() * 25.0; var hx := p.x + cos(a) * d; var hz := p.z + sin(a) * d
		if Terrain.region_at(hx, hz) == "highland":
			var home := Vector3(hx, 0, hz)
			var n := 4 + (1 if rng.next() < 0.5 else 0)
			for i in n:
				var x := hx + (rng.next() - 0.5) * 7.0; var z := hz + (rng.next() - 0.5) * 7.0
				if not Terrain.is_water(x, z): pending.append(["bison", x, z, home])
	if not has.call("turkey") and rng.next() < 0.2:
		var a := rng.next() * TAU; var d := 26.0 + rng.next() * 20.0; var hx := p.x + cos(a) * d; var hz := p.z + sin(a) * d
		if Terrain.region_at(hx, hz) == "forest":
			var home := Vector3(hx, 0, hz)
			var n := 3 + (1 if rng.next() < 0.5 else 0)
			for i in n:
				var x := hx + (rng.next() - 0.5) * 4.0; var z := hz + (rng.next() - 0.5) * 4.0
				if not Terrain.is_water(x, z): pending.append(["turkey", x, z, home])
	for tw in [["rabbit", 6], ["deer", 4]]:
		if count.call(tw[0]) >= tw[1]: continue
		var a := rng.next() * TAU; var d := 28.0 + rng.next() * 30.0
		var x := p.x + cos(a) * d; var z := p.z + sin(a) * d
		var reg := Terrain.region_at(x, z)
		if reg == "water" or reg == "peak": continue
		if tw[0] == "deer" and reg != "forest" and reg != "meadow": continue
		spawn(tw[0], x, z)

func update(dt: float, player_pos: Vector3, camera: Camera3D) -> void:
	spawn_t -= dt
	if spawn_t <= 0.0: spawn_t = 1.5; manage(player_pos)
	if pending.size(): var q: Array = pending.pop_front(); spawn(q[0], q[1], q[2], q[3])
	gobble_t -= dt
	if gobble_t <= 0.0:
		gobble_t = 12.0 + rng.next() * 16.0
		var bd := INF
		for c in list: if c.type == "turkey" and c.state != "down": bd = minf(bd, pos(c).distance_to(player_pos))
		if bd < 35.0 and on_gobble.is_valid(): on_gobble.call(bd)
	var cam := camera.global_position
	var ca := atan2(cam.x - player_pos.x, cam.z - player_pos.z)
	var cam_right := Vector3(cos(ca), 0, -sin(ca))
	for c in list.duplicate():
		var spec: Dictionary = SPEC[c.type]
		var g: Node3D = c.puppet.group
		var to_p := g.position - player_pos; to_p.y = 0
		var dist := to_p.length()
		if c.state == "down":
			c.timer += dt; c.puppet.set_fold(1.0 - pow(minf(1.0, c.timer / 0.45), 2))
			if dist < 2.2 and c.timer > 0.5:
				if on_dressed.is_valid(): on_dressed.call(c)
				despawn(c)
			elif c.timer > 120.0: despawn(c)
			continue
		# the hens go in to roost at nightfall; the cow and sheep in to the barn; out again at sunup
		var den = roost if c.type == "hen" else (barn if c.type == "cow" or c.type == "sheep" else null)
		if den != null:
			if abed:
				if c.roosting: continue
				var rx: float = den.x - g.position.x; var rz: float = den.z - g.position.z; var rd := sqrt(rx * rx + rz * rz)
				if rd < (0.45 if c.type == "hen" else 1.2):
					c.roosting = true; g.visible = false; c.lod = -1; continue
				c.dir = Vector3(rx / rd, 0, rz / rd); c.speed = spec.walk * 1.4; c.state = "walk"
				g.position.x += c.dir.x * c.speed * dt; g.position.z += c.dir.z * c.speed * dt; g.position.y = Terrain.get_height(g.position.x, g.position.z)
				c.puppet.update(dt, c.speed, c.state, c.dir.dot(cam_right) < 0.0, atan2(cam.x - g.position.x, cam.z - g.position.z))
				continue
			elif c.roosting:
				c.roosting = false; g.visible = true
				g.position = Vector3(den.x + (rng.next() - 0.5) * 1.5, Terrain.get_height(den.x, den.z), den.z + (rng.next() - 0.5) * 1.5)
				c.lod = -1; c.state = "idle"; c.timer = 1.0 + rng.next() * 3.0
		if c.type == "deer" and not c.spotted and dist < 12.0:
			c.spotted = true
			if on_spotted.is_valid(): on_spotted.call(c)
		if c.type == "bison" and not herd_seen and dist < 26.0:
			herd_seen = true
			if on_herd.is_valid(): on_herd.call(c)
		if dist < spec.flee and c.state != "flee":
			c.state = "flee"; c.timer = 0.8 if c.type == "hen" else 2.6
			c.dir = to_p.normalized().rotated(Vector3.UP, (rng.next() - 0.5) * 0.8)
		c.timer -= dt
		if c.state == "idle" and c.timer <= 0.0:
			var a := rng.next() * TAU; var d: float = 1.5 + rng.next() * spec.range
			c.target = Vector3(c.home.x + cos(a) * d, 0, c.home.z + sin(a) * d)
			c.state = "walk"
		var speed := 0.0
		if c.state == "walk":
			var to: Vector3 = c.target - g.position; to.y = 0
			if to.length() < 0.3: c.state = "idle"; c.timer = 1.0 + rng.next() * 4.0
			else: c.dir = to.normalized(); speed = spec.walk
		elif c.state == "flee":
			speed = spec.run
			if c.timer <= 0.0:
				c.state = "idle"; c.timer = 1.0 + rng.next() * 2.0
				if not (c.type in FARM): c.home = g.position
		c.speed += (speed - c.speed) * minf(1.0, dt * 6.0)
		if c.speed > 0.01:
			var nx: float = g.position.x + c.dir.x * c.speed * dt; var nz: float = g.position.z + c.dir.z * c.speed * dt
			if Terrain.is_water(nx, nz): c.dir = -c.dir; c.state = "idle"; c.timer = 0.5
			else: g.position.x = nx; g.position.z = nz
		# far ones (lost in the haze) hidden; mid-distance ones cast no shadow
		var cd2 := (cam.x - g.position.x) * (cam.x - g.position.x) + (cam.z - g.position.z) * (cam.z - g.position.z)
		var lod := 2 if cd2 > 55.0 * 55.0 else (1 if cd2 > 22.0 * 22.0 else 0)
		if lod != c.lod:
			c.lod = lod; g.visible = lod < 2
			_shadows(g, lod == 0)
		if lod == 2: continue
		g.position.y = Terrain.get_height(g.position.x, g.position.z)
		c.puppet.update(dt, c.speed, c.state, c.dir.dot(cam_right) < 0.0, atan2(cam.x - g.position.x, cam.z - g.position.z))
		# the rooster crowing at sunup: he stops, draws himself up and throws his head back
		if c.crowT > 0.0:
			c.crowT -= dt; c.speed = 0.0
			var k := minf(1.0, minf(c.crowT, 1.8 - c.crowT) * 4.0)
			c.puppet.head.rotation.z = 0.75 * k; c.puppet.rig.position.y += 0.04 * k; c.puppet.rig.rotation.z += 0.25 * k

func _shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D: (n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in n.get_children(): _shadows(ch, on)

## A beast struck by an arrow: down it goes, and the others of its kind nearby bolt.
func fell(c: Dictionary) -> void:
	c.state = "down"; c.timer = 0.0; c.speed = 0.0
	for o in list:
		if o != c and o.type == c.type and o.state != "down" and pos(o).distance_to(pos(c)) < 25.0:
			o.state = "flee"; o.timer = 3.0; var d := pos(o) - pos(c); d.y = 0; o.dir = d.normalized()

## The nearest cow or sheep within r metres (for milking and shearing).
func livestock_near(p: Vector3, r := 2.3):
	var best = null; var bd := r
	for c in list:
		if (c.type != "cow" and c.type != "sheep") or c.roosting: continue
		var d := Vector2(pos(c).x - p.x, pos(c).z - p.z).length()
		if d < bd: bd = d; best = c
	return best

func hold(c: Dictionary, seconds := 2.5) -> void: c.state = "idle"; c.timer = seconds; c.speed = 0.0
## A shorn sheep looks slimmer until its fleece grows back.
func set_shorn(c: Dictionary, shorn: bool) -> void:
	# (the web scales the paper body; where the sheep wears its model that body is hidden, so nothing shows)
	if c.puppet.body != null: c.puppet.body.scale = Vector3(0.86 if shorn else 1.0, 0.82 if shorn else 1.0, 1.0)
