class_name Player
extends RefCounted
## player.js: the third-person traveller. Free look (the mouse turns the camera, the wheel zooms 2.5..42), WASD
## relative to the camera, a sprint on stamina (Shift), jumping (Space), hunger and slow healing, wading slowly
## through shallow water (deep water and the mountains' steep sides turn you back along the bank), swimming, slopes
## that slow you, collisions with trunks, rocks and the world's colliders, and turning to face the way he walks.
## (Climbing, riding, decks and built floors hook in with their systems: climbs, build, riding flags.)

const WALK := 6.0
const SPRINT := 11.5
const SWIM := 2.6
const JUMP := 7.4
const GRAVITY := 22.0
const SWIM_DEPTH := 1.15
const REACH := 2.1

var avatar: Avatar
var rig: CameraRig
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var vel_y := 0.0
var on_ground := true
var swimming := false
var wading := false
var facing := 0.0
var max_stamina := 200.0
var stamina := 100.0
var stamina_boost := 0.0
var fullness := 70.0
var stamina_rest := 0.0
var health := 100.0
var max_health := 100.0
var hurt_timer := 0.0
var dead := false
var events: Array = []     ## "jump" | "land" | "splash", drained by the game loop for sound
# flags other systems set
var thrift := 1.0          ## leather boots: 0.67
var warm := false
var chilled := false
var riding := false
var oats_fed := false
var mount_k := 1.0        ## the horse's own pace (Domino, Dusty Jake's bay: 1.15)
var aiming := false
var ice_on := false
var on_ice := false
var on_deck := false
var build = null           ## BuildSystem: surface_at(x, z, y), collide(pos)
var climbs = null
var climbing = null     ## a climb under way: {pts, len, dur, face, t} (climb.js)

func _init(scene: Node3D, camera_rig: CameraRig, spawn: Vector3) -> void:
	rig = camera_rig
	avatar = Avatar.new()
	scene.add_child(avatar.root)
	pos = spawn

## Terrain height, or a built floor/stair surface he can step onto.
func ground_at(x: float, z: float) -> float:
	var t := Terrain.get_height(x, z)
	if ice_on and t < Terrain.WATER_LEVEL + 0.04: t = Terrain.WATER_LEVEL + 0.04
	if climbs: t = maxf(t, climbs.surface_at(x, z, pos.y))
	return maxf(t, build.surface_at(x, z, pos.y)) if build else t

func forward() -> Vector3: return rig.forward()

