class_name ModelFigure
extends RefCounted
## modelfolk.js ModelFigure: a rigged figure from the reference art (assets/models/folk/<name>.glb), printed on card
## (no snow on folk), optionally re-dyed (hue, radians: clothes turn, skin/hair/leather never do), playing its own
## clips (idle, walk, work, wave, dance, sit). Each figure idles at its own pace from its own point in the clip, so
## no two folk breathe in step. root > turn > body > model, as the web's groups; hands are holders on the hand bones.

const POSE_CLIP := {"cast": "wave", "work": "work", "dance": "dance", "cancan": "dance", "sit": "sit", "beckon": "wave", "clipboard": "idle", "fiddle": "idle"}
const BASE := "res://assets/models/folk/"

var name: String
var root := Node3D.new()
var turn := Node3D.new()
var body := Node3D.new()
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var hands: Array = []      ## [left, right] BoneAttachment3D holders (or the body)
var head: Node3D
var current := ""
var rate := 1.0
var phase := 0.0
var t := 0.0

const RUN_AT := 8.0 ## m/s: faster than this, a figure with a run clip runs (the farmer walks at 6, sprints at 11.5)

static func has_folk(n: String) -> bool: return ResourceLoader.exists(BASE + n + ".glb")

## A model, safely: main preloads every model on background threads at the start; asking for one the ordinary way
## while its background load is still going came back empty now and then (the player: a mended building's keeper
## was only a floating "hello"). So a model already loading is waited for and taken from that load.
static func load_model(path: String) -> PackedScene:
	if ResourceLoader.has_cached(path): return load(path)
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS or st == ResourceLoader.THREAD_LOAD_LOADED:
		var r = ResourceLoader.load_threaded_get(path) # (waits for it)
		if r is PackedScene: return r
	return load(path)

## Borrow a clip from another figure on the same skeleton (the same bone names), re-pointed at this one's skeleton:
## the farmer's model has no run, the warriors' do (the player's ask: he should run when he sprints).
func borrow_clip(clip: String, from_model: String) -> bool:
	if player == null or skeleton == null or player.has_animation(clip) or not has_folk(from_model): return false
	var src: Node3D = load_model(BASE + from_model + ".glb").instantiate()
	var aps := src.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty() or not (aps[0] as AnimationPlayer).has_animation(clip): src.free(); return false
	var anim: Animation = (aps[0] as AnimationPlayer).get_animation(clip).duplicate(true)
	src.free()
	var to_skel := String(player.get_node(player.root_node).get_path_to(skeleton))
	for i in anim.get_track_count():
		var path := anim.track_get_path(i)
		var bone := path.get_concatenated_subnames()
		if bone != "" and skeleton.find_bone(bone) >= 0: anim.track_set_path(i, NodePath(to_skel + ":" + bone))
	anim.loop_mode = Animation.LOOP_LINEAR
	var lib := player.get_animation_library("")
	if lib == null: lib = AnimationLibrary.new(); player.add_animation_library("", lib)
	lib.add_animation(clip, anim)
	return true

## Clips from Quaternius's library (UAL), retargeted onto this figure's rig, added as u_<clip> (false if none could be).
func add_ual(clips: Array) -> bool:
	if player == null or skeleton == null: return false
	var lib := player.get_animation_library("")
	if lib == null: return false
	var prefix := String(player.get_node(player.root_node).get_path_to(skeleton))
	var any := false
	for c in clips:
		if player.has_animation("u_" + c) or not UAL.has_clip(c): continue
		var a := UAL.clip_for(name, skeleton, model, prefix, c)
		if a != null: lib.add_animation("u_" + c, a); any = true
	return any

