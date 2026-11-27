extends SceneTree
## Through his eyes with the box-built tools (no Meshy model): the old hatchet (<out>_axe), the fishing pole (<out>_rod),
## the bow at rest (<out>_bow) and drawn (<out>_bowaim). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var at: Vector3 = main.spawn + Vector3(4, 0, 6)
	for i in 30: main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); await process_frame
	main.rig.pitch = 0.1
	main.input.pressed["KeyV"] = true
	main.tools["rod"] = true; main.tools["bow"] = true
	for c in [["axe", false, "axe"], ["rod", false, "rod"], ["bow", false, "bow"], ["bow", true, "bowaim"]]:
		main.pick_tool(c[0]); main.input.mouse_down = c[1]
		for i in 30: main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); await process_frame
		print("%s: shown '%s'" % [c[2], main.fp_view.shown if main.fp_view else "-"])
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % c[2]))
	main.input.mouse_down = false
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
