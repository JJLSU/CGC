extends SceneTree
## The made tools in the farmer's hand (the player's tools-and-weapons set): each in turn, close up from his right side,
## saved as <out>_<key>.png; prints which ones showed as their own model. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var base: Vector3 = main.spawn + Vector3(6, 0, 9)
	var shown := 0
	var cases := [["axe", [], "hatchet"], ["axe", ["stoneaxe"], "axe_stone"], ["axe", ["ironaxe"], "axe_iron"], ["axe", ["steelaxe"], "axe_steel"], ["pick", ["pickaxe"], "pick_stone"],
		["pick", ["ironpick"], "pick_iron"], ["pick", ["steelpick"], "pick_steel"], ["spear", ["spear"], "spear"], ["revolver", ["revolver"], "revolver"], ["rifle", ["rifle"], "rifle"]]
	for c in cases:
		main.tools = {}
		for t in c[1]: main.tools[t] = true
		main.tools[c[0]] = true; main.held = c[0]
		for i in 40:
			main.player.pos = base; main.player.vel = Vector3.ZERO; main.player.facing = 0.0
			await process_frame
		var av: Avatar = main.player.avatar
		var ok: bool = (av._made_on == null) if c[2] == "hatchet" else (av._made_on != null and av._made_on.visible and av.made.get(c[2]) == av._made_on)
		if ok: shown += 1
		print("%s: own model in hand %s" % [c[2], ok])
		main.set_process(false)
		var cam: Camera3D = main.rig.camera; var p: Vector3 = av.root.global_position
		var side: Vector3 = av.root.global_basis.x.normalized(); var fwd: Vector3 = av.root.global_basis.z.normalized()
		var g: Vector3 = av.fist.global_position if c[0] in ["revolver", "rifle"] else av.grip.global_position if av._made_on == null or av._made_on.get_parent() == av.grip else av._made_on.global_position
		cam.global_position = g + side * -1.3 + fwd * 0.9 + Vector3(0, 0.45, 0); cam.look_at(g + Vector3(0, 0.15, 0), Vector3.UP); cam.fov = 45.0
		await process_frame; await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % c[2]))
		main.set_process(true); cam.fov = 30.0
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("MADE TOOLS %d of %d shown" % [shown, cases.size()])
	quit(0 if shown == cases.size() else 1)