func _init(model_name: String, spec := {}) -> void:
	name = model_name
	root.add_child(turn); turn.add_child(body)
	if spec.has("scale"): root.scale = Vector3.ONE * float(spec.scale)
	var scene: PackedScene = load_model(BASE + model_name + ".glb")
	model = scene.instantiate() as Node3D
	PaperMats.paperize(model, false, float(spec.get("hue", 0.0)))
	body.add_child(model)
	# not drawn past ~65 m (scaled with a giant): a figure there is a few pixels tall, and each is ~20k triangles, drawn
	# again for every shadow slice; a town full of them cost the GPU dearly (spec "far" to set another distance)
	var far_m: float = float(spec.get("far", 65.0)) * maxf(1.0, float(spec.get("scale", 1.0)))
	for gi in model.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).visibility_range_end = far_m; (gi as GeometryInstance3D).visibility_range_end_margin = 5.0
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	player = aps[0] if aps.size() else null
	if player:
		for a in player.get_animation_list(): player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var sks := model.find_children("*", "Skeleton3D", true, false)
	skeleton = sks[0] if sks.size() else null
	hands = [_attach(["LeftHand"]), _attach(["RightHand"])]
	head = _attach(["Head"])
	# (a figure rigged but never animated: the standard clips lent by another of the same sex on the same skeleton)
	if player and skeleton and not player.has_animation("idle"):
		var donor := "cgc_woman_calico" if (model_name.begins_with("cgc_woman") or model_name.begins_with("cgc_saloon") or model_name.begins_with("cgc_girl")) else "cgc_man_elder"
		for c in ["idle", "walk", "wave", "work", "dance", "sit", "run"]: borrow_clip(c, donor)
		if not player.has_animation("run"): borrow_clip("run", "folk_native_warrior")
	rate = 0.85 + randf() * 0.3
	play("idle", 0.0)
	if player and player.has_animation("idle"): player.seek(randf() * player.get_animation("idle").length, true)

func _attach(bone_names: Array) -> Node3D:
	if skeleton == null: return body
	for bn in bone_names:
		var i := skeleton.find_bone(bn)
		if i >= 0:
			var att := BoneAttachment3D.new(); att.bone_name = bn; skeleton.add_child(att)
			var holder := Node3D.new(); att.add_child(holder)
			return holder
	return body

## Each figure's own way of standing and walking (the player: lots of people use the same animations, mix them up):
## the idle it rests in, picked once from the idles its model has (the library's Idle, or the everyday extras' Idle
## 3-6), and its own pace through its walk and run (gait, +-12%), on top of the idle's own rate.
var rest_idle := ""
var gait := 0.88 + randf() * 0.24
func _rest() -> String:
	if rest_idle != "" or player == null: return rest_idle if rest_idle != "" else "idle"
	var opts := ["idle"]
	for c in ["x_idle_a", "x_idle_b", "u_Idle"]: if player.has_animation(c): opts.append(c)
	rest_idle = opts[randi() % opts.size()]
	if not player.has_animation(rest_idle): rest_idle = "idle"
	return rest_idle

func play(clip: String, fade := 0.25, time_scale := 1.0) -> void:
	if player == null: return
	if clip == "idle": clip = _rest()
	elif clip == "walk": clip = walk_clip
	elif clip == "sit": clip = sit_clip
	elif clip == "work": clip = work_clip
	elif clip == "_plain": clip = "idle" # (the library's Idle itself, as one of a figure's turns)
	if not player.has_animation(clip): clip = "idle" if player.has_animation("idle") else player.get_animation_list()[0]
	player.speed_scale = time_scale * rate if clip == _rest() else (time_scale * gait if clip == walk_clip or clip == "run" else time_scale)
	if clip == current: return
	player.play(clip, fade)
	current = clip

## speed in m/s; pose as for the paper figures ("swing", "sit", "work", "dance"...).
## The library's clips (UAL) baked onto this figure's rig a little after it's made, one kind of figure a frame across
## the town (each ~15 ms, so never at the start in one lump); then its own walk, way of sitting and idle are drawn
## again from the wider set.
var walk_clip := "walk"
var sit_clip := "sit"
var work_clip := "work"
## A library clip for this figure's work in place of the tool swing (a trade that doesn't chop or dig: the player
## asked for more different animations): "Fixing_Kneeling", "Interact", "Push"... "" keeps the swing.
var work_ual := ""
## A library clip this figure always rests in, in place of a drawn idle (a gunman standing guard: "Pistol_Idle").
var rest_ual := ""
var _ual_done := false
static var _ual_frame := -1
func _ual_life() -> void:
	_ual_done = true
	if skeleton == null or skeleton.find_bone("Spine02") < 0 or skeleton.find_bone("LeftUpLeg") < 0: return # (a Meshy folk rig only)
	if name.begins_with("folk_jim") or name == "folk_player": return # (the farmer himself keeps his own walk)
	_ual_frame = Engine.get_process_frames()
	if not add_ual(["Walk", "Walk_Formal", "Idle", "Idle_Talking", "Sitting_Idle"] + ([work_ual] if work_ual != "" else []) + ([rest_ual] if rest_ual != "" else [])): return
	if work_ual != "" and player.has_animation("u_" + work_ual): work_clip = "u_" + work_ual
	var r := randf()
	walk_clip = "walk" if r < 0.4 else ("u_Walk" if r < 0.75 else "u_Walk_Formal")
	if randf() < 0.4: sit_clip = "u_Sitting_Idle"
	rest_idle = ""; _extras = null
	if rest_ual != "" and player.has_animation("u_" + rest_ual): rest_idle = "u_" + rest_ual
	if current == "idle" or current.begins_with("x_idle") or current == "walk" or current == "sit" or current == "work": current = "" # (picked up again next frame)