func update(dt: float, input: GameInput, world: World, active: bool) -> Dictionary:
	# --- look (the camera is entirely yours)
	if active:
		rig.yaw -= input.dx * 0.0024
		rig.pitch = clampf(rig.pitch + input.dy * 0.0022, -1.2 if rig.first_person else -0.45, 1.53) # (through his eyes you can look up at the sky)
		if not rig.first_person: rig.dist = clampf(rig.dist * (1.0 + input.wheel * 0.12), 2.5, 42.0)
	else: rig.yaw += dt * 0.05
	# --- climbing a ladder (or scrambling up rock): carried along the climb's path, nothing else to do meanwhile
	if climbing != null:
		var c: Dictionary = climbing; c.t += dt
		pos = Climbs.along_path(c.pts, c.len, minf(1.0, c.t / c.dur))
		vel = Vector3.ZERO; vel_y = 0.0; on_ground = true
		var dfc: float = c.face - facing; dfc = atan2(sin(dfc), cos(dfc)); facing += dfc * minf(1.0, dt * 12.0)
		if c.t >= c.dur: climbing = null
		var con := avatar.update(dt, 1.6, false, false) # (hand over hand: the walk cycle reads as climbing)
		avatar.root.position = pos; avatar.root.rotation.y = facing
		return {"connected": con, "sprinting": false}
	# up on a deck: the world's ground-level colliders don't reach up here; a railed deck keeps you on it
	var up_on = climbs.standing(pos) if climbs else null
	# --- move intent
	var f := forward()
	var r := Vector3(-f.z, 0, f.x)
	var wish := Vector3.ZERO
	if active:
		if input.down("KeyW"): wish += f
		if input.down("KeyS"): wish -= f
		if input.down("KeyD"): wish += r
		if input.down("KeyA"): wish -= r
	var moving := wish.length_squared() > 0.0
	if moving: wish = wish.normalized()
	var ground := ground_at(pos.x, pos.z)
	swimming = ground < Terrain.WATER_LEVEL - SWIM_DEPTH and pos.y <= Terrain.WATER_LEVEL - SWIM_DEPTH + 0.3
	# --- health: heals slowly once left alone a while (faster by a fire), only with something in your belly
	hurt_timer -= dt
	if not dead and hurt_timer <= 0.0 and fullness >= 30.0 and not chilled and health < max_health: health = minf(max_health, health + dt * (5.0 if warm else 1.5))
	# --- stamina / sprint / hunger
	stamina_boost = maxf(0.0, stamina_boost - dt)
	max_stamina = 300.0 if stamina_boost > 0.0 else 200.0
	var wants_sprint := active and moving and input.down("ShiftLeft") and not swimming
	var sprinting := wants_sprint and stamina > 1.0
	if sprinting:
		stamina -= 11.0 * dt * thrift; stamina_rest = 0.6
	else:
		stamina_rest -= dt
		if stamina_rest <= 0.0: stamina += 34.0 * dt * (2.0 if warm else 1.0) * (0.5 if chilled else 1.0)
	fullness = maxf(0.0, fullness - dt * (0.19 if sprinting else 0.09) * (1.5 if chilled else 1.0))
	if fullness < 10.0: max_stamina = minf(max_stamina, 100.0)
	if fullness <= 0.0 and not dead and health > 20.0: health = maxf(20.0, health - dt * 0.3)
	stamina = clampf(stamina, 0.0, max_stamina)
	var speed := (SWIM if swimming else (SPRINT if sprinting else WALK)) * ((1.7 * mount_k * (1.25 if oats_fed else 1.0)) if riding and not swimming else 1.0)
	if wading: speed *= (0.8 - 0.15 * Terrain.wade_depth(pos.x, pos.z)) if riding else (0.6 - 0.2 * Terrain.wade_depth(pos.x, pos.z))
	if avatar.swing >= 0.0: speed *= 0.45
	if moving and on_ground: # steep uphill slows you down
		var ahead := ground_at(pos.x + wish.x * 0.6, pos.z + wish.z * 0.6)
		speed *= clampf(1.35 - (ahead - ground) / 0.6 * (0.2 if riding else 0.35), 0.5 if riding else 0.3, 1.0) # (a horse takes a hill in its stride)
	var k := 1.0 - exp(-((3.2 if moving else 0.45) if (on_ice and on_ground) else (12.0 if (on_ground or swimming) else 3.0)) * dt)
	vel.x += (wish.x * speed - vel.x) * k
	vel.z += (wish.z * speed - vel.z) * k
	var prev_x := pos.x; var prev_z := pos.z
	pos.x += vel.x * dt; pos.z += vel.z * dt
	if up_on == null: collide(world)
	else: pos = climbs.keep_on(pos, prev_x, prev_z, up_on)
	var deck := func(x: float, z: float) -> bool: return (build != null and build.surface_at(x, z, pos.y) > -INF) or (climbs != null and climbs.surface_at(x, z, pos.y) > -INF)
	on_deck = Terrain.is_water(pos.x, pos.z) and deck.call(pos.x, pos.z)
	on_ice = ice_on and Terrain.is_water(pos.x, pos.z) and not on_deck
	var steep: float = Terrain.HORSE_STEEP if riding else Terrain.STEEP; var ford: float = Terrain.HORSE_WADE if riding else 4.0 # (mounted, deeper fords and steeper ground)
	var deep := func(x: float, z: float) -> bool: return (Terrain.is_water(x, z) and not Terrain.wadeable(x, z, ford)) or Terrain.impassable(x, z, steep)
	if deep.call(pos.x, pos.z) and ((not on_deck and not ice_on) or Terrain.impassable(pos.x, pos.z, steep)):
		if not deep.call(pos.x, prev_z): pos.z = prev_z
		elif not deep.call(prev_x, pos.z): pos.x = prev_x
		else: pos.x = prev_x; pos.z = prev_z
		on_deck = Terrain.is_water(pos.x, pos.z) and deck.call(pos.x, pos.z)
	wading = Terrain.is_water(pos.x, pos.z) and not on_deck and not on_ice
	# --- vertical (wading, his feet go down through the water sheet: shin-deep at the edge, waist-deep out)
	var g2 := ground_at(pos.x, pos.z) - ((0.3 + 0.5 * Terrain.wade_depth(pos.x, pos.z)) if wading else 0.0)
	if swimming:
		var target := Terrain.WATER_LEVEL - SWIM_DEPTH
		pos.y += (target + sin(Time.get_ticks_msec() * 0.003) * 0.05 - pos.y) * minf(1.0, dt * 6.0)
		vel_y = 0.0
		if g2 > target: pos.y = g2; on_ground = true
		else: on_ground = false
	else:
		if active and on_ground and input.hit("Space") and stamina > 5.0:
			vel_y = JUMP; on_ground = false; stamina -= 5.0; stamina_rest = 0.4; events.append("jump")
		vel_y -= GRAVITY * dt
		pos.y += vel_y * dt
		if pos.y <= g2:
			if not on_ground and vel_y < -6.0: events.append("land")
			pos.y = g2; vel_y = 0.0; on_ground = true
		elif on_ground and vel_y <= 0.0 and pos.y - g2 < 0.45: pos.y = g2; vel_y = 0.0
		else: on_ground = false
		if g2 < Terrain.WATER_LEVEL - SWIM_DEPTH and pos.y < Terrain.WATER_LEVEL - SWIM_DEPTH:
			pos.y = Terrain.WATER_LEVEL - SWIM_DEPTH; vel_y = 0.0; events.append("splash")
	# --- facing
	var hs := Vector2(vel.x, vel.z).length()
	var target_facing := facing
	if avatar.swing >= 0.0 or aiming: target_facing = atan2(f.x, f.z)
	elif hs > 0.4: target_facing = atan2(vel.x, vel.z)
	var d := target_facing - facing
	d = atan2(sin(d), cos(d))
	facing += d * minf(1.0, dt * 12.0)
	var connected := avatar.update(dt, hs, not on_ground and not swimming, swimming)
	avatar.root.position = pos
	avatar.root.rotation.y = facing
	return {"connected": connected, "sprinting": sprinting}

