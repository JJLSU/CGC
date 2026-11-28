extends SceneTree
## A gunman resting in the library's Pistol_Idle with his Colt (<out>), beside one in his own idle. Windowed.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var p: Vector3 = main.player.pos
	var figs := []
	for i in 2:
		var f := ModelFigure.new("cgc_man_outlaw_cowboy")
		var g := Boss._colt_mesh(0.5); g.position = Vector3(0, 0.02, 0.04); f.hands[1].add_child(g)
		if i == 0: f.rest_ual = "Pistol_Idle"
		var q := p + Vector3(-1.0 + i * 2.0, 0, 1.5); q.y = Terrain.get_height(q.x, q.z)
		f.root.position = q; f.root.rotation.y = PI + 0.5; main.add_child(f.root); figs.append(f)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		for f in figs: f.update(1.0 / 60.0, 0.0, null)
		main.player.avatar.root.visible = false
		main.rig.yaw = PI; main.rig.pitch = 0.1; main.rig.dist = 5.0
		await process_frame
	print("resting in: ", figs.map(func(f): return f.current))
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
