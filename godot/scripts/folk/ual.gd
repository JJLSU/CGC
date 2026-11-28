class_name UAL
## Quaternius's Universal Animation Library (CC0, assets/anims/ual: the player's ask for more animations, from more
## sources, when Meshy's credits ran out) retargeted onto the Meshy folk rigs. Its Rigify skeleton (DEF-hips,
## DEF-upper_arm.L, ...) is mapped bone for bone onto the Meshy one (Hips, LeftArm, ...). Each target bone takes the
## source bone's turn away from its rest, in the world, after first swinging the source's rest direction onto the
## target's (so an A-posed rest and a T-posed one line up). The hips carry the source's lift and sway, scaled by hip
## height. Baked at 30 fps into an ordinary Animation, once per model and clip (figures of one model share it).

const PATH := "res://assets/anims/ual/ual_standard.glb"
const FPS := 30.0
const MAP := {"DEF-hips": "Hips", "DEF-spine.001": "Spine02", "DEF-spine.002": "Spine01", "DEF-spine.003": "Spine",
	"DEF-neck": "neck", "DEF-head": "Head",
	"DEF-shoulder.L": "LeftShoulder", "DEF-upper_arm.L": "LeftArm", "DEF-forearm.L": "LeftForeArm", "DEF-hand.L": "LeftHand",
	"DEF-shoulder.R": "RightShoulder", "DEF-upper_arm.R": "RightArm", "DEF-forearm.R": "RightForeArm", "DEF-hand.R": "RightHand",
	"DEF-thigh.L": "LeftUpLeg", "DEF-shin.L": "LeftLeg", "DEF-foot.L": "LeftFoot", "DEF-toe.L": "LeftToeBase",
	"DEF-thigh.R": "RightUpLeg", "DEF-shin.R": "RightLeg", "DEF-foot.R": "RightFoot", "DEF-toe.R": "RightToeBase"}

static var _src = null       ## {skel: Skeleton3D, S: Transform3D, anims: {name: Animation}}
static var _frames := {}     ## clip -> Array of {bone_name: Transform3D (skeleton space)} per frame
static var _baked := {}      ## "model/clip" -> Animation

static func has_clip(clip: String) -> bool:
	_load()
	return _src != null and _src.anims.has(clip)

static func _load() -> void:
	if _src != null or not ResourceLoader.exists(PATH): return
	var n: Node = (load(PATH) as PackedScene).instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
	var anims := {}
	for a in ap.get_animation_list(): anims[String(a)] = ap.get_animation(a)
	_src = {"skel": sk, "S": _rel(sk, n), "anims": anims, "node": n}

