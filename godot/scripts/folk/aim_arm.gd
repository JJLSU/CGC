class_name AimArm
extends SkeletonModifier3D
## A gunman's arm brought up to his mark (the player: when anybody shoots at you they should raise their hand with a
## gun): after the clip has posed him, the right upper arm and forearm are swung to point at the target, eased in
## fast, held a moment, eased back down. Times itself, so it works on a figure nobody updates (a robber in the saddle).

var arm := -1
var fore := -1
var hand := -1
var target := Vector3.ZERO   ## in the world
var hold := 0.0              ## seconds left up
var w := 0.0                 ## how far up, 0..1

## Bring the gun up at at (world) for sec.
func raise(at: Vector3, sec := 0.9) -> void: target = at; hold = maxf(hold, sec)

func _process_modification_with_delta(delta: float) -> void: _aim(delta)
func _process_modification() -> void: _aim(get_process_delta_time())

func _aim(dt: float) -> void:
	var sk := get_skeleton()
	if sk == null or arm < 0 or fore < 0 or hand < 0: return
	hold = maxf(0.0, hold - dt)
	w = move_toward(w, 1.0 if hold > 0.0 else 0.0, dt * (9.0 if hold > 0.0 else 3.0))
	if w <= 0.001:
		if holder != null and is_instance_valid(holder) and not holder.quaternion.is_equal_approx(Quaternion.IDENTITY): holder.quaternion = Quaternion.IDENTITY
		return
	var t_local := sk.global_transform.affine_inverse() * target
	_point(sk, arm, fore, t_local)
	_point(sk, fore, hand, t_local)
	_level_gun()

## The gun in the hand turned to point down the arm at the mark as it comes up (the player: those rifles are
## backwards; a rifle carried muzzle up at his side pointed back over his shoulder once the arm was raised), and back
## to how it's carried as the arm goes down. The held gun says which way its muzzle lies (meta "muzzle", its own frame).
var holder: Node3D = null
func _level_gun() -> void:
	if holder == null or not is_instance_valid(holder): return
	var mz := Vector3.ZERO
	for c in holder.get_children():
		if c is Node3D and c.has_meta("muzzle"): mz = (c as Node3D).transform.basis * (c.get_meta("muzzle") as Vector3); break
	if mz.length_squared() < 1e-8: return
	var q := Quaternion(mz.normalized(), Vector3(0, 1, 0)) # (the hand's +y runs down the fingers: along the raised arm)
	holder.quaternion = Quaternion.IDENTITY.slerp(q, w)

## Turn bone b (in its parent's frame) so the line from it to its child c points at t (skeleton space), by w.
func _point(sk: Skeleton3D, b: int, c: int, t: Vector3) -> void:
	var gb := sk.get_bone_global_pose(b); var gc := sk.get_bone_global_pose(c)
	var now := (gc.origin - gb.origin); var want := (t - gb.origin)
	if now.length_squared() < 1e-8 or want.length_squared() < 1e-8: return
	var q := Quaternion(now.normalized(), want.normalized())
	q = Quaternion.IDENTITY.slerp(q, w)
	var g_new := Basis(q) * gb.basis
	var p := sk.get_bone_parent(b)
	var pb: Basis = sk.get_bone_global_pose(p).basis if p >= 0 else Basis()
	sk.set_bone_pose_rotation(b, (pb.inverse() * g_new).get_rotation_quaternion())

## The modifier on fig's skeleton (made the first time), or null if it has no right arm.
static func on(fig: ModelFigure) -> AimArm:
	if fig == null or fig.skeleton == null: return null
	for c in fig.skeleton.get_children(): if c is AimArm: return c
	var h := fig.skeleton.find_bone("RightHand")
	if h < 0: return null
	var f := fig.skeleton.get_bone_parent(h); var a := fig.skeleton.get_bone_parent(f) if f >= 0 else -1
	if a < 0: return null
	var m := AimArm.new(); m.arm = a; m.fore = f; m.hand = h
	if fig.hands.size() > 1: m.holder = fig.hands[1]
	fig.skeleton.add_child(m)
	return m
