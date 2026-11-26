extends SceneTree
## The farmyard from overhead (<out>): the house, barn, coop and the way between. Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var C: Vector3 = main.extras.C
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		var st: Vector3 = C + Vector3(-8.0, 0, -4.0)
		main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); main.rig.yaw = 0.0; main.rig.pitch = 1.35; main.rig.dist = 36.0
		await process_frame
	main.player.avatar.root.visible = false
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
