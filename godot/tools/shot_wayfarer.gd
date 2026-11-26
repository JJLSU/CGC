extends SceneTree
## A wayfarer's camp (<out>; the kind after it, e.g. widow). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]; var kind: String = args[1] if args.size() > 1 else "widow"
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var c = main.wayfarers.camps.filter(func(q): return q.kind.id == kind)[0]
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		var st: Vector3 = c.at + Vector3(4.5, 0, 4.5)
		main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); main.rig.yaw = 0.8; main.rig.pitch = 0.32; main.rig.dist = 9.0
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