## A node's transform relative to an ancestor (outside the tree).
static func _rel(node: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY; var c := node
	while c != null and c != top:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

## The source skeleton's bone globals (skeleton space) at time t of the clip.
static func _pose_at(anim: Animation, t: float) -> Dictionary:
	var sk: Skeleton3D = _src.skel
	var tr := {}
	for i in anim.get_track_count():
		var b := String(anim.track_get_path(i).get_concatenated_subnames())
		if b == "": continue
		if not tr.has(b): tr[b] = [-1, -1]
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D: tr[b][0] = i
			Animation.TYPE_POSITION_3D: tr[b][1] = i
	var glob := {}; var out := {}
	for bi in sk.get_bone_count():
		var nm := sk.get_bone_name(bi); var rest := sk.get_bone_rest(bi)
		var q := rest.basis.get_rotation_quaternion(); var p := rest.origin
		if tr.has(nm):
			if tr[nm][0] >= 0: q = anim.rotation_track_interpolate(tr[nm][0], t)
			if tr[nm][1] >= 0: p = anim.position_track_interpolate(tr[nm][1], t)
		var local := Transform3D(Basis(q), p)
		var par := sk.get_bone_parent(bi)
		var g: Transform3D = (glob[par] as Transform3D) * local if par >= 0 else local
		glob[bi] = g; out[nm] = g
	return out

static func _src_frames(clip: String) -> Array:
	if _frames.has(clip): return _frames[clip]
	var anim: Animation = _src.anims[clip]
	var n := maxi(2, ceili(anim.length * FPS) + 1)
	var fr := []
	for k in n: fr.append(_pose_at(anim, minf(anim.length, k / FPS)))
	_frames[clip] = fr
	return fr

## The clip retargeted onto this figure's rig (null if the library or the clip isn't there). Cached per model.
static func clip_for(model_name: String, skel: Skeleton3D, model_root: Node, track_prefix: String, clip: String) -> Animation:
	var key := model_name + "/" + clip
	if _baked.has(key): return _baked[key]
	_load()
	if _src == null or not _src.anims.has(clip): return null
	var ssk: Skeleton3D = _src.skel
	var SS: Transform3D = _src.S; var ST := _rel(skel, model_root)
	var SSb := SS.basis.orthonormalized(); var STb := ST.basis.orthonormalized()
	# rest globals, both skeletons (skeleton space)
	var src_rest := {}
	for bi in ssk.get_bone_count():
		var par := ssk.get_bone_parent(bi)
		src_rest[ssk.get_bone_name(bi)] = (src_rest[ssk.get_bone_name(par)] as Transform3D) * ssk.get_bone_rest(bi) if par >= 0 else ssk.get_bone_rest(bi)
	var tgt_rest := {}
	for bi in skel.get_bone_count():
		var par := skel.get_bone_parent(bi)
		tgt_rest[bi] = (tgt_rest[par] as Transform3D) * skel.get_bone_rest(bi) if par >= 0 else skel.get_bone_rest(bi)
	# per mapped bone: the swing from the target's rest direction (to its child) onto the source's, in the world
	var corr := {}; var tb_of := {}
	for s_name in MAP:
		var ti := skel.find_bone(MAP[s_name])
		if ti < 0 or not src_rest.has(s_name): continue
		tb_of[s_name] = ti
	for s_name in tb_of:
		var ti: int = tb_of[s_name]
		var c := Basis()
		var t_child := -1; var s_child := ""
		for s2 in tb_of: if skel.get_bone_parent(tb_of[s2]) == ti: t_child = tb_of[s2]; s_child = s2; break
		if t_child >= 0:
			var dt: Vector3 = STb * ((tgt_rest[t_child] as Transform3D).origin - (tgt_rest[ti] as Transform3D).origin)
			var ds: Vector3 = SSb * ((src_rest[s_child] as Transform3D).origin - (src_rest[s_name] as Transform3D).origin)
			if dt.length_squared() > 1e-10 and ds.length_squared() > 1e-10: c = Basis(Quaternion(dt.normalized(), ds.normalized()))
		corr[s_name] = c
	# leaves (hands, head, toes) take their parent's swing
	for s_name in tb_of:
		var has_child := false
		for s2 in tb_of: if skel.get_bone_parent(tb_of[s2]) == tb_of[s_name]: has_child = true
		if not has_child:
			var pt := skel.get_bone_parent(tb_of[s_name])
			for s2 in tb_of: if tb_of[s2] == pt: corr[s_name] = corr[s2]
	var frames := _src_frames(clip)
	var anim := Animation.new(); anim.length = (frames.size() - 1) / FPS; anim.loop_mode = Animation.LOOP_LINEAR
	var rot_tr := {}
	for s_name in tb_of:
		var i := anim.add_track(Animation.TYPE_ROTATION_3D); anim.track_set_path(i, NodePath(track_prefix + ":" + MAP[s_name])); rot_tr[s_name] = i
	var hips_i := -1
	if tb_of.has("DEF-hips"):
		hips_i = anim.add_track(Animation.TYPE_POSITION_3D); anim.track_set_path(hips_i, NodePath(track_prefix + ":Hips"))
	var hs: float = (SS * (src_rest["DEF-hips"] as Transform3D).origin).y if src_rest.has("DEF-hips") else 1.0
	var ht: float = (ST * (tgt_rest[tb_of.get("DEF-hips", 0)] as Transform3D).origin).y if tb_of.has("DEF-hips") else 1.0
	var k_h := ht / hs if absf(hs) > 1e-5 else 1.0
	for f in frames.size():
		var pose: Dictionary = frames[f]; var t := f / FPS
		var gt := {} # target bone index -> skeleton-space basis
		for s_name in tb_of:
			var gs_w: Basis = SSb * (pose[s_name] as Transform3D).basis.orthonormalized()
			var gs_rest_w: Basis = SSb * (src_rest[s_name] as Transform3D).basis.orthonormalized()
			var gt_rest_w: Basis = STb * (tgt_rest[tb_of[s_name]] as Transform3D).basis.orthonormalized()
			var w: Basis = gs_w * gs_rest_w.inverse() * (corr[s_name] as Basis) * gt_rest_w
			gt[tb_of[s_name]] = STb.inverse() * w
		for s_name in tb_of:
			var ti: int = tb_of[s_name]
			var par := skel.get_bone_parent(ti)
			var pb: Basis = (gt[par] as Basis) if gt.has(par) else ((tgt_rest[par] as Transform3D).basis.orthonormalized() if par >= 0 else Basis())
			anim.rotation_track_insert_key(rot_tr[s_name], t, (pb.inverse() * (gt[ti] as Basis)).get_rotation_quaternion())
		if hips_i >= 0:
			var d_w: Vector3 = SS.basis * ((pose["DEF-hips"] as Transform3D).origin - (src_rest["DEF-hips"] as Transform3D).origin) * k_h
			var hi: int = tb_of["DEF-hips"]
			var gpos: Vector3 = (tgt_rest[hi] as Transform3D).origin + ST.basis.inverse() * d_w
			var par := skel.get_bone_parent(hi)
			var lpos: Vector3 = (tgt_rest[par] as Transform3D).affine_inverse() * gpos if par >= 0 else gpos
			anim.position_track_insert_key(hips_i, t, lpos)
	_baked[key] = anim
	return anim
