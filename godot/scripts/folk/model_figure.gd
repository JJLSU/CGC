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

func _init(model_name: String, spec := {}) -> void:
	name = model_name
	root.add_child(turn); turn.add_child(body)
	if spec.has("scale"): root.scale = Vector3.ONE * float(spec.scale)
	var scene: PackedScene = load_model(BASE + model_name + ".glb")
	model = scene.instantiate() as Node3D
	PaperMats.paperize(model, false, float(spec.get("hue", 0.0)))
	body.add_child(model)
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

func play(clip: String, fade := 0.25, time_scale := 1.0) -> void:
	if player == null: return
	if not player.has_animation(clip): clip = "idle" if player.has_animation("idle") else player.get_animation_list()[0]
	player.speed_scale = time_scale * rate if clip == "idle" else time_scale
	if clip == current: return
	player.play(clip, fade)
	current = clip

## speed in m/s; pose as for the paper figures ("swing", "sit", "work", "dance"...).
func update(dt: float, speed := 0.0, pose = null) -> void:
	t += dt; phase += dt * (2.4 + speed * 1.9)
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
		_tool_node.rotation.x = PI / 2.0; _tool_node.position = Vector3(0, 0, 0.12); h.add_child(_tool_node)
	_tool_node.visible = working
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
		if player: for a in player.get_animation_list(): if String(a).begins_with("x_"): _extras.append(a)
		_ex_wait = 4.0 + randf() * 12.0
	if _ex_left > 0.0:
		_ex_left -= dt
		if _ex_left > 0.0: return
		play("idle", 0.5); _ex_wait = 7.0 + randf() * 11.0; return
	if _extras.is_empty(): play("idle", 0.4); return
	_ex_wait -= dt
	if _ex_wait > 0.0: play("idle", 0.4); return
	var clip: String = _extras[randi() % _extras.size()]
	play(clip, 0.45); _ex_left = minf(player.get_animation(clip).length, 9.0)