func update(dt: float, speed := 0.0, pose = null) -> void:
	t += dt; phase += dt * (2.4 + speed * 1.9)
	if OS.get_environment("NO_UAL") == "" and not _ual_done and t > 0.5 and _ual_frame != Engine.get_process_frames(): _ual_life()
	_hold_true()
	if pose == "swing" and player and player.has_animation("work"): play("work", 0.08, player.get_animation("work").length / 0.55)
	elif pose != null and POSE_CLIP.has(pose): play(POSE_CLIP[pose])
	elif speed > RUN_AT and player and player.has_animation("run"): play("run", 0.2, clampf(speed / 9.0, 0.8, 1.6))
	elif speed > 0.3: play("walk", 0.25, clampf(speed / 1.4, 0.6, 2.0)); _ex_left = 0.0
	else: _idle_life(dt)
	_work_tool_show() # (after the clip's chosen: shown for the swing, put away the moment it ends)
	_keep_feet(dt, pose)

## Feet on the ground (the player: some folks' feet were in it): a few of the clips drop the hips, sinking the soles
## through the floor in a wide stance; each frame the lowest toe is measured and the body lifted just enough that the
## soles rest on the ground under the figure. Never pulled down; not while sitting (or, for the farmer, riding, swimming).
var ground_feet := true
var _toes: Array = []
var _lift := 0.0
func _keep_feet(dt: float, pose) -> void:
	if skeleton == null or not root.is_inside_tree(): return
	if _toes.is_empty():
		for b in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
			var i := skeleton.find_bone(b)
			if i >= 0: _toes.append([i, 0.035 if b.ends_with("ToeBase") else 0.085]) # (the bone's point above the sole)
		if _toes.is_empty(): _toes = [[-1, 0.0]]
	if _toes[0][0] < 0: return
	var want := 0.0
	if ground_feet and pose != "sit":
		var k := root.global_transform.basis.get_scale().y
		# (each toe against whichever is higher under it: the figure's own footing, or the ground itself, so the uphill
		# foot on a slope doesn't sink either)
		for tb in _toes:
			var q: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(tb[0])).origin
			var floor_y := maxf(root.global_position.y, Terrain.get_height(q.x, q.z))
			want = maxf(want, floor_y - (q.y - float(tb[1]) * k - _lift)) # (what it'd sink by, unlifted)
		want = minf(want, 0.35 * k) # (a sane bound)
	_lift = lerpf(_lift, want, minf(1.0, dt * 12.0))
	body.position.y = _lift

## Things held in the hands at the figure's own size: Meshy's skeletons are in centimetres, so a hand holder on a
## bone sits at a world scale of 0.01 and a rifle or spear put in it shrank to nothing. Each frame the holders undo
## that, leaving what they hold scaled as the figure itself is (a giant's pick giant-sized).
func _hold_true() -> void:
	if not root.is_inside_tree(): return
	var want := root.global_transform.basis.get_scale().x
	for h in hands + [head]:
		var att := (h as Node3D).get_parent()
		if not att is BoneAttachment3D: continue
		var ps: float = (att as Node3D).global_transform.basis.get_scale().x
		if ps > 1e-6 and absf(ps * h.scale.x - want) > want * 0.02: h.scale = Vector3.ONE * (want / ps)

## A tool in hand for the work swing (the player: anybody chopping needs a tool): when a figure plays its work clip
## with nothing else in its right hand, an axe, a pickaxe or a hammer (work_tool) appears there, gone between swings.
var work_tool := "hammer"
var _tool_node: Node3D = null
func _work_tool_show() -> void:
	if hands.size() < 2: return
	var working := current == "work"
	if _tool_node == null:
		if not working: return
		var h: Node3D = hands[1]
		if h.get_child_count() > 0: return # (already holding something of its own: a pick, a rifle, a club)
		match work_tool:
			"axe": _tool_node = Boss._axe_mesh(0.8)
			"pick": _tool_node = Boss._pick_mesh(0.8)
			_: _tool_node = _hammer_mesh()
		_tool_node.transform = grip_xf(); h.add_child(_tool_node)
	_tool_node.visible = working; fist(false, working)
