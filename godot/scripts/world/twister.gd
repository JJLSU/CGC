class_name Twister
extends Node3D
## A twister on the prairie (the player's three paper tornado frames: a flat cut-out print, its three frames turned
## like a flip-book so it seems to churn). Some thunderstorms bring one: it drops out of the clouds well off across the
## county, wanders over the open land at a trot (a rider can outrun it, a man on foot only just), tossing paper scraps
## from its foot, and after a minute and a half lifts back into the sky. Caught in it, you're picked up and thrown
## clear (a knock to your health); close by, it draws you in. The card turns to face you and leans a little as it goes.

const H := 26.0                       ## its height, m (the frames are 504 x 748)
const W := H * 504.0 / 748.0
const SPEED := 5.2                    ## m/s (a farmer walks 6, rides 12)
const LIFE := 95.0                    ## s on the ground
const CATCH_R := 5.5                  ## caught within this of its foot
const PULL_R := 26.0                  ## drawn toward it within this
const FRAME_T := 0.11                 ## s a frame
const SCRAPS := [0xb79a72, 0x8c8478, 0xd8c3a0, 0x6f665c]

var card: MeshInstance3D
var mats: Array = []
var pos := Vector3.ZERO
var dir := Vector3.FORWARD
var aim := Vector3.ZERO
var t := 0.0
var _frame_t := 0.0
var _frame := 0
var _step := 1
var _scrap_t := 0.0
var _throw_cool := 0.0
var drop := 1.0                       ## 1 high in the clouds .. 0 on the ground (touching down, lifting off)
var gone := false

func _init() -> void:
	for i in 3:
		var tex: Texture2D = load("res://assets/baked/tornado/tornado_%d.png" % (i + 1))
		mats.append(PaperMats.card(tex, {"snow": 0.0, "alpha_cut": 0.5, "pulp": 0.45}))
	var q := QuadMesh.new(); q.size = Vector2(W, H); q.center_offset = Vector3(0, H / 2.0, 0)
	card = MeshInstance3D.new(); card.mesh = q; card.material_override = mats[0]; card.extra_cull_margin = 40.0
	add_child(card)

## Touch down at p, heading for aim (a point it will wander toward, then on past).
func start(p: Vector3, toward: Vector3) -> void:
	pos = p; aim = toward; dir = Vector3(toward.x - p.x, 0, toward.z - p.z).normalized(); t = 0.0; drop = 1.0; gone = false
	position = Vector3(pos.x, Terrain.get_height(pos.x, pos.z) + drop * 40.0, pos.z)

## Each frame: churn, wander, face the camera; what it does to the player: {"thrown": bool, "pull": Vector3}.
func update(dt: float, camera: Camera3D, player_pos: Vector3, on_scraps: Callable) -> Dictionary:
	t += dt; _throw_cool = maxf(0.0, _throw_cool - dt)
	# the flip-book: 1-2-3-2-1 ...
	_frame_t += dt
	if _frame_t >= FRAME_T:
		_frame_t = 0.0; _frame += _step
		if _frame == 2 or _frame == 0: _step = -_step
		card.material_override = mats[_frame]
	# touching down out of the clouds, and at the end lifting back up
	var want_drop := 1.0 if t > LIFE else 0.0
	drop = move_toward(drop, want_drop, dt / 3.0)
	if t > LIFE and drop >= 1.0: gone = true
	# wander: steer softly toward its aim, with a lazy weave; never into deep water or up the mountains
	var to := Vector3(aim.x - pos.x, 0, aim.z - pos.z)
	if to.length() < 12.0: aim = pos + dir * 200.0 # (past its mark: carry on the way it was going)
	var want := (to.normalized() + Vector3(-dir.z, 0, dir.x) * sin(t * 0.35) * 0.6).normalized()
	dir = dir.lerp(want, minf(1.0, dt * 0.4)).normalized()
	var nxt := pos + dir * SPEED * dt
	if Terrain.is_water(nxt.x, nxt.z) and not Terrain.wadeable(nxt.x, nxt.z, 3.0) or Terrain.impassable(nxt.x, nxt.z, 1.4):
		dir = Vector3(-dir.z, 0, dir.x); aim = pos + dir * 150.0
	else: pos = nxt
	var gy := Terrain.get_height(pos.x, pos.z)
	position = Vector3(pos.x, gy + ease(drop, 2.0) * 40.0, pos.z)
	# the flat print turns to face you, and leans into its going, rocking a little
	var cam := camera.global_position
	rotation.y = atan2(cam.x - pos.x, cam.z - pos.z)
	var side := Vector3(cos(rotation.y), 0, -sin(rotation.y)) # (the card's own right, on the ground)
	rotation.z = -dir.dot(side) * 0.09 + sin(t * 1.7) * 0.035
	# paper scraps whirled off its foot
	_scrap_t -= dt
	if drop < 0.3 and _scrap_t <= 0.0 and on_scraps.is_valid():
		_scrap_t = 0.18
		on_scraps.call(Vector3(pos.x, gy + 0.8, pos.z), SCRAPS)
	var out := {"thrown": false, "pull": Vector3.ZERO}
	if drop > 0.4: return out
	var off := Vector3(player_pos.x - pos.x, 0, player_pos.z - pos.z); var d := off.length()
	if d < CATCH_R and _throw_cool <= 0.0:
		_throw_cool = 4.0; out.thrown = true
	elif d < PULL_R and d > 0.1:
		out.pull = -off / d * lerpf(3.4, 0.4, d / PULL_R) # (drawn in: stronger the nearer)
	return out
