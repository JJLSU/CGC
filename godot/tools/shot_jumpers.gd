extends SceneTree
## A claim jumpers' camp, close up (<out>): their tent and fire, the men in their re-dyed clothes.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.45
	var c: Dictionary = main.jumpers.camps[0]
	var off: Vector3 = c.at + Vector3(0, 0, 45)
	main.player.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z)
	main.jumpers.camps[0].men = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500: await process_frame
	main.hud.visible = false; main.post.set_shader_parameter("dof_enabled", 0.0)
	main.player.pos = Vector3(c.at.x, Terrain.get_height(c.at.x, c.at.z + 12.0), c.at.z + 12.0)
	main.rig.yaw = 0.0; main.rig.pitch = 0.32; main.rig.dist = 11.0; main.rig.snap()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
