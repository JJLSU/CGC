class_name HorseRace
extends Node3D
## The horse race: out past the south end of town a starting post with a red pennant, and a loop of six flagged posts
## round the open ground beyond it. By day Dusty Jake waits at the post on his paint horse; ride up on Biscuit and
## race him round the flags for a $5 stake (the winner takes $10). Each flag must be passed in turn, close by (the
## next one's pennant flies yellow and bobs); first back to the post wins. Get down, stray far off, or take too long
## and the race is his. He rides a little faster than Biscuit trots and a little slower than her gallop, so you must
## gallop (sprint) to beat him, and keep a line.

const FLAGS := 6
const PASS_R := 7.5        ## how near a flag counts as rounding it
const STAKE := 5
const JAKE := 15.6         ## his pace, m/s (Biscuit: 10.2 at a trot, 19.6 at a gallop; 1.25x with oats)
const TIME_LIMIT := 150.0
const RIVAL := ["cgc_man_suspenders", "cgc_man_goatee", "prospectors_1"]

var start := Vector3.ZERO  ## the starting post
var flags: Array = []      ## Vector3: the course, in order (back to start after the last)
var posts: Array = []      ## {post, pennant}
var start_post: Node3D
var jake: ModelFigure
var horse: Puppet
var jpos := Vector3.ZERO
var jake_next := 0         ## his next flag (FLAGS: the post)
var you_next := 0
var state := "idle"        ## idle, count, run, done
var t := 0.0
var wins := 0
var bob := 0.0
var _pen_mats := {}
var taken: Array = []     ## the world's spots kept for something (the town, the farm, the sites): {x, z, r}
var cum: Array = []        ## the course's length from the post to each flag in turn (and back to the post)

## Lay out the course off the south end of town: start the post; centre the loop's middle, away from town.
func setup(town: Town, world: World = null) -> void:
	var out := -town.along
	taken = world.exclusions.duplicate() if world != null else []
	# the post: out past the end of Squatters' Row, on open ground
	start = town.at + town.along * -74.0
	for k in 12:
		var q: Vector3 = town.at + town.along * (-74.0 - k * 6.0)
		if not Terrain.is_water(q.x, q.z) and not _taken(q, 4.0): start = q; break
	var best: Array = []; var best_bad := 1e9
	for turn in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]: # (straight out from town first, then swung round either way)
		var dir := out.rotated(Vector3.UP, turn)
		for r in [48.0, 40.0, 58.0, 34.0, 68.0]:
			for way in [1.0, -1.0]:
				var c: Vector3 = start + dir * (r + 4.0)
				var a0 := atan2(start.z - c.z, start.x - c.x)
				var list: Array = []
				for i in FLAGS:
					var a: float = a0 + (i + 1) * TAU / (FLAGS + 1) * way
					list.append(Vector3(c.x + cos(a) * r, 0, c.z + sin(a) * r))
				var bad: int = _bad(list) + (0 if _clear_of_town(list, town) else 1000) + list.filter(func(f): return _taken(f, 5.0)).size() * 6
				if bad < best_bad: best_bad = bad; best = list
				if bad == 0: break
			if best_bad == 0: break
		if best_bad == 0: break
	flags = best
	for i in flags.size(): flags[i].y = Terrain.get_height(flags[i].x, flags[i].z)
	start.y = Terrain.get_height(start.x, start.z)
	cum = [0.0]; var prev := start
	for f in flags + [start]: cum.append(cum[-1] + Vector2(f.x - prev.x, f.z - prev.z).length()); prev = f
	cum.remove_at(0)
	if world != null: for q in [start] + flags: world.exclusions.append({"x": q.x, "z": q.z, "r": 4.0}) # (no tree grows up through a flag)
	start_post = _post(start, true)
	for f in flags: posts.append(_post(f, false))
	# Dusty Jake and his paint horse, by the post
	var nm: String = "prospectors_1"
	for n in RIVAL: if ModelFigure.has_folk(n): nm = n; break
	jake = ModelFigure.new(nm, {"hue": 0.0}); add_child(jake.root)
	horse = Puppet.new("horse", 1.7); add_child(horse.group)
	jpos = start + town.toward * 3.0; jpos.y = Terrain.get_height(jpos.x, jpos.z)
	_place_jake(0.0, 0.0, null)

