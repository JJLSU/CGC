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

## Borrow a clip from another figure on the same skeleton (the same bone names), re-pointed at this one's skeleton:
## the farmer's model has no run, the warriors' do (the player's ask: he should run when he sprints).
func borrow_clip(clip: String, from_model: String) -> bool:
	if player == null or skeleton == null or player.has_animation(clip) or not has_folk(from_model): return false
	var src: Node3D = (load(BASE + from_model + ".glb") as PackedScene).instantiate()
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
	var scene: PackedScene = load(BASE + model_name + ".glb")
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
	elif speed > 0.3: play("walk", 0.25, clampf(speed / 1.4, 0.6, 2.0))
	else: play("idle", 0.4)

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
