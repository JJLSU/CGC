extends Node3D
## A gallery of every baked prop kind on the printed page, plus one card built at runtime by CardMesh, for checking
## the bake by eye (tools/shot.gd -- res://scenes/tests/props_gallery.tscn out.png).

const KINDS := ["pine", "pine~1", "pine~2", "maple", "goldtree", "appletree", "birch", "sagetree", "snag",
	"bush", "bush~1", "bush~2", "flowers", "flowers~1", "flowers~2", "grass", "rock", "rock~1", "rock~2", "ore",
	"quartz", "silver", "log", "lodge", "mushroom", "clay", "hive", "sang", "geode", "pearl", "amber", "apples",
	"satchel", "bale", "stook", "corn", "pumpkin", "cattail", "lilypad", "lilybloom", "signvein", "signgrove", "signthicket", "hill", "peak"]

func _ready() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfe0e8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("c9b08a"); e.ambient_light_energy = 0.35
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.light_energy = 1.1; sun.light_color = Color(1, 0.94, 0.84); sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -55, 0); add_child(sun)
	RenderingServer.global_shader_parameter_set("paper_key_dir", sun.global_basis.z)
	var fill := DirectionalLight3D.new(); fill.light_energy = 0.25; fill.rotation_degrees = Vector3(-30, 160, 0); add_child(fill)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 60); ground.mesh = pm
	ground.material_override = PaperMats.paper(Color("c8c6a6")); add_child(ground)
	var cols := 9
	for i in KINDS.size():
		var k = PropKinds.get_kind(KINDS[i])
		if k == null: print("MISSING ", KINDS[i]); continue
		var mi := MeshInstance3D.new(); mi.mesh = k.mesh; mi.material_override = k.material
		var sc := 0.5 if KINDS[i] == "hill" or KINDS[i] == "peak" else 1.0
		mi.scale = Vector3.ONE * sc
		mi.position = Vector3((i % cols - cols / 2.0) * 3.2, 0, (i / cols) * 3.6 - 8.0)
		add_child(mi)
	# a runtime card: a ragged sign board
	var pts := PackedVector2Array([Vector2(-0.6, 0), Vector2(0.6, 0.02), Vector2(0.62, 0.7), Vector2(-0.58, 0.68)])
	var card := MeshInstance3D.new(); card.mesh = CardMesh.build(pts, 0.05)
	card.material_override = PaperMats.card(load("res://assets/baked/props/signvein.png"), {"flip": true})
	card.position = Vector3(13, 0.3, 10); add_child(card)
	var cam := Camera3D.new(); cam.fov = 30; add_child(cam)
	cam.position = Vector3(0, 34, 40); cam.look_at(Vector3(0, 0, 2)); cam.current = true
