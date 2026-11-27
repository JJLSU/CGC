class_name Puppet
extends RefCounted
## puppets.js: the animals. A paper model (body, head, legs on pivots, ears, tail: printed die-cut cards) baked from
## the web (assets/baked/puppets/<kind>.glb), or, where the reference art has the beast, the rigged model worn in its
## place, sized to the paper shell exactly as the web fits it (puppets.json: turn scale, the lift to its lowest toe).
## The walk and run clips blend by speed; legs swing, heads nod and graze (hens peck), ears twitch, tails flick, the
## rig bobs and leans and lunges; the puppet turns smoothly to face the way it actually moves.

static var INFO := {}
static var _scenes := {}

var name: String
var kind: String
var gait := "walk"
var group := Node3D.new()
var flip := Node3D.new()
var rig := Node3D.new()
var body: Node3D
var head: Node3D
var legs: Array = []
var ears: Array = []
var tail: Node3D
var model: Node3D
var tree: AnimationTree
var mw := 0.0
var rw := 0.0
var heading = null
var _last := Vector3.ZERO
var _has := false
var phase := randf() * 6.0
var t := randf() * 10.0
var graze := 0.0
var lop = null ## {roll, drop}: a lopsided beast (the gouger), its short legs drawn by a LopLegs modifier

static func _info() -> Dictionary:
	if INFO.is_empty(): INFO = JSON.parse_string(FileAccess.open("res://assets/baked/puppets/puppets.json", FileAccess.READ).get_as_text())
	return INFO

## kind: the species key (hen, cow, calf, donkey...).
## wear_of: another kind whose model this one wears (the sidehill gouger wears the bramble boar's).
func _init(k: String, scale := 1.0, wear_of := "") -> void:
	kind = k
	var info: Dictionary = _info().get(k, {})
	name = info.get("name", k); gait = info.get("gait", "walk")
	group.add_child(flip); flip.add_child(rig)
	rig.scale = Vector3.ONE * scale
	if wear_of != "" and _info().get(wear_of, {}).get("model") != null: _wear(_info()[wear_of].model)
	elif info.get("model") != null: _wear(info.model)
	else: _paper()
	if head == null: head = Node3D.new(); rig.add_child(head)
	_wear_still()

## The farm's hens and rooster and the wild turkeys as the player's Meshy birds (still models: no rig), in place of the
## paper cut-outs: [model, height before the puppet's own scale]. The paper parts stay (they still drive the gait) but
## aren't drawn; each peck dips the whole bird forward.
const STILL := {"hen": ["animal_hen", 0.42], "rooster": ["animal_rooster", 0.55], "turkey": ["animal_turkey", 0.62]}
var still: Node3D = null
func _wear_still() -> void:
	if not STILL.has(kind) or model != null: return
	var path := "res://assets/models/props/%s.glb" % STILL[kind][0]
	if not ResourceLoader.exists(path): return
	for c in rig.get_children(): if c is Node3D: (c as Node3D).visible = false
	head.visible = false
	var piv := Node3D.new(); rig.add_child(piv)
	var m := ModelBake.still(path, float(STILL[kind][1]), 1); m.rotation.y = PI / 2.0 # (its face to the puppet's +x, the way it goes)
	piv.add_child(m); still = piv

static func _unown(n: Node) -> void:
	n.owner = null
	for c in n.get_children(): _unown(c)

func _paper() -> void:
	var path := "res://assets/baked/puppets/%s.glb" % kind
	if not _scenes.has(path): _scenes[path] = load(path)
	var src := (_scenes[path] as PackedScene).instantiate() as Node3D
	# the baked group is the puppet's group > flip > rig: lift the rig's parts (body, legs, head, tail) into ours
	var r: Node = src.find_child("body", true, false).get_parent()
	for c in r.get_children():
		r.remove_child(c); _unown(c); rig.add_child(c)
	src.free()
	body = rig.find_child("body", false, false)
	head = rig.find_child("head", false, false)
	tail = rig.find_child("tail", false, false)
	var i := 0
	while true:
		var l := rig.find_child("leg%d" % i, false, false)
		if l == null: break
		legs.append(l); i += 1
	i = 0
	while true:
		var e := head.find_child("ear%d" % i, true, false) if head else null
		if e == null: break
		ears.append(e); i += 1
	_skin(rig)