## Take damage (armour softens it). True if this blow knocked the farmer out.
func hurt(amount: float, armour := 0.0) -> bool:
	if dead: return false
	health -= amount * (1.0 - armour)
	hurt_timer = 6.0
	if health <= 0.0:
		health = 0.0; dead = true; return true
	return false

func collide(world: World) -> void:
	var near := []
	for res in world.resources_near(pos.x, pos.z, 1.5):
		if res.type in Res.WALK_THROUGH: continue
		near.append({"x": res.x, "z": res.z, "r": float(Res.TYPES[res.type].radius) * res.scale})
	near.append_array(world.colliders)
	for c in near:
		var rad: float = c.r + 0.3
		var dx: float = pos.x - c.x; var dz: float = pos.z - c.z
		var dd := sqrt(dx * dx + dz * dz)
		if dd < rad and dd > 1e-4:
			pos.x = c.x + (dx / dd) * rad; pos.z = c.z + (dz / dd) * rad
	if build: pos = build.collide(pos)

## The resource he'd hit: the nearest alive one in front, within reach (grass only when nothing better is).
func find_target(world: World):
	var f := forward()
	var best = null; var best_d := INF
	for res in world.resources_near(pos.x, pos.z, REACH):
		var dx: float = res.x - pos.x; var dz: float = res.z - pos.z
		var dd := sqrt(dx * dx + dz * dz)
		var def: Dictionary = Res.TYPES[res.type]
		var edge: float = dd - float(def.radius) * res.scale
		if edge > REACH: continue
		var dot := (dx * f.x + dz * f.z) / dd if dd > 0.01 else 1.0
		if dot < 0.25: continue
		var score := edge + (1.2 if def.get("minor", false) else 0.0)
		if score < best_d: best_d = score; best = res
	return best
