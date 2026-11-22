extends SceneTree
## Night grading probe (20d): a night view far from any lamp, with the sky's light levels, to set against the web's.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	var p: Player = main.player
	var x := float(OS.get_cmdline_user_args()[1]); var z := float(OS.get_cmdline_user_args()[2])
	p.pos = Vector3(x, Terrain.get_height(x, z), z); main.sky.time = 0.92
	main.rig.yaw = 0.35; main.rig.pitch = 0.46; main.rig.dist = 15.0; main.rig.snap()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	var S: DaySky = main.sky
	print("night %.2f expo %.2f hemi %.2f sun %.2f %s fill %.2f %s" % [S.night, main.expo, S.hemi_intensity, S.sun.light_energy, S.sun.light_color.to_html(false), S.fill.light_energy, S.fill.light_color.to_html(false)])
	quit()