## Where a tool sits in the right hand's holder (the player: many if not all folk with tools didn't hold them right:
## the haft ran up the forearm and stood off the back of the hand). The rigs have no finger bones: the hand bone runs
## wrist to fingertips along its +y, the palm on its -z. A haft held in the fist crosses the hand square, through the
## palm a little down from the wrist, its head out on the thumb's side (forward when the arm hangs) and its working
## face (the hammer's, the pick's point, the axe's edge) along the knuckles. For the box-built tools (handle along
## +z from the grip, head at the far end, working toward +y).
var _thumb := [0.0, 0.0]
func grip_xf(left := false) -> Transform3D:
	var k := 0 if left else 1
	if _thumb[k] == 0.0:
		_thumb[k] = 1.0
		var hi := skeleton.find_bone("LeftHand" if left else "RightHand") if skeleton else -1
		if hi >= 0:
			# in the rest (T) pose, palm down, the thumb points forward (the figure's +z)
			var bx := skeleton.get_bone_global_rest(hi).basis.x
			_thumb[k] = 1.0 if bx.z >= 0.0 else -1.0
	var s: float = _thumb[k]
	return Transform3D(Basis(Vector3(0, 0, -s), Vector3(0, 1, 0), Vector3(s, 0, 0)), Vector3(0, 0.05, -0.03))

## Put a tool (handle along its +z from the grip, head on ahead, working toward +y) in a hand, in the fist; extra:
## turned or slid further in the grip's own frame (a walking staff stood up, a spear held at its balance).
func hold(tool: Node3D, left := false, extra := Transform3D.IDENTITY) -> void:
	tool.transform = grip_xf(left) * extra
	hands[0 if left else 1].add_child(tool)
	fist(left, true)

## The open hand closed round a handle (FistHand: the straight fingers drawn in), or let open again.
var _fists := [null, null]
func fist(left: bool, on: bool) -> void:
	if skeleton == null: return
	var k := 0 if left else 1
	if _fists[k] == null:
		if not on: return
		var bi := skeleton.find_bone("LeftHand" if left else "RightHand")
		if bi < 0: return
		var f := FistHand.new(); f.bone = bi; skeleton.add_child(f); _fists[k] = f
	(_fists[k] as FistHand).on = on

static func _hammer_mesh() -> Node3D:
	var g := Node3D.new()
	var hd := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.022; cm.bottom_radius = 0.026; cm.height = 0.42; cm.radial_segments = 6
	hd.mesh = cm; hd.material_override = PaperMats.paper(Color("8a6038")); hd.rotation.x = PI / 2.0; hd.position = Vector3(0, 0, 0.11); g.add_child(hd)
	var head := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.07, 0.2, 0.08)
	head.mesh = bm; head.material_override = PaperMats.paper(Color("6a6d72")); head.position = Vector3(0, 0.04, 0.3); g.add_child(head)
	return g

## Standing about, now and then a clip of its own (the player's ask: more different idles and actions; the everyday
## extras x_* from tools/meshy_extras.py: another idle, a shrug, talking, a drink, a look round, a wave...), once
## through, then back to its idle; every 7-18 s, each figure on its own clock.
var _extras = null
var _ex_wait := 0.0
var _ex_left := 0.0
func _idle_life(dt: float) -> void:
	if _extras == null:
		_extras = []
		if player: for a in player.get_animation_list(): if (String(a).begins_with("x_") or String(a) in ["u_Idle", "u_Idle_Talking"]) and String(a) != _rest(): _extras.append(a)
		if _rest() != "idle" and player and player.has_animation("idle"): _extras.append("_plain") # (the plain Idle now one of its turns)
		_ex_wait = 4.0 + randf() * 12.0
	if _ex_left > 0.0:
		_ex_left -= dt
		if _ex_left > 0.0: return
		play("idle", 0.5); _ex_wait = 7.0 + randf() * 11.0; return
	if _extras.is_empty(): play("idle", 0.4); return
	_ex_wait -= dt
	if _ex_wait > 0.0: play("idle", 0.4); return
	var clip: String = _extras[randi() % _extras.size()]
	play(clip, 0.45); _ex_left = minf(player.get_animation("idle" if clip == "_plain" else clip).length, 9.0)
