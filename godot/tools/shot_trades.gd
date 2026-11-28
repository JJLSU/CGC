extends SceneTree
## Settlers at their trades' own motions from the library (<out>): the miller pushing, the brickmaker kneeling at his
## work, the beekeeper reaching in, beside a woodcutter's swing. Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var p: Vector3 = main.player.pos
	var figs := []
	var who := [["folk_ezra", "Push"], ["folk_luther", "Fixing_Kneeling"], ["cgc_woman_plumstripe", "Interact"], ["folk_silas", ""]]
	for i in who.size():
		var f := ModelFigure.new(who[i][0] if ModelFigure.has_folk(who[i][0]) else "cgc_man_elder"); f.work_ual = who[i][1]; f.work_tool = "axe" if i == 3 else "hammer"
		var q := p + Vector3(-3.0 + i * 2.0, 0, 1.2); q.y = Terrain.get_height(q.x, q.z)
		f.root.position = q; f.root.rotation.y = PI / 2.0; main.add_child(f.root); figs.append(f)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500:
		for f in figs: f.update(1.0 / 60.0, 0.0, "work")
		main.player.avatar.root.visible = false
		main.rig.yaw = PI; main.rig.pitch = 0.12; main.rig.dist = 7.0
		await process_frame
	print("work clips: ", figs.map(func(f): return f.current))
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
