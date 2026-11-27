class_name SayCard
extends Label3D
## A line called out, on a torn paper card over a speaker's head (the bosses', Dusty Jake's, the robbers'): ink on cream,
## facing the camera, up for a few seconds. say(text) shows it; tick(dt, at) keeps it over him and lets it go.

var t := 0.0

static func make(width_m := 3.3) -> SayCard:
	var c := SayCard.new()
	c.billboard = BaseMaterial3D.BILLBOARD_ENABLED; c.font_size = 64; c.pixel_size = 0.0042
	c.modulate = Color("3a2f25"); c.outline_size = 0; c.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS; c.render_priority = 10
	var sf := SystemFont.new(); sf.font_names = PackedStringArray(["Patrick Hand", "Segoe Print", "Comic Sans MS"]); c.font = sf
	var back := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(width_m, 0.5); back.mesh = qm; back.position.z = -0.02
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color("f4ecd8"); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; bm.render_priority = 9
	back.material_override = bm; back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; c.add_child(back)
	c.visible = false
	return c

func say(line: String, sec := 2.6) -> void:
	text = line; t = sec
	# the paper as wide as the words (and a margin), so a long shout never runs off its edge
	var tw: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * pixel_size
	var bk := get_child(0) as MeshInstance3D
	if bk: (bk.mesh as QuadMesh).size = Vector2(tw + 0.5, 0.5)

func tick(dt: float, at: Vector3) -> void:
	t -= dt; visible = t > 0.0
	if visible: global_position = at
