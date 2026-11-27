class_name Rattlers
extends Node3D
## Rattlesnakes in the Redrock Breaks (the player's giant rattlesnake model): coiled on the warm ground here and there,
## one to a spot of the land's own choosing (the same spots every visit). Come within a few paces and it rattles (a
## dry clicking and a word of warning); step closer and it strikes (a snakebite, 10, less in a coat), then thinks
## better of it and slithers off for the day. A blow from any tool kills it first, for its skin (a pelt).

const CELL := 34.0
const NEAR := 120.0
const RATTLE_R := 5.0
const STRIKE_R := 1.7
const LEN := 1.4             ## the coiled snake's span, m

var snakes := {}             ## cell key -> {node, pos, gone, rattle, strike, cool, coil}
var gone := {}               ## cell key -> day it left or was killed
var day := 0
var on_rattle: Callable      ## (snake pos): the first rattle as you come near
var on_strike: Callable      ## (snake pos): it bites
var _scene: PackedScene

func _init() -> void:
	if ResourceLoader.exists("res://assets/models/props/animal_rattlesnake.glb"): _scene = load("res://assets/models/props/animal_rattlesnake.glb")

## Is there a rattler's spot in this cell, and where: in the Breaks, on dry ground, one cell in three or so.
static func spot(cx: int, cz: int):
	var h := absi(hash(Vector2i(cx, cz) * 7919))
	if h % 3 != 0: return null
	var x := (cx + 0.2 + (h % 97) / 97.0 * 0.6) * CELL; var z := (cz + 0.2 + (h % 89) / 89.0 * 0.6) * CELL
	Terrain.land_at(x, z)
	if Terrain.L_w.get("breaks", 0.0) < 0.6 or Terrain.is_water(x, z) or Terrain.impassable(x, z): return null
	return Vector3(x, 0, z)

func update(dt: float, player: Player, today: int) -> void:
	if _scene == null: return
	day = today
	var pc := Vector2i(floori(player.pos.x / CELL), floori(player.pos.z / CELL)); var r := ceili(NEAR / CELL)
	var want := {}
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var key := "%d,%d" % [pc.x + dx, pc.y + dz]
			if gone.get(key, -1) == day: continue
			if snakes.has(key): want[key] = true; continue
			var p = spot(pc.x + dx, pc.y + dz)
			if p == null or Vector2(p.x - player.pos.x, p.z - player.pos.z).length() > NEAR: continue
			want[key] = true
			var n := PaperMats.seated(_scene, LEN, false, false)
			var q: Vector3 = p; q.y = Terrain.get_height(q.x, q.z)
			n.position = q; n.rotation.y = float(absi(hash(key)) % 628) / 100.0; add_child(n)
			snakes[key] = {"node": n, "pos": q, "rattle": 0.0, "strike": 0.0, "cool": 0.0, "warned": false, "face": n.rotation.y}
	for key in snakes.keys():
		if not want.has(key): (snakes[key].node as Node3D).queue_free(); snakes.erase(key)
	for key in snakes.keys():
		var s: Dictionary = snakes[key]; var n: Node3D = s.node
		n.visible = World.ground_ready(s.pos.x, s.pos.z) # (not coiled in mid-air before its ground is built)
		var to := Vector3(player.pos.x - s.pos.x, 0, player.pos.z - s.pos.z); var d := to.length()
		s.cool = maxf(0.0, s.cool - dt)
		if s.get("leaving", 0.0) > 0.0: # (slithering off)
			s.leaving -= dt; n.position += Vector3(-to.x, 0, -to.z).normalized() * dt * 2.2; n.scale = Vector3.ONE * maxf(0.05, s.leaving / 2.0)
			if s.leaving <= 0.0: gone[key] = day; n.queue_free(); snakes.erase(key)
			continue
		# it turns its head to you while you're near, and shivers (the rattle)
		if d < RATTLE_R * 1.6: n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 4.0))
		if d < RATTLE_R:
			s.rattle += dt
			n.rotation.z = sin(s.rattle * 55.0) * 0.025
			if not s.warned: s.warned = true; if on_rattle.is_valid(): on_rattle.call(s.pos)
		else: s.warned = false; n.rotation.z = 0.0
		# the strike: a lunge at you and back
		if s.strike > 0.0:
			s.strike -= dt
			var k := sin((1.0 - s.strike / 0.35) * PI)
			n.position = s.pos + to.normalized() * k * 0.9
			if s.strike <= 0.0: n.position = s.pos; s.leaving = 2.0
		elif d < STRIKE_R and s.cool <= 0.0 and not player.dead:
			s.strike = 0.35; s.cool = 3.0
			if on_strike.is_valid(): on_strike.call(s.pos)

## A blow from where you stand, facing f: kills the rattler within reach, if any; true if one was.
func hit(pos: Vector3, f: Vector3, reach: float) -> bool:
	for key in snakes.keys():
		var s: Dictionary = snakes[key]
		if s.get("leaving", 0.0) > 0.0: continue
		var to := Vector3(s.pos.x - pos.x, 0, s.pos.z - pos.z)
		if to.length() < reach + 0.6 and to.normalized().dot(f) > 0.3:
			gone[key] = day; (s.node as Node3D).queue_free(); snakes.erase(key); return true
	return false
