extends SceneTree
## A native camp from above (<out>): the lodges, the warriors, the folk. Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var c = main.camp.list[0]
	print("camp: %d lodges, %d warriors (%s), %d folk, land %.0f m" % [c.lodges.size(), c.warriors.size(), ", ".join(c.warriors.map(func(w): return w.fig.name)), c.folk.size(), NativeCamps.R])
	main.camp.list[0].peace_until = 999 # (a gift: let us look without a fight)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		var st: Vector3 = (c.warriors.filter(func(w): return w.fig.name.begins_with("cgc_warrior"))[0].fig.root.position + Vector3(0, 0, 4)) if OS.get_cmdline_user_args().has("close") and c.warriors.any(func(w): return w.fig.name.begins_with("cgc_warrior")) else c.at + Vector3(0, 0, 4)
		main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); main.rig.yaw = 0.0; main.rig.pitch = (0.2 if OS.get_cmdline_user_args().has("close") else 0.85); main.rig.dist = (12.0 if OS.get_cmdline_user_args().has("close") else 42.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
