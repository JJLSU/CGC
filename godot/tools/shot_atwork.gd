extends SceneTree
## The hired hands at their work a few seconds after a game loads by day (<out>_<id> for a few of them): they start
## at their work now, not a minute's walk off at home. Run with CGC_SAVE_PATH set to a copy of a played save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	for id in ["ezra", "luther", "clem", "silas"]:
		var q = null
		for s in main.settlers.list: if s.S.id == id: q = s
		if q == null: continue
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000:
			var fp: Vector3 = q.folk.root.position + Vector3(2.5, 0, 2.5)
			main.player.pos = Vector3(fp.x, Terrain.get_height(fp.x, fp.z), fp.z); main.player.avatar.root.visible = false
			main.rig.yaw = PI / 4.0; main.rig.pitch = 0.3; main.rig.dist = 5.0
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % id))
	quit()
