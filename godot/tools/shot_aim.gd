extends SceneTree
## A trooper and an outlaw bringing their guns up at a mark beside them (the player: those rifles were backwards):
## seen from the side mid-aim (<out>). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var p: Vector3 = main.player.pos
	var figs := []
	for i in 2:
		var f := ModelFigure.new(ArmyForts.SOLDIERS[0] if i == 0 else "cgc_man_outlaw_cowboy")
		if i == 0: f.hands[1].add_child(ArmyForts.rifle())
		else: var g := Boss._colt_mesh(0.5); g.position = Vector3(0, 0.02, 0.04); f.hands[1].add_child(g)
		var q := p + Vector3(-1.2 + i * 2.4, 0, 2.0); q.y = Terrain.get_height(q.x, q.z)
		f.root.position = q; f.root.rotation.y = -PI / 2.0; main.add_child(f.root); figs.append(f)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500:
		for f in figs:
			f.update(1.0 / 60.0, 0.0, null)
			var aa := AimArm.on(f); if aa: aa.raise(f.root.position + Vector3(-8, 1.3, 0), 0.5)
		main.player.avatar.root.visible = false
		main.rig.yaw = PI; main.rig.pitch = 0.1; main.rig.dist = 5.0
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
