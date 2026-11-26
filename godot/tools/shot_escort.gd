extends SceneTree
## The hired escort at your heels by a claim jumpers' camp (<out>). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main._hire_escort(main.forts.forts[0])
	var jc: Dictionary = main.jumpers.camps[0]; var st: Vector3 = jc.at + Vector3(26, 0, 0)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000:
		main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); main.player.health = 100.0; main.player.dead = false
		main.rig.yaw = PI / 2.0 + 0.5; main.rig.pitch = 0.3; main.rig.dist = 13.0
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
