extends SceneTree
## The farmer's own tools in his fist, seen from his right side, close: for each of the pick, the iron axe, the hammer
## and the spear, standing (<out>_<tool>_0) and mid-swing (<out>_<tool>_1). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	for k in ["pick", "ironpick", "axe", "ironaxe", "hammer", "spear"]: main.tools[k] = true
	for tl in ["pick", "axe", "hammer", "spear"]:
		main.pick_tool(tl)
		for f in 2:
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 1500:
				var face: float = main.player.avatar.root.rotation.y
				main.rig.yaw = face - PI / 2.0; main.rig.pitch = 0.12; main.rig.dist = 3.2
				await process_frame
			if f == 1:
				main.player.avatar.start_swing()
				while main.player.avatar.swing >= 0.0 and main.player.avatar.swing < 0.3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s_%d.png" % [tl, f]))
	quit()
