class_name TrainRobbers
extends Node3D
## The train robbers (the player's train you can ride, the outlaws, the shotgun): now and then, once she's well out
## on the line with you aboard, a gang of three or four outlaws comes galloping up from behind and rides alongside,
## either side of the open car, firing at you as they keep pace. Shoot them out of the saddle from the car (they
## sit a little off the track: a revolver needs two hits, the shotgun's spread knocks one down at a blow up close).
## Bring them all down and the railroad pays a bounty when she's home; get off, or let her turn for home, and the
## ones still up wheel away. A rider shot down falls in the grass beside the line and his horse runs off.

const SIDE := 6.5          ## how far off the track they ride, either side
const HP := 9
const HIT := 12            ## a bullet that finds you
const HIT_CHANCE := 0.35
const COOL := Vector2(2.6, 4.2) ## seconds between a rider's shots
const GALLOP := 11.0       ## catching up
const FIRE_R := 22.0       ## they fire from this close
const BOUNTY := 12         ## dollars a head, paid by the railroad
const EVERY := 2           ## days at least between robberies

var men: Array = []        ## {fig, horse: Puppet, side, ahead, hp, dead, cool, pos, hurt}
var active := false
var last_day := -99
var downed := 0            ## shot down on this run (paid when she's home)
var owed := 0

## A gang rides up behind the train: count men, from behind the open car.
func start(train: Train, count := 3) -> void:
	clear()
	active = true; downed = 0
	var car := train.ride_car()
	var fwd := _fwd(car); var side := fwd.cross(Vector3.UP).normalized()
	var have: Array = ClaimJumpers.OUTLAWS.filter(func(n): return ModelFigure.has_folk(n)); have.shuffle()
	for i in count:
		var sd := 1.0 if i % 2 == 0 else -1.0
		var p: Vector3 = car.global_position - fwd * (40.0 + i * 7.0) + side * sd * SIDE
		p.y = Terrain.get_height(p.x, p.z)
		var h := Puppet.new("horse", 1.7); h.group.position = p; add_child(h.group)
		var nm: String = have[i % have.size()] if have.size() else "prospectors_1"
		var fig := ModelFigure.new(nm, {"hue": 0.0})
		var g := Boss._colt_mesh(0.5); g.position = Vector3(0, 0.02, 0.04); fig.hands[1].add_child(g) # (a Colt, barrel along the hand)
		fig.root.position = p; add_child(fig.root)
		men.append({"fig": fig, "horse": h, "side": sd, "ahead": -3.5 + i * 3.0, "hp": HP, "dead": 0.0, "cool": 2.0 + randf() * 2.0, "pos": p, "hurt": 0.0})

## Gone: the gang and their horses taken off the page.
func clear() -> void:
	for m in men:
		if is_instance_valid(m.fig.root): m.fig.root.queue_free()
		if is_instance_valid(m.horse.group): m.horse.group.queue_free()
	men = []; active = false

func up() -> Array: return men.filter(func(m): return not m.dead)

static func _fwd(car: Node3D) -> Vector3:
	var f := car.global_basis.z; f.y = 0.0
	return f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD

## For the bullets: {pos, r, h, rob}.
func targets() -> Array:
	var out := []
	for m in men: if not m.dead: out.append({"pos": m.pos, "r": 1.0, "h": 3.0, "rob": m})
	return out

## A wound; true if he fell. hooks: on_fall(man)
func damage(m: Dictionary, n: int, hooks: Dictionary) -> bool:
	if m.dead: return false
	m.hp -= n; m.hurt = 0.3
	if m.hp > 0: return false
	m.dead = 0.001; downed += 1
	m.fig.play("idle", 0.1)
	if hooks.has("on_fall"): hooks.on_fall.call(m)
	return true

