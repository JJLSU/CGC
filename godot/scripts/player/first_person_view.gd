class_name FirstPersonView
extends Node3D
## The tool in hand as seen through the farmer's own eyes (the first-person camera option): its own copy of the made
## model (Avatar.MADE) on the camera, low at the right. A gun points ahead, comes up to the middle while you aim and
## kicks when it fires; an axe, pick or spear rides with its haft forward, head up, and chops down across the view when
## you swing. A slight bob as you walk. No shadow of its own (his body casts the real one).

var models := {}           ## MADE key -> Node3D holder
var shown := ""
var t := 0.0
var aim_k := 0.0           ## 0 at rest, 1 raised to aim
const REST := Vector3(0.3, -0.3, -0.55)
const AIM := Vector3(0.0, -0.17, -0.5)

func _holder(key: String) -> Node3D:
	if models.has(key): return models[key]
	models[key] = null
	var spec: Array = Avatar.MADE.get(key, [])
	if spec.is_empty(): return null
	var path := "res://assets/models/props/%s.glb" % spec[0]
	if not ResourceLoader.exists(path): return null
	var m := (load(path) as PackedScene).instantiate() as Node3D
	PaperMats.paperize(m, false)
	for c in m.find_children("*", "GeometryInstance3D", true, false): (c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var k: float = float(spec[1]) / 1.9
	var holder := Node3D.new(); var pivot := Node3D.new(); holder.add_child(pivot); pivot.add_child(m)
	if key in ["revolver", "rifle", "rifle_lever", "shotgun"]:
		# along the view, muzzle ahead: model -x to the camera's -z (its x to +z), y up; the grip at the pivot
		m.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)) * k, Vector3(0, -0.04, -float(spec[2]) * k + (0.25 if key != "revolver" else 0.0)))
	else:
		# a haft: its foot at the pivot, the handle (model y) reaching forward and up, the head's blade (model +x) leading
		var b := Basis(Vector3.RIGHT, -1.05) * Basis(Vector3.UP, PI / 2.0)
		m.transform = Transform3D(b * k, b * Vector3(0, -float(spec[2]) * 0.0, 0) * k)
		pivot.position = Vector3(0, 0, 0.1)
	add_child(holder); holder.visible = false
	models[key] = holder
	return holder

## Each frame through his eyes: key the held made tool ("" for none), aiming (a gun raised), swing (0..1 through a
## chop, < 0 none), casting (> 0 just after a shot), speed (walking pace).
func update(dt: float, key: String, aiming: bool, swing: float, casting: float, speed: float) -> void:
	t += dt
	var h: Node3D = _holder(key) if key != "" else null
	if shown != key:
		if models.get(shown) != null: (models[shown] as Node3D).visible = false
		shown = key
	if h == null: return
	h.visible = true
	var gun: bool = key in ["revolver", "rifle", "rifle_lever", "shotgun"]
	aim_k = move_toward(aim_k, 1.0 if aiming and gun else 0.0, dt * 6.0)
	var bob := sin(t * 9.0) * 0.012 * clampf(speed / 6.0, 0.0, 1.0) * (1.0 - aim_k)
	h.position = REST.lerp(AIM, aim_k) + Vector3(bob * 0.5, absf(bob), 0)
	var pivot := h.get_child(0) as Node3D
	if gun: pivot.rotation = Vector3(casting * 0.5, 0.0, 0.0) # (the kick)
	else: pivot.rotation = Vector3(-sin(clampf(swing, 0.0, 1.0) * PI) * 1.2 if swing >= 0.0 else 0.0, 0.0, 0.0) # (the chop)

func hide_all() -> void:
	for k in models: if models[k] != null: (models[k] as Node3D).visible = false
	shown = ""
