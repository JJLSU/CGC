extends SceneTree
## Tools in hand, close: three townsfolk swinging a hammer, a pick and an axe beside the player, caught through the
## swing (<out>_0.._3). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var p: Vector3 = main.player.pos
	var figs := []
	var names := ["cgc_man_suspenders", "cgc_woman_blueapron", "cgc_man_gaunt_young"]
	var tools := ["hammer", "pick", "axe"]
	for i in [int(OS.get_environment("GRIP_I")) if OS.get_environment("GRIP_I") != "" else 1]:
		var f := ModelFigure.new(names[i] if ModelFigure.has_folk(names[i]) else "folk_player"); f.work_tool = tools[i]
		var q := p + Vector3(0, 0, 2.6); q.y = Terrain.get_height(q.x, q.z)
		f.root.position = q; f.root.rotation.y = float(OS.get_environment("GRIP_YAW")) if OS.get_environment("GRIP_YAW") != "" else PI / 2.0; main.add_child(f.root); figs.append(f)
	var t0 := Time.get_ticks_msec(); var n := 0
	while n < 4:
		var dt := 1.0 / 60.0
		for f in figs: f.update(dt, 0.0, "swing")
		main.rig.yaw = PI; main.rig.pitch = 0.12; main.rig.dist = 4.0; main.player.avatar.root.visible = false
		await process_frame
		var el := Time.get_ticks_msec() - t0
		if el > 3000 + n * 120:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % n)); n += 1
	quit()