## Every flag well off the streets (out past the town's ends and sides).
func _clear_of_town(list: Array, town: Town) -> bool:
	for f in list:
		var rel: Vector3 = f - town.at
		if rel.dot(town.along) > -68.0 and rel.dot(town.along) < 60.0 and absf(rel.dot(town.toward)) < 70.0: return false
	return true

func _taken(q: Vector3, pad: float) -> bool:
	for e in taken: if Vector2(q.x - e.x, q.z - e.z).length() < float(e.r) + pad: return true
	return false

## How much of the course runs over water or ground too steep (sampled every 4 m round the loop).
func _bad(list: Array) -> int:
	var n := 0; var pts: Array = [start] + list + [start]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]; var k := int(a.distance_to(b) / 4.0)
		for j in k:
			var q := a.lerp(b, float(j) / maxf(1, k))
			if Terrain.is_water(q.x, q.z) or Terrain.impassable(q.x, q.z): n += 1
	return n

func _post(at: Vector3, is_start: bool) -> Node3D:
	var g := Node3D.new(); g.position = at; add_child(g)
	var p := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.09; cm.height = 3.2; p.mesh = cm
	p.material_override = PaperMats.paper(Color("e8dcc0") if is_start else Color("8a5e36")); p.position.y = 1.6; g.add_child(p)
	var pen := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(0.9, 0.6, 0.03); pen.mesh = pm
	pen.rotation.z = -PI / 2.0; pen.position = Vector3(0.48, 2.85, 0); g.add_child(pen)
	pen.material_override = _mat("start" if is_start else "flag")
	if is_start: # (a crossbar and a second pennant: the finish line)
		var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.08, 1.4); bar.mesh = bm
		bar.material_override = PaperMats.paper(Color("e8dcc0")); bar.position = Vector3(0, 2.4, 0); g.add_child(bar)
	g.set_meta("pennant", pen)
	return g

func _mat(k: String) -> Material:
	if not _pen_mats.has(k): _pen_mats[k] = PaperMats.paper(Color({"start": "b8402e", "flag": "3e6a8a", "next": "e8b83a", "done": "d8cfbe"}[k]))
	return _pen_mats[k]

func _place_jake(dt: float, speed: float, face) -> void:
	horse.group.position = jpos
	horse.update(dt, speed * 0.8, "chase" if speed > 4.0 else ("walk" if speed > 0.2 else "idle"), false, 0.0, 0.0)
	jake.root.position = jpos
	jake.play("sit", 0.2); NativeCamps.astride(jake); NativeCamps.seat(horse, jake)

## He's about (by day, or while a race runs).
## The stake a side for the next race: $5, then doubled after each win, $20 at most.
func stake() -> int: return STAKE * (1 << mini(wins, 2))
## His pace for the next race: a touch harder each time he's lost to you.
func pace0() -> float: return JAKE * (1.0 + 0.03 * mini(wins, 4))

func shown(sky_time: float) -> bool: return state != "idle" or (sky_time > 0.28 and sky_time < 0.76)
func near_post(p: Vector3, r := 7.0) -> bool: return Vector2(p.x - start.x, p.z - start.z).length() < r

## Off they go: the stake taken by main; a three-count first.
func begin() -> void:
	state = "count"; t = 3.0; jake_next = 0; you_next = 0
	jpos = start + ((flags[0] as Vector3) - start).normalized().cross(Vector3.UP) * 2.5; jpos.y = Terrain.get_height(jpos.x, jpos.z)

