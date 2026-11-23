extends SceneTree
## A line-up of figure models, labelled in order (names after --), side by side on open ground: <out> (from the args'
## first). To tell who's who.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]; var names: Array = Array(args).slice(1)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await process_frame
	main.hud.visible = false; main.post.set_shader_parameter("dof_enabled", 0.0)
	main.player.pos = main.spawn + Vector3(6, 0, 8); main.player.pos.y = Terrain.get_height(main.player.pos.x, main.player.pos.z)
	main.rig.yaw = 1.2; main.rig.pitch = 0.12; main.rig.dist = 9.0; main.rig.snap()
	await process_frame
	var cam: Vector3 = main.rig.camera.global_position; var to_cam := Vector3(cam.x - main.player.pos.x, 0, cam.z - main.player.pos.z).normalized()
	var across := Vector3(-to_cam.z, 0, to_cam.x)
	var base: Vector3 = main.player.pos + to_cam * 4.0
	for i in names.size():
		var f := ModelFigure.new(names[i])
		var q := base + across * (i - (names.size() - 1) / 2.0) * 1.1
		f.root.position = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z); f.root.rotation.y = atan2(to_cam.x, to_cam.z)
		main.add_child(f.root)
	main.player.avatar.root.visible = false
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("order: ", names)
	quit()