## Where he rides beside the car: his side of the line, SIDE off; nearer in if that's water or a steep bank; else the
## other side; else on the right-of-way itself, behind the last car (never across a lake or up a hillside).
func _spot(cp: Vector3, fwd: Vector3, side: Vector3, m: Dictionary) -> Vector3:
	var ty := cp.y
	for sd in [m.side, -m.side]:
		for off in [SIDE, 4.6]:
			var q: Vector3 = cp + fwd * m.ahead + side * sd * off
			var gy := Terrain.get_height(q.x, q.z)
			if not Terrain.is_water(q.x, q.z) and absf(gy - ty) < 2.6 and not Terrain.impassable(q.x, q.z): return q
	return cp - fwd * (16.0 + absf(m.ahead) * 2.0)

## Each frame. riding: you're aboard and she's out on the line; hooks: on_shoot(from, at), on_hit(dmg), on_gone(beaten)
func update(dt: float, train: Train, player: Player, riding: bool, hooks: Dictionary) -> void:
	if men.is_empty(): return
	var car := train.ride_car()
	var fwd := _fwd(car); var side := fwd.cross(Vector3.UP).normalized()
	var cp: Vector3 = car.global_position
	var leaving := not riding
	var all_down := up().is_empty()
	for m in men:
		var fig: ModelFigure = m.fig; var h: Puppet = m.horse
		if m.dead:
			# out of the saddle: he tumbles off on the side away from the train and lies in the grass; his horse runs on
			m.dead += dt
			if m.dead < 0.7:
				fig.root.position.y = lerpf(fig.root.position.y, Terrain.get_height(fig.root.position.x, fig.root.position.z), minf(1.0, dt * 5.0))
				fig.root.position += side * m.side * dt * 2.0
			fig.root.rotation.x = -minf(1.0, m.dead / 0.6) * PI / 2.0 * 0.95
			var hp: Vector3 = h.group.position + (fwd * 0.6 + side * m.side * 0.8).normalized() * 9.0 * dt
			hp.y = Terrain.get_height(hp.x, hp.z); h.group.position = hp; h.update(dt, 7.0, "flee", false, 0.0, 0.0)
			fig.update(dt, 0.0, null)
			continue
		var want: Vector3
		if leaving: want = m.pos - fwd * 30.0 + side * m.side * 12.0 # (they wheel off and fall behind)
		else: want = _spot(cp, fwd, side, m)
		var d: Vector3 = want - m.pos; d.y = 0.0
		var spd := minf(GALLOP, maxf(train.SPEED * 0.6, d.length() * 1.5)) if not leaving else 8.0
		var step := d.normalized() * minf(spd * dt, d.length()) if d.length() > 0.01 else Vector3.ZERO
		m.pos += step; m.pos.y = Terrain.get_height(m.pos.x, m.pos.z)
		h.group.position = m.pos
		var v := step.length() / maxf(dt, 1e-4)
		h.update(dt, v * 0.8, "chase" if v > 4.0 else "walk", false, 0.0, 0.0)
		fig.root.position = m.pos
		var aim: Vector3 = player.pos - m.pos
		var dp := Vector2(aim.x, aim.z).length()
		m.cool -= dt
		var act = null
		if not leaving and dp < FIRE_R and m.cool <= 0.0 and not player.dead:
			m.cool = randf_range(COOL.x, COOL.y); act = "attack"
			var hit := randf() < HIT_CHANCE
			var aa := AimArm.on(fig); if aa: aa.raise(player.pos + Vector3(0, 1.3, 0)) # (the gun hand up at you)
			if hooks.has("on_shoot"): hooks.on_shoot.call(m.pos + Vector3(0, 2.4, 0), player.pos)
			if hit and hooks.has("on_hit"): hooks.on_hit.call(HIT)
		fig.play(act if act != null else "sit", 0.2)
		if act == null: NativeCamps.astride(fig)
		NativeCamps.seat(h, fig)
		if dp < FIRE_R * 1.4 and not leaving: fig.root.rotation.y = lerp_angle(fig.root.rotation.y, atan2(aim.x, aim.z), minf(1.0, dt * 4.0)) # (turned in the saddle toward you)
	if leaving and (all_down or men.all(func(m): return m.dead or Vector2(m.pos.x - cp.x, m.pos.z - cp.z).length() > 60.0)):
		var beaten := all_down
		owed += downed * BOUNTY
		clear()
		if hooks.has("on_gone"): hooks.on_gone.call(beaten)