func _skin(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null: continue
			mi.set_surface_override_material(s, PaperMats.card(src.albedo_texture, {"albedo": src.albedo_color, "snow": 0.0}) if src.albedo_texture else PaperMats.paper(src.albedo_color, false))
	for c in n.get_children(): _skin(c)

func _wear(m: Dictionary) -> void:
	var path := "res://assets/models/animals/%s.glb" % m.model
	if not ResourceLoader.exists(path): path = "res://assets/models/props/%s.glb" % m.model
	if not _scenes.has(path): _scenes[path] = load(path)
	var inst := (_scenes[path] as PackedScene).instantiate() as Node3D
	PaperMats.paperize(inst, false)
	var turn := Node3D.new(); turn.rotation.y = m.turnRotY; turn.scale = Vector3.ONE * float(m.turnScale)
	inst.position.y = m.posY
	turn.add_child(inst); rig.add_child(turn); model = inst
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size():
		var ap: AnimationPlayer = aps[0]
		for a in ap.get_animation_list(): ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		# walk and run blended by speed, easing back to the standing pose when still (an empty clip = the rest pose)
		var lib := ap.get_animation_library("")
		if not lib.has_animation("rest"): lib.add_animation("rest", Animation.new())
		var bt := AnimationNodeBlendTree.new()
		var still := AnimationNodeAnimation.new(); still.animation = "rest"
		var walk := AnimationNodeAnimation.new(); walk.animation = "walk" if ap.has_animation("walk") else ap.get_animation_list()[0]
		var run := AnimationNodeAnimation.new(); run.animation = "run" if ap.has_animation("run") else walk.animation
		var ws := AnimationNodeTimeScale.new(); var rs := AnimationNodeTimeScale.new()
		var gr := AnimationNodeBlend2.new(); var mv := AnimationNodeBlend2.new()
		bt.add_node("still", still); bt.add_node("walk", walk); bt.add_node("run", run)
		bt.add_node("ws", ws); bt.add_node("rs", rs); bt.add_node("gait", gr); bt.add_node("move", mv)
		bt.connect_node("ws", 0, "walk"); bt.connect_node("rs", 0, "run")
		bt.connect_node("gait", 0, "ws"); bt.connect_node("gait", 1, "rs")
		bt.connect_node("move", 0, "still"); bt.connect_node("move", 1, "gait")
		bt.connect_node("output", 0, "move")
		tree = AnimationTree.new(); tree.tree_root = bt
		inst.add_child(tree)
		tree.anim_player = tree.get_path_to(ap)
		tree.active = true

## speed m/s; state idle | walk | flee | chase | attack; yaw_to_cam (the broadside facing before it first moves).
func update(dt: float, speed: float, state: String, left: bool, yaw_to_cam: float, lunge := 0.0) -> void:
	t += dt
	if tree:
		var fast := speed > (1.2 if gait == "hop" else 3.2) or state == "flee" or state == "chase"
		mw += ((1.0 if speed > 0.15 else 0.0) - mw) * minf(1.0, dt * 6.0)
		rw += ((1.0 if fast else 0.0) - rw) * minf(1.0, dt * 4.0)
		tree.set("parameters/move/blend_amount", mw)
		tree.set("parameters/gait/blend_amount", rw)
		tree.set("parameters/ws/scale", clampf(speed / 1.4, 0.5, 1.8))
		tree.set("parameters/rs/scale", clampf(speed / 4.0, 0.6, 1.6))
	var moving := speed > 0.15
	phase += dt * (8.0 if gait == "hop" else 6.0 + speed * 1.3) * (1.0 if moving else 0.2)
	var s := sin(phase)
	var bob := 0.0; var lean := 0.0
	if gait == "hop":
		bob = maxf(0.0, sin(phase)) * (0.32 if state == "flee" else 0.14) if moving else 0.0
		lean = -cos(phase) * 0.12 if moving else 0.0
		for l in legs: l.rotation.z = ((-1.0 if l.position.x < 0 else 0.5) * maxf(0.0, cos(phase)) * 0.9) if moving else 0.0
	else:
		var amp := minf(0.75, 0.25 + speed * 0.07) if moving else 0.0
		for i in legs.size():
			var diag := 0.0 if (i == 0 or i == 3) else PI
			legs[i].rotation.z = sin(phase + diag) * amp
		bob = absf(cos(phase)) * 0.03 * minf(2.0, speed / 2.0) if moving else 0.0
	if not moving and state == "idle": graze = minf(1.0, graze + dt * 0.8)
	else: graze = maxf(0.0, graze - dt * 3.0)
	var peck := maxf(0.0, sin(t * 5.0)) * 0.6 if gait == "peck" else 0.0
	head.rotation.z = -graze * (peck if gait == "peck" else 0.7) + (s * 0.05 if moving else sin(t * 0.7) * 0.04) - lunge * 0.5
	if still: still.rotation.z = head.rotation.z * 0.4 # (the Meshy bird dips to peck, sways as it goes)
	for e in ears: e.rotation.z = sin(t * 1.7 + phase) * 0.12 + (-0.4 if state == "flee" else 0.0)
	if tail: tail.rotation.z = sin(t * 9.0) * 0.25 if (state == "chase" or state == "attack") else sin(t * 2.3) * 0.15 + (0.6 if state == "flee" else 0.0)
	rig.position = Vector3(lunge * 0.3, bob, 0)
	rig.rotation.z = lean - lunge * 0.15
	if lop != null: rig.rotation.x = lop.roll; rig.position.y -= lop.drop # (listing toward its short legs, paws on the ground)
	# face the way it's going (a quarter-turn a beat); till it first moves, broadside to the camera
	var pos := group.position
	if _has:
		var dx := pos.x - _last.x; var dz := pos.z - _last.z; var d2 := dx * dx + dz * dz
		if d2 > 1e-6 and d2 < 4.0:
			var want := atan2(dx, dz) - PI / 2.0
			if heading == null: heading = want
			var dh: float = want - heading; dh = atan2(sin(dh), cos(dh))
			heading += dh * minf(1.0, dt * 6.0)
	_last = pos; _has = true
	flip.rotation.y = heading if heading != null else yaw_to_cam + (PI if left else 0.0)

## How far it stands up: 1 standing, 0 pressed flat and spread on the page.
func set_fold(f: float) -> void:
	flip.scale.y = 0.06 + 0.94 * maxf(0.0, f); flip.scale.z = 1.0 + 0.6 * (1.0 - clampf(f, 0.0, 1.0))