## Each frame. hooks: on_count(n), on_go(), on_flag(i, behind_m), on_end(won, why)
func update(dt: float, player: Player, riding: bool, sky_time: float, hooks: Dictionary) -> void:
	if flags.is_empty(): return
	var on := shown(sky_time)
	jake.root.visible = on; horse.group.visible = on
	bob += dt
	for i in posts.size():
		var pen: MeshInstance3D = posts[i].get_meta("pennant")
		var k := "flag"
		if state == "run" or state == "count": k = "next" if i == you_next else ("done" if i < you_next else "flag")
		pen.material_override = _mat(k)
		pen.position.y = 2.85 + (sin(bob * 6.0) * 0.12 if k == "next" else 0.0)
	if not on: return
	match state:
		"idle", "done":
			# back to the post at a walk, and wait there
			var home: Vector3 = start + (start - (flags[0] as Vector3)).normalized().cross(Vector3.UP) * 3.0
			var d := Vector3(home.x - jpos.x, 0, home.z - jpos.z)
			var spd := 0.0
			if d.length() > 0.4: spd = 3.0; jpos += d.normalized() * minf(spd * dt, d.length())
			jpos.y = Terrain.get_height(jpos.x, jpos.z); _place_jake(dt, spd, null)
			if state == "done": t -= dt; if t <= 0.0: state = "idle"
		"count":
			var n0 := ceili(t); t -= dt; var n1 := ceili(t)
			if n1 != n0 and n1 > 0 and hooks.has("on_count"): hooks.on_count.call(n1)
			_place_jake(dt, 0.0, null)
			if t <= 0.0:
				state = "run"; t = 0.0
				if hooks.has("on_go"): hooks.on_go.call()
		"run":
			t += dt
			# Jake: flag to flag, at his pace (a touch of give: a little quicker when you're ahead, easier when far behind)
			var tgt: Vector3 = flags[jake_next] if jake_next < FLAGS else start
			var lead := _progress(you_next, player.pos) - _progress(jake_next, jpos)
			var pace := pace0() * (1.0 + 0.05 * sin(t * 0.7)) * (1.06 if lead > 8.0 else (0.92 if lead < -40.0 else 1.0))
			var d := Vector3(tgt.x - jpos.x, 0, tgt.z - jpos.z)
			jpos += d.normalized() * minf(pace * dt, d.length()); jpos.y = Terrain.get_height(jpos.x, jpos.z)
			if d.length() < 2.0:
				jake_next += 1
				if jake_next > FLAGS: _end(false, "jake", hooks); return
			_place_jake(dt, pace, null)
			# you
			var yt: Vector3 = flags[you_next] if you_next < FLAGS else start
			if Vector2(player.pos.x - yt.x, player.pos.z - yt.z).length() < PASS_R:
				you_next += 1
				if you_next > FLAGS: _end(true, "", hooks); return
				if hooks.has("on_flag"): hooks.on_flag.call(you_next, -lead)
			if not riding: _end(false, "down", hooks)
			elif t > TIME_LIMIT: _end(false, "slow", hooks)
			elif _off_course(player.pos): _end(false, "astray", hooks)

## Metres of course covered: as far as the next flag, less the way still to go to it.
func _progress(next: int, p: Vector3) -> float:
	var tgt: Vector3 = flags[next] if next < FLAGS else start
	return float(cum[mini(next, cum.size() - 1)]) - Vector2(tgt.x - p.x, tgt.z - p.z).length()

func _off_course(p: Vector3) -> bool:
	var c := Vector3.ZERO
	for f in flags: c += f
	c /= flags.size()
	return Vector2(p.x - c.x, p.z - c.z).length() > 190.0

func _end(won: bool, why: String, hooks: Dictionary) -> void:
	state = "done"; t = 6.0
	var pot := stake() * 2
	if won: wins += 1
	if hooks.has("on_end"): hooks.on_end.call(won, why, pot)
